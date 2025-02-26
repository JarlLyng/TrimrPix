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

class CompressionService {
    
    func optimizeImage(at url: URL) async -> URL? {
        // Bestem filtype
        let fileExtension = url.pathExtension.lowercased()
        
        // Optimer billedet baseret på filtype
        var optimizedData: Data?
        let suggestedFilename = url.deletingPathExtension().lastPathComponent + "-optimized." + fileExtension
        
        switch fileExtension {
        case "jpg", "jpeg":
            optimizedData = await optimizeJPEGData(at: url)
        case "png":
            optimizedData = await optimizePNGData(at: url)
        case "gif":
            optimizedData = await optimizeGIFData(at: url)
        default:
            print("Unsupported file format: \(fileExtension)")
            return nil
        }
        
        // Hvis optimeringen fejlede, returner nil
        guard let data = optimizedData else { return nil }
        
        // Gem den optimerede fil
        return await saveOptimizedImage(data: data, originalURL: url, suggestedFilename: suggestedFilename)
    }
    
    private func optimizeJPEGData(at url: URL) async -> Data? {
        guard let image = NSImage(contentsOf: url) else { 
            print("Error loading JPEG image")
            return nil 
        }
        
        // Komprimeringsindstillinger for JPEG
        let compressionQuality = 0.8 // 80% kvalitet
        
        // Konverter NSImage til Data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality]) else {
            print("Error optimizing JPEG")
            return nil
        }
        
        return jpegData
    }
    
    private func optimizePNGData(at url: URL) async -> Data? {
        guard let image = NSImage(contentsOf: url) else { 
            print("Error loading PNG image")
            return nil 
        }
        
        // Konverter NSImage til PNG data
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            print("Error optimizing PNG")
            return nil
        }
        
        return pngData
    }
    
    private func optimizeGIFData(at url: URL) async -> Data? {
        // For MVP kopierer vi blot GIF-data
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Error reading GIF: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func saveOptimizedImage(data: Data, originalURL: URL, suggestedFilename: String) async -> URL? {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = suggestedFilename
        savePanel.directoryURL = originalURL.deletingLastPathComponent()
        savePanel.allowedContentTypes = [UTType.image]
        
        let response = await savePanel.beginSheetModal(for: NSApp.keyWindow!)
        
        if response == .OK, let url = savePanel.url {
            do {
                try data.write(to: url)
                return url
            } catch {
                print("Error writing optimized image: \(error)")
                return nil
            }
        }
        
        return nil
    }
} 