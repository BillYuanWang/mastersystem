#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PreparedImageUpload: Equatable, Sendable {
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let wasOptimized: Bool
}

enum ImageUploadOptimizerError: LocalizedError {
    case unreadable
    case encodingFailed
    case cannotMeetFileLimit

    var errorDescription: String? {
        switch self {
        case .unreadable: "无法读取这张图片。"
        case .encodingFailed: "无法处理这张图片。"
        case .cannotMeetFileLimit: "图片自动压缩后仍然过大，请更换图片。"
        }
    }
}

enum ImageUploadOptimizer {
    private static let jpegQualities: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]

    static func prepare(
        data: Data,
        sourceMimeType: String,
        maximumByteCount: Int,
        maximumPixelDimension: Int
    ) throws -> PreparedImageUpload {
        guard maximumByteCount > 0,
              maximumPixelDimension > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let dimensions = displayDimensions(source: source) else {
            throw ImageUploadOptimizerError.unreadable
        }

        let longestDimension = max(dimensions.width, dimensions.height)
        guard data.count > maximumByteCount || longestDimension > maximumPixelDimension else {
            return PreparedImageUpload(
                data: data,
                mimeType: sourceMimeType.lowercased(),
                pixelWidth: dimensions.width,
                pixelHeight: dimensions.height,
                wasOptimized: false
            )
        }

        let minimumAttemptDimension = min(320, longestDimension)
        var targetDimension = min(longestDimension, maximumPixelDimension)

        while targetDimension >= minimumAttemptDimension {
            guard let thumbnail = thumbnail(source: source, maximumDimension: targetDimension),
                  let jpegImage = flattenedForJPEG(thumbnail) else {
                throw ImageUploadOptimizerError.encodingFailed
            }

            for quality in jpegQualities {
                guard let encoded = jpegData(image: jpegImage, quality: quality) else {
                    throw ImageUploadOptimizerError.encodingFailed
                }
                if encoded.count <= maximumByteCount {
                    return PreparedImageUpload(
                        data: encoded,
                        mimeType: "image/jpeg",
                        pixelWidth: jpegImage.width,
                        pixelHeight: jpegImage.height,
                        wasOptimized: true
                    )
                }
            }

            guard targetDimension > minimumAttemptDimension else { break }
            let reduced = Int((Double(targetDimension) * 0.8).rounded(.down))
            targetDimension = max(minimumAttemptDimension, min(targetDimension - 1, reduced))
        }

        throw ImageUploadOptimizerError.cannotMeetFileLimit
    }

    private static func displayDimensions(source: CGImageSource) -> (width: Int, height: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
            let rawWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let rawHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
            rawWidth > 0,
            rawHeight > 0 else {
            return nil
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if (5...8).contains(orientation) {
            return (rawHeight, rawWidth)
        }
        return (rawWidth, rawHeight)
    }

    private static func thumbnail(
        source: CGImageSource,
        maximumDimension: Int
    ) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func flattenedForJPEG(_ image: CGImage) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            return nil
        }

        let bounds = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        return context.makeImage()
    }

    private static func jpegData(image: CGImage, quality: CGFloat) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
#endif
