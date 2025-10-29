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

    @Test func testImageItemInitialization() async throws {
        // Test at ImageItem initialiseres korrekt
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")
        let imageItem = ImageItem(url: testURL)
        
        #expect(imageItem.filename == "test.jpg")
        #expect(imageItem.url == testURL)
        #expect(imageItem.isOptimizing == false)
        #expect(imageItem.isOptimized == false)
    }
    
    @Test func testSavingsPercentageCalculation() async throws {
        // Test beregning af besparelse i procent
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")
        var imageItem = ImageItem(url: testURL)
        imageItem.originalSize = 1000
        imageItem.optimizedSize = 800
        
        #expect(imageItem.savingsPercentage == 20)
    }
    
    @Test func testSavingsPercentageWithZeroOriginalSize() async throws {
        // Test edge case med 0 original størrelse
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")
        var imageItem = ImageItem(url: testURL)
        imageItem.originalSize = 0
        imageItem.optimizedSize = 500
        
        #expect(imageItem.savingsPercentage == 0)
    }
    
    @Test func testFormattedSizeExtension() async throws {
        // Test formatering af filstørrelse
        let size1: Int64 = 1024
        let size2: Int64 = 1048576
        
        #expect(size1.formattedSize.contains("KB"))
        #expect(size2.formattedSize.contains("MB"))
    }
    
    @Test func testCompressionServiceInitialization() async throws {
        // Test at CompressionService initialiseres korrekt
        let service = CompressionService()
        #expect(service != nil)
    }

}
