#if os(macOS)
import AppKit
import Foundation

struct ReceiptFileStore {
    static let rootFolderName = "MD Desk Docs"

    let rootDirectory: URL

    static func documents(fileManager: FileManager = .default) throws -> ReceiptFileStore {
        guard let documentsDirectory = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw ReceiptFileStoreError.documentsDirectoryUnavailable
        }
        return ReceiptFileStore(
            rootDirectory: documentsDirectory.appendingPathComponent(rootFolderName, isDirectory: true)
        )
    }

    @discardableResult
    func prepareRootDirectory(fileManager: FileManager = .default) throws -> URL {
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
        return rootDirectory
    }

    func savePNG(
        _ data: Data,
        learnerName: String,
        filenameStem: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        try prepareRootDirectory(fileManager: fileManager)

        let learnerDirectory = rootDirectory.appendingPathComponent(
            Self.safePathComponent(learnerName, fallback: "未命名学员"),
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: learnerDirectory,
            withIntermediateDirectories: true
        )

        let safeStem = Self.safePathComponent(filenameStem, fallback: "收据")
        var destination = learnerDirectory
            .appendingPathComponent(safeStem)
            .appendingPathExtension("png")
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            destination = learnerDirectory
                .appendingPathComponent("\(safeStem)-\(suffix)")
                .appendingPathExtension("png")
            suffix += 1
        }

        try data.write(to: destination, options: .atomic)
        return destination
    }

    static func safePathComponent(_ value: String, fallback: String) -> String {
        let disallowed = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = value
            .components(separatedBy: disallowed)
            .joined(separator: "-")
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        return cleaned.isEmpty ? fallback : String(cleaned.prefix(96))
    }
}

enum ReceiptFileStoreError: LocalizedError {
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            "无法找到这台 Mac 的 Documents 文件夹。"
        }
    }
}

@MainActor
enum ReceiptClipboard {
    static func copyPNG(_ data: Data, to pasteboard: NSPasteboard = .general) throws {
        guard let image = NSImage(data: data) else {
            throw ReceiptClipboardError.invalidPNG
        }

        let item = NSPasteboardItem()
        item.setData(data, forType: .png)
        if let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
        }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else {
            throw ReceiptClipboardError.writeFailed
        }
    }
}

enum ReceiptClipboardError: LocalizedError {
    case invalidPNG
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidPNG: "生成的收据不是有效 PNG。"
        case .writeFailed: "无法复制 PNG 到剪贴板。"
        }
    }
}
#endif
