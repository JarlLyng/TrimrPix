//
//  ColorQuantizer.swift
//  TrimrPix
//
//  Median-cut color quantization for lossy PNG compression.
//  Reduces images to 256 colors for dramatically smaller PNG files.
//

import Foundation
import CoreGraphics

/// Median-cut color quantizer that reduces a CGImage to a limited color palette
final class ColorQuantizer {

    private let maxColors: Int
    private let logger: any LoggerProtocol

    init(maxColors: Int = 256, logger: any LoggerProtocol = Logger.shared) {
        self.maxColors = maxColors
        self.logger = logger
    }

    /// Quantizes a CGImage to the configured number of colors
    /// - Parameter image: The source CGImage
    /// - Returns: A new CGImage with reduced colors, or nil if quantization fails
    func quantize(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let pixelCount = width * height

        // Extract RGBA pixel data
        guard let pixels = extractPixels(from: image, width: width, height: height) else {
            logger.debug("ColorQuantizer: Failed to extract pixels")
            return nil
        }

        // Build color buckets using median-cut
        let palette = medianCut(pixels: pixels, maxColors: maxColors)
        guard !palette.isEmpty else {
            logger.debug("ColorQuantizer: Empty palette")
            return nil
        }

        // Map each pixel to nearest palette color and write output
        let outputImage = applyPalette(pixels: pixels, palette: palette, width: width, height: height)

        logger.debug("ColorQuantizer: Reduced to \(palette.count) colors for \(pixelCount) pixels")
        return outputImage
    }

    // MARK: - Pixel Extraction

    private struct RGBA {
        var r: UInt8
        var g: UInt8
        var b: UInt8
        var a: UInt8
    }

    private func extractPixels(from image: CGImage, width: Int, height: Int) -> [RGBA]? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels = [RGBA]()
        pixels.reserveCapacity(width * height)

        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            pixels.append(RGBA(
                r: pixelData[i],
                g: pixelData[i + 1],
                b: pixelData[i + 2],
                a: pixelData[i + 3]
            ))
        }

        return pixels
    }

    // MARK: - Median Cut

    private struct ColorBucket {
        var pixels: [RGBA]

        var rangeR: Int {
            let values = pixels.map { Int($0.r) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }
        var rangeG: Int {
            let values = pixels.map { Int($0.g) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }
        var rangeB: Int {
            let values = pixels.map { Int($0.b) }
            return (values.max() ?? 0) - (values.min() ?? 0)
        }

        /// The channel with the greatest range
        var dominantChannel: Int {
            let r = rangeR, g = rangeG, b = rangeB
            if r >= g && r >= b { return 0 }
            if g >= r && g >= b { return 1 }
            return 2
        }

        /// Average color of all pixels in this bucket
        var averageColor: RGBA {
            guard !pixels.isEmpty else { return RGBA(r: 0, g: 0, b: 0, a: 255) }
            var sumR = 0, sumG = 0, sumB = 0, sumA = 0
            for p in pixels {
                sumR += Int(p.r)
                sumG += Int(p.g)
                sumB += Int(p.b)
                sumA += Int(p.a)
            }
            let count = pixels.count
            return RGBA(
                r: UInt8(sumR / count),
                g: UInt8(sumG / count),
                b: UInt8(sumB / count),
                a: UInt8(sumA / count)
            )
        }
    }

    private func medianCut(pixels: [RGBA], maxColors: Int) -> [RGBA] {
        // Separate fully transparent pixels — they get a single palette entry
        var opaquePixels = [RGBA]()
        var hasTransparent = false

        for p in pixels {
            if p.a < 10 {
                hasTransparent = true
            } else {
                opaquePixels.append(p)
            }
        }

        guard !opaquePixels.isEmpty else {
            return hasTransparent ? [RGBA(r: 0, g: 0, b: 0, a: 0)] : []
        }

        // For large images, sample pixels to speed up the median-cut
        let samplePixels: [RGBA]
        let maxSampleSize = 100_000
        if opaquePixels.count > maxSampleSize {
            let step = opaquePixels.count / maxSampleSize
            samplePixels = stride(from: 0, to: opaquePixels.count, by: step).map { opaquePixels[$0] }
        } else {
            samplePixels = opaquePixels
        }

        let targetColors = hasTransparent ? maxColors - 1 : maxColors
        var buckets = [ColorBucket(pixels: samplePixels)]

        while buckets.count < targetColors {
            // Find the bucket with the most pixels (weighted) to split
            guard let splitIndex = buckets.enumerated().max(by: { $0.element.pixels.count < $1.element.pixels.count })?.offset,
                  buckets[splitIndex].pixels.count > 1 else {
                break
            }

            let bucket = buckets.remove(at: splitIndex)
            let channel = bucket.dominantChannel

            var sorted = bucket.pixels
            switch channel {
            case 0: sorted.sort { $0.r < $1.r }
            case 1: sorted.sort { $0.g < $1.g }
            default: sorted.sort { $0.b < $1.b }
            }

            let mid = sorted.count / 2
            buckets.append(ColorBucket(pixels: Array(sorted[..<mid])))
            buckets.append(ColorBucket(pixels: Array(sorted[mid...])))
        }

        var palette = buckets.map { $0.averageColor }
        if hasTransparent {
            palette.append(RGBA(r: 0, g: 0, b: 0, a: 0))
        }

        return palette
    }

    // MARK: - Palette Mapping

    private func applyPalette(pixels: [RGBA], palette: [RGBA], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var outputData = [UInt8](repeating: 0, count: height * bytesPerRow)

        for (i, pixel) in pixels.enumerated() {
            let nearest = findNearest(pixel: pixel, palette: palette)
            let offset = i * bytesPerPixel
            outputData[offset] = nearest.r
            outputData[offset + 1] = nearest.g
            outputData[offset + 2] = nearest.b
            outputData[offset + 3] = nearest.a
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &outputData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }

    private func findNearest(pixel: RGBA, palette: [RGBA]) -> RGBA {
        // Transparent pixels map to the transparent palette entry
        if pixel.a < 10 {
            for p in palette where p.a < 10 {
                return p
            }
        }

        var bestDistance = Int.max
        var best = palette[0]

        for color in palette {
            guard color.a >= 10 else { continue }
            let dr = Int(pixel.r) - Int(color.r)
            let dg = Int(pixel.g) - Int(color.g)
            let db = Int(pixel.b) - Int(color.b)
            let dist = dr * dr + dg * dg + db * db
            if dist < bestDistance {
                bestDistance = dist
                best = color
                if dist == 0 { break }
            }
        }

        return best
    }
}
