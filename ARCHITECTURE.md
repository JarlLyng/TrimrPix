# TrimrPix Architecture Documentation

## Overview

TrimrPix er en macOS-applikation bygget med SwiftUI, der tilbyder billedkomprimering og optimering. Projektet følger MVVM-arkitektur (Model-View-ViewModel) og benytter moderne Swift-konventioner inklusive async/await, dependency injection og protocol-orienteret design.

## Arkitekturprincipper

### 1. Separation of Concerns
Projektet er organiseret i klare lag med veldefinerede ansvarsområder:
- **Models**: Datastrukturer og forretningslogik
- **Views**: UI-komponenter og præsentation
- **ViewModels**: Koordination mellem Views og Services
- **Services**: Specialiserede funktioner for compression og filsystem-monitorering

### 2. Dependency Injection
Alle services benytter protocol-baserede interfaces, der gør det muligt at injicere dependencies og forenkle testning:
- `CompressionServiceProtocol`
- `WatchFolderServiceProtocol`
- `SettingsProtocol`
- `LoggerProtocol`
- `FileManagerProtocol`

Projektet bruger Swift 5.9+ existential any types (`any` keyword) for protocol types:
- Påkrævet for bedre type safety
- Gør det eksplicit når vi bruger protocol types
- Bruges i property declarations, parameter types og return types

### 3. Error Handling
Centraliseret fejlhåndtering gennem `TrimrPixError` enum:
- Strukturerede fejltyper med brugervenlige beskeder
- Recovery-suggestions til brugere
- Tekniske beskrivelser til logging

### 4. Logging
Centraliseret logging-system gennem `Logger`:
- Strukturerede log-niveauer (debug, info, warning, error, fault)
- Integration med OSLog for Console.app
- Protocol-baseret for testbarhed

## Projektstruktur

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
- Repræsenterer et billede der skal optimeres
- Indeholder original og optimeret filstørrelse
- Beregner besparelsesprocent
- Lazy-loaded thumbnails (max 120px) for memory optimization
- Throwing initializer for bedre error handling

#### Settings
- Singleton for applikationsindstillinger
- Persisterer til UserDefaults
- Validerer indstillingsværdier (compression quality, watch folder path)
- Håndterer compression presets
- Transparent migration fra legacy `jpegQuality` til `compressionQuality` key
- Watch folder delay konfiguration (0.5-10s)
- **Security-Scoped Bookmarks**: Gemmer og genoptager bookmarks for watch folder ved app restart
- **Bookmark Management**: `setWatchFolder()` og `getWatchFolderURL()` metoder for persistent folder access

#### TrimrPixError
- Centraliseret fejltyper for hele applikationen
- Lokaliseret fejlbeskeder (dansk)
- Recovery-suggestions
- Tekniske beskrivelser til logging

### ViewModels

#### ImageOptimizationViewModel
- Koordinerer image optimization workflow
- Håndterer drag & drop operations
- Managerer image list state
- Koordinerer watch folder integration
- `@MainActor` for thread-safe UI updates
- **Background Processing**: Optimering kører i `Task.detached` for at undgå UI-freezing
- **Security-Scoped Access Management**: Tracks og stopper security-scoped resource access når billeder fjernes
- **Dependency Injection**: Bruger injicerede services korrekt (fx compressionService til WatchFolderService)

### Services

#### CompressionService
- Implementerer `CompressionServiceProtocol`
- Håndterer format-specifik komprimering:
  - JPEG: Kvalitets-komprimeret via NSBitmapImageRep (60%-95%)
  - PNG: Optimized compression med alpha channel stripping for opaque images
  - GIF: Validering og kopiering (ingen komprimering)
  - WebP: Ægte komprimering via CGImageDestination (macOS 14+)
  - AVIF: Komprimering via CGImageDestination med graceful fallback
  - HEIC: Komprimering via CGImageDestination
- Delt helper-metode `compressWithCGImageDestination()` for WebP/AVIF/HEIC
- Filtype detection via UTType for robust identifikation
- Security-scoped resource access for sandboxed apps
- Automatisk filnavn konflikthåndtering med unique naming
- Fallback til save panel ved manglende folder access

#### WatchFolderService
- Implementerer `WatchFolderServiceProtocol`
- Monitører en mappe for nye billeder
- Bruger `DispatchSourceFileSystemObject` til file system events
- Debouncing med konfigurerbart delay (fra Settings, 0.5-10s) for at undgå overflødige events
- Filstabilitets-check med konfigurerbart delay (fra Settings)
- Validerer folder path og permissions før start
- **Loop Prevention**: Filtrerer output-filer (`*-optimized*`) og tracker processed files for at undgå re-optimering
- **Processed Files Tracking**: Set-baseret tracking af allerede-behandlede filer for at forhindre re-processing

#### Logger
- Implementerer `LoggerProtocol`
- Struktureret logging med OSLog
- Forskellige log-niveauer
- Automatisk source location tracking
- Protocol extension giver default parameter values for nemmere brug
- Specialiseret `logError()` metode for error objects med context

### Views

#### ContentView
- Hoved-UI view
- Indeholder DropZoneView, ImageListView og controls
- Håndterer error alerts
- Starter/stopper watch folder
- Real-time opdatering af optimization status via reactive bindings

#### SettingsView
- Indstillingspanel
- Compression quality configuration med presets
- Save options (overwrite/auto-save)
- Watch folder configuration med path validation
- Watch folder delay konfiguration (0.5-10s)

## Concurrency

Applikationen bruger moderne Swift concurrency:

- **async/await**: For asynkron operations (image loading, compression)
- **TaskGroup**: For concurrent batch processing
- **Task.detached**: Optimering kører i baggrunden for at undgå UI-freezing
- **@MainActor**: For thread-safe UI updates
- **Actor isolation**: ViewModel er markeret med @MainActor
- **Data Race Prevention**: Settings værdier kopieres på main actor før baggrundsarbejde

## Error Handling Strategy

1. **Error Types**: Brug `TrimrPixError` enum for alle applikations-specifikke fejl
2. **Logging**: Log alle fejl gennem Logger service
3. **User Feedback**: Vis brugervenlige fejlbeskeder gennem alerts
4. **Recovery**: Provide recovery suggestions i `TrimrPixError.recoverySuggestion`

## Testing Considerations

Arkitekturen er designet til testbarhed:

- **Protocols**: Alle services har protocol-definerede interfaces
- **Dependency Injection**: Services kan injiceres i constructors
- **Mocking**: Protocol-baserede services kan nemt mockes

### Eksempel Test Setup

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

1. **Concurrent Processing**: Batch optimization bruger TaskGroup for concurrent processing i baggrunden (`Task.detached`)
2. **Memory Management**: Lazy-loaded thumbnails (max 120px) reducerer memory footprint
3. **File System Monitoring**: Debouncing og konfigurerbart delay reducerer overflødige events
4. **Security-Scoped Resources**: Automatisk håndtering af sandboxed file access med korrekt start/stop
5. **UI Responsiveness**: Optimering kører i baggrunden, UI opdateres kun via `MainActor.run`
6. **Processed Files Tracking**: Set-baseret tracking begrænset til 1000 entries for memory management

## Future Improvements

### Arkitektur
- [ ] Separate ImageRepository for bedre abstraktion
- [ ] Event-baseret kommunikation mellem services
- [ ] Caching layer for optimerede billeder

### Error Handling
- [ ] Retry-strategi for fejlende operations
- [ ] Error reporting til analytics (hvis ønsket)

### Performance
- [ ] Stream-based image loading for store billeder
- [ ] Background processing queue
- [ ] Progress tracking for batch operations

### Testing
- [ ] Unit tests for alle services
- [ ] Integration tests for workflows
- [ ] UI tests med XCTest

## Dependencies

- **SwiftUI**: UI framework
- **Foundation**: Core functionality
- **AppKit**: macOS-specifik functionality (NSSavePanel, NSImage)
- **ImageIO**: CGImageDestination for WebP/AVIF/HEIC compression
- **OSLog**: Unified logging system
- **UniformTypeIdentifiers**: File type identification

## Security Considerations

- **Sandboxing**: Appen er sandboxed (TrimrPix.entitlements)
- **Security-Scoped Resources**: Automatisk håndtering af file access via `startAccessingSecurityScopedResource()`
- **File Access**: Restricted til bruger-valgte lokationer med fallback til save panel
- **Error Messages**: Ingen sensitive data i fejlbeskeder

## Code Quality Standards

1. **Documentation**: Alle public APIs har dokumentation
2. **Naming**: Klare og beskrivende navne
3. **Error Handling**: Alle fejl håndteres eksplicit
4. **Logging**: Alle vigtige operations logges
5. **Type Safety**: Minimal brug af force unwrapping og optionals

---

**Opdateret**: 12. marts 2026
**Version**: 1.4

