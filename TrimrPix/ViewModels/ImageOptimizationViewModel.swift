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
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let compressionService = CompressionService()
    private let watchFolderService = WatchFolderService()
    private let settings = Settings.shared
    
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
                    await MainActor.run {
                        self.showError(message: "Error loading image: \(error.localizedDescription)")
                    }
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
            // Concurrent processing for better performance
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<images.count {
                    group.addTask {
                        await self.optimizeImage(at: index)
                    }
                }
                
                // Wait for all tasks to complete
                await group.waitForAll()
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
                    self.showError(message: "Error reading optimized file: \(error.localizedDescription)")
                }
            }
        } else {
            await MainActor.run {
                self.images[index].isOptimizing = false
                self.showError(message: "Error optimizing image: \(imageItem.filename)")
            }
        }
    }
    
    @MainActor
    private func showError(message: String) {
        self.errorMessage = message
        self.showError = true
    }
    
    func dismissError() {
        self.showError = false
        self.errorMessage = nil
    }
    
    func startWatchFolder() {
        guard settings.watchFolderEnabled, !settings.watchFolderPath.isEmpty else { return }
        watchFolderService.startWatching(path: settings.watchFolderPath)
    }
    
    func stopWatchFolder() {
        watchFolderService.stopWatching()
    }
    
    var isWatchFolderActive: Bool {
        watchFolderService.isWatching
    }
}
