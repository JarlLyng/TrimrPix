//
//  ImageOptimizationViewModel.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import SwiftUI
import StoreKit
import UniformTypeIdentifiers

/// ViewModel responsible for managing image optimization operations
/// Coordinates between UI, compression service, and watch folder service
@MainActor
final class ImageOptimizationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// List of images to be optimized
    @Published var images: [ImageItem] = []
    
    /// Indicates whether optimization is in progress
    @Published var isOptimizing: Bool = false
    
    /// Error message to display to the user
    @Published var errorMessage: String?
    
    /// Indicates whether error alert should be shown
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    
    private let compressionService: any CompressionServiceProtocol
    private let watchFolderService: any WatchFolderServiceProtocol
    private let settings: any SettingsProtocol
    private let logger: any LoggerProtocol
    
    // MARK: - Security-Scoped Resources
    
    /// Tracks security-scoped resource access for dropped files
    /// Maps image ID to whether access was granted
    private var securityScopedAccess: [UUID: Bool] = [:]

    /// The watch-folder URL we started security-scoped access on, if any.
    /// Kept so `stopWatchFolder()` can balance the `startAccessingSecurityScopedResource()`
    /// call and avoid leaking a security-scope reference on each start.
    private var watchFolderScopedURL: URL?
    
    // MARK: - Initialization
    
    /// Initializes the view model with dependencies
    /// - Parameters:
    ///   - compressionService: Compression service protocol instance
    ///   - watchFolderService: Watch folder service protocol instance
    ///   - settings: Settings protocol instance (defaults to Settings.shared)
    ///   - logger: Logger protocol instance (defaults to Logger.shared)
    init(
        compressionService: (any CompressionServiceProtocol)? = nil,
        watchFolderService: (any WatchFolderServiceProtocol)? = nil,
        settings: any SettingsProtocol = Settings.shared,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.compressionService = compressionService ?? CompressionService()
        // Use the injected compressionService for WatchFolderService to maintain dependency injection
        let serviceToUse = compressionService ?? CompressionService()
        self.watchFolderService = watchFolderService ?? WatchFolderService(
            compressionService: serviceToUse,
            settings: settings
        )
        self.settings = settings
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Handles dropped image files from drag and drop
    /// - Parameter providers: Array of NSItemProvider instances containing dropped items
    func handleDrop(providers: [NSItemProvider]) async {
        logger.info("Handling dropped items: \(providers.count) items")
        
        var loadedCount = 0
        var failedCount = 0
        
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                logger.debug("Item does not conform to image type, skipping")
                continue
            }
            
            var attemptedURL: URL?
            do {
                let url = try await loadItemFromProvider(provider: provider)
                attemptedURL = url
                
                guard let url = url else {
                    logger.warning("Provider did not return a URL")
                    failedCount += 1
                    continue
                }
                
                // Check if image is already added
                if images.contains(where: { $0.url.path == url.path }) {
                    logger.debug("Image already in list, skipping: \(url.lastPathComponent)")
                    continue
                }
                
                // Start security-scoped resource access for sandboxed apps
                // This gives us access to the file and its parent directory
                let hasAccess = url.startAccessingSecurityScopedResource()
                if hasAccess {
                    logger.debug("Started security-scoped access for: \(url.lastPathComponent)")
                }
                
                // Create image item
                do {
                    let imageItem = try ImageItem(url: url)
                    self.images.append(imageItem)
                    
                    // Track security-scoped access
                    if hasAccess {
                        self.securityScopedAccess[imageItem.id] = true
                    }
                    
                    loadedCount += 1
                    
                    logger.debug("Added image: \(url.lastPathComponent)")
                } catch {
                    // Stop access if image creation failed
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                    
                    failedCount += 1
                    let error = TrimrPixError.imageLoadFailed(url: url, underlyingError: error)
                    logger.error("Error creating image item: \(error.technicalDescription)")
                    showError(message: error.errorDescription ?? "Could not load image")
                }
                
            } catch {
                failedCount += 1
                let errorURL = attemptedURL ?? URL(fileURLWithPath: "unknown")
                let error = TrimrPixError.imageLoadFailed(url: errorURL, underlyingError: error)
                logger.error("Error loading image from provider: \(error.technicalDescription)")
                showError(message: error.errorDescription ?? "Could not load image")
            }
        }
        
        logger.info("Drop handling completed: \(loadedCount) loaded, \(failedCount) failed")
    }
    
    /// Clears all images from the list
    func clearImages() {
        let count = images.count
        
        // Stop all security-scoped resource access
        for imageItem in images {
            if securityScopedAccess[imageItem.id] == true {
                imageItem.url.stopAccessingSecurityScopedResource()
                logger.debug("Stopped security-scoped access for: \(imageItem.filename)")
            }
        }
        
        securityScopedAccess.removeAll()
        images.removeAll()
        logger.info("Cleared \(count) images from list")
    }
    
    /// Removes a single image from the list
    /// - Parameter id: The ID of the image to remove
    func removeImage(id: UUID) {
        if let index = images.firstIndex(where: { $0.id == id }) {
            let imageItem = images[index]
            let filename = imageItem.filename
            
            // Stop security-scoped resource access if it was started
            if securityScopedAccess[id] == true {
                imageItem.url.stopAccessingSecurityScopedResource()
                securityScopedAccess.removeValue(forKey: id)
                logger.debug("Stopped security-scoped access for: \(filename)")
            }
            
            images.remove(at: index)
            logger.info("Removed image from list: \(filename)")
        } else {
            logger.warning("Attempted to remove image with ID that doesn't exist")
        }
    }
    
    /// Optimizes all images in the list concurrently
    func optimizeAllImages() {
        guard !images.isEmpty else {
            logger.warning("Optimize all called but images list is empty")
            return
        }
        
        guard !isOptimizing else {
            logger.warning("Optimize all called but optimization already in progress")
            return
        }
        
        logger.info("Starting optimization for \(images.count) images")
        isOptimizing = true
        
        // Launch a task that inherits MainActor, then capture a snapshot of IDs on MainActor
        Task { [weak self] in
            guard let self else { return }
            
            // Capture a stable snapshot of the image IDs to process
            let idsToProcess: [UUID] = await MainActor.run { self.images.map { $0.id } }
            
            // Process with a bounded number of concurrent optimizations. Each running
            // optimization decodes a full image into memory, so an unbounded group
            // would load the entire batch at once — a memory spike on large drops.
            let maxConcurrent = max(1, min(4, ProcessInfo.processInfo.activeProcessorCount))
            await withTaskGroup(of: Void.self) { group in
                var index = 0
                // Prime the group up to the concurrency limit.
                while index < maxConcurrent, index < idsToProcess.count {
                    let id = idsToProcess[index]
                    group.addTask { [weak self] in await self?.optimizeImage(withID: id) }
                    index += 1
                }
                // As each finishes, start the next one, keeping at most `maxConcurrent` in flight.
                while await group.next() != nil {
                    if index < idsToProcess.count {
                        let id = idsToProcess[index]
                        group.addTask { [weak self] in await self?.optimizeImage(withID: id) }
                        index += 1
                    }
                }
            }
            
            // Update UI state on main actor
            await MainActor.run {
                self.isOptimizing = false
            }

            self.logger.info("Completed optimization for all images")

            // Request App Store review after 5 successful optimization runs
            let runs = self.settings.incrementOptimizationRuns()
            if runs == 5 {
                await MainActor.run {
                    if let controller = NSApplication.shared.keyWindow?.contentViewController {
                        AppStore.requestReview(in: controller)
                    }
                }
            }
        }
    }
    
    /// Optimizes a single image at the specified index
    /// - Parameter index: The index of the image to optimize
    func optimizeImage(at index: Int) async {
        guard images.indices.contains(index) else {
            logger.warning("Optimize image called with invalid index: \(index)")
            return
        }
        // Delegate to the ID-based implementation so the operation stays correct
        // even if the list is mutated while compression is running.
        await optimizeImage(withID: images[index].id)
    }

    /// Optimizes a single image identified by its ID.
    ///
    /// The image's current index is re-resolved from its ID after every suspension
    /// point. If the image is removed or reordered while compression runs, the update
    /// is skipped gracefully instead of crashing or mutating the wrong item.
    /// - Parameter id: The ID of the image to optimize
    private func optimizeImage(withID id: UUID) async {
        guard let imageItem = images.first(where: { $0.id == id }) else {
            logger.warning("Optimize image called with missing ID: \(id)")
            return
        }
        logger.info("Starting optimization for: \(imageItem.filename)")

        // Snapshot settings on the main actor before crossing into background work.
        let settingsSnapshot = settings.compressionSnapshot

        if let idx = images.firstIndex(where: { $0.id == id }) {
            images[idx].isOptimizing = true
        }

        do {
            let optimizedURL = try await compressionService.optimizeImage(at: imageItem.url, settings: settingsSnapshot)

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: optimizedURL.path)
                let optimizedSize = attributes[.size] as? Int64 ?? 0

                // Re-resolve the index after the await — the list may have changed.
                guard let idx = images.firstIndex(where: { $0.id == id }) else {
                    logger.debug("Image removed during optimization, skipping update: \(imageItem.filename)")
                    return
                }
                images[idx].optimizedSize = optimizedSize
                images[idx].isOptimized = true
                images[idx].isOptimizing = false
                logger.info("Successfully optimized: \(imageItem.filename) - \(images[idx].savingsPercentage)% reduction")

            } catch {
                let error = TrimrPixError.fileSizeReadError(optimizedURL, underlyingError: error)
                logger.error("Error reading optimized file size: \(error.technicalDescription)")
                clearOptimizing(id: id)
                showError(message: error.errorDescription ?? "Could not read file size")
            }

        } catch let error as TrimrPixError {
            logger.error("Optimization failed: \(error.technicalDescription)")
            clearOptimizing(id: id)
            showError(message: error.errorDescription ?? "Could not optimize image")
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: imageItem.url, underlyingError: error)
            logger.error("Optimization failed: \(trimmedError.technicalDescription)")
            clearOptimizing(id: id)
            showError(message: trimmedError.errorDescription ?? "Could not optimize image")
        }
    }

    /// Clears the `isOptimizing` flag for the image with the given ID, if it still exists.
    private func clearOptimizing(id: UUID) {
        if let idx = images.firstIndex(where: { $0.id == id }) {
            images[idx].isOptimizing = false
        }
    }
    
    /// Starts watch folder monitoring if enabled in settings
    func startWatchFolder() {
        guard settings.watchFolderEnabled else {
            logger.debug("Watch folder not enabled")
            return
        }
        
        // Try to get watch folder URL from bookmark first
        var watchFolderPath: String
        if let bookmarkURL = settings.getWatchFolderURL() {
            // Start accessing security-scoped resource from bookmark.
            // Track the URL so stopWatchFolder() can balance this call (avoids leaking a scope reference).
            if bookmarkURL.startAccessingSecurityScopedResource() {
                watchFolderScopedURL = bookmarkURL
            }
            watchFolderPath = bookmarkURL.path
            logger.debug("Using watch folder from bookmark: \(watchFolderPath)")
        } else if !settings.watchFolderPath.isEmpty {
            watchFolderPath = settings.watchFolderPath
        } else {
            logger.debug("Watch folder path is empty")
            return
        }
        
        // Validate watch folder path before starting
        do {
            try settings.validateWatchFolderPath()
        } catch let error as TrimrPixError {
            logger.error("Watch folder path validation failed: \(error.technicalDescription)")
            showError(message: error.errorDescription ?? "Invalid watch folder path")
            return
        } catch {
            let trimmedError = TrimrPixError.watchFolderSetupFailed(watchFolderPath, underlyingError: error)
            logger.error("Watch folder path validation failed: \(trimmedError.technicalDescription)")
            showError(message: trimmedError.errorDescription ?? "Invalid watch folder path")
            return
        }
        
        do {
            try watchFolderService.startWatching(path: watchFolderPath)
            logger.info("Watch folder started: \(watchFolderPath)")
        } catch let error as TrimrPixError {
            logger.error("Failed to start watch folder: \(error.technicalDescription)")
            showError(message: error.errorDescription ?? "Could not start watch folder")
        } catch {
            let trimmedError = TrimrPixError.watchFolderSetupFailed(watchFolderPath, underlyingError: error)
            logger.error("Failed to start watch folder: \(trimmedError.technicalDescription)")
            showError(message: trimmedError.errorDescription ?? "Could not start watch folder")
        }
    }
    
    /// Stops watch folder monitoring
    func stopWatchFolder() {
        // Balance the security-scoped access started in startWatchFolder().
        // Done unconditionally (before the isWatching guard) so a scope acquired
        // during a start that later failed to begin watching is still released.
        if let scopedURL = watchFolderScopedURL {
            scopedURL.stopAccessingSecurityScopedResource()
            watchFolderScopedURL = nil
            logger.debug("Stopped security-scoped access for watch folder")
        }

        guard watchFolderService.isWatching else {
            logger.debug("Watch folder not active, skipping stop")
            return
        }

        watchFolderService.stopWatching()
        logger.info("Watch folder stopped")
    }
    
    /// Indicates whether watch folder is currently active
    var isWatchFolderActive: Bool {
        watchFolderService.isWatching
    }
    
    // MARK: - Private Methods
    
    /// Loads a URL from an NSItemProvider
    /// - Parameter provider: The item provider to load from
    /// - Returns: The URL of the loaded item, or nil if loading fails
    /// - Throws: Error if loading fails
    private func loadItemFromProvider(provider: NSItemProvider) async throws -> URL? {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Shows an error message to the user
    /// - Parameter message: The error message to display
    private func showError(message: String) {
        self.errorMessage = message
        self.showError = true
        logger.warning("Showing error to user: \(message)")
    }
    
    /// Dismisses the error alert
    func dismissError() {
        self.showError = false
        self.errorMessage = nil
        logger.debug("Error dismissed by user")
    }
}

