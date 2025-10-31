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
    
    /// Thumbnail preview of the image
    var thumbnail: NSImage?
    
    /// Indicates whether optimization is currently in progress
    var isOptimizing: Bool = false
    
    /// Indicates whether the image has been optimized
    var isOptimized: Bool = false
    
    // MARK: - Initialization
    
    /// Initializes an image item from a URL
    /// - Parameter url: The URL of the image file
    /// 
    /// Loads file size and creates a thumbnail preview automatically
    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        
        // Load file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.originalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            self.originalSize = 0
            // Note: Logger is not accessible from struct, so we silently handle the error
            // The error will be logged when the ImageItem is used in the ViewModel
        }
        
        // Create thumbnail
        self.thumbnail = NSImage(contentsOf: url)
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
