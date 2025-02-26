//
//  ImageOptimizationViewModel.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class ImageOptimizationViewModel: ObservableObject {
    @Published var images: [ImageItem] = []
    @Published var isOptimizing: Bool = false
    
    private let compressionService = CompressionService()
    
    @MainActor
    func handleDrop(providers: [NSItemProvider]) async {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                do {
                    let url = try await loadItemFromProvider(provider: provider)
                    if let url = url {
                        // Kontroller om billedet allerede er tilføjet
                        if !images.contains(where: { $0.url.path == url.path }) {
                            let imageItem = ImageItem(url: url)
                            self.images.append(imageItem)
                        }
                    }
                } catch {
                    print("Error loading image: \(error)")
                }
            }
        }
    }
    
    @MainActor
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
    
    func clearImages() {
        images.removeAll()
    }
    
    func optimizeAllImages() {
        guard !images.isEmpty, !isOptimizing else { return }
        
        isOptimizing = true
        
        Task {
            for index in 0..<images.count {
                await optimizeImage(at: index)
            }
            
            await MainActor.run {
                self.isOptimizing = false
            }
        }
    }
    
    func optimizeImage(at index: Int) async {
        guard index < images.count else { return }
        
        await MainActor.run {
            self.images[index].isOptimizing = true
        }
        
        // Hent billedet
        let imageItem = images[index]
        
        // Optimer billedet
        if let optimizedURL = await compressionService.optimizeImage(at: imageItem.url) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: optimizedURL.path)
                let optimizedSize = attributes[.size] as? Int64 ?? 0
                
                await MainActor.run {
                    self.images[index].optimizedSize = optimizedSize
                    self.images[index].isOptimized = true
                    self.images[index].isOptimizing = false
                }
            } catch {
                print("Error reading optimized file size: \(error)")
                await MainActor.run {
                    self.images[index].isOptimizing = false
                }
            }
        } else {
            await MainActor.run {
                self.images[index].isOptimizing = false
            }
        }
    }
} 