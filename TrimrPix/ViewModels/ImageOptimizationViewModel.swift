//
//  ImageOptimizationViewModel.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import SwiftUI
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
        self.watchFolderService = watchFolderService ?? WatchFolderService(compressionService: CompressionService())
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
            
            do {
                let url = try await loadItemFromProvider(provider: provider)
                
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
                
                // Create image item
                let imageItem = ImageItem(url: url)
                self.images.append(imageItem)
                loadedCount += 1
                
                logger.debug("Added image: \(url.lastPathComponent)")
                
            } catch {
                failedCount += 1
                let error = TrimrPixError.imageLoadFailed(url: URL(fileURLWithPath: ""), underlyingError: error)
                logger.error("Error loading image from provider: \(error.technicalDescription)")
                showError(message: error.errorDescription ?? "Kunne ikke indlæse billede")
            }
        }
        
        logger.info("Drop handling completed: \(loadedCount) loaded, \(failedCount) failed")
    }
    
    /// Clears all images from the list
    func clearImages() {
        let count = images.count
        images.removeAll()
        logger.info("Cleared \(count) images from list")
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
        
        Task {
            // Concurrent processing for better performance
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<self.images.count {
                    group.addTask {
                        await self.optimizeImage(at: index)
                    }
                }
                
                // Wait for all tasks to complete
                await group.waitForAll()
            }
            
            isOptimizing = false
            logger.info("Completed optimization for all images")
        }
    }
    
    /// Optimizes a single image at the specified index
    /// - Parameter index: The index of the image to optimize
    func optimizeImage(at index: Int) async {
        guard index < images.count else {
            logger.warning("Optimize image called with invalid index: \(index)")
            return
        }
        
        let imageItem = images[index]
        logger.info("Starting optimization for: \(imageItem.filename)")
        
        // Set optimizing state
        self.images[index].isOptimizing = true
        
        // Optimize the image
        do {
            let optimizedURL = try await compressionService.optimizeImage(at: imageItem.url)
            
            // Get optimized file size
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: optimizedURL.path)
                let optimizedSize = attributes[.size] as? Int64 ?? 0
                
                // Update image item
                self.images[index].optimizedSize = optimizedSize
                self.images[index].isOptimized = true
                self.images[index].isOptimizing = false
                
                let savings = self.images[index].savingsPercentage
                logger.info("Successfully optimized: \(imageItem.filename) - \(savings)% reduction")
                
            } catch {
                let error = TrimrPixError.fileSizeReadError(optimizedURL, underlyingError: error)
                logger.error("Error reading optimized file size: \(error.technicalDescription)")
                self.images[index].isOptimizing = false
                showError(message: error.errorDescription ?? "Kunne ikke læse filstørrelse")
            }
            
        } catch let error as TrimrPixError {
            logger.error("Optimization failed: \(error.technicalDescription)")
            self.images[index].isOptimizing = false
            showError(message: error.errorDescription ?? "Kunne ikke optimere billede")
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: imageItem.url, underlyingError: error)
            logger.error("Optimization failed: \(trimmedError.technicalDescription)")
            self.images[index].isOptimizing = false
            showError(message: trimmedError.errorDescription ?? "Kunne ikke optimere billede")
        }
    }
    
    /// Starts watch folder monitoring if enabled in settings
    func startWatchFolder() {
        guard settings.watchFolderEnabled, !settings.watchFolderPath.isEmpty else {
            logger.debug("Watch folder not enabled or path is empty")
            return
        }
        
        do {
            try watchFolderService.startWatching(path: settings.watchFolderPath)
            logger.info("Watch folder started: \(settings.watchFolderPath)")
        } catch let error as TrimrPixError {
            logger.error("Failed to start watch folder: \(error.technicalDescription)")
            showError(message: error.errorDescription ?? "Kunne ikke starte watch folder")
        } catch {
            let trimmedError = TrimrPixError.watchFolderSetupFailed(settings.watchFolderPath, underlyingError: error)
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
