import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: render_rounded_icon.swift <input.png> <output.png>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: inputURL) else {
    fputs("Unable to load input image.\n", stderr)
    exit(65)
}

let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create output bitmap.\n", stderr)
    exit(70)
}

bitmap.size = NSSize(width: pixelSize, height: pixelSize)
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(70)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

let iconRect = NSRect(x: 64, y: 64, width: 896, height: 896)
NSBezierPath(roundedRect: iconRect, xRadius: 196, yRadius: 196).addClip()
source.draw(
    in: iconRect,
    from: NSRect(origin: .zero, size: source.size),
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode output PNG.\n", stderr)
    exit(70)
}

try png.write(to: outputURL, options: .atomic)
