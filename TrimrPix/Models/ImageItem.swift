//
//  ImageItem.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit

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
    
    /// Thumbnail preview of the image (lazy loaded)
    private var _thumbnail: NSImage?
    
    /// Indicates whether optimization is currently in progress
    var isOptimizing: Bool = false
    
    /// Indicates whether the image has been optimized
    var isOptimized: Bool = false
    
    // MARK: - Initialization
    
    /// Initializes an image item from a URL
    /// - Parameter url: The URL of the image file
    /// - Throws: TrimrPixError if file cannot be read or is invalid
    /// 
    /// Loads file size. Thumbnail is loaded lazily when accessed.
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
        
        // Thumbnail will be loaded lazily
        self._thumbnail = nil
    }
    
    // MARK: - Thumbnail Management
    
    /// Lazy-loaded thumbnail property
    /// Loads thumbnail on first access to optimize memory usage
    var thumbnail: NSImage? {
        mutating get {
            if _thumbnail == nil {
                _thumbnail = loadThumbnail()
            }
            return _thumbnail
        }
        set {
            _thumbnail = newValue
        }
    }
    
    /// Loads thumbnail from file
    /// - Returns: NSImage thumbnail or nil if loading fails
    private func loadThumbnail() -> NSImage? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        
        // Create a smaller thumbnail to save memory
        let maxDimension: CGFloat = 120
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var thumbnailSize: NSSize
        if size.width > size.height {
            thumbnailSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            thumbnailSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Resize image to thumbnail size
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .sourceOver,
                   fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
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
