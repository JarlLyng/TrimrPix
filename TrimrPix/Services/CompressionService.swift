//
//  CompressionService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import CoreImage
import UniformTypeIdentifiers

/// Service responsible for image compression and optimization
/// Implements CompressionServiceProtocol for dependency injection and testing
final class CompressionService: CompressionServiceProtocol {
    
    // MARK: - Dependencies
    
    private let settings: any SettingsProtocol
    private let fileManager: any FileManagerProtocol
    private let logger: any LoggerProtocol
    
    // MARK: - Initialization
    
    /// Initializes the compression service with dependencies
    /// - Parameters:
    ///   - settings: Settings protocol instance (defaults to Settings.shared)
    ///   - fileManager: File manager protocol instance (defaults to FileManager.default)
    ///   - logger: Logger protocol instance (defaults to Logger.shared)
    init(
        settings: any SettingsProtocol = Settings.shared,
        fileManager: any FileManagerProtocol = FileManager.default,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.settings = settings
        self.fileManager = fileManager
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Optimizes an image at the given URL
    /// - Parameter url: The URL of the image to optimize
    /// - Returns: The URL of the optimized image
    /// - Throws: TrimrPixError if optimization fails
    func optimizeImage(at url: URL) async throws -> URL {
        logger.info("Starting image optimization for: \(url.lastPathComponent)")
        
        // Determine file type using UTType for better detection
        let fileExtension: String
        if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let contentType = resourceValues.contentType {
            // Use UTType to determine extension
            fileExtension = contentType.preferredFilenameExtension ?? url.pathExtension.lowercased()
            logger.debug("Detected file type: \(contentType.identifier), extension: \(fileExtension)")
        } else {
            // Fallback to path extension
            fileExtension = url.pathExtension.lowercased()
            logger.debug("Using path extension: \(fileExtension)")
        }
        
        // Validate file exists
        guard fileManager.fileExists(atPath: url.path) else {
            let error = TrimrPixError.fileNotFound(url)
            logger.error("File not found: \(error.technicalDescription)")
            throw error
        }
        
        // Optimize image based on file type
        let optimizedData: Data
        do {
            optimizedData = try await optimizeImageData(at: url, fileExtension: fileExtension)
        } catch let error as TrimrPixError {
            logger.error("Compression failed: \(error.technicalDescription)")
            throw error
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: url, underlyingError: error)
            logger.error("Compression failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
        
        // Generate suggested filename
        let suggestedFilename = url.deletingPathExtension().lastPathComponent + "-optimized." + fileExtension
        
        // Save the optimized file based on settings
        let savedURL: URL
        do {
            if settings.overwriteOriginal {
                savedURL = try await overwriteOriginalImage(data: optimizedData, originalURL: url)
            } else if settings.autoSave {
                savedURL = try await saveInSameFolder(data: optimizedData, originalURL: url, suggestedFilename: suggestedFilename)
            } else {
                savedURL = try await saveOptimizedImage(data: optimizedData, originalURL: url, suggestedFilename: suggestedFilename)
            }
            
            logger.info("Successfully optimized image: \(savedURL.lastPathComponent)")
            return savedURL
        } catch let error as TrimrPixError {
            logger.error("Save failed: \(error.technicalDescription)")
            throw error
        } catch {
            let trimmedError = TrimrPixError.fileWriteError(url: url, underlyingError: error)
            logger.error("Save failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    // MARK: - Private Compression Methods
    
    /// Optimizes image data based on file extension
    /// - Parameters:
    ///   - url: The URL of the image
    ///   - fileExtension: The file extension (lowercased)
    /// - Returns: The optimized image data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeImageData(at url: URL, fileExtension: String) async throws -> Data {
        switch fileExtension {
        case "jpg", "jpeg":
            return try await optimizeJPEGData(at: url)
        case "png":
            return try await optimizePNGData(at: url)
        case "gif":
            return try await optimizeGIFData(at: url)
        case "webp":
            return try await optimizeWebPData(at: url)
        case "avif":
            return try await optimizeAVIFData(at: url)
        default:
            let error = TrimrPixError.unsupportedImageFormat(fileExtension)
            logger.warning("Unsupported format: \(error.technicalDescription)")
            throw error
        }
    }
    
    /// Optimizes JPEG image data
    /// - Parameter url: The URL of the JPEG image
    /// - Returns: The optimized JPEG data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeJPEGData(at url: URL) async throws -> Data {
        logger.debug("Optimizing JPEG: \(url.lastPathComponent)")
        
        // Load image
        guard let image = NSImage(contentsOf: url) else {
            let error = TrimrPixError.imageLoadFailed(url: url, underlyingError: nil)
            logger.error("Failed to load JPEG: \(error.technicalDescription)")
            throw error
        }
        
        // Get compression quality from settings
        let compressionQuality = settings.jpegQuality
        
        // Convert NSImage to JPEG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(
                using: .jpeg,
                properties: [.compressionFactor: compressionQuality]
              ) else {
            let error = TrimrPixError.jpegCompressionFailed(url)
            logger.error("JPEG compression failed: \(error.technicalDescription)")
            throw error
        }
        
        logger.debug("JPEG optimization completed, quality: \(Int(compressionQuality * 100))%")
        return jpegData
    }
    
    /// Optimizes PNG image data
    /// - Parameter url: The URL of the PNG image
    /// - Returns: The optimized PNG data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizePNGData(at url: URL) async throws -> Data {
        logger.debug("Optimizing PNG: \(url.lastPathComponent)")
        
        // Load image
        guard let image = NSImage(contentsOf: url) else {
            let error = TrimrPixError.imageLoadFailed(url: url, underlyingError: nil)
            logger.error("Failed to load PNG: \(error.technicalDescription)")
            throw error
        }
        
        // Convert NSImage to PNG data with compression
        // Compression level: 0.0 (no compression) to 1.0 (max compression)
        // Using 0.75 as a good balance between size and speed
        let compressionLevel: Float = 0.75
        let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionMethod: NSBitmapImageRep.TIFFCompression.lzw.rawValue
        ]
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            let error = TrimrPixError.pngCompressionFailed(url)
            logger.error("Failed to create bitmap representation: \(error.technicalDescription)")
            throw error
        }
        
        // Try with compression properties first
        if let pngData = bitmapImage.representation(using: .png, properties: pngProperties) {
            logger.debug("PNG optimization completed with compression level: \(compressionLevel)")
            return pngData
        }
        
        // Fallback to default PNG representation if compression fails
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            let error = TrimrPixError.pngCompressionFailed(url)
            logger.error("PNG compression failed: \(error.technicalDescription)")
            throw error
        }
        
        logger.debug("PNG optimization completed (fallback to default compression)")
        return pngData
    }
    
    /// Validates and copies GIF data (no compression in MVP)
    /// - Parameter url: The URL of the GIF image
    /// - Returns: The validated GIF data
    /// - Throws: TrimrPixError if validation fails
    private func optimizeGIFData(at url: URL) async throws -> Data {
        logger.debug("Validating GIF: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            
            // Validate GIF header
            guard data.count > 6 else {
                let error = TrimrPixError.invalidImageData(url)
                logger.error("Invalid GIF data: \(error.technicalDescription)")
                throw error
            }
            
            let header = data.prefix(6)
            guard let headerString = String(data: header, encoding: .ascii),
                  headerString == "GIF87a" || headerString == "GIF89a" else {
                let error = TrimrPixError.invalidImageData(url)
                logger.error("Invalid GIF format: \(error.technicalDescription)")
                throw error
            }
            
            logger.debug("GIF validation completed (no compression applied)")
            return data
        } catch let error as TrimrPixError {
            throw error
        } catch {
            let trimmedError = TrimrPixError.fileReadError(url: url, underlyingError: error)
            logger.error("Failed to read GIF: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    /// Validates WebP data (no compression in MVP due to macOS limitations)
    /// - Parameter url: The URL of the WebP image
    /// - Returns: The validated WebP data
    /// - Throws: TrimrPixError if validation fails
    private func optimizeWebPData(at url: URL) async throws -> Data {
        logger.debug("Validating WebP: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            
            // Minimal validation: WebP signature "RIFF....WEBP"
            guard data.count >= 12 else {
                let error = TrimrPixError.invalidImageData(url)
                logger.error("Invalid WebP data: \(error.technicalDescription)")
                throw error
            }
            
            let riff = data.prefix(4)
            let webp = data.dropFirst(8).prefix(4)
            
            guard let riffString = String(data: riff, encoding: .ascii),
                  let webpString = String(data: webp, encoding: .ascii),
                  riffString == "RIFF",
                  webpString == "WEBP" else {
                logger.warning("WebP validation failed (returning original data)")
                // Still return data as fallback
                return data
            }
            
            logger.debug("WebP validation completed (no compression applied - macOS limitation)")
            return data
        } catch let error as TrimrPixError {
            throw error
        } catch {
            let trimmedError = TrimrPixError.fileReadError(url: url, underlyingError: error)
            logger.error("Failed to read WebP: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    /// Validates AVIF data (no compression in MVP due to macOS limitations)
    /// - Parameter url: The URL of the AVIF image
    /// - Returns: The validated AVIF data
    /// - Throws: TrimrPixError if validation fails
    private func optimizeAVIFData(at url: URL) async throws -> Data {
        logger.debug("Validating AVIF: \(url.lastPathComponent)")
        
        do {
            let data = try Data(contentsOf: url)
            
            // Minimal validation: ISO BMFF brand contains "avif"/"avis"
            guard data.count >= 12 else {
                let error = TrimrPixError.invalidImageData(url)
                logger.error("Invalid AVIF data: \(error.technicalDescription)")
                throw error
            }
            
            // ftyp box starts at offset 4 with "ftyp"
            let brand = data.dropFirst(8).prefix(4)
            if let brandStr = String(data: brand, encoding: .ascii),
               brandStr.lowercased() == "avif" || brandStr.lowercased() == "avis" {
                logger.debug("AVIF validation completed (no compression applied - macOS limitation)")
                return data
            } else {
                // Not a strict validator; still accept to avoid false negatives
                logger.debug("AVIF validation inconclusive (returning original data)")
                return data
            }
        } catch let error as TrimrPixError {
            throw error
        } catch {
            let trimmedError = TrimrPixError.fileReadError(url: url, underlyingError: error)
            logger.error("Failed to read AVIF: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    // MARK: - Private Save Methods
    
    /// Presents save panel for user to choose location
    /// - Parameters:
    ///   - data: The image data to save
    ///   - originalURL: The original image URL
    ///   - suggestedFilename: The suggested filename
    /// - Returns: The URL where the file was saved
    /// - Throws: TrimrPixError if save fails or user cancels
    @MainActor
    private func saveOptimizedImage(data: Data, originalURL: URL, suggestedFilename: String) async throws -> URL {
        logger.debug("Presenting save panel for: \(suggestedFilename)")
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.directoryURL = originalURL.deletingLastPathComponent()
        savePanel.allowedContentTypes = [UTType.image]
        
        let response: NSApplication.ModalResponse
        
        if let keyWindow = NSApp.keyWindow {
            response = await savePanel.beginSheetModal(for: keyWindow)
        } else {
            // Fallback: present as modal if no keyWindow
            response = savePanel.runModal()
        }
        
        guard response == .OK, let url = savePanel.url else {
            logger.info("User cancelled save operation")
            throw TrimrPixError.userCancelled
        }
        
        do {
            try data.write(to: url)
            logger.info("Image saved to: \(url.path)")
            return url
        } catch {
            let trimmedError = TrimrPixError.fileWriteError(url: url, underlyingError: error)
            logger.error("Save failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
    
    /// Saves optimized image in the same folder as original
    /// - Parameters:
    ///   - data: The image data to save
    ///   - originalURL: The original image URL
    ///   - suggestedFilename: The suggested filename
    /// - Returns: The URL where the file was saved
    /// - Throws: TrimrPixError if save fails
    private func saveInSameFolder(data: Data, originalURL: URL, suggestedFilename: String) async throws -> URL {
        let folderURL = originalURL.deletingLastPathComponent()
        
        // For sandboxed apps, we need to access security-scoped resources
        // Start accessing the original file's security-scoped resource to get access to its parent directory
        // This MUST be called before any file operations on the parent directory
        let fileHasAccess = originalURL.startAccessingSecurityScopedResource()
        let folderHasAccess = folderURL.startAccessingSecurityScopedResource()
        
        // We'll stop access after we're done writing
        defer {
            if folderHasAccess {
                folderURL.stopAccessingSecurityScopedResource()
            }
            if fileHasAccess {
                originalURL.stopAccessingSecurityScopedResource()
            }
        }
        
        logger.debug("Security-scoped access: file=\(fileHasAccess), folder=\(folderHasAccess)")
        
        // Validate folder exists
        guard fileManager.fileExists(atPath: folderURL.path) else {
            let error = TrimrPixError.directoryNotFound(folderURL)
            logger.error("Destination folder does not exist: \(error.technicalDescription)")
            throw error
        }
        
        // Try to check if folder is writable
        // If we don't have access, we'll try to write anyway and catch the error
        let isWritable = isFolderWritable(folderURL)
        logger.debug("Folder writable check: \(isWritable)")
        
        if !isWritable && !fileHasAccess && !folderHasAccess {
            // No security-scoped access and folder not writable
            // Fall back to save panel
            logger.warning("No write access to folder, falling back to save panel")
            return try await saveOptimizedImage(data: data, originalURL: originalURL, suggestedFilename: suggestedFilename)
        }
        
        // Validate and sanitize filename
        let sanitizedFilename = sanitizeFilename(suggestedFilename)
        
        // Find a unique filename if the suggested one already exists
        var finalFilename = generateUniqueFilename(baseFilename: sanitizedFilename, in: folderURL)
        var destinationURL = folderURL.appendingPathComponent(finalFilename)
        
        logger.debug("Auto-saving to: \(destinationURL.path)")
        logger.debug("File size: \(data.count) bytes")
        logger.debug("Folder URL: \(folderURL.path)")
        logger.debug("Has security-scoped access: file=\(fileHasAccess), folder=\(folderHasAccess)")
        
        // Try to save, and if file exists error occurs, find new unique name and retry
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            do {
                // Use atomic write to prevent race conditions
                try data.write(to: destinationURL, options: .atomic)
                logger.info("Image auto-saved to: \(destinationURL.path)")
                return destinationURL
            } catch let error as NSError {
                logger.error("File write error - Domain: \(error.domain), Code: \(error.code), Description: \(error.localizedDescription)")
                logger.error("Attempted path: \(destinationURL.path)")
                
                // Check if error is because file already exists (race condition)
                if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                    logger.debug("File exists during write (race condition), finding new name: \(destinationURL.lastPathComponent)")
                    attempts += 1
                    
                    // Generate new unique filename
                    finalFilename = generateUniqueFilename(baseFilename: suggestedFilename, in: folderURL, excludeFilename: finalFilename)
                    destinationURL = folderURL.appendingPathComponent(finalFilename)
                    
                    if attempts >= maxAttempts {
                        let trimmedError = TrimrPixError.fileWriteError(url: destinationURL, underlyingError: error)
                        logger.error("Auto-save failed after \(maxAttempts) attempts: \(trimmedError.technicalDescription)")
                        throw trimmedError
                    }
                } else {
                    // Check if it's a permission error
                    if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
                        logger.warning("Permission denied, falling back to save panel")
                        // Stop accessing resources before showing save panel
                        if folderHasAccess {
                            folderURL.stopAccessingSecurityScopedResource()
                        }
                        if fileHasAccess {
                            originalURL.stopAccessingSecurityScopedResource()
                        }
                        // Fall back to save panel
                        return try await saveOptimizedImage(data: data, originalURL: originalURL, suggestedFilename: suggestedFilename)
                    }
                    
                    // Different error, log details and throw it
                    let trimmedError = TrimrPixError.fileWriteError(url: destinationURL, underlyingError: error)
                    logger.error("Auto-save failed with error: \(trimmedError.technicalDescription)")
                    logger.error("Error details - Domain: \(error.domain), Code: \(error.code), UserInfo: \(error.userInfo)")
                    throw trimmedError
                }
            } catch {
                // Other error types
                let trimmedError = TrimrPixError.fileWriteError(url: destinationURL, underlyingError: error)
                logger.error("Auto-save failed with unknown error: \(trimmedError.technicalDescription)")
                logger.error("Error type: \(type(of: error)), Description: \(error.localizedDescription)")
                throw trimmedError
            }
        }
        
        // Should never reach here, but just in case
        let trimmedError = TrimrPixError.fileWriteError(url: destinationURL, underlyingError: nil)
        logger.error("Auto-save failed: \(trimmedError.technicalDescription)")
        throw trimmedError
    }
    
    /// Checks if a folder is writable by using URL resource values and a safe write probe fallback
    /// - Parameter folderURL: The folder URL to check
    /// - Returns: True if the folder appears writable
    private func isFolderWritable(_ folderURL: URL) -> Bool {
        // First, attempt to read the isWritable resource value
        if let values = try? folderURL.resourceValues(forKeys: [.isWritableKey]),
           let writable = values.isWritable {
            return writable
        }
        
        // Fallback: attempt to create and remove a tiny temp file in the folder
        // Use FileManager.default directly since removeItem is not in the protocol
        let tempFilename = ".trimrpix_write_test_\(UUID().uuidString)"
        let tempURL = folderURL.appendingPathComponent(tempFilename)
        do {
            try Data().write(to: tempURL, options: .atomic)
            try? FileManager.default.removeItem(at: tempURL)
            return true
        } catch {
            return false
        }
    }
    
    /// Sanitizes a filename by removing invalid characters
    /// - Parameter filename: The filename to sanitize
    /// - Returns: A sanitized filename safe for filesystem use
    private func sanitizeFilename(_ filename: String) -> String {
        // Remove invalid characters for macOS filesystem
        let invalidChars = CharacterSet(charactersIn: "/\\:<>\"|?*")
        let components = filename.components(separatedBy: invalidChars)
        return components.joined(separator: "_")
    }
    
    /// Generates a unique filename by appending a number if the file already exists
    /// - Parameters:
    ///   - baseFilename: The base filename to use
    ///   - folderURL: The folder where the file will be saved
    ///   - excludeFilename: Optional filename to exclude from check (already tried)
    /// - Returns: A unique filename that doesn't exist in the folder
    private func generateUniqueFilename(baseFilename: String, in folderURL: URL, excludeFilename: String? = nil) -> String {
        // Check if base filename already exists
        let baseURL = folderURL.appendingPathComponent(baseFilename)
        
        guard fileManager.fileExists(atPath: baseURL.path) || baseFilename == excludeFilename else {
            // File doesn't exist and it's not the excluded one, use base filename
            return baseFilename
        }
        
        // File exists, find a unique name by appending a number
        let nameWithoutExtension = (baseFilename as NSString).deletingPathExtension
        let fileExtension = (baseFilename as NSString).pathExtension
        
        var counter = 2
        var uniqueFilename: String
        
        repeat {
            if fileExtension.isEmpty {
                uniqueFilename = "\(nameWithoutExtension)-\(counter)"
            } else {
                uniqueFilename = "\(nameWithoutExtension)-\(counter).\(fileExtension)"
            }
            
            // Skip if this is the excluded filename
            if uniqueFilename == excludeFilename {
                counter += 1
                continue
            }
            
            let testURL = folderURL.appendingPathComponent(uniqueFilename)
            
            if !fileManager.fileExists(atPath: testURL.path) {
                logger.debug("Found unique filename: \(uniqueFilename)")
                return uniqueFilename
            }
            
            counter += 1
            
            // Safety limit to prevent infinite loop
            if counter > 1000 {
                logger.warning("Could not find unique filename after 1000 attempts, using timestamp")
                let timestamp = Int(Date().timeIntervalSince1970)
                if fileExtension.isEmpty {
                    uniqueFilename = "\(nameWithoutExtension)-\(timestamp)"
                } else {
                    uniqueFilename = "\(nameWithoutExtension)-\(timestamp).\(fileExtension)"
                }
                return uniqueFilename
            }
        } while true
    }
    
    /// Overwrites the original image with optimized version
    /// - Parameters:
    ///   - data: The optimized image data
    ///   - originalURL: The original image URL
    /// - Returns: The URL of the overwritten file (same as originalURL)
    /// - Throws: TrimrPixError if overwrite fails
    private func overwriteOriginalImage(data: Data, originalURL: URL) async throws -> URL {
        logger.debug("Overwriting original: \(originalURL.lastPathComponent)")
        
        do {
            try data.write(to: originalURL)
            logger.info("Original image overwritten: \(originalURL.path)")
            return originalURL
        } catch {
            let trimmedError = TrimrPixError.fileWriteError(url: originalURL, underlyingError: error)
            logger.error("Overwrite failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
    }
}

