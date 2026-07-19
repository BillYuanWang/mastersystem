import Foundation
import MasterDanceCore
import Supabase

@MainActor
struct MobileMemberActionService {
    let client: SupabaseClient
    private let queue: MobileMemberActionQueue

    init(
        client: SupabaseClient,
        cacheDirectory: URL = FileManager.default.temporaryDirectory,
        cacheKey: String = UUID().uuidString
    ) {
        self.client = client
        queue = MobileMemberActionQueue(
            client: client,
            cacheDirectory: cacheDirectory,
            cacheKey: cacheKey
        )
    }

    func submitLeave(
        sessionID: ClassSessionID,
        studentID: StudentID,
        note: String
    ) async throws {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try await queue.enqueue(
            .submitLeave(
                sessionID,
                studentID,
                trimmedNote.isEmpty ? nil : trimmedNote
            )
        )
    }

    func recordContractConsent(
        documentID: ContractDocumentID,
        enrollmentID: EnrollmentID?,
        signerDisplayName: String
    ) async throws {
        let trimmedName = signerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        try await queue.enqueue(
            .recordContractConsent(
                documentID,
                enrollmentID,
                trimmedName.isEmpty ? nil : trimmedName
            )
        )
    }

    func markNotificationRead(id: NotificationRecordID) async throws {
        try await queue.enqueue(.markNotificationRead(id))
    }

    func updateGuardianContact(
        guardianID: GuardianID,
        email: String,
        phone: String
    ) async throws {
        guard let email = GuardianContact.normalizedEmail(email) else {
            throw MobileMemberActionError.invalidEmail
        }
        guard let phone = GuardianContact.formattedUSPhone(phone) else {
            throw MobileMemberActionError.invalidPhone
        }
        try await queue.enqueue(.updateGuardianContact(guardianID, email, phone))
    }

    @discardableResult
    func synchronizePendingChanges() async throws -> Int {
        try await queue.synchronizeIfNeeded()
    }

    func downloadContract(path: String) async throws -> Data {
        guard !path.isEmpty else { throw MobileMemberActionError.missingContract }
        return try await client.storage
            .from("contracts")
            .download(path: path)
    }
}

private actor MobileMemberActionQueue {
    private let client: SupabaseClient
    private let cacheURL: URL
    private var pending: [QueuedMobileMemberAction]
    private var isSynchronizing = false

    init(client: SupabaseClient, cacheDirectory: URL, cacheKey: String) {
        self.client = client
        let safeCacheKey = cacheKey.map {
            $0.isLetter || $0.isNumber ? String($0) : "-"
        }.joined()
        cacheURL = cacheDirectory
            .appendingPathComponent("mobile-actions-\(safeCacheKey).json", isDirectory: false)
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([QueuedMobileMemberAction].self, from: data) {
            pending = decoded
        } else {
            pending = []
        }
    }

    func enqueue(_ action: PendingMobileMemberAction) throws {
        let queued = QueuedMobileMemberAction(action: action)
        let firstReplaceableIndex = isSynchronizing ? 1 : 0
        if firstReplaceableIndex < pending.count,
           let index = pending[firstReplaceableIndex...]
            .firstIndex(where: { $0.action.coalescingKey == action.coalescingKey }) {
            pending[index] = queued
        } else {
            pending.append(queued)
        }
        try persist()
    }

    func synchronizeIfNeeded() async throws -> Int {
        guard !isSynchronizing, !pending.isEmpty else { return 0 }
        isSynchronizing = true
        defer { isSynchronizing = false }

        var synchronizedCount = 0
        while let queued = pending.first {
            try await queued.action.apply(to: client)
            pending.removeAll { $0.id == queued.id }
            synchronizedCount += 1
            try persist()
        }
        return synchronizedCount
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(pending)
        try FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: cacheURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: cacheURL.path
        )
    }
}

private struct QueuedMobileMemberAction: Codable, Sendable {
    let id: UUID
    let action: PendingMobileMemberAction

    init(id: UUID = UUID(), action: PendingMobileMemberAction) {
        self.id = id
        self.action = action
    }
}

private enum PendingMobileMemberAction: Codable, Sendable {
    case submitLeave(ClassSessionID, StudentID, String?)
    case recordContractConsent(ContractDocumentID, EnrollmentID?, String?)
    case markNotificationRead(NotificationRecordID)
    case updateGuardianContact(GuardianID, String, String)

    var coalescingKey: String {
        switch self {
        case .submitLeave(let sessionID, let studentID, _):
            "leave:\(sessionID):\(studentID)"
        case .recordContractConsent(let documentID, let enrollmentID, _):
            "consent:\(documentID):\(enrollmentID?.description ?? "term")"
        case .markNotificationRead(let id):
            "notification:\(id)"
        case .updateGuardianContact(let id, _, _):
            "guardian-contact:\(id)"
        }
    }

    func apply(to client: SupabaseClient) async throws {
        switch self {
        case .submitLeave(let sessionID, let studentID, let note):
            let _: LeaveRequestRow = try await client
                .rpc(
                    "submit_leave_request",
                    params: SubmitLeaveRequestParameters(
                        sessionID: sessionID.rawValue,
                        studentID: studentID.rawValue,
                        note: note
                    )
                )
                .execute()
                .value
        case .recordContractConsent(let documentID, let enrollmentID, let signerDisplayName):
            let _: ContractConsentRow = try await client
                .rpc(
                    "record_contract_consent",
                    params: RecordContractConsentParameters(
                        documentID: documentID.rawValue,
                        enrollmentID: enrollmentID?.rawValue,
                        signerDisplayName: signerDisplayName
                    )
                )
                .execute()
                .value
        case .markNotificationRead(let id):
            let _: NotificationRow = try await client
                .rpc(
                    "mark_notification_read",
                    params: MarkNotificationReadParameters(notificationID: id.rawValue)
                )
                .execute()
                .value
        case .updateGuardianContact(let guardianID, let email, let phone):
            try await client
                .from("guardians")
                .update(GuardianContactUpdate(email: email, phone: phone))
                .eq("id", value: guardianID.rawValue)
                .execute()
        }
    }
}

enum MobileMemberActionError: LocalizedError {
    case invalidEmail
    case invalidPhone
    case missingContract

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "请输入有效邮箱。"
        case .invalidPhone: "请输入 10 位美国电话号码。"
        case .missingContract: "这份合同还没有可查看的 PDF。"
        }
    }
}

private struct SubmitLeaveRequestParameters: Encodable, Sendable {
    let sessionID: UUID
    let studentID: UUID
    let note: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "target_session_id"
        case studentID = "target_student_id"
        case note = "request_note"
    }
}

private struct RecordContractConsentParameters: Encodable, Sendable {
    let documentID: UUID
    let enrollmentID: UUID?
    let signerDisplayName: String?

    enum CodingKeys: String, CodingKey {
        case documentID = "target_document_id"
        case enrollmentID = "target_enrollment_id"
        case signerDisplayName = "signer_display_name"
    }
}

private struct MarkNotificationReadParameters: Encodable, Sendable {
    let notificationID: UUID

    enum CodingKeys: String, CodingKey {
        case notificationID = "target_notification_id"
    }
}

private struct GuardianContactUpdate: Encodable, Sendable {
    let email: String
    let phone: String
}
