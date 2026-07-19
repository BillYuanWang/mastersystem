#if os(iOS)
import Foundation
import MasterDanceCore
import Observation
import Security
import Supabase

enum MobileSessionPhase: Equatable {
    case restoring
    case signedOut
    case emailConfirmationRequired(String)
    case guardianLinkRequired
    case ready
}

struct MobileAccountProfile: Equatable, Sendable {
    let userID: UUID
    let organizationID: UUID
    let role: AppRole
    let displayName: String
    let appearance: String
    let isActive: Bool
}

@MainActor
@Observable
final class MobileSessionModel {
    @ObservationIgnored private let configuration: SupabaseConfiguration
    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private var cachedMemberActions: MobileMemberActionService?
    @ObservationIgnored private let pendingInvitationStore = PendingGuardianInvitationStore()

    var phase = MobileSessionPhase.restoring
    var profile: MobileAccountProfile?
    var repository: (any MasterDanceRepository)?
    var accountEmail: String?
    var isWorking = false
    var errorMessage: String?
    var noticeMessage: String?
    var needsPasswordUpdate = false

    init(configuration: SupabaseConfiguration = .production) {
        self.configuration = configuration
        client = configuration.makeClient()
    }

    var memberActions: MobileMemberActionService? { cachedMemberActions }

    func restore() async {
        guard phase == .restoring else { return }
        do {
            let session = try await client.auth.session
            accountEmail = session.user.email
            try await finishAuthentication(userID: session.user.id)
        } catch {
            if phase == .guardianLinkRequired {
                errorMessage = friendlyMessage(for: error)
            } else {
                clearAuthenticatedState()
                phase = .signedOut
            }
        }
    }

    func signIn(email: String, password: String) async {
        let email = normalizedEmail(email)
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "请输入邮箱和密码。"
            return
        }

        await runCloudAction {
            let session = try await client.auth.signIn(email: email, password: password)
            accountEmail = session.user.email
            try await finishAuthentication(userID: session.user.id)
        }
    }

    func previewGuardianRegistration(_ code: String) async -> GuardianRegistrationInvitation? {
        let normalizedCode = code.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !normalizedCode.isEmpty else {
            errorMessage = "请输入教务老师提供的家长邀请码。"
            return nil
        }

        var invitation: GuardianRegistrationInvitation?
        await runCloudAction {
            invitation = try await GuardianAccountService(
                client: client,
                configuration: configuration
            )
                .previewRegistration(code: normalizedCode)
        }
        return invitation
    }

    func downloadGuardianRegistrationContract(
        invitation: GuardianRegistrationInvitation
    ) async -> GuardianRegistrationContractDocument? {
        var document: GuardianRegistrationContractDocument?
        await runCloudAction {
            document = try await GuardianAccountService(
                client: client,
                configuration: configuration
            ).downloadRegistrationContract(invitation: invitation)
        }
        return document
    }

    @discardableResult
    func registerGuardian(
        invitation: GuardianRegistrationInvitation,
        document: GuardianRegistrationContractDocument,
        signaturePNG: Data,
        password: String,
        confirmation: String
    ) async -> Bool {
        let email = normalizedEmail(invitation.email)
        guard email.contains("@") else {
            errorMessage = "该邀请码没有有效邮箱，请联系教务老师。"
            return false
        }
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致。"
            return false
        }
        guard isAcceptablePassword(password) else {
            errorMessage = "密码至少 10 位，并且同时包含字母和数字。"
            return false
        }
        guard signaturePNG.count >= 128 else {
            errorMessage = "请先完成手写签名。"
            return false
        }

        var didRegister = false
        await runCloudAction {
            try await GuardianAccountService(
                client: client,
                configuration: configuration
            ).acceptRegistrationContract(
                invitation: invitation,
                document: document,
                signaturePNG: signaturePNG
            )
            try pendingInvitationStore.save(
                PendingGuardianInvitation(code: invitation.code, email: email)
            )
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: callbackURL
            )
            accountEmail = response.user.email ?? email
            if let session = response.session {
                try await finishAuthentication(userID: session.user.id)
            } else {
                profile = nil
                repository = nil
                phase = .emailConfirmationRequired(email)
            }
            didRegister = true
        }
        return didRegister
    }

    func claimGuardianCode(_ code: String) async {
        let normalizedCode = code
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        guard !normalizedCode.isEmpty else {
            errorMessage = "请输入教务老师提供的家长邀请码。"
            return
        }

        await runCloudAction {
            let row = try await GuardianAccountService(
                client: client,
                configuration: configuration
            )
                .claimFamily(code: normalizedCode)
            try acceptProfile(row)
            pendingInvitationStore.clear()
            noticeMessage = "家庭已经连接。"
        }
    }

    func sendPasswordReset(email: String) async -> Bool {
        let email = normalizedEmail(email)
        guard email.contains("@") else {
            errorMessage = "请输入有效邮箱。"
            return false
        }

        var didSend = false
        await runCloudAction {
            try await client.auth.resetPasswordForEmail(email, redirectTo: callbackURL)
            noticeMessage = "密码重设邮件已发送，请从邮件返回 Master Dance。"
            didSend = true
        }
        return didSend
    }

    func updatePassword(_ password: String, confirmation: String) async -> Bool {
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致。"
            return false
        }
        guard isAcceptablePassword(password) else {
            errorMessage = "密码至少 10 位，并且同时包含字母和数字。"
            return false
        }

        var didUpdate = false
        await runCloudAction {
            try await client.auth.update(user: UserAttributes(password: password))
            needsPasswordUpdate = false
            noticeMessage = "密码已更新。"
            didUpdate = true
        }
        return didUpdate
    }

    func continueAfterEmailConfirmation() async {
        let email = accountEmail
        await signOut(showNotice: false)
        accountEmail = email
        noticeMessage = "邮箱确认后，请使用刚刚设置的密码登录，家庭会自动连接。"
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == "masterdance" else { return }
        let isRecovery = url.absoluteString.localizedCaseInsensitiveContains("recovery")
        await runCloudAction {
            let session = try await client.auth.session(from: url)
            accountEmail = session.user.email
            try await finishAuthentication(userID: session.user.id)
            needsPasswordUpdate = isRecovery
        }
    }

    func signOut() async {
        await signOut(showNotice: false)
    }

    func clearMessages() {
        errorMessage = nil
        noticeMessage = nil
    }

    private func signOut(showNotice: Bool) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
        clearAuthenticatedState()
        phase = .signedOut
        if showNotice {
            noticeMessage = "已经退出登录。"
        }
    }

    private func finishAuthentication(userID: UUID) async throws {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            pendingInvitationStore.clear()
            try acceptProfile(row)
            return
        }

        profile = nil
        repository = nil
        phase = .guardianLinkRequired

        guard let pendingInvitation = try pendingInvitationStore.load(),
              normalizedEmail(pendingInvitation.email) == normalizedEmail(accountEmail ?? "") else {
            return
        }

        let row = try await GuardianAccountService(
            client: client,
            configuration: configuration
        )
            .claimFamily(code: pendingInvitation.code)
        try acceptProfile(row)
        pendingInvitationStore.clear()
        noticeMessage = "家长账号已激活，家庭信息已连接。"
    }

    private func acceptProfile(_ row: ProfileRow) throws {
        guard row.isActive else {
            throw SupabaseRepositoryError.server("这个账号已停用，请联系学校。")
        }
        let role: AppRole
        switch row.role {
        case "administrator": role = .administrator
        case "guardian": role = .guardian
        case "adult_student": role = .adultStudent
        default:
            throw SupabaseRepositoryError.server("这个账号类型暂不支持 iPhone 版。")
        }

        let accepted = MobileAccountProfile(
            userID: row.userID,
            organizationID: row.organizationID,
            role: role,
            displayName: row.displayName,
            appearance: row.appearance,
            isActive: row.isActive
        )
        profile = accepted
        repository = LocalFirstRepositoryFactory.make(
            client: client,
            organizationID: accepted.organizationID,
            userID: accepted.userID
        )
        cachedMemberActions = MobileMemberActionService(
            client: client,
            cacheDirectory: LocalFirstRepositoryFactory.cacheDirectory,
            cacheKey: "\(accepted.organizationID.uuidString)-\(accepted.userID.uuidString)"
        )
        phase = .ready
    }

    private func runCloudAction(_ operation: @MainActor () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        noticeMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func clearAuthenticatedState() {
        profile = nil
        repository = nil
        cachedMemberActions = nil
        accountEmail = nil
        needsPasswordUpdate = false
    }

    private func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isAcceptablePassword(_ password: String) -> Bool {
        password.count >= 10
            && password.contains(where: \.isLetter)
            && password.contains(where: \.isNumber)
    }

    private var callbackURL: URL {
        URL(string: "masterdance://auth-callback")!
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("invalid login credentials") {
            return "邮箱或密码不正确。"
        }
        if message.localizedCaseInsensitiveContains("email not confirmed") {
            return "请先从邮件完成邮箱确认。"
        }
        if message.localizedCaseInsensitiveContains("already registered") {
            return "这个邮箱已经注册，请直接登录。"
        }
        if message.localizedCaseInsensitiveContains("invalid or expired guardian link code") {
            return "家长邀请码无效或已经过期，请向教务老师获取新码。"
        }
        if message.localizedCaseInsensitiveContains("guardian invitation email is unavailable") {
            return "该邀请码没有有效邮箱，请联系教务老师更新监护人信息。"
        }
        if message.localizedCaseInsensitiveContains("guardian invitation email does not match") {
            return "当前登录邮箱与家长邀请码不匹配。"
        }
        if message.localizedCaseInsensitiveContains("guardian registration contract is unavailable") {
            return "学校尚未发布注册合同，请联系教务老师。"
        }
        if message.localizedCaseInsensitiveContains("guardian registration contract acceptance required") {
            return "请先阅读合同并完成手写签名。"
        }
        if message.localizedCaseInsensitiveContains("registration contract changed") {
            return "合同已更新，请重新阅读后签名。"
        }
        if message.localizedCaseInsensitiveContains("already linked")
            || message.localizedCaseInsensitiveContains("already attached") {
            return "这个账号或家庭已经完成连接。"
        }
        return message
    }
}

private struct PendingGuardianInvitation: Codable {
    let code: String
    let email: String
}

private struct PendingGuardianInvitationStore {
    private let service = "com.masterdance.mobile.guardian-registration"
    private let account = "pending-invitation"

    func load() throws -> PendingGuardianInvitation? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw PendingGuardianInvitationStoreError(status: status)
        }
        return try JSONDecoder().decode(PendingGuardianInvitation.self, from: data)
    }

    func save(_ invitation: PendingGuardianInvitation) throws {
        let data = try JSONEncoder().encode(invitation)
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PendingGuardianInvitationStoreError(status: status)
        }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct PendingGuardianInvitationStoreError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "\(status)"
        return "无法安全保存家长邀请码：\(detail)"
    }
}
#endif
