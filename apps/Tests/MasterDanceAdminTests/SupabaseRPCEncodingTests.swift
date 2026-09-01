import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Supabase RPC parameter encoding")
struct SupabaseRPCEncodingTests {
    @Test("Enrollment RPC keeps nullable billing keys")
    func enrollmentRPCEncodesNullBillingValues() throws {
        let enrollment = Enrollment(
            termID: TermID(),
            courseID: CourseID(),
            studentID: StudentID(),
            enrolledAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let data = try JSONEncoder().encode(AdminSaveEnrollmentParameters(enrollment))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        for key in [
            "target_billing_starts_on",
            "target_unit_price_cents",
            "target_discount_name",
            "target_discount_kind",
            "target_discount_value",
            "target_billing_notes",
        ] {
            #expect(object.keys.contains(key))
            #expect(object[key] is NSNull)
        }
        #expect(object["target_trial_fee_cents"] as? Int == 0)
        #expect((object["target_selected_session_ids"] as? [Any])?.isEmpty == true)
    }

    @Test("Dual billing RPC carries both document variants")
    func dualBillingRPCEncodesBothArtifacts() throws {
        let bilingualID = UUID()
        let englishID = UUID()
        let learnerIDs = [UUID(), UUID()]
        let parameters = IssueDualBillingInvoiceParameters(
            invoiceID: UUID(),
            guardianID: UUID(),
            termID: UUID(),
            learnerIDs: learnerIDs,
            invoiceNumber: "INV-2026-0001",
            version: 1,
            schoolYearLabel: "2026 秋季学期",
            issuedAt: "2026-08-31T12:00:00Z",
            notes: "",
            supersedesInvoiceID: nil,
            bilingualArtifactID: bilingualID,
            bilingualStoragePath: "org/family/invoice-v1-zh_en.png",
            englishArtifactID: englishID,
            englishStoragePath: "org/family/invoice-v1-en.png",
            items: []
        )

        let data = try JSONEncoder().encode(parameters)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["target_bilingual_artifact_id"] as? String == bilingualID.uuidString)
        #expect(object["target_english_artifact_id"] as? String == englishID.uuidString)
        #expect(object["target_bilingual_storage_path"] as? String == "org/family/invoice-v1-zh_en.png")
        #expect(object["target_english_storage_path"] as? String == "org/family/invoice-v1-en.png")
        #expect(object["target_learner_ids"] as? [String] == learnerIDs.map(\.uuidString))
        #expect(object["target_supersedes_invoice_id"] is NSNull)
    }

    @Test("Billing payload keeps waived prices separate from amount due")
    func billingPayloadEncodesSettlementStatus() throws {
        let item = BillingInvoiceLineItem(
            invoiceID: BillingInvoiceID(),
            kind: .tuition,
            title: "免付课程",
            unitAmountCents: 59_500,
            amountCents: 59_500,
            settlementStatus: .waived
        )

        let data = try JSONEncoder().encode(BillingInvoiceItemPayload(item))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["settlement_status"] as? String == "waived")
        #expect(object["included_in_amount_due"] as? Bool == false)
        #expect(object["amount_cents"] as? Int == 59_500)
    }
}
