import Testing
@testable import MasterDanceCore

@Suite("Guardian contact validation")
struct GuardianContactTests {
    @Test("Email is required, validated, and normalized")
    func emailValidation() {
        #expect(GuardianContact.normalizedEmail("  Parent.Name+child@Example.COM ") == "parent.name+child@example.com")
        #expect(GuardianContact.normalizedEmail("") == nil)
        #expect(GuardianContact.normalizedEmail("parent@example") == nil)
        #expect(GuardianContact.normalizedEmail("parent..name@example.com") == nil)
    }

    @Test("Raw US phone numbers receive the canonical format")
    func rawPhoneFormatting() {
        #expect(GuardianContact.formattedUSPhone("9495550123") == "+1 (949) 555-0123")
        #expect(GuardianContact.formattedUSPhone("19495550123") == "+1 (949) 555-0123")
    }

    @Test("Already formatted US phone numbers are normalized")
    func formattedPhoneNormalization() {
        #expect(GuardianContact.formattedUSPhone("+1 (949) 555-0123") == "+1 (949) 555-0123")
        #expect(GuardianContact.formattedUSPhone("949.555.0123") == "+1 (949) 555-0123")
    }

    @Test("Invalid phone numbers are rejected")
    func invalidPhoneRejection() {
        #expect(GuardianContact.formattedUSPhone("") == nil)
        #expect(GuardianContact.formattedUSPhone("949555012") == nil)
        #expect(GuardianContact.formattedUSPhone("+44 20 7946 0958") == nil)
        #expect(GuardianContact.formattedUSPhone("call 9495550123") == nil)
    }
}
