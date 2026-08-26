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
}
