import Foundation
import Supabase

struct ClaimGuardianLinkCodeParameters: Encodable, Sendable {
    let claimCode: String

    enum CodingKeys: String, CodingKey {
        case claimCode = "claim_code"
    }
}

struct GuardianRegistrationInvitation: Equatable, Sendable {
    let code: String
    let email: String
    let guardianName: String
}

private struct GuardianRegistrationPreviewRow: Decodable, Sendable {
    let email: String
    let guardianName: String

    enum CodingKeys: String, CodingKey {
        case email
        case guardianName = "guardian_name"
    }
}

@MainActor
struct GuardianAccountService {
    let client: SupabaseClient

    func previewRegistration(code: String) async throws -> GuardianRegistrationInvitation {
        let normalizedCode = normalize(code)
        let row: GuardianRegistrationPreviewRow = try await client
            .rpc(
                "preview_guardian_registration",
                params: ClaimGuardianLinkCodeParameters(claimCode: normalizedCode)
            )
            .execute()
            .value
        return GuardianRegistrationInvitation(
            code: normalizedCode,
            email: row.email,
            guardianName: row.guardianName
        )
    }

    func register(email: String, password: String) async throws {
        _ = try await client.auth.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
    }

    func signIn(email: String, password: String) async throws {
        _ = try await client.auth.signIn(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password
        )
    }

    func claimFamily(code: String) async throws -> ProfileRow {
        try await client
            .rpc(
                "claim_guardian_link_code",
                params: ClaimGuardianLinkCodeParameters(claimCode: normalize(code))
            )
            .execute()
            .value
    }

    private func normalize(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
