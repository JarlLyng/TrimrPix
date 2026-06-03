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
    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "webp", "avif", "heic", "heif"]
    private var debounceTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var processedFiles: Set<String> = [] // Track processed files to avoid re-processing

    private static let debounceNanoseconds: UInt64 = 1_000_000_000 // 1s
    private static let maxProcessedFiles = 1000

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

        // The handler fires on a background queue; hop to the main actor to touch state.
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.handleFileSystemEvent()
            }
        }

        source.setCancelHandler {
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

        // Snapshot Sendable values on the main actor before doing background work.
        let path = watchedPath
        let delaySeconds = settings.watchFolderDelay
        let extensions = supportedExtensions
        let compressionSettings = settings.compressionSnapshot
        let compressionService = self.compressionService
        let logger = self.logger

        logger.debug("Processing new files in watched folder: \(path)")

        scanTask = Task.detached { [weak self] in
            let contents: [String]
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: path)
            } catch {
                let trimmedError = TrimrPixError.watchFolderSetupFailed(path, underlyingError: error)
                logger.error("Error reading watch folder contents: \(trimmedError.technicalDescription)")
                return
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
                if Task.isCancelled { return }

                let fullPath = URL(fileURLWithPath: path).appendingPathComponent(imageFile)
                let fileKey = fullPath.path

                // Skip if already processed (state lives on the main actor).
                if await self?.isFileProcessed(fileKey) == true {
                    logger.debug("Skipping already processed file: \(imageFile)")
                    continue
                }

                await WatchFolderService.processImageFile(
                    at: fullPath,
                    delaySeconds: delaySeconds,
                    settings: compressionSettings,
                    compressionService: compressionService,
                    logger: logger
                )
                await self?.markFileAsProcessed(fileKey)
            }
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
    ) async {
        logger.debug("Processing image file: \(url.lastPathComponent)")

        // Check if the file is still being written to (size changes).
        let initialSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            initialSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read initial file size: \(error.technicalDescription)")
            return
        }

        // Wait for the file to stabilize.
        let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch {
            logger.warning("Task sleep interrupted")
            return
        }

        // Check final size.
        let finalSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            finalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read final file size: \(error.technicalDescription)")
            return
        }

        // Only process if the file size is stable.
        guard initialSize == finalSize, initialSize > 0 else {
            logger.debug("File size not stable for: \(url.lastPathComponent), skipping")
            return
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
