#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import MasterDanceAdmin

@Suite("Image upload optimizer")
struct ImageUploadOptimizerTests {
    @Test("Oversized images are downscaled without changing aspect ratio")
    func downscalesWithoutCropping() throws {
        let original = try pngData(width: 5_000, height: 1_000)
        let prepared = try ImageUploadOptimizer.prepare(
            data: original,
            sourceMimeType: "image/png",
            maximumByteCount: 1_024 * 1_024,
            maximumPixelDimension: 1_024
        )

        #expect(prepared.wasOptimized)
        #expect(prepared.mimeType == "image/jpeg")
        #expect(max(prepared.pixelWidth, prepared.pixelHeight) <= 1_024)
        #expect(prepared.data.count <= 1_024 * 1_024)
        #expect(abs(Double(prepared.pixelWidth) / Double(prepared.pixelHeight) - 5) < 0.03)
    }

    @Test("Images already inside the limits remain byte-for-byte unchanged")
    func preservesAcceptableImages() throws {
        let original = try pngData(width: 640, height: 400)
        let prepared = try ImageUploadOptimizer.prepare(
            data: original,
            sourceMimeType: "image/png",
            maximumByteCount: 1_024 * 1_024,
            maximumPixelDimension: 1_024
        )

        #expect(!prepared.wasOptimized)
        #expect(prepared.mimeType == "image/png")
        #expect(prepared.pixelWidth == 640)
        #expect(prepared.pixelHeight == 400)
        #expect(prepared.data == original)
    }

    @Test("Byte-heavy images are compressed even when resolution is acceptable")
    func compressesByteHeavyImages() throws {
        let original = try noisyPNGData(width: 1_024, height: 768)
        let byteLimit = 350_000
        #expect(original.count > byteLimit)

        let prepared = try ImageUploadOptimizer.prepare(
            data: original,
            sourceMimeType: "image/png",
            maximumByteCount: byteLimit,
            maximumPixelDimension: 2_048
        )

        #expect(prepared.wasOptimized)
        #expect(prepared.data.count <= byteLimit)
        #expect(abs(Double(prepared.pixelWidth) / Double(prepared.pixelHeight) - 4.0 / 3.0) < 0.02)
    }

    private func pngData(width: Int, height: Int) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(CGColor(red: 0.15, green: 0.45, blue: 0.8, alpha: 1))
        context.fill(
            CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        )
        context.setFillColor(CGColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1))
        context.fill(
            CGRect(
                x: CGFloat(width) / 2,
                y: 0,
                width: CGFloat(width) / 2,
                height: CGFloat(height)
            )
        )

        return try encodedPNG(try #require(context.makeImage()))
    }

    private func noisyPNGData(width: Int, height: Int) throws -> Data {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 0x4D44_4553
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            state = state &* 1_664_525 &+ 1_013_904_223
            pixels[offset] = UInt8(truncatingIfNeeded: state >> 16)
            state = state &* 1_664_525 &+ 1_013_904_223
            pixels[offset + 1] = UInt8(truncatingIfNeeded: state >> 16)
            state = state &* 1_664_525 &+ 1_013_904_223
            pixels[offset + 2] = UInt8(truncatingIfNeeded: state >> 16)
        }

        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        )
        let image = try #require(
            CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        )
        return try encodedPNG(image)
    }

    private func encodedPNG(_ image: CGImage) throws -> Data {
        let output = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                output,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
#endif
