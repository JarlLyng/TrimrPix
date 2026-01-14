//
//  WatchFolderService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

/// Service responsible for monitoring folders for new images
/// Implements WatchFolderServiceProtocol for dependency injection and testing
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
    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "webp", "avif"]
    private var debounceWorkItem: DispatchWorkItem?
    private var processedFiles: Set<String> = [] // Track processed files to avoid re-processing
    
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
        fileSystemWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )
        
        fileSystemWatcher?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        
        fileSystemWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileSystemWatcher?.resume()
        
        // Update published properties
        DispatchQueue.main.async {
            self.isWatching = true
            self.watchedPath = path
        }
        
        logger.info("Successfully started watching folder: \(path)")
    }
    
    /// Stops monitoring the current folder
    func stopWatching() {
        guard isWatching else { return }
        
        logger.info("Stopping watch folder monitoring")
        
        // Cancel debounce work item
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        
        // Cancel file system watcher
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil
        
        // Update published properties
        DispatchQueue.main.async {
            self.isWatching = false
            self.watchedPath = ""
        }
        
        logger.info("Stopped watching folder")
        
        // Clear processed files tracking
        Task { @MainActor in
            self.processedFiles.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks if a file has already been processed
    /// - Parameter fileKey: The file path to check
    /// - Returns: True if the file has been processed
    @MainActor
    private func isFileProcessed(_ fileKey: String) -> Bool {
        return processedFiles.contains(fileKey)
    }
    
    /// Marks a file as processed
    /// - Parameter fileKey: The file path to mark
    @MainActor
    private func markFileAsProcessed(_ fileKey: String) {
        processedFiles.insert(fileKey)
        
        // Limit the size of processed files set to prevent memory growth
        // Keep only the most recent 1000 entries
        if processedFiles.count > 1000 {
            let toRemove = processedFiles.prefix(processedFiles.count - 1000)
            processedFiles.subtract(toRemove)
        }
    }
    
    /// Handles file system events with debouncing
    private func handleFileSystemEvent() {
        // Cancel previous debounce work item
        debounceWorkItem?.cancel()
        
        // Create new debounce work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.processNewFiles()
        }
        
        debounceWorkItem = workItem
        
        // Schedule work item with delay (1 second debounce)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// Processes new files in the watched folder
    @objc private func processNewFiles() {
        guard !watchedPath.isEmpty else {
            logger.warning("Process new files called but watched path is empty")
            return
        }
        
        logger.debug("Processing new files in watched folder: \(watchedPath)")
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Copy settings values on main actor before background work to avoid data races
            let delaySeconds = await MainActor.run {
                self.settings.watchFolderDelay
            }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(atPath: self.watchedPath)
                let imageFiles = contents.filter { file in
                    let fileExtension = (file as NSString).pathExtension.lowercased()
                    // Filter out output files (e.g., *-optimized.*) to prevent re-optimization loop
                    let filename = (file as NSString).deletingPathExtension
                    let isOutputFile = filename.contains("-optimized")
                    
                    return self.supportedExtensions.contains(fileExtension) && !isOutputFile
                }
                
                logger.debug("Found \(imageFiles.count) image file(s) in watched folder (excluding output files)")
                
                for imageFile in imageFiles {
                    let fullPath = URL(fileURLWithPath: self.watchedPath).appendingPathComponent(imageFile)
                    let fileKey = fullPath.path
                    
                    // Skip if already processed
                    if await self.isFileProcessed(fileKey) {
                        logger.debug("Skipping already processed file: \(imageFile)")
                        continue
                    }
                    
                    await self.processImageFile(at: fullPath, delaySeconds: delaySeconds)
                    await self.markFileAsProcessed(fileKey)
                }
            } catch {
                let trimmedError = TrimrPixError.watchFolderSetupFailed(self.watchedPath, underlyingError: error)
                self.logger.error("Error reading watch folder contents: \(trimmedError.technicalDescription)")
            }
        }
    }
    
    /// Processes a single image file from the watched folder
    /// - Parameters:
    ///   - url: The URL of the image file to process
    ///   - delaySeconds: The delay in seconds to wait for file stability (copied from settings to avoid data race)
    private func processImageFile(at url: URL, delaySeconds: Double) async {
        logger.debug("Processing image file: \(url.lastPathComponent)")
        
        // Check if file is still being written to (size changes)
        let initialSize: Int64
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            initialSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read initial file size: \(error.technicalDescription)")
            return
        }
        
        // Wait for file to stabilize (using copied delay value to avoid data race)
        let delayNanoseconds = UInt64(delaySeconds * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        } catch {
            logger.warning("Task sleep interrupted")
            return
        }
        
        // Check final size
        let finalSize: Int64
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            finalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            let error = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.warning("Could not read final file size: \(error.technicalDescription)")
            return
        }
        
        // Only process if file size is stable
        guard initialSize == finalSize, initialSize > 0 else {
            logger.debug("File size not stable for: \(url.lastPathComponent), skipping")
            return
        }
        
        logger.info("Processing new image from watch folder: \(url.lastPathComponent)")
        
        // Optimize the image
        do {
            let optimizedURL = try await compressionService.optimizeImage(at: url)
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
        stopWatching()
    }
}
