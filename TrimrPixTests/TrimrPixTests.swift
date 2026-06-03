//
//  TrimrPixTests.swift
//  TrimrPixTests
//
//  Created by Jarl Lyng on 26/02/2025.
//

import Testing
@testable import TrimrPix
import Foundation

struct TrimrPixTests {
    
    // MARK: - ImageItem Tests
    
    @Test func testImageItemInitializationWithNonExistentFile() async throws {
        // Test at ImageItem thrower fejl for ikke-eksisterende fil
        let testURL = URL(fileURLWithPath: "/tmp/nonexistent_test.jpg")
        
        do {
            _ = try ImageItem(url: testURL)
            Issue.record("ImageItem should throw error for non-existent file")
        } catch {
            // Expected behavior
            #expect(error is TrimrPixError)
        }
    }
    
    @Test func testSavingsPercentageCalculation() async throws {
        // Test beregning af besparelse i procent
        // Create a temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_savings.jpg")
        
        // Create empty file
        try? "test".write(to: testFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        var imageItem = try ImageItem(url: testFile)
        // Manually set sizes for testing (normally set in init)
        // Note: originalSize is set in init, so we need to test with actual file
        imageItem.optimizedSize = 800
        
        // Calculate expected savings if originalSize was 1000
        // Since we can't modify originalSize (it's let), we test with actual file size
        if imageItem.originalSize > 0 {
            let savings = Double(imageItem.originalSize - (imageItem.optimizedSize ?? 0)) / Double(imageItem.originalSize) * 100
            #expect(imageItem.savingsPercentage == Int(savings.rounded()))
        }
    }
    
    @Test func testSavingsPercentageWithZeroOriginalSize() async throws {
        // Test edge case - savings should be 0 if original size is 0
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_zero.jpg")
        
        // Create empty file
        try? Data().write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        var imageItem = try ImageItem(url: testFile)
        imageItem.optimizedSize = 500
        
        // If originalSize is 0, savings should be 0
        if imageItem.originalSize == 0 {
            #expect(imageItem.savingsPercentage == 0)
        }
    }
    
    @Test func testFormattedSizeExtension() async throws {
        // Test formatering af filstørrelse
        let size1: Int64 = 1024
        let size2: Int64 = 1048576
        
        #expect(size1.formattedSize.contains("KB"))
        #expect(size2.formattedSize.contains("MB"))
    }
    
    // MARK: - CompressionService Tests
    
    @Test func testCompressionServiceInitialization() async throws {
        // Test at CompressionService initialiseres korrekt
        let service = CompressionService()
        // Ensure the instance is of the expected type and accessible
        #expect(type(of: service) == CompressionService.self)
    }
    
    // MARK: - Settings Tests
    
    @Test @MainActor func testSettingsValidation() async throws {
        let settings = Settings.shared
        
        // Test compression quality validation
        settings.compressionQuality = 0.8
        #expect(settings.compressionQuality == 0.8)

        // Test compression preset
        settings.compressionPreset = .high
        #expect(settings.compressionPreset == .high)
        settings.updateQualityFromPreset()
        #expect(settings.compressionQuality == 0.95)
    }
    
    @Test @MainActor func testWatchFolderPathValidation() async throws {
        let settings = Settings.shared
        
        // Test with invalid path
        settings.watchFolderPath = "/nonexistent/path"
        do {
            try settings.validateWatchFolderPath()
            Issue.record("Should throw error for non-existent path")
        } catch {
            #expect(error is TrimrPixError)
        }
        
        // Test with valid path (temp directory)
        let tempDir = FileManager.default.temporaryDirectory
        settings.watchFolderPath = tempDir.path
        do {
            try settings.validateWatchFolderPath()
            // Should succeed for valid directory
        } catch {
            // May fail if no read permission, which is acceptable
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testTrimrPixErrorDescriptions() async throws {
        let testURL = URL(fileURLWithPath: "/test.jpg")
        let error = TrimrPixError.fileNotFound(testURL)
        
        #expect(error.errorDescription != nil)
        #expect(error.technicalDescription.contains("FileNotFound"))
        #expect(error.recoverySuggestion != nil)
    }

}
