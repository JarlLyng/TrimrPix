//
//  Protocols.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation
import AppKit

// MARK: - Compression Service Protocol

/// Protocol defining the interface for image compression operations
/// Enables dependency injection and testing
protocol CompressionServiceProtocol {
    /// Optimizes an image at the given URL
    /// - Parameter url: The URL of the image to optimize
    /// - Returns: The URL of the optimized image, or nil if optimization failed
    /// - Throws: TrimrPixError if optimization fails
    func optimizeImage(at url: URL) async throws -> URL
}

// MARK: - Watch Folder Service Protocol

/// Protocol defining the interface for file system monitoring
protocol WatchFolderServiceProtocol {
    /// Starts monitoring a folder for new images
    /// - Parameter path: The folder path to monitor
    /// - Throws: TrimrPixError if monitoring setup fails
    func startWatching(path: String) throws
    
    /// Stops monitoring the current folder
    func stopWatching()
    
    /// Indicates whether a folder is currently being monitored
    var isWatching: Bool { get }
    
    /// The path of the currently monitored folder
    var watchedPath: String { get }
}

// MARK: - File Manager Protocol

/// Protocol for file system operations
/// Enables dependency injection for testing
protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
}

extension FileManager: FileManagerProtocol {}

// MARK: - Image Repository Protocol

/// Protocol for image data access operations
protocol ImageRepositoryProtocol {
    /// Loads image data from a URL
    /// - Parameter url: The URL to load from
    /// - Returns: The loaded image data
    /// - Throws: TrimrPixError if loading fails
    func loadImageData(from url: URL) async throws -> Data
    
    /// Saves image data to a URL
    /// - Parameters:
    ///   - data: The image data to save
    ///   - url: The destination URL
    /// - Throws: TrimrPixError if saving fails
    func saveImageData(_ data: Data, to url: URL) async throws
    
    /// Reads file size for a given URL
    /// - Parameter url: The URL to read size for
    /// - Returns: The file size in bytes
    /// - Throws: TrimrPixError if reading fails
    func getFileSize(for url: URL) async throws -> Int64
}

// MARK: - Settings Protocol

/// Protocol for application settings management
protocol SettingsProtocol: ObservableObject {
    var jpegQuality: Double { get set }
    var compressionPreset: CompressionPreset { get set }
    var overwriteOriginal: Bool { get set }
    var autoSave: Bool { get set }
    var watchFolderEnabled: Bool { get set }
    var watchFolderPath: String { get set }
    
    func saveSettings() throws
    func loadSettings() throws
    func updateQualityFromPreset()
}

