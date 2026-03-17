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

private extension ImageItem {
    static var placeholder: ImageItem {
        // Create a minimal placeholder that won't be used; values won't be accessed
        // Use a temporary file URL as a dummy
        let tempURL = URL(fileURLWithPath: "/dev/null")
        // Force-try is acceptable here because it's only used when index is missing and won't be accessed
        return try! ImageItem(url: tempURL)
    }
}

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
                    showError(message: error.errorDescription ?? "Kunne ikke indlæse billede")
                }
                
            } catch {
                failedCount += 1
                let errorURL = attemptedURL ?? URL(fileURLWithPath: "unknown")
                let error = TrimrPixError.imageLoadFailed(url: errorURL, underlyingError: error)
                logger.error("Error loading image from provider: \(error.technicalDescription)")
                showError(message: error.errorDescription ?? "Kunne ikke indlæse billede")
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
            
            // Perform concurrent processing without touching MainActor-isolated state directly
            await withTaskGroup(of: Void.self) { group in
                for id in idsToProcess {
                    group.addTask { [weak self] in
                        await self?.optimizeImage(withID: id)
                    }
                }
                await group.waitForAll()
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
        guard index < images.count else {
            logger.warning("Optimize image called with invalid index: \(index)")
            return
        }
        
        let imageItem: ImageItem = await MainActor.run { self.images[index] }
        logger.info("Starting optimization for: \(imageItem.filename)")
        
        // Set optimizing state on main actor
        await MainActor.run {
            self.images[index].isOptimizing = true
        }
        
        // Optimize the image in background
        do {
            let optimizedURL = try await compressionService.optimizeImage(at: imageItem.url)
            
            // Get optimized file size
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: optimizedURL.path)
                let optimizedSize = attributes[.size] as? Int64 ?? 0
                
                // Update image item on main actor
                await MainActor.run {
                    self.images[index].optimizedSize = optimizedSize
                    self.images[index].isOptimized = true
                    self.images[index].isOptimizing = false
                }
                
                let savings: Int = await MainActor.run { self.images[index].savingsPercentage }
                self.logger.info("Successfully optimized: \(imageItem.filename) - \(savings)% reduction")
                
            } catch {
                let error = TrimrPixError.fileSizeReadError(optimizedURL, underlyingError: error)
                logger.error("Error reading optimized file size: \(error.technicalDescription)")
                await MainActor.run {
                    self.images[index].isOptimizing = false
                    self.showError(message: error.errorDescription ?? "Kunne ikke læse filstørrelse")
                }
            }
            
        } catch let error as TrimrPixError {
            logger.error("Optimization failed: \(error.technicalDescription)")
            await MainActor.run {
                self.images[index].isOptimizing = false
                self.showError(message: error.errorDescription ?? "Kunne ikke optimere billede")
            }
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: imageItem.url, underlyingError: error)
            logger.error("Optimization failed: \(trimmedError.technicalDescription)")
            await MainActor.run {
                self.images[index].isOptimizing = false
                self.showError(message: trimmedError.errorDescription ?? "Kunne ikke optimere billede")
            }
        }
    }
    
    /// Optimizes a single image identified by its ID
    /// - Parameter id: The ID of the image to optimize
    private func optimizeImage(withID id: UUID) async {
        // Resolve the current index for this ID on the main actor
        let result = await MainActor.run {
            if let idx = self.images.firstIndex(where: { $0.id == id }) {
                return (idx, self.images[idx])
            } else {
                return (-1, ImageItem.placeholder)
            }
        }
        
        guard result.0 >= 0 else {
            logger.warning("Optimize image called with missing ID: \(id)")
            return
        }
        
        await optimizeImage(at: result.0)
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
            // Start accessing security-scoped resource from bookmark
            _ = bookmarkURL.startAccessingSecurityScopedResource()
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
            showError(message: error.errorDescription ?? "Ugyldig watch folder sti")
            return
        } catch {
            let trimmedError = TrimrPixError.watchFolderSetupFailed(watchFolderPath, underlyingError: error)
            logger.error("Watch folder path validation failed: \(trimmedError.technicalDescription)")
            showError(message: trimmedError.errorDescription ?? "Ugyldig watch folder sti")
            return
        }
        
        do {
            try watchFolderService.startWatching(path: watchFolderPath)
            logger.info("Watch folder started: \(watchFolderPath)")
        } catch let error as TrimrPixError {
            logger.error("Failed to start watch folder: \(error.technicalDescription)")
            showError(message: error.errorDescription ?? "Kunne ikke starte watch folder")
        } catch {
            let trimmedError = TrimrPixError.watchFolderSetupFailed(watchFolderPath, underlyingError: error)
            logger.error("Failed to start watch folder: \(trimmedError.technicalDescription)")
            showError(message: trimmedError.errorDescription ?? "Kunne ikke starte watch folder")
        }
    }
    
    /// Stops watch folder monitoring
    func stopWatchFolder() {
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

