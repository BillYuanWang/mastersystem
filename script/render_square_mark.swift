import CoreImage
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: render_square_mark.swift <input.png> <output.png>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CIImage(contentsOf: inputURL) else {
    fputs("Unable to load input image.\n", stderr)
    exit(65)
}

let side = max(source.extent.width, source.extent.height)
let xOffset = (side - source.extent.width) / 2
let yOffset = (side - source.extent.height) / 2
let positioned = source.transformed(
    by: CGAffineTransform(translationX: xOffset, y: yOffset)
)
let outputExtent = CGRect(x: 0, y: 0, width: side, height: side)
let square = positioned.clampedToExtent().cropped(to: outputExtent)

let context = CIContext(options: [.useSoftwareRenderer: false])
guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
      let cgImage = context.createCGImage(square, from: outputExtent, format: .RGBA8, colorSpace: colorSpace) else {
    fputs("Unable to render square mark.\n", stderr)
    exit(70)
}

let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    "public.png" as CFString,
    1,
    nil
)
guard let destination else {
    fputs("Unable to create output file.\n", stderr)
    exit(70)
}

CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to encode output PNG.\n", stderr)
    exit(70)
}
