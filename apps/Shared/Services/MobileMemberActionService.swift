import Foundation
import MasterDanceCore
import Supabase

struct MobileGuardianAgreement: Decodable, Equatable, Identifiable, Sendable {
    let id: UUID
    let termID: UUID
    let title: String
    let version: String
    let bodyText: String
    let sha256: String
    let requiresAcceptance: Bool
    let acceptedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case termID = "term_id"
        case title
        case version
        case bodyText = "body_text"
        case sha256
        case requiresAcceptance = "requires_acceptance"
        case acceptedAt = "accepted_at"
    }
}

private struct MobileGuardianAgreementEnvelope: Decodable, Sendable {
    let agreement: MobileGuardianAgreement?
}

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

    func currentGuardianAgreement() async throws -> MobileGuardianAgreement? {
        let envelope: MobileGuardianAgreementEnvelope = try await client
            .rpc("current_guardian_agreement")
            .execute()
            .value
        return envelope.agreement
    }

    func acceptGuardianAgreement(
        documentID: UUID,
        displayedSHA256: String,
        signaturePNG: Data
    ) async throws {
        guard signaturePNG.count >= 128 else {
            throw MobileMemberActionError.invalidSignature
        }
        let _: GuardianAgreementAcceptanceRow = try await client
            .rpc(
                "accept_guardian_agreement",
                params: GuardianAgreementAcceptanceParameters(
                    documentID: documentID,
                    displayedSHA256: displayedSHA256,
                    signatureBase64: signaturePNG.base64EncodedString()
                )
            )
            .execute()
            .value
    }
}

private actor MobileMemberActionQueue {
    private let client: SupabaseClient
    private let cacheURL: URL
    private var pending: [QueuedMobileMemberAction]
    private var hasLoadedCache = false
    private var isSynchronizing = false

    init(client: SupabaseClient, cacheDirectory: URL, cacheKey: String) {
        self.client = client
        let safeCacheKey = cacheKey.map {
            $0.isLetter || $0.isNumber ? String($0) : "-"
        }.joined()
        cacheURL = cacheDirectory
            .appendingPathComponent("mobile-actions-\(safeCacheKey).json", isDirectory: false)
        pending = []
    }

    func enqueue(_ action: PendingMobileMemberAction) throws {
        loadCacheIfNeeded()
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

        Task {
            try? await self.synchronizeIfNeeded()
        }
    }

    func synchronizeIfNeeded() async throws -> Int {
        loadCacheIfNeeded()
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

    private func loadCacheIfNeeded() {
        guard !hasLoadedCache else { return }
        hasLoadedCache = true
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([QueuedMobileMemberAction].self, from: data) else {
            return
        }
        pending = decoded
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
    case invalidSignature

    var errorDescription: String? {
        switch self {
        case .invalidEmail: "请输入有效邮箱。"
        case .invalidPhone: "请输入 10 位美国电话号码。"
        case .invalidSignature: "请先完成手写签名。"
        }
    }
}

private struct GuardianAgreementAcceptanceParameters: Encodable, Sendable {
    let documentID: UUID
    let displayedSHA256: String
    let signatureBase64: String

    enum CodingKeys: String, CodingKey {
        case documentID = "target_document_id"
        case displayedSHA256 = "displayed_contract_sha256"
        case signatureBase64 = "signature_base64"
    }
}

private struct GuardianAgreementAcceptanceRow: Decodable, Sendable {
    let contractDocumentID: UUID
    let acceptedAt: String

    enum CodingKeys: String, CodingKey {
        case contractDocumentID = "contract_document_id"
        case acceptedAt = "accepted_at"
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
