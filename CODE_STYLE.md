# Code Style Guide - TrimrPix

## Overview

This guide defines coding standards and best practices for the TrimrPix project. All developers should follow these guidelines to ensure consistent code quality.

## Swift Style Guidelines

### Naming Conventions

#### Classes, Structs, Enums, Protocols
- **PascalCase** for all types
- Descriptive names that indicate purpose
- **Example**: `CompressionService`, `ImageOptimizationViewModel`, `TrimrPixError`

#### Functions and Methods
- **camelCase** for functions and methods
- Verb-based names for action methods
- Descriptive names that indicate what the method does
- **Example**: `optimizeImage(at:)`, `startWatching(path:)`, `loadSettings()`

#### Variables and Properties
- **camelCase** for variables and properties
- Descriptive names
- Boolean properties should start with `is`, `has`, `can`, etc.
- **Example**: `isOptimizing`, `hasCompleted`, `canSave`, `compressionQuality`

#### Constants
- **camelCase** for local constants
- **SCREAMING_SNAKE_CASE** for global constants (rarely used)
- **Example**: `maxFileSize`, `defaultQuality`

### File Organization

Each file should have the following structure:

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
All types (classes, structs, enums) should have documentation:

```swift
/// Service responsible for image compression and optimization
/// Implements CompressionServiceProtocol for dependency injection and testing
final class CompressionService: CompressionServiceProtocol {
```

#### Method Documentation
All public and internal methods should have documentation:

```swift
/// Optimizes an image at the given URL
/// - Parameter url: The URL of the image to optimize
/// - Returns: The URL of the optimized image
/// - Throws: TrimrPixError if optimization fails
func optimizeImage(at url: URL) async throws -> URL {
```

#### Property Documentation
Complex properties should have documentation:

```swift
/// List of images currently loaded in the application
@Published var images: [ImageItem] = []
```

#### MARK Comments
Use MARK comments to organize code:

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Extensions
```

### Code Formatting

#### Indentation
- **4 spaces** per indentation level (no tabs)
- Xcode standard indentation

#### Line Length
- Try to keep lines under 120 characters
- Break long lines logically

#### Spacing
- One blank line between MARK sections
- One blank line between methods
- No blank lines at the start or end of a type

#### Braces
- Opening brace on the same line as the statement
- Closing brace on a new line

```swift
if condition {
    // code
} else {
    // code
}
```

### Error Handling

#### Use TrimrPixError
Always use the `TrimrPixError` enum for application-specific errors:

```swift
guard fileExists else {
    let error = TrimrPixError.fileNotFound(url)
    logger.error("File not found: \(error.technicalDescription)")
    throw error
}
```

#### Logging Errors
Log all errors through the Logger service:

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
- Propagate errors to the calling function when relevant
- Log errors before propagation
- Display user-friendly messages in the UI layer

### Logging Guidelines

#### Log Levels

- **DEBUG**: Detailed information for development and debugging
- **INFO**: General informational messages about application flow
- **WARNING**: Warnings about potentially problematic situations
- **ERROR**: Errors that do not stop the application
- **FAULT**: Critical errors that may cause application failure

#### When to Log

- **Info**: Start/end of important operations, user actions
- **Debug**: Detailed flow, parameter values
- **Warning**: Unexpected but non-critical situations
- **Error**: All error conditions
- **Fault**: Critical errors that may crash the app

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
Use async/await for asynchronous operations:

```swift
func optimizeImage(at url: URL) async throws -> URL {
    // async work
}
```

#### MainActor
Mark UI-related code with `@MainActor`:

```swift
@MainActor
final class ImageOptimizationViewModel: ObservableObject {
    // UI-related code
}
```

#### TaskGroup for Concurrent Processing
Use TaskGroup for concurrent batch processing:

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
- Avoid force unwrapping (`!`) when possible
- Use optional binding or optional chaining
- Provide default values where it makes sense

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
- Clear type annotations for complex types
- Avoid redundant annotations where the compiler can infer types

```swift
// Good
var images: [ImageItem] = []
let quality: Double = 0.8

// Avoid (when type is obvious)
var images = [ImageItem]()  // OK, but less clear
```

### Dependency Injection

#### Protocol-Based
All services should have protocol-defined interfaces:

```swift
protocol CompressionServiceProtocol {
    func optimizeImage(at url: URL) async throws -> URL
}

final class CompressionService: CompressionServiceProtocol {
    // Implementation
}
```

#### Existential Any Types (Swift 5.9+)
Use the `any` keyword for protocol types (existential any):
- Required in Swift 5.9+ for better type safety
- Makes it explicit that we are using protocol types

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

**Note**: The `any` keyword must be used:
- In property declarations
- In parameter types
- In return types (if a protocol is returned)

**Not required** in:
- Protocol conformance declarations (`class X: Protocol {}`)
- Generic constraints (`where T: Protocol`)

### Testing Considerations

#### Testability
- Design for testability with protocols and dependency injection
- Separation of concerns makes code testable
- Avoid singleton dependencies where possible (use dependency injection)

#### Mocking
- All services should have protocols for mocking
- Logging should be injected for testability

### Comments

#### When to Comment
- **Complex logic**: Explain how and why, not what
- **Workarounds**: Explain limitations and workarounds
- **Business rules**: Document business logic

#### Comment Style
- **Code comments**: `//` for inline comments
- **Documentation comments**: `///` for API documentation
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
Local constants should be defined at the point of use:

```swift
func processImage() {
    let maxSize = 10_000_000  // 10 MB
    // use maxSize
}
```

#### Shared Constants
Shared constants should be in dedicated structs or enums:

```swift
enum UserDefaultsKeys {
    static let compressionQuality = "compressionQuality"
    static let compressionPreset = "compressionPreset"
}
```

### File Organization

#### Single Responsibility
Each file should have one clear responsibility:
- One class/struct/enum per file
- Related extensions in the same file

#### File Naming
- **PascalCase** matching the type name
- **Example**: `ImageItem.swift` for the `ImageItem` type

## Code Review Checklist

When reviewing code, check the following:

- [ ] All public APIs have documentation
- [ ] Error handling is correctly implemented
- [ ] All errors are logged through Logger
- [ ] Dependency injection is used correctly
- [ ] MARK comments organize the code
- [ ] Naming conventions are followed
- [ ] Type safety (no unnecessary force unwraps)
- [ ] Concurrency is handled correctly (@MainActor, async/await)
- [ ] Code is testable (protocols, dependency injection)

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

**Updated**: April 15, 2026
**Version**: 1.5.1
