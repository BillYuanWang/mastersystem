import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Contract signatures")
struct ContractSignatureTests {
    private let pngBytes: [UInt8] = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x00,
    ]

    @Test("Postgres bytea hex signatures decode as PNG data")
    func decodesPostgresHex() {
        let hex = pngBytes.map { String(format: "%02x", $0) }.joined()
        let row = ContractConsentSignatureRow(
            contractConsentID: UUID(),
            signaturePNG: "\\x\(hex)"
        )

        #expect(row.decodedPNG == Data(pngBytes))
    }

    @Test("Base64 signatures remain compatible")
    func decodesBase64() {
        let data = Data(pngBytes)
        let row = ContractConsentSignatureRow(
            contractConsentID: UUID(),
            signaturePNG: data.base64EncodedString()
        )

        #expect(row.decodedPNG == data)
    }

    @Test("Non-PNG evidence is ignored without breaking the record list")
    func rejectsInvalidEvidence() {
        let row = ContractConsentSignatureRow(
            contractConsentID: UUID(),
            signaturePNG: "\\x00010203"
        )

        #expect(row.decodedPNG == nil)
    }

    @Test("A newly accepted agreement keeps its signature in local UI state")
    @MainActor
    func keepsNewSignatureLocally() async {
        let term = Term(name: "测试学期", startsOn: .now, endsOn: .now, status: .open)
        let document = ContractDocument(
            termID: term.id,
            version: "v1",
            title: "测试协议",
            bodyText: "测试协议正文",
            status: .published,
            publishedAt: .now
        )
        let repository = PreviewMasterDanceStore(
            data: PreviewData(terms: [term], contractDocuments: [document])
        )
        let model = AppModel(repository: repository)
        await model.reload()
        let signature = Data(pngBytes)

        model.applyLocalContractConsent(
            documentID: document.id,
            enrollmentID: nil,
            signerKind: .guardian,
            signerDisplayName: "测试家长",
            signaturePNG: signature
        )

        #expect(model.contractConsents.first?.signaturePNG == signature)
    }
}
