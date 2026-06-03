# TrimrPix Architecture Documentation

## Overview

TrimrPix is a macOS application built with SwiftUI that offers image compression and optimization. The project follows MVVM architecture (Model-View-ViewModel) and uses modern Swift conventions including async/await, dependency injection, and protocol-oriented design.

## Architecture Principles

### 1. Separation of Concerns
The project is organized into clear layers with well-defined responsibilities:
- **Models**: Data structures and business logic
- **Views**: UI components and presentation
- **ViewModels**: Coordination between Views and Services
- **Services**: Specialized functionality for compression and file system monitoring

### 2. Dependency Injection
All services use protocol-based interfaces, enabling dependency injection and simplifying testing:
- `CompressionServiceProtocol`
- `WatchFolderServiceProtocol`
- `SettingsProtocol`
- `LoggerProtocol`
- `FileManagerProtocol`

The project uses Swift 5.9+ existential any types (`any` keyword) for protocol types:
- Required for better type safety
- Makes protocol type usage explicit
- Used in property declarations, parameter types, and return types

### 3. Error Handling
Centralized error handling through `TrimrPixError` enum:
- Structured error types with user-friendly messages
- Recovery suggestions for users
- Technical descriptions for logging

### 4. Logging
Centralized logging system through `Logger`:
- Structured log levels (debug, info, warning, error, fault)
- Integration with OSLog for Console.app
- Protocol-based for testability

## Project Structure

```
TrimrPix/
├── TrimrPixApp.swift          # App entry point
├── ContentView.swift          # Main UI view
├── Models/
│   ├── ImageItem.swift        # Image data model
│   ├── Settings.swift         # Settings management
│   └── TrimrPixError.swift    # Centralized error types
├── ViewModels/
│   └── ImageOptimizationViewModel.swift  # Business logic coordination
├── Views/
│   └── SettingsView.swift     # Settings panel UI
├── Services/
│   ├── CompressionService.swift    # Image compression logic
│   ├── ColorQuantizer.swift        # Median-cut color quantization for PNG
│   ├── WatchFolderService.swift    # File system monitoring
│   ├── Logger.swift                # Logging service
│   └── Protocols.swift             # Service protocol definitions
└── Assets.xcassets/          # App icons and assets
```

## Data Flow

### Image Optimization Flow

```
User Drags Image
    ↓
ContentView.handleDrop()
    ↓
ImageOptimizationViewModel.handleDrop()
    ↓
ImageItem created → Images array updated
    ↓
User clicks "Optimize All"
    ↓
ImageOptimizationViewModel.optimizeAllImages()
    ↓
Concurrent TaskGroup → optimizeImage(at:) for each
    ↓
CompressionService.optimizeImage()
    ↓
Format-specific optimization (JPEG/PNG/GIF/WebP/AVIF/HEIC)
    ↓
Save optimized file based on settings
    ↓
Update ImageItem with optimized size
    ↓
UI updates automatically via @Published properties
```

### Watch Folder Flow

```
User enables Watch Folder in Settings
    ↓
Settings.saveSettings() → UserDefaults
    ↓
ImageOptimizationViewModel.startWatchFolder()
    ↓
WatchFolderService.startWatching()
    ↓
DispatchSourceFileSystemObject monitors folder
    ↓
File system event detected
    ↓
Debounce (1 second delay)
    ↓
Process new files
    ↓
Check file stability (size check with configurable delay from Settings)
    ↓
CompressionService.optimizeImage()
    ↓
Optimized file saved
```

## Core Components

### Models

#### ImageItem
- Represents an image to be optimized
- Contains original and optimized file size
- Calculates savings percentage
- Lazy-loaded thumbnails (max 120px) for memory optimization
- Throwing initializer for better error handling

#### Settings
- Singleton for application settings
- Persists to UserDefaults
- Validates setting values (compression quality, watch folder path)
- Handles compression presets
- Transparent migration from legacy `jpegQuality` to `compressionQuality` key
- Watch folder delay configuration (0.5-10s)
- **Security-Scoped Bookmarks**: Stores and restores bookmarks for watch folder on app restart
- **Bookmark Management**: `setWatchFolder()` and `getWatchFolderURL()` methods for persistent folder access

#### TrimrPixError
- Centralized error types for the entire application
- Localized error messages
- Recovery suggestions
- Technical descriptions for logging

### ViewModels

#### ImageOptimizationViewModel
- Coordinates image optimization workflow
- Handles drag & drop operations
- Manages image list state
- Coordinates watch folder integration
- `@MainActor` for thread-safe UI updates
- **Background Processing**: Optimization runs off the main actor with bounded concurrency (capped at the processor count) to avoid UI freezing and memory spikes on large batches
- **Security-Scoped Access Management**: Tracks and stops security-scoped resource access when images are removed
- **Dependency Injection**: Uses injected services correctly (e.g. compressionService for WatchFolderService)

### Services

#### CompressionService
- Implements `CompressionServiceProtocol`
- Handles format-specific compression:
  - JPEG: Progressive encoding via CGImageDestination with optimized Huffman tables (60%-95%)
  - PNG: Lossy quantization (median-cut, 256 colors) with fallback to alpha channel stripping
  - GIF: Re-encoding via CGImageSource/CGImageDestination with LZW re-compression (preserves animation timing)
  - WebP: Compression via CGImageDestination (macOS 14+)
  - AVIF: Compression via CGImageDestination with graceful fallback
  - HEIC: Compression via CGImageDestination
- Shared helper method `compressWithCGImageDestination()` for JPEG/WebP/AVIF/HEIC with metadata stripping
- Shared `loadImage()` helper with optional pre-compression resizing via `CGImageSourceCreateThumbnailAtIndex`
- **Metadata stripping**: EXIF, GPS, IPTC, and MakerApple data removed from all CGImageDestination formats
- **Image resizing**: Optional downscaling before compression (configurable max dimension, never upscales)
- File type detection via UTType for robust identification
- Security-scoped resource access for sandboxed apps
- Automatic filename conflict resolution with unique naming
- Fallback to save panel when folder access is missing
- **Size guard**: Keeps the original file if compression would increase file size

#### ColorQuantizer
- Median-cut color quantization algorithm for lossy PNG compression
- Reduces images to 256 colors for 60-80% smaller PNG files
- Handles transparency (transparent pixels mapped to single palette entry)
- Samples up to 100,000 pixels for performance on large images
- Pure Swift implementation, no third-party dependencies

#### WatchFolderService
- Implements `WatchFolderServiceProtocol`
- Monitors a folder for new images
- Uses `DispatchSourceFileSystemObject` for file system events
- Debouncing with configurable delay (from Settings, 0.5-10s) to avoid redundant events
- File stability check with configurable delay (from Settings)
- Validates folder path and permissions before starting
- **Loop Prevention**: Filters output files (`*-optimized*`) and tracks processed files to avoid re-optimization
- **Processed Files Tracking**: Set-based tracking of already-processed files to prevent re-processing

#### Logger
- Implements `LoggerProtocol`
- Structured logging with OSLog
- Multiple log levels
- Automatic source location tracking
- Protocol extension provides default parameter values for easier use
- Specialized `logError()` method for error objects with context

### Views

#### ContentView
- Main UI view
- Contains DropZoneView, ImageListView, and controls
- Handles error alerts
- Starts/stops watch folder
- Real-time updates of optimization status via reactive bindings

#### SettingsView
- Settings panel
- Compression quality configuration with presets
- Image resize options (toggle + max dimension picker)
- PNG lossy quantization toggle
- Save options (overwrite/auto-save)
- Watch folder configuration with path validation
- Watch folder delay configuration (0.5-10s)

## Concurrency

The application uses modern Swift concurrency:

- **async/await**: For asynchronous operations (image loading, compression)
- **TaskGroup**: For concurrent batch processing
- **Bounded concurrency**: Batch optimization runs at most `min(processorCount, 4)` jobs at once via a `TaskGroup`, so large drops don't decode every image into memory simultaneously
- **@MainActor**: For thread-safe UI updates; `ImageOptimizationViewModel`, `WatchFolderService`, `Settings` and `SettingsProtocol` are all main-actor isolated
- **Data Race Prevention**: Settings are captured into an immutable `Sendable` `CompressionSettings` snapshot on the main actor before any background work; `CompressionService` is stateless and reads no shared state off-main
- **Swift 6**: The project builds in Swift 6 language mode with complete data-race checking enabled

## Error Handling Strategy

1. **Error Types**: Use `TrimrPixError` enum for all application-specific errors
2. **Logging**: Log all errors through the Logger service
3. **User Feedback**: Display user-friendly error messages through alerts
4. **Recovery**: Provide recovery suggestions in `TrimrPixError.recoverySuggestion`

## Testing Considerations

The architecture is designed for testability:

- **Protocols**: All services have protocol-defined interfaces
- **Dependency Injection**: Services can be injected in constructors
- **Mocking**: Protocol-based services can be easily mocked

### Example Test Setup

```swift
// Mock Logger
class MockLogger: LoggerProtocol {
    var loggedMessages: [String] = []
    func log(_ level: LogLevel, message: String, ...) {
        loggedMessages.append(message)
    }
    // ... implement other methods
}

// Test CompressionService
let mockLogger = MockLogger()
let compressionService = CompressionService(logger: mockLogger)
// ... test compression logic
```

## Performance Considerations

1. **Concurrent Processing**: Batch optimization uses a `TaskGroup` with bounded concurrency, so peak memory stays low even on large batches
2. **Memory Management**: Lazy-loaded thumbnails (max 120px) reduce memory footprint
3. **File System Monitoring**: Debouncing and configurable delay reduce redundant events
4. **Security-Scoped Resources**: Automatic handling of sandboxed file access with correct start/stop
5. **UI Responsiveness**: Optimization runs in the background, UI updates only via `MainActor.run`
6. **Processed Files Tracking**: Set-based tracking limited to 1000 entries for memory management

## Future Improvements

Planned improvements are tracked as [GitHub Issues](https://github.com/JarlLyng/TrimrPix/issues). Key areas include architecture refinements, error handling improvements, performance optimizations, and expanded test coverage.

## Dependencies

- **SwiftUI**: UI framework
- **Foundation**: Core functionality
- **AppKit**: macOS-specific functionality (NSSavePanel, NSImage)
- **ImageIO**: CGImageSource/CGImageDestination for JPEG/PNG/GIF/WebP/AVIF/HEIC compression and image resizing
- **StoreKit**: App Store review prompts
- **OSLog**: Unified logging system
- **UniformTypeIdentifiers**: File type identification

## Security Considerations

- **Sandboxing**: The app is sandboxed (TrimrPix.entitlements)
- **Security-Scoped Resources**: Automatic handling of file access via `startAccessingSecurityScopedResource()`
- **File Access**: Restricted to user-selected locations with fallback to save panel
- **Error Messages**: No sensitive data in error messages

## Code Quality Standards

1. **Documentation**: All public APIs are documented
2. **Naming**: Clear and descriptive names
3. **Error Handling**: All errors are handled explicitly
4. **Logging**: All important operations are logged
5. **Type Safety**: Minimal use of force unwrapping and optionals

---

**Updated**: June 3, 2026
**Version**: 1.5.2
