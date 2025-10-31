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
        
        // Determine file type
        let fileExtension = url.pathExtension.lowercased()
        
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
        
        // Convert NSImage to PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            let error = TrimrPixError.pngCompressionFailed(url)
            logger.error("PNG compression failed: \(error.technicalDescription)")
            throw error
        }
        
        logger.debug("PNG optimization completed")
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
        let destinationURL = originalURL.deletingLastPathComponent().appendingPathComponent(suggestedFilename)
        
        logger.debug("Auto-saving to: \(destinationURL.lastPathComponent)")
        
        do {
            try data.write(to: destinationURL)
            logger.info("Image auto-saved to: \(destinationURL.path)")
            return destinationURL
        } catch {
            let trimmedError = TrimrPixError.fileWriteError(url: destinationURL, underlyingError: error)
            logger.error("Auto-save failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }
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
