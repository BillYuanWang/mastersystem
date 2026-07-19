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
    let contract: GuardianRegistrationContractMetadata
}

struct GuardianRegistrationContractMetadata: Equatable, Sendable {
    let id: UUID
    let title: String
    let version: String
}

struct GuardianRegistrationContractDocument: Equatable, Sendable {
    let metadata: GuardianRegistrationContractMetadata
    let data: Data
    let sha256: String
}

private struct GuardianRegistrationPreviewRow: Decodable, Sendable {
    let email: String
    let guardianName: String
    let contract: GuardianRegistrationContractPreviewRow

    enum CodingKeys: String, CodingKey {
        case email
        case guardianName = "guardian_name"
        case contract
    }
}

private struct GuardianRegistrationContractPreviewRow: Decodable, Sendable {
    let id: UUID
    let title: String
    let version: String
}

@MainActor
struct GuardianAccountService {
    let client: SupabaseClient
    let configuration: SupabaseConfiguration

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
            guardianName: row.guardianName,
            contract: GuardianRegistrationContractMetadata(
                id: row.contract.id,
                title: row.contract.title,
                version: row.contract.version
            )
        )
    }

    func downloadRegistrationContract(
        invitation: GuardianRegistrationInvitation
    ) async throws -> GuardianRegistrationContractDocument {
        let (data, response) = try await invokeContractGateway(
            GuardianRegistrationContractRequest(
                action: "download",
                invitationCode: invitation.code,
                contractDocumentID: invitation.contract.id,
                displayedContractSHA256: nil,
                signatureBase64: nil
            )
        )
        try validate(response: response, data: data)

        guard data.starts(with: Data("%PDF".utf8)) else {
            throw SupabaseRepositoryError.server("学校合同文件格式无效，请联系教务老师。")
        }
        let hash = response.value(forHTTPHeaderField: "X-Contract-SHA256")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard hash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw SupabaseRepositoryError.server("无法验证合同版本，请稍后重试。")
        }

        return GuardianRegistrationContractDocument(
            metadata: invitation.contract,
            data: data,
            sha256: hash
        )
    }

    func acceptRegistrationContract(
        invitation: GuardianRegistrationInvitation,
        document: GuardianRegistrationContractDocument,
        signaturePNG: Data
    ) async throws {
        guard document.metadata == invitation.contract else {
            throw SupabaseRepositoryError.server("合同已更新，请重新阅读后签名。")
        }
        let (data, response) = try await invokeContractGateway(
            GuardianRegistrationContractRequest(
                action: "accept",
                invitationCode: invitation.code,
                contractDocumentID: invitation.contract.id,
                displayedContractSHA256: document.sha256,
                signatureBase64: signaturePNG.base64EncodedString()
            )
        )
        try validate(response: response, data: data)
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

    private func invokeContractGateway(
        _ body: GuardianRegistrationContractRequest
    ) async throws -> (Data, HTTPURLResponse) {
        let endpoint = configuration.url
            .appendingPathComponent("functions/v1/guardian-registration-contract")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseRepositoryError.server("合同服务没有返回有效响应。")
        }
        return (data, httpResponse)
    }

    private func validate(response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? JSONDecoder().decode(
                GuardianRegistrationContractError.self,
                from: data
            )
            throw SupabaseRepositoryError.server(payload?.error ?? "合同服务暂时不可用。")
        }
    }
}

private struct GuardianRegistrationContractRequest: Encodable, Sendable {
    let action: String
    let invitationCode: String
    let contractDocumentID: UUID
    let displayedContractSHA256: String?
    let signatureBase64: String?

    enum CodingKeys: String, CodingKey {
        case action
        case invitationCode
        case contractDocumentID = "contractDocumentId"
        case displayedContractSHA256 = "displayedContractSha256"
        case signatureBase64
    }
}

private struct GuardianRegistrationContractError: Decodable, Sendable {
    let error: String
}
