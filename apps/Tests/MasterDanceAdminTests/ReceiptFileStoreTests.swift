#if os(macOS)
import Foundation
import AppKit
import MasterDanceCore
import SwiftUI
import Testing
@testable import MasterDanceAdmin

@Suite("Receipt file store")
struct ReceiptFileStoreTests {
    @Test("Receipt brand assets resolve outside the running app bundle")
    func resolvesReceiptBrandAssets() {
        #expect(MasterDanceImageResource.image(named: "MasterDanceMacLogo") != nil)
        #expect(MasterDanceImageResource.image(named: "ReceiptWaterSleeveWatermark") != nil)
    }

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
            kind: .receipt,
            receiptNumber: "MD-2026-001",
            version: 2,
            termLabel: "2026 秋季学期",
            issuedOn: Date(timeIntervalSince1970: 0),
            guardianName: "测试监护人",
            guardianEmail: "guardian@example.com",
            guardianPhone: "+1 (949) 555-0100",
            learnerName: "测试学员",
            currency: .usd,
            items: [
                ReceiptLineItem(
                    kind: .tuition,
                    section: .fullTerm,
                    title: "2026 秋季学期 · 中国舞基本功",
                    englishTitle: "Chinese Dance Fundamentals · Full-Term Tuition",
                    amount: 595,
                    learnerName: "测试学员",
                    detail: "周一 3:30–4:30 PM"
                ),
                ReceiptLineItem(
                    kind: .registration,
                    title: "2026–2027 学年注册费",
                    englishTitle: "Annual Registration Fee",
                    amount: 50,
                    learnerName: "测试学员"
                ),
                ReceiptLineItem(
                    title: "上期已付款项目",
                    englishTitle: "Previously Paid Item",
                    amount: 120,
                    learnerName: "测试学员",
                    detail: "仅供家庭查阅",
                    isPaid: true
                ),
                ReceiptLineItem(
                    kind: .tuition,
                    section: .fullTerm,
                    title: "免付课程",
                    englishTitle: "Waived Tuition",
                    amount: 300,
                    learnerName: "测试学员",
                    settlementStatus: .waived
                )
            ],
            paymentMethod: "Zelle",
            paymentAmount: 645,
            outstandingAfterPayment: 0,
            note: "测试收据"
        )

        let data = try ReceiptPNGRenderer.render(document)
        let bitmap = NSBitmapImageRep(data: data)

        #expect(document.paidItemTotal == 120)
        #expect(document.waivedItemTotal == 300)
        #expect(document.currentDue == 645)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        let expectedSize = ReceiptPNGRenderer.canvasSize(for: document)
        #expect(bitmap?.pixelsWide == Int(expectedSize.width * 2))
        #expect(bitmap?.pixelsHigh == Int(expectedSize.height * 2))

        if let path = ProcessInfo.processInfo.environment["MD_RECEIPT_DOCUMENT_SNAPSHOT_PATH"] {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    @Test("Copied receipts expose PNG data to other apps")
    @MainActor
    func copiesPNG() throws {
        _ = NSApplication.shared
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
        let guardian = Guardian(
            displayName: "王渊",
            email: "guardian@example.com",
            phone: "+1 (949) 555-0100"
        )
        let learners = [
            Student(guardianID: guardian.id, displayName: "小毛豆", kind: .child),
            Student(guardianID: guardian.id, displayName: "王渊", kind: .adult),
        ]
        let term = Term(
            name: "2026 年秋季学期",
            startsOn: Date(timeIntervalSince1970: 1_787_020_800),
            endsOn: Date(timeIntervalSince1970: 1_797_923_200),
            status: .open
        )
        let model = AppModel(
            repository: PreviewMasterDanceStore(
                data: PreviewData(terms: [term], students: learners, guardians: [guardian])
            )
        )
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
