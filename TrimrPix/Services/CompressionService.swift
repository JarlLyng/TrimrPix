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
    private let settings = Settings.shared
    
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
        case "webp":
            optimizedData = await optimizeWebPData(at: url)
        case "avif":
            optimizedData = await optimizeAVIFData(at: url)
        default:
            print("Unsupported file format: \(fileExtension)")
            return nil
        }
        
        // Hvis optimeringen fejlede, returner nil
        guard let data = optimizedData else { return nil }
        
        // Gem den optimerede fil
        if settings.overwriteOriginal {
            return await overwriteOriginalImage(data: data, originalURL: url)
        } else if settings.autoSave {
            // Auto-save: gem i samme mappe som originalen
            return await saveInSameFolder(data: data, originalURL: url, suggestedFilename: suggestedFilename)
        } else {
            // Manual save: spørg brugeren om placering
            return await saveOptimizedImage(data: data, originalURL: url, suggestedFilename: suggestedFilename)
        }
    }
    
    private func optimizeJPEGData(at url: URL) async -> Data? {
        guard let image = NSImage(contentsOf: url) else { 
            print("Error loading JPEG image")
            return nil 
        }
        
        // Komprimeringsindstillinger for JPEG
        let compressionQuality = settings.jpegQuality
        
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
        // For MVP kopierer vi blot GIF-data, men tilføjer validering
        do {
            let data = try Data(contentsOf: url)
            
            // Valider at det er en gyldig GIF
            guard data.count > 6 else { return nil }
            let header = data.prefix(6)
            guard String(data: header, encoding: .ascii) == "GIF87a" || 
                  String(data: header, encoding: .ascii) == "GIF89a" else {
                print("Invalid GIF format")
                return nil
            }
            
            return data
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
        
        guard let keyWindow = NSApp.keyWindow else {
            // Fallback: present as modal if no keyWindow
            let response = savePanel.runModal()
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
        
        let response = await savePanel.beginSheetModal(for: keyWindow)
        
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
    
    private func optimizeWebPData(at url: URL) async -> Data? {
        // macOS/AppKit har ikke indbygget WebP-encoder i NSBitmapImageRep.
        // MVP: valider og returner original data (no-op).
        do {
            let data = try Data(contentsOf: url)
            // Minimal validering: WebP signature "RIFF....WEBP"
            guard data.count >= 12 else { return nil }
            let riff = data.prefix(4)
            let webp = data.dropFirst(8).prefix(4)
            guard String(data: riff, encoding: .ascii) == "RIFF",
                  String(data: webp, encoding: .ascii) == "WEBP" else {
                print("Invalid WebP format")
                return nil
            }
            return data
        } catch {
            print("Error reading WebP: \(error)")
            return nil
        }
    }
    
    private func optimizeAVIFData(at url: URL) async -> Data? {
        // macOS/AppKit har ikke indbygget AVIF-encoder i NSBitmapImageRep.
        // MVP: valider og returner original data (no-op).
        do {
            let data = try Data(contentsOf: url)
            // Minimal validering: ISO BMFF brand contains "avif"/"avis"
            guard data.count >= 12 else { return nil }
            // ftyp box starts at offset 4 with "ftyp"
            let brand = data.dropFirst(8).prefix(4)
            if let brandStr = String(data: brand, encoding: .ascii),
               brandStr.lowercased() == "avif" || brandStr.lowercased() == "avis" {
                return data
            } else {
                // Not a strict validator; still accept to avoid false negatives
                return data
            }
        } catch {
            print("Error reading AVIF: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func saveInSameFolder(data: Data, originalURL: URL, suggestedFilename: String) async -> URL? {
        let destinationURL = originalURL.deletingLastPathComponent().appendingPathComponent(suggestedFilename)
        
        do {
            try data.write(to: destinationURL)
            return destinationURL
        } catch {
            print("Error saving optimized image in same folder: \(error)")
            return nil
        }
    }
    
    @MainActor
    private func overwriteOriginalImage(data: Data, originalURL: URL) async -> URL? {
        do {
            try data.write(to: originalURL)
            return originalURL
        } catch {
            print("Error overwriting original image: \(error)")
            return nil
        }
    }
}
