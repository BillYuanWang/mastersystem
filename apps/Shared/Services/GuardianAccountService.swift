import Foundation
import Supabase

struct ClaimGuardianLinkCodeParameters: Encodable, Sendable {
    let claimCode: String

    enum CodingKeys: String, CodingKey {
        case claimCode = "claim_code"
    }
}

@MainActor
struct GuardianAccountService {
    let client: SupabaseClient

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
                params: ClaimGuardianLinkCodeParameters(claimCode: code)
            )
            .execute()
            .value
    }
}
