//
//  TrimrPixError.swift
//  TrimrPix
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Foundation

/// Centralized error handling for the application
/// Provides structured error types with user-friendly messages
enum TrimrPixError: LocalizedError {
    // MARK: - Image Loading Errors
    case imageLoadFailed(url: URL, underlyingError: Error?)
    case unsupportedImageFormat(String)
    case invalidImageData(URL)
    case imageTooLarge(URL, maxSize: Int64)
    
    // MARK: - Compression Errors
    case compressionFailed(url: URL, underlyingError: Error?)
    case jpegCompressionFailed(URL)
    case pngCompressionFailed(URL)
    case gifCompressionFailed(URL)
    case webpCompressionFailed(URL)
    case avifCompressionFailed(URL)
    case heicCompressionFailed(URL)
    case formatNotSupported(String)
    
    // MARK: - File System Errors
    case fileNotFound(URL)
    case fileReadError(url: URL, underlyingError: Error?)   // labeled to match call sites
    case fileWriteError(url: URL, underlyingError: Error?)  // labeled to match call sites
    case fileSizeReadError(URL, underlyingError: Error?)
    case invalidFilePath(String)
    case directoryNotFound(URL)
    case permissionDenied(URL)
    
    // MARK: - Watch Folder Errors
    case watchFolderSetupFailed(String, underlyingError: Error?)
    case watchFolderNotFound(String)
    case watchFolderPermissionDenied(String)
    
    // MARK: - Settings Errors
    case settingsLoadFailed(underlyingError: Error?)
    case settingsSaveFailed(underlyingError: Error?)
    case invalidSettingsValue(String)
    
    // MARK: - User Cancellation
    case userCancelled
    
    // MARK: - Unknown Error
    case unknown(underlyingError: Error?)
    
    // MARK: - Error Descriptions
    
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let url, _):
            return "Could not load image: \(url.lastPathComponent)"
        case .unsupportedImageFormat(let format):
            return "Unsupported image format: \(format). Supported formats: JPEG, PNG, GIF, WebP, AVIF, HEIC"
        case .invalidImageData(let url):
            return "Invalid image data: \(url.lastPathComponent)"
        case .imageTooLarge(let url, let maxSize):
            return "Image is too large (\(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file))): \(url.lastPathComponent)"

        case .compressionFailed(let url, _):
            return "Could not compress image: \(url.lastPathComponent)"
        case .jpegCompressionFailed(let url):
            return "JPEG compression failed: \(url.lastPathComponent)"
        case .pngCompressionFailed(let url):
            return "PNG compression failed: \(url.lastPathComponent)"
        case .gifCompressionFailed(let url):
            return "GIF compression failed: \(url.lastPathComponent)"
        case .webpCompressionFailed(let url):
            return "WebP compression failed: \(url.lastPathComponent)"
        case .avifCompressionFailed(let url):
            return "AVIF compression failed: \(url.lastPathComponent)"
        case .heicCompressionFailed(let url):
            return "HEIC compression failed: \(url.lastPathComponent)"
        case .formatNotSupported(let format):
            return "Format not supported: \(format)"

        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileReadError(let url, _):
            return "Could not read file: \(url.lastPathComponent)"
        case .fileWriteError(let url, let error):
            var message = "Could not write file: \(url.lastPathComponent)"
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain {
                    switch nsError.code {
                    case NSFileWriteNoPermissionError:
                        message += " (No write permission)"
                    case NSFileWriteFileExistsError:
                        message += " (File already exists)"
                    case NSFileWriteVolumeReadOnlyError:
                        message += " (Volume is read-only)"
                    default:
                        message += " (\(error.localizedDescription))"
                    }
                } else {
                    message += " (\(error.localizedDescription))"
                }
            }
            return message
        case .fileSizeReadError(let url, _):
            return "Could not read file size: \(url.lastPathComponent)"
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
        case .directoryNotFound(let url):
            return "Folder not found: \(url.path)"
        case .permissionDenied(let url):
            return "Access denied to: \(url.lastPathComponent)"

        case .watchFolderSetupFailed(let path, _):
            return "Could not set up watch folder: \(path)"
        case .watchFolderNotFound(let path):
            return "Watch folder not found: \(path)"
        case .watchFolderPermissionDenied(let path):
            return "Access denied to watch folder: \(path)"

        case .settingsLoadFailed:
            return "Could not load settings"
        case .settingsSaveFailed:
            return "Could not save settings"
        case .invalidSettingsValue(let value):
            return "Invalid settings value: \(value)"

        case .userCancelled:
            return "Operation cancelled by user"

        case .unknown(let error):
            if let error = error {
                return "Unknown error: \(error.localizedDescription)"
            }
            return "An unknown error occurred"
        }
    }
    
    /// Technical description for logging purposes
    var technicalDescription: String {
        switch self {
        case .imageLoadFailed(let url, let error):
            return "ImageLoadFailed(url: \(url.path), error: \(error?.localizedDescription ?? "nil"))"
        case .unsupportedImageFormat(let format):
            return "UnsupportedImageFormat(format: \(format))"
        case .invalidImageData(let url):
            return "InvalidImageData(url: \(url.path))"
        case .imageTooLarge(let url, let maxSize):
            return "ImageTooLarge(url: \(url.path), maxSize: \(maxSize))"
        case .compressionFailed(let url, let error):
            return "CompressionFailed(url: \(url.path), error: \(error?.localizedDescription ?? "nil"))"
        case .jpegCompressionFailed(let url):
            return "JPEGCompressionFailed(url: \(url.path))"
        case .pngCompressionFailed(let url):
            return "PNGCompressionFailed(url: \(url.path))"
        case .gifCompressionFailed(let url):
            return "GIFCompressionFailed(url: \(url.path))"
        case .webpCompressionFailed(let url):
            return "WebPCompressionFailed(url: \(url.path))"
        case .avifCompressionFailed(let url):
            return "AVIFCompressionFailed(url: \(url.path))"
        case .heicCompressionFailed(let url):
            return "HEICCompressionFailed(url: \(url.path))"
        case .formatNotSupported(let format):
            return "FormatNotSupported(format: \(format))"
        case .fileNotFound(let url):
            return "FileNotFound(url: \(url.path))"
        case .fileReadError(let url, let error):
            return "FileReadError(url: \(url.path), error: \(error?.localizedDescription ?? "nil"))"
        case .fileWriteError(let url, let error):
            return "FileWriteError(url: \(url.path), error: \(error?.localizedDescription ?? "nil"))"
        case .fileSizeReadError(let url, let error):
            return "FileSizeReadError(url: \(url.path), error: \(error?.localizedDescription ?? "nil"))"
        case .invalidFilePath(let path):
            return "InvalidFilePath(path: \(path))"
        case .directoryNotFound(let url):
            return "DirectoryNotFound(url: \(url.path))"
        case .permissionDenied(let url):
            return "PermissionDenied(url: \(url.path))"
        case .watchFolderSetupFailed(let path, let error):
            return "WatchFolderSetupFailed(path: \(path), error: \(error?.localizedDescription ?? "nil"))"
        case .watchFolderNotFound(let path):
            return "WatchFolderNotFound(path: \(path))"
        case .watchFolderPermissionDenied(let path):
            return "WatchFolderPermissionDenied(path: \(path))"
        case .settingsLoadFailed(let error):
            return "SettingsLoadFailed(error: \(error?.localizedDescription ?? "nil"))"
        case .settingsSaveFailed(let error):
            return "SettingsSaveFailed(error: \(error?.localizedDescription ?? "nil"))"
        case .invalidSettingsValue(let value):
            return "InvalidSettingsValue(value: \(value))"
        case .userCancelled:
            return "UserCancelled"
        case .unknown(let error):
            return "Unknown(error: \(error?.localizedDescription ?? "nil"))"
        }
    }
    
    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        switch self {
        case .imageLoadFailed, .invalidImageData:
            return "Make sure the image isn't corrupted and try again"
        case .unsupportedImageFormat:
            return "Convert the image to a supported format first"
        case .imageTooLarge:
            return "Reduce the image's resolution or size first"
        case .compressionFailed, .jpegCompressionFailed, .pngCompressionFailed,
             .gifCompressionFailed, .webpCompressionFailed, .avifCompressionFailed, .heicCompressionFailed:
            return "Try reopening the file or convert it to a different format"
        case .fileNotFound:
            return "Make sure the file exists and try again"
        case .fileWriteError, .permissionDenied:
            return "Make sure you have write access to the destination"
        case .watchFolderNotFound:
            return "Choose a valid folder in Settings"
        case .watchFolderPermissionDenied:
            return "Grant the app access to the folder in System Settings"
        case .settingsLoadFailed, .settingsSaveFailed:
            return "Try resetting settings or restart the app"
        default:
            return "Try again. If the problem persists, restart the app"
        }
    }
}

