import Foundation
import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Billing invoice series")
struct BillingInvoiceSeriesTests {
    @Test("Versions for one family and term are grouped into one series")
    func groupsVersions() throws {
        let guardianID = GuardianID()
        let termID = TermID()
        let firstID = BillingInvoiceID()
        let secondID = BillingInvoiceID()
        let first = invoice(
            id: firstID,
            guardianID: guardianID,
            termID: termID,
            number: "INV-2026-0001",
            version: 1,
            supersededByInvoiceID: secondID
        )
        let second = invoice(
            id: secondID,
            guardianID: guardianID,
            termID: termID,
            number: first.invoiceNumber,
            version: 2,
            supersedesInvoiceID: first.id
        )

        let series = BillingInvoiceSeriesResolver.series(from: [first, second])

        #expect(series.count == 1)
        #expect(series[0].invoices.map(\.version) == [2, 1])
        #expect(series[0].latestInvoice.id == second.id)
    }

    @Test("Different guardians or terms remain separate records")
    func separatesGuardianAndTerm() {
        let guardianID = GuardianID()
        let firstTermID = TermID()
        let invoices = [
            invoice(guardianID: guardianID, termID: firstTermID, number: "INV-1"),
            invoice(guardianID: guardianID, termID: TermID(), number: "INV-2"),
            invoice(guardianID: GuardianID(), termID: firstTermID, number: "INV-3"),
        ]

        #expect(BillingInvoiceSeriesResolver.series(from: invoices).count == 3)
    }

    private func invoice(
        id: BillingInvoiceID = BillingInvoiceID(),
        guardianID: GuardianID,
        termID: TermID,
        number: String,
        version: Int = 1,
        supersedesInvoiceID: BillingInvoiceID? = nil,
        supersededByInvoiceID: BillingInvoiceID? = nil
    ) -> BillingInvoice {
        BillingInvoice(
            id: id,
            guardianID: guardianID,
            termID: termID,
            invoiceNumber: number,
            version: version,
            schoolYearLabel: "2026–2027",
            issuedAt: Date(timeIntervalSince1970: TimeInterval(version)),
            amountDueCents: 10_000,
            supersedesInvoiceID: supersedesInvoiceID,
            supersededByInvoiceID: supersededByInvoiceID
        )
    }
}
