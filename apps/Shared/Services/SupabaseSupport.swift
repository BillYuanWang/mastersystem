import Foundation
import MasterDanceCore

enum SupabaseRepositoryError: LocalizedError, Sendable {
    case invalidDate(String)
    case invalidValue(field: String, value: String)
    case missingContractDocument(UUID)
    case missingSession
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidDate(let value):
            "服务器返回了无法识别的日期：\(value)"
        case .invalidValue(let field, let value):
            "服务器返回了无法识别的 \(field)：\(value)"
        case .missingContractDocument:
            "合同记录缺少对应的版本文件。"
        case .missingSession:
            "登录已过期，请重新登录。"
        case .server(let message):
            message
        }
    }
}

enum SupabaseDateCodec {
    static func date(from value: String) throws -> Date {
        let pieces = value.split(separator: "-")
        guard
            pieces.count == 3,
            let year = Int(pieces[0]),
            let month = Int(pieces[1]),
            let day = Int(pieces[2])
        else {
            throw SupabaseRepositoryError.invalidDate(value)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            throw SupabaseRepositoryError.invalidDate(value)
        }
        return date
    }

    static func dayString(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func timestamp(from value: String) throws -> Date {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: value) {
            return date
        }
        throw SupabaseRepositoryError.invalidDate(value)
    }

    static func timestampString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

extension EntityID {
    init(serverID: UUID) {
        self.init(rawValue: serverID)
    }
}
