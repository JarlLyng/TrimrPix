//
//  WatchFolderService.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class WatchFolderService: NSObject, ObservableObject {
    @Published var isWatching: Bool = false
    @Published var watchedPath: String = ""
    
    private var fileSystemWatcher: DispatchSourceFileSystemObject?
    private let fileManager = FileManager.default
    private let compressionService = CompressionService()
    private let supportedExtensions = ["jpg", "jpeg", "png", "gif", "webp", "avif"]
    
    func startWatching(path: String) {
        guard !path.isEmpty, fileManager.fileExists(atPath: path) else {
            print("Invalid watch path: \(path)")
            return
        }
        
        stopWatching()
        
        let url = URL(fileURLWithPath: path)
        let fileDescriptor = open(url.path, O_EVTONLY)
        
        guard fileDescriptor != -1 else {
            print("Failed to open watch path: \(path)")
            return
        }
        
        fileSystemWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .background)
        )
        
        fileSystemWatcher?.setEventHandler { [weak self] in
            self?.handleFileSystemEvent()
        }
        
        fileSystemWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileSystemWatcher?.resume()
        
        DispatchQueue.main.async {
            self.isWatching = true
            self.watchedPath = path
        }
        
        print("Started watching folder: \(path)")
    }
    
    func stopWatching() {
        fileSystemWatcher?.cancel()
        fileSystemWatcher = nil
        
        DispatchQueue.main.async {
            self.isWatching = false
            self.watchedPath = ""
        }
        
        print("Stopped watching folder")
    }
    
    private func handleFileSystemEvent() {
        // Debounce file system events
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(processNewFiles), object: nil)
        self.perform(#selector(processNewFiles), with: nil, afterDelay: 1.0)
    }
    
    @objc private func processNewFiles() {
        guard !watchedPath.isEmpty else { return }
        
        Task.detached { [watchedPath, supportedExtensions, fileManager = self.fileManager, compressionService = self.compressionService] in
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: watchedPath)
                let imageFiles = contents.filter { file in
                    let fileExtension = URL(fileURLWithPath: file).pathExtension.lowercased()
                    return supportedExtensions.contains(fileExtension)
                }
                
                for imageFile in imageFiles {
                    let fullPath = URL(fileURLWithPath: watchedPath).appendingPathComponent(imageFile)
                    await Self.processImageFile(at: fullPath, fileManager: fileManager, compressionService: compressionService)
                }
            } catch {
                print("Error reading watch folder contents: \(error)")
            }
        }
    }
    
    private static func processImageFile(at url: URL, fileManager: FileManager, compressionService: CompressionService) async {
        // Check if file is still being written to (size changes)
        let initialSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64
        try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        let finalSize = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64
        
        // Only process if file size is stable
        guard initialSize == finalSize else { return }
        
        print("Processing new image: \(url.lastPathComponent)")
        
        // Optimize the image
        if let optimizedURL = await compressionService.optimizeImage(at: url) {
            print("Successfully optimized: \(optimizedURL.lastPathComponent)")
        } else {
            print("Failed to optimize: \(url.lastPathComponent)")
        }
    }
    
    deinit {
        stopWatching()
    }
}
