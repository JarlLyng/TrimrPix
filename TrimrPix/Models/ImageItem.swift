//
//  ImageItem.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
    let originalSize: Int64
    var optimizedSize: Int64?
    var thumbnail: NSImage?
    var isOptimizing: Bool = false
    var isOptimized: Bool = false
    
    init(url: URL) {
        self.url = url
        self.filename = url.lastPathComponent
        
        // Hent filstørrelse
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.originalSize = attributes[.size] as? Int64 ?? 0
        } catch {
            self.originalSize = 0
            print("Fejl ved læsning af filstørrelse: \(error)")
        }
        
        // Opret thumbnail
        self.thumbnail = NSImage(contentsOf: url)
    }
    
    var savingsPercentage: Int {
        guard let optimizedSize = optimizedSize, originalSize > 0 else { return 0 }
        let savings = Double(originalSize - optimizedSize) / Double(originalSize) * 100
        return Int(savings)
    }
}

extension Int64 {
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self)
    }
} 