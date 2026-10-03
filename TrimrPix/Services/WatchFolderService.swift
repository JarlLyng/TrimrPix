//
//  WatchFolderService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service responsible for monitoring folders for new images.
///
/// Implements `WatchFolderServiceProtocol` for dependency injection and testing.
///
/// Concurrency model: the service is `@MainActor`-isolated, so all of its mutable
/// state (`isWatching`, `watchedPath`, `processedFiles`, the dispatch source and the
/// debounce/scan tasks) lives on the main actor and is free of data races. The
/// `DispatchSource` event handler runs on a background queue and hops back to the
/// main actor. The only blocking work — directory scanning and image optimization —
/// runs in a detached task that captures Sendable values exclusively.
@MainActor
final class WatchFolderService: NSObject, WatchFolderServiceProtocol, ObservableObject {

    // MARK: - Published Properties

    @Published var isWatching: Bool = false
    @Published var watchedPath: String = ""

    // MARK: - Private Properties

    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private let fileManager: any FileManagerProtocol
    private let compressionService: any CompressionServiceProtocol
    private let settings: any SettingsProtocol
    private let logger: any LoggerProtocol
    // No "webp": macOS cannot write WebP, so those files can only be skipped, and a
    // watched folder has no way to explain that to anyone. Better not to pick them up.
    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "avif", "heic", "heif", "pdf"]
    private var debounceTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var processedFiles: Set<String> = [] // Track processed files to avoid re-processing
    /// A change arrived while a scan was running; scan again once it finishes.
    private var rescanRequested = false
    /// Identifies the current scan, so a scan cancelled by stop/start cannot clear its successor.
    private var scanGeneration = 0
    /// How many scans in a row found a file empty. See `maxEmptyChecks`.
    private var emptyChecks: [String: Int] = [:]

    private static let debounceNanoseconds: UInt64 = 1_000_000_000 // 1s
    private static let maxProcessedFiles = 1000
    /// An empty file is looked at this many times before it is given up on, so a file that
    /// stays at zero bytes cannot keep the folder scanning forever.
    private static let maxEmptyChecks = 10

    /// What one look at a file came to.
    enum FileOutcome: Sendable {
        /// Optimized, or failed for a reason that waiting will not change. Not looked at again.
        case handled
        /// Its size changed while we waited, so it is still being written. Looked at again.
        case stillWriting
        /// Zero bytes, and still zero after the wait. Looked at again, a limited number of times.
        case empty
    }

    // MARK: - Initialization

    /// Initializes the watch folder service with dependencies
    /// - Parameters:
    ///   - fileManager: File manager protocol instance (defaults to FileManager.default)
    ///   - compressionService: Compression service protocol instance
    ///   - settings: Settings protocol instance (defaults to Settings.shared)
    ///   - logger: Logger protocol instance (defaults to Logger.shared)
    init(
        fileManager: any FileManagerProtocol = FileManager.default,
        compressionService: (any CompressionServiceProtocol)? = nil,
        settings: any SettingsProtocol = Settings.shared,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.fileManager = fileManager
        self.compressionService = compressionService ?? CompressionService()
        self.settings = settings
        self.logger = logger
        super.init()
    }

    // MARK: - Public Methods

    /// Starts monitoring a folder for new images
    /// - Parameter path: The folder path to monitor
    /// - Throws: TrimrPixError if monitoring setup fails
    func startWatching(path: String) throws {
        logger.info("Attempting to start watching folder: \(path)")

        // Validate path
        guard !path.isEmpty else {
            let error = TrimrPixError.invalidFilePath(path)
            logger.error("Invalid watch path (empty): \(error.technicalDescription)")
            throw error
        }

        guard fileManager.fileExists(atPath: path) else {
            let error = TrimrPixError.watchFolderNotFound(path)
            logger.error("Watch folder not found: \(error.technicalDescription)")
            throw error
        }

        // Stop any existing watch
        stopWatching()

        // Open file descriptor for watching
        let url = URL(fileURLWithPath: path)
        let fileDescriptor = open(url.path, O_EVTONLY)

        guard fileDescriptor != -1 else {
            let error = TrimrPixError.watchFolderSetupFailed(path, underlyingError: nil)
            logger.error("Failed to open watch path: \(error.technicalDescription)")
            throw error
        }

        // Create file system watcher
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )

        // Both handlers run on the source's background queue. They must be @Sendable:
        // written inside this @MainActor class, a plain closure is inferred to be
        // main-actor isolated, and Swift 6 checks that at runtime and traps when the
        // background queue calls it. That crashed the app on the first change in the
        // watched folder, and again when watching stopped.
        source.setEventHandler { @Sendable [weak self] in
            Task { @MainActor in
                self?.handleFileSystemEvent()
            }
        }

        source.setCancelHandler { @Sendable in
            close(fileDescriptor)
        }

        fileSystemWatcher = source
        source.resume()

        isWatching = true
        watchedPath = path

        logger.info("Successfully started watching folder: \(path)")
    }

    /// Stops monitoring the current folder
    func stopWatching() {
        guard isWatching else { return }

        logger.info("Stopping watch folder monitoring")

        // Cancel pending debounce / scan work
        debounceTask?.cancel()
        debounceTask = nil
        scanTask?.cancel()
        scanTask = nil

        // Cancel file system watcher
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil

        isWatching = false
        watchedPath = ""

        // Clear processed files tracking
        processedFiles.removeAll()
        emptyChecks.removeAll()
        rescanRequested = false

        logger.info("Stopped watching folder")
    }

    // MARK: - Private Methods

    /// Checks if a file has already been processed
    /// - Parameter fileKey: The file path to check
    /// - Returns: True if the file has been processed
    private func isFileProcessed(_ fileKey: String) -> Bool {
        return processedFiles.contains(fileKey)
    }

    /// Marks a file as processed
    /// - Parameter fileKey: The file path to mark
    private func markFileAsProcessed(_ fileKey: String) {
        processedFiles.insert(fileKey)

        // Limit the size of the processed files set to prevent memory growth.
        // Keep only the most recent entries.
        if processedFiles.count > Self.maxProcessedFiles {
            let toRemove = processedFiles.prefix(processedFiles.count - Self.maxProcessedFiles)
            processedFiles.subtract(toRemove)
        }
    }

    /// Handles file system events with debouncing
    private func handleFileSystemEvent() {
        // Restart the debounce window on every event.
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.processNewFiles()
        }
    }

    /// Processes new files in the watched folder.
    ///
    /// Snapshots the values needed for the scan on the main actor, then performs the
    /// blocking directory read and image optimization in a detached task that captures
    /// only Sendable values.
    private func processNewFiles() {
        guard !watchedPath.isEmpty else {
            logger.warning("Process new files called but watched path is empty")
            return
        }

        // One scan at a time. A second scan alongside the first picks up files the first
        // has not reached or marked yet, and optimizes them twice. The optimized output
        // landing in the folder is itself a change, so this happened on ordinary batches.
        guard scanTask == nil else {
            rescanRequested = true
            return
        }

        // Snapshot Sendable values on the main actor before doing background work.
        let path = watchedPath
        let delaySeconds = settings.watchFolderDelay
        let extensions = supportedExtensions
        let compressionSettings = settings.compressionSnapshot
        let compressionService = self.compressionService
        let logger = self.logger
        scanGeneration += 1
        let generation = scanGeneration

        logger.debug("Processing new files in watched folder: \(path)")

        scanTask = Task.detached { [weak self] in
            var lookAgain = false

            let contents: [String]
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: path)
            } catch {
                let trimmedError = TrimrPixError.watchFolderSetupFailed(path, underlyingError: error)
                logger.error("Error reading watch folder contents: \(trimmedError.technicalDescription)")
                contents = []
            }

            let imageFiles = contents.filter { file in
                let fileExtension = (file as NSString).pathExtension.lowercased()
                // Filter out output files (e.g., *-optimized.*) to prevent a re-optimization loop.
                let filename = (file as NSString).deletingPathExtension
                let isOutputFile = filename.contains("-optimized")
                return extensions.contains(fileExtension) && !isOutputFile
            }

            logger.debug("Found \(imageFiles.count) image file(s) in watched folder (excluding output files)")

            for imageFile in imageFiles {
                if Task.isCancelled { break }

                let fullPath = URL(fileURLWithPath: path).appendingPathComponent(imageFile)
                let fileKey = fullPath.path

                // Skip if already processed (state lives on the main actor).
                if await self?.isFileProcessed(fileKey) == true {
                    logger.debug("Skipping already processed file: \(imageFile)")
                    continue
                }

                let outcome = await WatchFolderService.processImageFile(
                    at: fullPath,
                    delaySeconds: delaySeconds,
                    settings: compressionSettings,
                    compressionService: compressionService,
                    logger: logger
                )
                if await self?.record(outcome, for: fileKey) == true {
                    lookAgain = true
                }
            }

            await self?.scanFinished(generation: generation, lookAgain: lookAgain && !Task.isCancelled)
        }
    }

    /// Records what a look at a file came to. Returns true if it should be looked at again.
    ///
    /// Only a file that was actually dealt with is marked processed. Marking a file that was
    /// skipped because it was still being written lost it for good: finishing a copy changes
    /// the file, not the folder, so no further event came to pick it up.
    private func record(_ outcome: FileOutcome, for fileKey: String) -> Bool {
        switch outcome {
        case .handled:
            emptyChecks[fileKey] = nil
            markFileAsProcessed(fileKey)
            return false
        case .stillWriting:
            emptyChecks[fileKey] = nil
            return true
        case .empty:
            let checks = (emptyChecks[fileKey] ?? 0) + 1
            guard checks < Self.maxEmptyChecks else {
                logger.debug("Giving up on empty file: \((fileKey as NSString).lastPathComponent)")
                emptyChecks[fileKey] = nil
                markFileAsProcessed(fileKey)
                return false
            }
            emptyChecks[fileKey] = checks
            return true
        }
    }

    /// Ends a scan, and starts the next one if a change arrived meanwhile or a file was not
    /// ready. The second matters on its own: a file still being copied produces no folder
    /// event when the copy finishes, so nothing else would bring the scan back to it.
    private func scanFinished(generation: Int, lookAgain: Bool) {
        // A scan cancelled by stopWatching (and perhaps a new start) must not touch its successor.
        guard generation == scanGeneration else { return }
        scanTask = nil
        guard isWatching else { return }
        if rescanRequested || lookAgain {
            rescanRequested = false
            handleFileSystemEvent()
        }
    }

    /// Processes a single image file from the watched folder.
    ///
    /// `nonisolated` so it runs off the main actor; it takes its collaborators as
    /// Sendable parameters rather than reading isolated instance state.
    /// - Parameters:
    ///   - url: The URL of the image file to process
    ///   - delaySeconds: The delay in seconds to wait for file stability
    ///   - compressionService: The compression service to optimize with
    ///   - logger: The logger to report progress/errors with
    nonisolated private static func processImageFile(
        at url: URL,
        delaySeconds: Double,
        settings: CompressionSettings,
        compressionService: any CompressionServiceProtocol,
        logger: any LoggerProtocol
    ) async -> FileOutcome {
        logger.debug("Processing image file: \(url.lastPathComponent)")

        // Check if the file is still being written to (size changes).
        let initialSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            initialSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read initial file size: \(error.technicalDescription)")
            return .handled // gone, most likely; nothing to wait for
        }

        // Wait for the file to stabilize.
        let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch {
            logger.warning("Task sleep interrupted")
            return .stillWriting // cancelled; the scan that asked is ending anyway
        }

        // Check final size.
        let finalSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            finalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read final file size: \(error.technicalDescription)")
            return .handled
        }

        // Only process if the file size is stable.
        guard initialSize == finalSize else {
            logger.debug("File size not stable for: \(url.lastPathComponent), looking again later")
            return .stillWriting
        }
        guard finalSize > 0 else {
            logger.debug("File is empty: \(url.lastPathComponent), looking again later")
            return .empty
        }

        logger.info("Processing new image from watch folder: \(url.lastPathComponent)")

        // Optimize the image.
        do {
            let optimizedURL = try await compressionService.optimizeImage(at: url, settings: settings)
            logger.info("Successfully optimized image from watch folder: \(optimizedURL.lastPathComponent)")
        } catch let error as TrimrPixError {
            logger.error("Failed to optimize image from watch folder: \(error.technicalDescription)")
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: url, underlyingError: error)
            logger.error("Failed to optimize image from watch folder: \(trimmedError.technicalDescription)")
        }
        // Failures included: a WebP or a PDF with text is refused every time, so trying again
        // would only repeat the same message.
        return .handled
    }

    // MARK: - Deinitialization

    deinit {
        // Best-effort teardown. The owning view model calls stopWatching() explicitly;
        // here we only cancel the GCD source and pending tasks (all safe to cancel from
        // any thread) so the file descriptor is released if the service is torn down
        // without an explicit stop.
        debounceTask?.cancel()
        scanTask?.cancel()
        fileSystemWatcher?.cancel()
    }
}
