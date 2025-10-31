# Code Style Guide - TrimrPix

## Oversigt

Denne guide definerer kodestandarder og bedste praksis for TrimrPix-projektet. Alle udviklere bør følge disse retningslinjer for at sikre konsistent kodekvalitet.

## Swift Style Guidelines

### Naming Conventions

#### Classes, Structs, Enums, Protocols
- **PascalCase** for alle typer
- Beskrivende navne der angiver formålet
- **Eksempel**: `CompressionService`, `ImageOptimizationViewModel`, `TrimrPixError`

#### Functions and Methods
- **camelCase** for funktioner og metoder
- Verb-baserede navne for action-methods
- Beskrivende navne der angiver hvad metoden gør
- **Eksempel**: `optimizeImage(at:)`, `startWatching(path:)`, `loadSettings()`

#### Variables and Properties
- **camelCase** for variabler og properties
- Beskrivende navne
- Boolean properties skal starte med `is`, `has`, `can`, osv.
- **Eksempel**: `isOptimizing`, `hasCompleted`, `canSave`, `jpegQuality`

#### Constants
- **camelCase** for lokale konstanter
- **SCREAMING_SNAKE_CASE** for globale konstanter (sjældent brugt)
- **Eksempel**: `maxFileSize`, `defaultQuality`

### File Organization

Hver fil skal have følgende struktur:

```swift
//
//  Filename.swift
//  TrimrPix
//
//  Created by Author on Date.
//

import Foundation
import SwiftUI

// MARK: - Type Definition

/// Brief description of the type
/// Additional details if needed
class MyClass {
    
    // MARK: - Properties
    
    /// Property documentation
    var property: String
    
    // MARK: - Initialization
    
    /// Initializer documentation
    init() {}
    
    // MARK: - Public Methods
    
    /// Public method documentation
    func publicMethod() {}
    
    // MARK: - Private Methods
    
    /// Private method documentation
    private func privateMethod() {}
}
```

### Documentation Standards

#### Type Documentation
Alle typer (classes, structs, enums) skal have dokumentation:

```swift
/// Service responsible for image compression and optimization
/// Implements CompressionServiceProtocol for dependency injection and testing
final class CompressionService: CompressionServiceProtocol {
```

#### Method Documentation
Alle public og internal metoder skal have dokumentation:

```swift
/// Optimizes an image at the given URL
/// - Parameter url: The URL of the image to optimize
/// - Returns: The URL of the optimized image
/// - Throws: TrimrPixError if optimization fails
func optimizeImage(at url: URL) async throws -> URL {
```

#### Property Documentation
Komplekse properties skal have dokumentation:

```swift
/// List of images currently loaded in the application
@Published var images: [ImageItem] = []
```

#### MARK Comments
Brug MARK-kommentarer til at organisere kode:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
```

### Code Formatting

#### Indentation
- **4 spaces** per indentation level (ingen tabs)
- Xcode standard indentation

#### Line Length
- Prøv at holde linjer under 120 karakterer
- Break lange linjer logisk

#### Spacing
- Én tom linje mellem MARK-sektioner
- Én tom linje mellem metoder
- Ingen tomme linjer i starten eller slutningen af en type

#### Braces
- Åbnende brace på samme linje som statement
- Lukkende brace på ny linje

```swift
if condition {
    // code
} else {
    // code
}
```

### Error Handling

#### Use TrimrPixError
Brug altid `TrimrPixError` enum for applikations-specifikke fejl:

```swift
guard fileExists else {
    let error = TrimrPixError.fileNotFound(url)
    logger.error("File not found: \(error.technicalDescription)")
    throw error
}
```

#### Logging Errors
Log alle fejl gennem Logger service:

```swift
catch let error as TrimrPixError {
    logger.logError(error, context: "Operation description")
    throw error
} catch {
    let trimmedError = TrimrPixError.unknown(underlyingError: error)
    logger.logError(trimmedError, context: "Operation description")
    throw trimmedError
}
```

#### Error Propagation
- Propagate errors til kaldende funktion når det er relevant
- Log fejl før propagation
- Vis brugervenlige beskeder i UI-lag

### Logging Guidelines

#### Log Levels

- **DEBUG**: Detaljeret information til development og debugging
- **INFO**: Generelle informationsbeskeder om applikationsflow
- **WARNING**: Advarsler om potentielt problematiske situationer
- **ERROR**: Fejl som ikke stopper applikationen
- **FAULT**: Kritiske fejl som kan forårsage applikationsfejl

#### When to Log

- **Info**: Start/slut af vigtige operations, bruger-actions
- **Debug**: Detaljeret flow, parameter-værdier
- **Warning**: Uventede men ikke-kritiske situationer
- **Error**: Alle fejl-conditions
- **Fault**: Kritiske fejl der kan crash appen

#### Log Message Format

```swift
// Good
logger.info("Starting optimization: \(filename)")
logger.debug("Compression quality: \(quality)%")
logger.error("Failed to save file: \(error.technicalDescription)")

// Bad
logger.info("Starting")
logger.debug("q: \(quality)")
print("Error: \(error)")
```

### Concurrency

#### Async/Await
Brug async/await for asynkron operations:

```swift
func optimizeImage(at url: URL) async throws -> URL {
    // async work
}
```

#### MainActor
Marker UI-relateret kode med `@MainActor`:

```swift
@MainActor
final class ImageOptimizationViewModel: ObservableObject {
    // UI-related code
}
```

#### TaskGroup for Concurrent Processing
Brug TaskGroup for concurrent batch processing:

```swift
await withTaskGroup(of: Void.self) { group in
    for item in items {
        group.addTask {
            await process(item)
        }
    }
    await group.waitForAll()
}
```

### Type Safety

#### Optionals
- Undgå force unwrapping (`!`) når muligt
- Brug optional binding eller optional chaining
- Provide default values hvor det giver mening

```swift
// Good
guard let value = optionalValue else {
    throw error
}

// Also good
let value = optionalValue ?? defaultValue

// Avoid
let value = optionalValue!  // Only when absolutely certain
```

#### Type Annotations
- Klare type annotations for complex types
- Undgå overflødige annotations hvor compiler kan infer types

```swift
// Good
var images: [ImageItem] = []
let quality: Double = 0.8

// Avoid (when type is obvious)
var images = [ImageItem]()  // OK, but less clear
```

### Dependency Injection

#### Protocol-Based
Alle services skal have protocol-definerede interfaces:

```swift
protocol CompressionServiceProtocol {
    func optimizeImage(at url: URL) async throws -> URL
}

final class CompressionService: CompressionServiceProtocol {
    // Implementation
}
```

#### Existential Any Types (Swift 5.9+)
Brug `any` keyword for protocol types (existential any):
- Påkrævet i Swift 5.9+ for bedre type safety
- Gør det eksplicit at vi bruger protocol types

```swift
private let compressionService: any CompressionServiceProtocol
private let logger: any LoggerProtocol

init(
    compressionService: (any CompressionServiceProtocol)? = nil,
    logger: any LoggerProtocol = Logger.shared
) {
    self.compressionService = compressionService ?? CompressionService()
    self.logger = logger
}
```

**Note**: `any` keyword skal bruges:
- I property declarations
- I parameter types
- I return types (hvis protocol returneret)

**Ikke påkrævet** i:
- Protocol conformance declarations (`class X: Protocol {}`)
- Generic constraints (`where T: Protocol`)

### Testing Considerations

#### Testability
- Design for testbarhed med protocols og dependency injection
- Separation of concerns gør kode testbar
- Undgå singleton-dependencies hvor muligt (brug dependency injection)

#### Mocking
- Alle services skal have protocols til mockning
- Logging skal injectes for testbarhed

### Comments

#### When to Comment
- **Kompleks logik**: Forklar hvordan og hvorfor, ikke hvad
- **Workarounds**: Forklar begrænsninger og workarounds
- **Business rules**: Dokumenter forretningslogik

#### Comment Style
- **Code comments**: `//` for inline comments
- **Documentation comments**: `///` for API dokumentation
- **MARK comments**: `// MARK:` for organization

```swift
/// Public API documentation
func publicMethod() {
    // Implementation detail explanation
    let result = complexCalculation()
    
    // Workaround for macOS limitation
    // See: https://example.com/issue
    if needsWorkaround {
        // ...
    }
}
```

### Constants

#### Local Constants
Lokale konstanter skal være ved brug:

```swift
func processImage() {
    let maxSize = 10_000_000  // 10 MB
    // use maxSize
}
```

#### Shared Constants
Deling konstanter skal være i dedikerede structs eller enums:

```swift
enum UserDefaultsKeys {
    static let jpegQuality = "jpegQuality"
    static let compressionPreset = "compressionPreset"
}
```

### File Organization

#### Single Responsibility
Hver fil skal have ét klart ansvar:
- En klasse/strukt/enum per fil
- Relaterede extensions i samme fil

#### File Naming
- **PascalCase** matcher type-navnet
- **Eksempel**: `ImageItem.swift` for `ImageItem` type

## Code Review Checklist

Når du reviewer kode, tjek følgende:

- [ ] Alle public APIs har dokumentation
- [ ] Error handling er korrekt implementeret
- [ ] Alle fejl logges gennem Logger
- [ ] Dependency injection bruges korrekt
- [ ] MARK-kommentarer organiserer kode
- [ ] Naming conventions følges
- [ ] Type safety (ingen unødvendige force unwraps)
- [ ] Concurrency er korrekt håndteret (@MainActor, async/await)
- [ ] Code er testbar (protocols, dependency injection)

## Examples

### Good Example

```swift
//
//  CompressionService.swift
//  TrimrPix
//
//  Created by Author on Date.
//

import Foundation
import AppKit

/// Service responsible for image compression and optimization
/// Implements CompressionServiceProtocol for dependency injection and testing
final class CompressionService: CompressionServiceProtocol {
    
    // MARK: - Dependencies
    
    private let settings: SettingsProtocol
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    
    /// Initializes the compression service with dependencies
    /// - Parameters:
    ///   - settings: Settings protocol instance
    ///   - logger: Logger protocol instance
    init(
        settings: SettingsProtocol = Settings.shared,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.settings = settings
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Optimizes an image at the given URL
    /// - Parameter url: The URL of the image to optimize
    /// - Returns: The URL of the optimized image
    /// - Throws: TrimrPixError if optimization fails
    func optimizeImage(at url: URL) async throws -> URL {
        logger.info("Starting image optimization for: \(url.lastPathComponent)")
        
        guard fileManager.fileExists(atPath: url.path) else {
            let error = TrimrPixError.fileNotFound(url)
            logger.logError(error, context: "Optimizing image")
            throw error
        }
        
        // Implementation
    }
}
```

### Bad Example

```swift
import Foundation

class CompressionService {
    var settings = Settings.shared
    var logger = Logger.shared
    
    init() {}
    
    func optimizeImage(at url: URL) async -> URL? {
        if !FileManager.default.fileExists(atPath: url.path) {
            print("File not found")
            return nil
        }
        
        // Implementation without error handling
    }
}
```

---

**Opdateret**: 26. februar 2025  
**Version**: 1.0

