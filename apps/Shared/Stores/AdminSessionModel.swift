import Foundation
import MasterDanceCore
import Observation
import Supabase

enum AdminSessionPhase: Equatable, Sendable {
    case restoring
    case signedOut
    case activationRequired
    case ready
}

struct AdministratorProfile: Identifiable, Equatable, Sendable {
    let userID: UUID
    let organizationID: UUID
    let displayName: String
    let appearance: String
    let isActive: Bool

    var id: UUID { userID }
}

@MainActor
@Observable
final class AdminSessionModel {
    @ObservationIgnored private let configuration: SupabaseConfiguration
    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private let authStorage: SessionAwareAuthStorage
    @ObservationIgnored private let retentionStore: LoginRetentionStore
    @ObservationIgnored private var expirationTask: Task<Void, Never>?

    var phase = AdminSessionPhase.restoring
    var profile: AdministratorProfile?
    var repository: (any MasterDanceRepository)?
    var administrators: [AdministratorProfile] = []
    var isWorking = false
    var errorMessage: String?
    var noticeMessage: String?
    var needsPasswordSetup = false

    init(configuration: SupabaseConfiguration = .production) {
        self.configuration = configuration
        let retentionStore = LoginRetentionStore()
        self.retentionStore = retentionStore
        let configuredClient = configuration.makeSessionClient(
            persistSession: retentionStore.remembersLogin
        )
        client = configuredClient.client
        authStorage = configuredClient.authStorage
    }

    var defaultRememberLogin: Bool { retentionStore.remembersLogin }

    func restore() async {
        guard phase == .restoring else { return }
        let rememberLogin = retentionStore.remembersLogin
        authStorage.setSessionPersistenceEnabled(rememberLogin)
        guard rememberLogin else {
            retentionStore.clearAuthentication()
            clearAuthenticatedState()
            phase = .signedOut
            return
        }
        if let authenticatedAt = retentionStore.authenticatedAt,
           !LoginRetentionPolicy.isWithinMaximumDuration(authenticatedAt: authenticatedAt) {
            await expireRetainedLogin()
            return
        }

        do {
            let session = try await client.auth.session
            beginLoginRetention(
                rememberLogin: true,
                authenticatedAt: retentionStore.authenticatedAt ?? Date()
            )
            try await finishAuthentication(userID: session.user.id)
        } catch {
            clearAuthenticatedState()
            phase = .signedOut
        }
    }

    func signIn(email: String, password: String, rememberLogin: Bool) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "请输入邮箱和密码。"
            return
        }

        isWorking = true
        errorMessage = nil
        noticeMessage = nil
        retentionStore.setRememberLogin(rememberLogin)
        authStorage.setSessionPersistenceEnabled(rememberLogin)
        defer { isWorking = false }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            beginLoginRetention(rememberLogin: rememberLogin)
            try await finishAuthentication(userID: session.user.id)
        } catch {
            await forceSignOut()
            errorMessage = friendlyMessage(for: error)
        }
    }

    func completeFirstAdministratorActivation(displayName: String) async {
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            errorMessage = "请输入教务姓名。"
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            struct Parameters: Encodable, Sendable {
                let displayName: String

                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }

            let created: ProfileRow = try await client
                .rpc(
                    "bootstrap_first_administrator",
                    params: Parameters(displayName: displayName)
                )
                .execute()
                .value
            try acceptAdministratorProfile(created)
            noticeMessage = "学校已激活，这台 Mac 现在可以正式使用。"
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func handleAuthCallback(_ url: URL) async {
        guard url.scheme == "masterdance-desk" else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let rememberLogin = retentionStore.remembersLogin
            authStorage.setSessionPersistenceEnabled(rememberLogin)
            client.auth.handle(url)
            let session = try await client.auth.session
            beginLoginRetention(rememberLogin: rememberLogin)
            try await finishAuthentication(userID: session.user.id)
            needsPasswordSetup = true
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func setInvitedAdministratorPassword(_ password: String, confirmation: String) async {
        guard password == confirmation else {
            errorMessage = "两次输入的密码不一致。"
            return
        }
        guard isAcceptablePassword(password) else {
            errorMessage = "密码至少 10 位，并且同时包含字母和数字。"
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await client.auth.update(user: UserAttributes(password: password))
            needsPasswordSetup = false
            noticeMessage = "密码设置完成。"
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func signOut() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
        clearAuthenticatedState()
        clearLoginRetention()
        phase = .signedOut
    }

    func enforceLoginRetention() async {
        guard phase == .ready || phase == .activationRequired else { return }
        guard let authenticatedAt = retentionStore.authenticatedAt,
              LoginRetentionPolicy.isWithinMaximumDuration(authenticatedAt: authenticatedAt) else {
            await expireRetainedLogin()
            return
        }
    }

    func loadAdministrators() async {
        guard phase == .ready else { return }
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("role", value: "administrator")
                .order("display_name")
                .execute()
                .value
            administrators = rows.map(Self.administratorProfile(from:))
            errorMessage = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    func inviteAdministrator(email: String, displayName: String) async -> Bool {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.contains("@"), !displayName.isEmpty else {
            errorMessage = "请输入有效邮箱和教务姓名。"
            return false
        }

        isWorking = true
        errorMessage = nil
        noticeMessage = nil
        defer { isWorking = false }

        do {
            let session = try await client.auth.session
            let endpoint = configuration.url.appendingPathComponent("functions/v1/admin-invite-member")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
            request.httpBody = try JSONEncoder().encode(
                InviteAdministratorRequest(email: email, displayName: displayName)
            )

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SupabaseRepositoryError.server("邀请服务没有返回有效响应。")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let payload = try? JSONDecoder().decode(EdgeFunctionError.self, from: data)
                throw SupabaseRepositoryError.server(payload?.error ?? "教务邀请失败。")
            }

            noticeMessage = "邀请已发送到 \(email)。对方从邮件打开 MD Desk 后设置密码即可。"
            await loadAdministrators()
            return true
        } catch {
            errorMessage = friendlyMessage(for: error)
            return false
        }
    }

    func clearMessages() {
        errorMessage = nil
        noticeMessage = nil
    }

    private func finishAuthentication(userID: UUID) async throws {
        let rows: [ProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            profile = nil
            repository = nil
            phase = .activationRequired
            return
        }
        try acceptAdministratorProfile(row)
    }

    private func acceptAdministratorProfile(_ row: ProfileRow) throws {
        guard row.role == "administrator", row.isActive else {
            throw SupabaseRepositoryError.server("MD Desk 只允许有效的教务账号登录。普通账号请使用 iPhone 版。")
        }

        let accepted = Self.administratorProfile(from: row)
        profile = accepted
        repository = LocalFirstRepositoryFactory.make(
            client: client,
            organizationID: accepted.organizationID,
            userID: accepted.userID
        )
        phase = .ready
    }

    private static func administratorProfile(from row: ProfileRow) -> AdministratorProfile {
        AdministratorProfile(
            userID: row.userID,
            organizationID: row.organizationID,
            displayName: row.displayName,
            appearance: row.appearance,
            isActive: row.isActive
        )
    }

    private func forceSignOut() async {
        try? await client.auth.signOut()
        clearAuthenticatedState()
        clearLoginRetention()
        phase = .signedOut
    }

    private func beginLoginRetention(
        rememberLogin: Bool,
        authenticatedAt: Date = Date()
    ) {
        retentionStore.recordAuthentication(
            rememberLogin: rememberLogin,
            at: authenticatedAt
        )
        scheduleExpiration(authenticatedAt: authenticatedAt)
    }

    private func scheduleExpiration(authenticatedAt: Date) {
        cancelExpirationTimer()
        let expirationDate = LoginRetentionPolicy.expirationDate(authenticatedAt: authenticatedAt)
        let seconds = max(0, expirationDate.timeIntervalSinceNow)
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        expirationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.enforceLoginRetention()
        }
    }

    private func expireRetainedLogin() async {
        cancelExpirationTimer()
        try? await client.auth.signOut(scope: .local)
        authStorage.setSessionPersistenceEnabled(false)
        retentionStore.clearAuthentication()
        clearAuthenticatedState()
        phase = .signedOut
        noticeMessage = nil
        errorMessage = "登录已超过 180 天，请重新登录。"
    }

    private func clearLoginRetention() {
        cancelExpirationTimer()
        retentionStore.clearAuthentication()
    }

    private func cancelExpirationTimer() {
        expirationTask?.cancel()
        expirationTask = nil
    }

    private func clearAuthenticatedState() {
        profile = nil
        repository = nil
        administrators = []
        needsPasswordSetup = false
    }

    private func isAcceptablePassword(_ password: String) -> Bool {
        password.count >= 10
            && password.contains(where: \.isLetter)
            && password.contains(where: \.isNumber)
    }

    private func friendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("invalid login credentials") {
            return "邮箱或密码不正确。"
        }
        if message.localizedCaseInsensitiveContains("email not confirmed") {
            return "请先从邀请邮件完成账号确认。"
        }
        if message.localizedCaseInsensitiveContains("bootstrap has already") {
            return "学校已经激活。这个账号需要由现有教务邀请后才能使用。"
        }
        return message
    }
}

private struct InviteAdministratorRequest: Encodable, Sendable {
    let email: String
    let displayName: String
    let role = "administrator"
    let studentIds: [UUID] = []
}

private struct EdgeFunctionError: Decodable, Sendable {
    let error: String
}
