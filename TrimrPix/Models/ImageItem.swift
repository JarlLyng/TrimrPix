//
//  ImageItem.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import ImageIO
import PDFKit

/// Represents an image item to be optimized
/// Contains all information about the image including original size, optimized size, and status
struct ImageItem: Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for the image item
    let id = UUID()
    
    /// URL of the image file
    let url: URL
    
    /// Filename of the image
    let filename: String
    
    /// Original file size in bytes
    let originalSize: Int64
    
    /// Optimized file size in bytes (nil if not yet optimized)
    var optimizedSize: Int64?

    /// Indicates whether optimization is currently in progress
    var isOptimizing: Bool = false
    
    /// Indicates whether the image has been optimized
    var isOptimized: Bool = false
    
    // MARK: - Initialization
    
    /// Initializes an image item from a URL
    /// - Parameter url: The URL of the image file
    /// - Throws: TrimrPixError if file cannot be read or is invalid
    ///
    /// Loads file size only; thumbnails are generated separately via `loadThumbnail(from:)`.
    init(url: URL) throws {
        self.url = url
        self.filename = url.lastPathComponent
        
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TrimrPixError.fileNotFound(url)
        }
        
        // Load file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.originalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            throw TrimrPixError.fileSizeReadError(url, underlyingError: error)
        }
    }
    
    // MARK: - Thumbnail Generation

    /// Generates a small preview thumbnail for the image at `url`.
    ///
    /// Runs off the main actor (nonisolated async) and uses ImageIO's
    /// `CGImageSourceCreateThumbnailAtIndex`, which decodes directly at thumbnail
    /// size — a large photo never occupies full-resolution memory or blocks the UI
    /// for a 60pt list preview. Same API family the compression pipeline uses for resize.
    ///
    /// - Parameters:
    ///   - url: The image file to preview
    ///   - maxPixelSize: Longest edge of the generated thumbnail (default 240 ≈ 120pt @2x)
    /// - Returns: A thumbnail CGImage, or nil if the file can't be read as an image
    static func loadThumbnail(from url: URL, maxPixelSize: Int = 240) async -> CGImage? {
        // PDFs are not readable by ImageIO, so render their first page instead.
        if url.pathExtension.lowercased() == "pdf" {
            return pdfThumbnail(from: url, maxPixelSize: maxPixelSize)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Renders the first page of a PDF as a preview thumbnail.
    private static func pdfThumbnail(from url: URL, maxPixelSize: Int) -> CGImage? {
        guard let document = CGPDFDocument(url as CFURL),
              let page = document.page(at: 1) else { return nil }

        let bounds = page.getBoxRect(.mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = CGFloat(maxPixelSize) / max(bounds.width, bounds.height)
        let width = max(1, Int(bounds.width * scale))
        let height = max(1, Int(bounds.height * scale))

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        // PDF pages have no background of their own; paper is white.
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.drawPDFPage(page)
        return context.makeImage()
    }
    
    // MARK: - Computed Properties
    
    /// Calculates the savings percentage after optimization
    /// Returns 0 if not yet optimized or original size is 0
    var savingsPercentage: Int {
        guard let optimizedSize = optimizedSize, originalSize > 0 else { return 0 }
        let savings = Double(originalSize - optimizedSize) / Double(originalSize) * 100
        return Int(savings.rounded())
    }
}

// MARK: - Extensions

/// Extension providing formatted size display
extension Int64 {
    /// Returns a formatted string representation of the byte count
    /// Example: "1.5 MB" or "256 KB"
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
}
