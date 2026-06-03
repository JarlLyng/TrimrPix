//
//  CompressionService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Service responsible for image compression and optimization
/// Implements CompressionServiceProtocol for dependency injection and testing.
/// `@unchecked Sendable`: all stored dependencies are immutable `let`s; the service
/// holds no mutable state, so it is safe to share across concurrency domains.
final class CompressionService: CompressionServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies

    private let fileManager: any FileManagerProtocol
    private let logger: any LoggerProtocol

    // MARK: - Initialization

    /// Initializes the compression service with dependencies.
    /// Settings are not held here — they are passed per call as a `CompressionSettings`
    /// snapshot so the service stays stateless and free of cross-actor reads.
    /// - Parameters:
    ///   - fileManager: File manager protocol instance (defaults to FileManager.default)
    ///   - logger: Logger protocol instance (defaults to Logger.shared)
    init(
        fileManager: any FileManagerProtocol = FileManager.default,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.fileManager = fileManager
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Optimizes an image at the given URL
    /// - Parameters:
    ///   - url: The URL of the image to optimize
    ///   - settings: A Sendable snapshot of the settings to use
    /// - Returns: The URL of the optimized image
    /// - Throws: TrimrPixError if optimization fails
    func optimizeImage(at url: URL, settings: CompressionSettings) async throws -> URL {
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
        
        // Read original file size for comparison — via attributes, without loading
        // the whole file into memory (matters for large batches).
        let originalSize: Int
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            originalSize = (attributes[.size] as? Int) ?? 0
        } catch {
            let trimmedError = TrimrPixError.fileSizeReadError(url, underlyingError: error)
            logger.error("Failed to read original file size: \(trimmedError.technicalDescription)")
            throw trimmedError
        }

        // Optimize image based on file type
        var optimizedData: Data
        do {
            optimizedData = try await optimizeImageData(at: url, fileExtension: fileExtension, settings: settings)
        } catch let error as TrimrPixError {
            logger.error("Compression failed: \(error.technicalDescription)")
            throw error
        } catch {
            let trimmedError = TrimrPixError.compressionFailed(url: url, underlyingError: error)
            logger.error("Compression failed: \(trimmedError.technicalDescription)")
            throw trimmedError
        }

        // Guard: if compression didn't shrink the file, keep the original bytes.
        // The original is read lazily here, so the common (successful) path never
        // loads the whole source file.
        if originalSize > 0, optimizedData.count >= originalSize {
            logger.info("Compressed size (\(optimizedData.count) bytes) >= original (\(originalSize) bytes), keeping original")
            optimizedData = try Data(contentsOf: url)
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
    private func optimizeImageData(at url: URL, fileExtension: String, settings: CompressionSettings) async throws -> Data {
        switch fileExtension {
        case "jpg", "jpeg":
            return try await optimizeJPEGData(at: url, settings: settings)
        case "png":
            return try await optimizePNGData(at: url, settings: settings)
        case "gif":
            return try await optimizeGIFData(at: url)
        case "webp":
            return try await optimizeWebPData(at: url, settings: settings)
        case "avif":
            return try await optimizeAVIFData(at: url, settings: settings)
        case "heic", "heif":
            return try await optimizeHEICData(at: url, settings: settings)
        default:
            let error = TrimrPixError.unsupportedImageFormat(fileExtension)
            logger.warning("Unsupported format: \(error.technicalDescription)")
            throw error
        }
    }
    
    /// Optimizes JPEG image data using CGImageDestination for progressive encoding
    /// - Parameter url: The URL of the JPEG image
    /// - Returns: The optimized JPEG data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeJPEGData(at url: URL, settings: CompressionSettings) async throws -> Data {
        logger.debug("Optimizing JPEG: \(url.lastPathComponent)")

        let extraOptions: [CFString: Any] = [
            kCGImagePropertyJFIFDictionary: [
                kCGImagePropertyJFIFIsProgressive: true
            ] as CFDictionary
        ]

        return try await compressWithCGImageDestination(
            at: url, type: .jpeg,
            settings: settings,
            extraOptions: extraOptions,
            errorFactory: TrimrPixError.jpegCompressionFailed
        )
    }
    
    /// Optimizes PNG image data with optional lossy quantization
    /// - Parameter url: The URL of the PNG image
    /// - Returns: The optimized PNG data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizePNGData(at url: URL, settings: CompressionSettings) async throws -> Data {
        logger.debug("Optimizing PNG: \(url.lastPathComponent)")

        let cgImage = try loadImage(at: url, settings: settings, errorFactory: TrimrPixError.pngCompressionFailed)

        // Try lossy quantization first (biggest win for photo-PNGs)
        if settings.pngQuantizationEnabled {
            let quantizer = ColorQuantizer(maxColors: 256, logger: logger)
            if let quantizedImage = quantizer.quantize(cgImage) {
                // Encode quantized image via CGImageDestination
                let outputData = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(outputData, UTType.png.identifier as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, quantizedImage, nil)
                    if CGImageDestinationFinalize(destination) {
                        let result = outputData as Data
                        logger.debug("PNG quantization completed, size: \(result.count) bytes")
                        return result
                    }
                }
                logger.debug("PNG quantization encoding failed, falling back to standard optimization")
            }
        }

        // Fallback: standard PNG optimization with alpha stripping
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let optimizedBitmap = optimizeBitmapForPNG(bitmap)

        guard let pngData = optimizedBitmap.representation(using: .png, properties: [:]) else {
            let error = TrimrPixError.pngCompressionFailed(url)
            logger.error("PNG compression failed: \(error.technicalDescription)")
            throw error
        }

        logger.debug("PNG optimization completed, size: \(pngData.count) bytes")
        return pngData
    }
    
    /// Optimizes bitmap representation for better PNG compression
    /// Strips unused alpha channel from fully opaque images to reduce file size
    /// - Parameter bitmap: The original bitmap image rep
    /// - Returns: An optimized bitmap representation
    private func optimizeBitmapForPNG(_ bitmap: NSBitmapImageRep) -> NSBitmapImageRep {
        guard bitmap.hasAlpha else { return bitmap }

        // Sample pixels to check for transparency
        var hasTransparency = false
        let sampleSize = min(1000, bitmap.pixelsWide * bitmap.pixelsHigh)
        let step = max(1, (bitmap.pixelsWide * bitmap.pixelsHigh) / sampleSize)

        for i in stride(from: 0, to: bitmap.pixelsWide * bitmap.pixelsHigh, by: step) {
            let x = i % bitmap.pixelsWide
            let y = i / bitmap.pixelsWide

            if x < bitmap.pixelsWide && y < bitmap.pixelsHigh {
                if let color = bitmap.colorAt(x: x, y: y),
                   color.alphaComponent < 0.99 {
                    hasTransparency = true
                    break
                }
            }
        }

        guard !hasTransparency else { return bitmap }

        // Alpha channel is unused — strip it by drawing into a non-alpha bitmap
        logger.debug("PNG is fully opaque, stripping alpha channel for smaller file size")

        guard let cgImage = bitmap.cgImage else { return bitmap }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 3,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            logger.debug("Could not create non-alpha context, keeping original bitmap")
            return bitmap
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let strippedCGImage = context.makeImage() else { return bitmap }

        let strippedBitmap = NSBitmapImageRep(cgImage: strippedCGImage)
        logger.debug("Alpha channel stripped: \(bitmap.bitsPerPixel)bpp → \(strippedBitmap.bitsPerPixel)bpp")
        return strippedBitmap
    }
    
    /// Optimizes GIF data by re-encoding through CGImageDestination
    /// Strips metadata and re-compresses LZW. Preserves animation frame timing.
    /// - Parameter url: The URL of the GIF image
    /// - Returns: The optimized GIF data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeGIFData(at url: URL) async throws -> Data {
        logger.debug("Optimizing GIF: \(url.lastPathComponent)")

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            let trimmedError = TrimrPixError.fileReadError(url: url, underlyingError: error)
            logger.error("Failed to read GIF: \(trimmedError.technicalDescription)")
            throw trimmedError
        }

        // Validate GIF header
        guard data.count > 6,
              let headerString = String(data: data.prefix(6), encoding: .ascii),
              headerString == "GIF87a" || headerString == "GIF89a" else {
            let error = TrimrPixError.invalidImageData(url)
            logger.error("Invalid GIF format: \(error.technicalDescription)")
            throw error
        }

        // Re-encode through CGImageSource/CGImageDestination to strip metadata and re-compress
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            let error = TrimrPixError.gifCompressionFailed(url)
            logger.error("Failed to create GIF image source: \(error.technicalDescription)")
            throw error
        }

        let frameCount = CGImageSourceGetCount(source)
        let outputData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            outputData, UTType.gif.identifier as CFString, frameCount, nil
        ) else {
            let error = TrimrPixError.gifCompressionFailed(url)
            logger.error("Failed to create GIF destination: \(error.technicalDescription)")
            throw error
        }

        // Copy global GIF properties (loop count etc.)
        if let sourceProperties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any],
           let gifProperties = sourceProperties[kCGImagePropertyGIFDictionary] {
            let globalProps: [CFString: Any] = [kCGImagePropertyGIFDictionary: gifProperties]
            CGImageDestinationSetProperties(destination, globalProps as CFDictionary)
        }

        // Copy each frame with its timing properties
        for i in 0..<frameCount {
            guard let frameImage = CGImageSourceCreateImageAtIndex(source, i, nil) else {
                continue
            }

            // Preserve frame delay and other per-frame GIF properties
            var frameOptions: [CFString: Any] = [:]
            if let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gifFrameProps = frameProperties[kCGImagePropertyGIFDictionary] {
                frameOptions[kCGImagePropertyGIFDictionary] = gifFrameProps
            }

            CGImageDestinationAddImage(destination, frameImage, frameOptions as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            let error = TrimrPixError.gifCompressionFailed(url)
            logger.error("GIF re-encoding failed: \(error.technicalDescription)")
            throw error
        }

        let result = outputData as Data
        logger.debug("GIF optimization completed, frames: \(frameCount), size: \(result.count) bytes")
        return result
    }
    
    /// Optimizes WebP image data using CGImageDestination
    /// - Parameter url: The URL of the WebP image
    /// - Returns: The optimized WebP data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeWebPData(at url: URL, settings: CompressionSettings) async throws -> Data {
        logger.debug("Optimizing WebP: \(url.lastPathComponent)")
        return try await compressWithCGImageDestination(at: url, type: .webP, settings: settings, errorFactory: TrimrPixError.webpCompressionFailed)
    }
    
    /// Optimizes AVIF image data using CGImageDestination
    /// Falls back to returning original data if AVIF writing is not supported
    /// - Parameter url: The URL of the AVIF image
    /// - Returns: The optimized AVIF data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeAVIFData(at url: URL, settings: CompressionSettings) async throws -> Data {
        logger.debug("Optimizing AVIF: \(url.lastPathComponent)")
        guard let avifType = UTType("public.avif") else {
            logger.warning("AVIF UTType not available, returning original data")
            return try Data(contentsOf: url)
        }
        return try await compressWithCGImageDestination(at: url, type: avifType, settings: settings, errorFactory: TrimrPixError.avifCompressionFailed)
    }

    /// Optimizes HEIC image data using CGImageDestination
    /// - Parameter url: The URL of the HEIC image
    /// - Returns: The optimized HEIC data
    /// - Throws: TrimrPixError if optimization fails
    private func optimizeHEICData(at url: URL, settings: CompressionSettings) async throws -> Data {
        logger.debug("Optimizing HEIC: \(url.lastPathComponent)")
        return try await compressWithCGImageDestination(at: url, type: .heic, settings: settings, errorFactory: TrimrPixError.heicCompressionFailed)
    }
    
    // MARK: - CGImageDestination Compression

    /// Compresses an image using CGImageDestination for a given UTType
    /// Shared logic for JPEG, WebP, AVIF, and HEIC compression
    /// - Parameters:
    ///   - url: The URL of the image to compress
    ///   - type: The UTType to write (e.g. .jpeg, .webP, .avif, .heic)
    ///   - extraOptions: Additional format-specific options (e.g. progressive JPEG)
    ///   - errorFactory: A closure that creates the appropriate TrimrPixError for the format
    /// - Returns: The compressed image data
    /// - Throws: TrimrPixError if compression fails
    private func compressWithCGImageDestination(
        at url: URL,
        type: UTType,
        settings: CompressionSettings,
        extraOptions: [CFString: Any] = [:],
        errorFactory: (URL) -> TrimrPixError
    ) async throws -> Data {
        let cgImage = try loadImage(at: url, settings: settings, errorFactory: errorFactory)

        let outputData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            outputData, type.identifier as CFString, 1, nil
        ) else {
            // Format not supported by this macOS version — fall back to original data
            logger.warning("\(type.identifier) writing not supported, returning original data")
            return try Data(contentsOf: url)
        }

        // Base options: lossy quality
        // Metadata (EXIF, GPS, IPTC) is already stripped because we load a raw CGImage
        // without copying source properties — no need to null out dictionaries here,
        // which can cause CGImageDestinationFinalize to fail for some formats (e.g. HEIC).
        var options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: settings.compressionQuality,
        ]

        // Merge format-specific options
        for (key, value) in extraOptions {
            options[key] = value
        }

        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            let error = errorFactory(url)
            logger.error("CGImageDestination finalize failed: \(error.technicalDescription)")
            throw error
        }

        let result = outputData as Data
        logger.debug("\(type.identifier) optimization completed, quality: \(Int(settings.compressionQuality * 100))%, size: \(result.count) bytes")
        return result
    }

    /// Loads an image from URL and returns a CGImage, optionally resizing if enabled
    /// - Parameters:
    ///   - url: The URL of the image to load
    ///   - errorFactory: A closure that creates the appropriate TrimrPixError
    /// - Returns: A CGImage ready for compression
    /// - Throws: TrimrPixError if loading fails
    private func loadImage(at url: URL, settings: CompressionSettings, errorFactory: (URL) -> TrimrPixError) throws -> CGImage {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            let error = TrimrPixError.imageLoadFailed(url: url, underlyingError: nil)
            logger.error("Failed to create image source: \(error.technicalDescription)")
            throw error
        }

        // Check if resize is needed
        if settings.resizeEnabled {
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
            let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
            let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
            let maxDim = settings.maxDimension

            if width > maxDim || height > maxDim {
                let thumbnailOptions: [CFString: Any] = [
                    kCGImageSourceThumbnailMaxPixelSize: maxDim,
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                ]

                if let resizedImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) {
                    logger.debug("Resized image from \(width)x\(height) to max \(maxDim)px")
                    return resizedImage
                }
            }
        }

        // No resize needed — load full image
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            let error = errorFactory(url)
            logger.error("Failed to create CGImage: \(error.technicalDescription)")
            throw error
        }

        return cgImage
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

