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
            return "Kunne ikke indlæse billede: \(url.lastPathComponent)"
        case .unsupportedImageFormat(let format):
            return "Ikke-understøttet billedformat: \(format). Støttede formater: JPEG, PNG, GIF, WebP, AVIF"
        case .invalidImageData(let url):
            return "Ugyldig billeddata: \(url.lastPathComponent)"
        case .imageTooLarge(let url, let maxSize):
            return "Billede er for stort (\(ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file))): \(url.lastPathComponent)"
            
        case .compressionFailed(let url, _):
            return "Kunne ikke komprimere billede: \(url.lastPathComponent)"
        case .jpegCompressionFailed(let url):
            return "JPEG komprimering fejlede: \(url.lastPathComponent)"
        case .pngCompressionFailed(let url):
            return "PNG komprimering fejlede: \(url.lastPathComponent)"
        case .formatNotSupported(let format):
            return "Format ikke understøttet: \(format)"
            
        case .fileNotFound(let url):
            return "Fil ikke fundet: \(url.lastPathComponent)"
        case .fileReadError(let url, _):
            return "Kunne ikke læse fil: \(url.lastPathComponent)"
        case .fileWriteError(let url, _):
            return "Kunne ikke skrive fil: \(url.lastPathComponent)"
        case .fileSizeReadError(let url, _):
            return "Kunne ikke læse filstørrelse: \(url.lastPathComponent)"
        case .invalidFilePath(let path):
            return "Ugyldig filsti: \(path)"
        case .directoryNotFound(let url):
            return "Mappe ikke fundet: \(url.path)"
        case .permissionDenied(let url):
            return "Adgang nægtet til: \(url.lastPathComponent)"
            
        case .watchFolderSetupFailed(let path, _):
            return "Kunne ikke opsætte watch folder: \(path)"
        case .watchFolderNotFound(let path):
            return "Watch folder ikke fundet: \(path)"
        case .watchFolderPermissionDenied(let path):
            return "Adgang nægtet til watch folder: \(path)"
            
        case .settingsLoadFailed:
            return "Kunne ikke indlæse indstillinger"
        case .settingsSaveFailed:
            return "Kunne ikke gemme indstillinger"
        case .invalidSettingsValue(let value):
            return "Ugyldig indstillingsværdi: \(value)"
            
        case .userCancelled:
            return "Operation annulleret af bruger"
            
        case .unknown(let error):
            if let error = error {
                return "Ukendt fejl: \(error.localizedDescription)"
            }
            return "Ukendt fejl opstod"
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
            return "Sørg for at billedet ikke er beskadiget og prøv igen"
        case .unsupportedImageFormat:
            return "Konverter billedet til et understøttet format først"
        case .imageTooLarge:
            return "Reducer billedets opløsning eller størrelse først"
        case .compressionFailed, .jpegCompressionFailed, .pngCompressionFailed:
            return "Prøv at genåbne filen eller konverter til et andet format"
        case .fileNotFound:
            return "Sørg for at filen eksisterer og prøv igen"
        case .fileWriteError, .permissionDenied:
            return "Sørg for at du har skriveadgang til destinationen"
        case .watchFolderNotFound:
            return "Vælg en gyldig mappe i indstillingerne"
        case .watchFolderPermissionDenied:
            return "Giv appen adgang til mappen i Systemindstillinger"
        case .settingsLoadFailed, .settingsSaveFailed:
            return "Prøv at nulstille indstillingerne eller genstart appen"
        default:
            return "Prøv igen. Hvis problemet vedvarer, genstart appen"
        }
    }
}

