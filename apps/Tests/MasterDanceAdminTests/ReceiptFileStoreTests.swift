#if os(macOS)
import Foundation
import AppKit
import MasterDanceCore
import SwiftUI
import Testing
@testable import MasterDanceAdmin

@Suite("Receipt file store")
struct ReceiptFileStoreTests {
    @Test("Receipts are grouped by learner and never overwrite")
    func savesUniqueReceiptFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-store-\(UUID().uuidString)", isDirectory: true)
        let store = ReceiptFileStore(rootDirectory: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let first = try store.savePNG(
            Data([0x89, 0x50, 0x4E, 0x47]),
            learnerName: "小毛豆",
            filenameStem: "收据-2026-07-20-MD-001"
        )
        let second = try store.savePNG(
            Data([0x89, 0x50, 0x4E, 0x47]),
            learnerName: "小毛豆",
            filenameStem: "收据-2026-07-20-MD-001"
        )

        #expect(first.deletingLastPathComponent().lastPathComponent == "小毛豆")
        #expect(first.lastPathComponent == "收据-2026-07-20-MD-001.png")
        #expect(second.lastPathComponent == "收据-2026-07-20-MD-001-2.png")
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test("Unsafe path characters cannot escape the learner folder")
    func sanitizesPathComponents() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("receipt-store-\(UUID().uuidString)", isDirectory: true)
        let store = ReceiptFileStore(rootDirectory: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let destination = try store.savePNG(
            Data([1, 2, 3]),
            learnerName: "  王/小:明  ",
            filenameStem: "../收据:001"
        )

        #expect(destination.path.hasPrefix(root.path + "/"))
        #expect(destination.deletingLastPathComponent().lastPathComponent == "王-小-明")
        #expect(destination.lastPathComponent == "收据-001.png")
    }

    @Test("Renderer creates a high-resolution PNG")
    @MainActor
    func rendersPNG() throws {
        let document = ReceiptDocument(
            receiptNumber: "MD-TEST-001",
            issuedOn: Date(timeIntervalSince1970: 0),
            guardianName: "测试监护人",
            guardianEmail: "guardian@example.com",
            guardianPhone: "+1 (949) 555-0100",
            learnerName: "测试学员",
            currency: .usd,
            items: [ReceiptLineItem(title: "秋季学费", amount: 125)],
            paymentMethod: "Zelle",
            note: "测试收据"
        )

        let data = try ReceiptPNGRenderer.render(document)
        let bitmap = NSBitmapImageRep(data: data)

        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        #expect(bitmap?.pixelsWide == 1_440)
        #expect(bitmap?.pixelsHigh == 1_920)
    }

    @Test("Copied receipts expose PNG data to other apps")
    @MainActor
    func copiesPNG() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("md-desk-receipt-tests"))
        defer { pasteboard.clearContents() }
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        try ReceiptClipboard.copyPNG(png, to: pasteboard)

        #expect(pasteboard.data(forType: .png) == png)
        #expect(pasteboard.data(forType: .tiff) != nil)
    }

    @Test("Receipt workspace renders at the default desktop size")
    @MainActor
    func rendersWorkspace() async throws {
        let model = AppModel(repository: PreviewMasterDanceStore())
        await model.reload()
        let size = NSSize(width: 1_380, height: 812)
        let hostingView = NSHostingView(
            rootView: ReceiptWorkspaceView(model: model)
                .frame(width: size.width, height: size.height)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        let backingScale = CGFloat(bitmap.pixelsWide) / size.width
        #expect(backingScale == 1 || backingScale == 2)
        #expect(bitmap.pixelsHigh == Int(size.height * backingScale))
        #expect(png.count > 50_000)

        if let path = ProcessInfo.processInfo.environment["MD_RECEIPT_SNAPSHOT_PATH"] {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
#endif
