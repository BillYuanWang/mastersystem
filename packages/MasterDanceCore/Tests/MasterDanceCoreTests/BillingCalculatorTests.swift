import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Billing calculator")
struct BillingCalculatorTests {
    @Test("full-term tuition uses actual scheduled sessions")
    func fullTermTuition() {
        let fixture = Fixture()
        let enrollment = fixture.enrollment(unitPriceCents: 2_500)

        let estimate = BillingCalculator.estimate(
            enrollment: enrollment,
            sessions: fixture.sessions(count: 17),
            calendar: fixture.calendar
        )

        #expect(estimate.normalSessionCount == 17)
        #expect(estimate.tuitionBeforeDiscountCents == 42_500)
        #expect(estimate.totalCents == 42_500)
    }

    @Test("per-session tuition includes only explicitly selected class dates")
    func perSessionTuition() {
        let fixture = Fixture()
        let sessions = fixture.sessions(count: 6)
        var enrollment = fixture.enrollment(unitPriceCents: 3_200)
        enrollment.registrationMode = .perSession
        enrollment.selectedSessionIDs = [sessions[1].id, sessions[4].id]

        let estimate = BillingCalculator.estimate(
            enrollment: enrollment,
            sessions: sessions,
            calendar: fixture.calendar
        )

        #expect(estimate.normalSessionCount == 2)
        #expect(estimate.tuitionBeforeDiscountCents == 6_400)
        #expect(estimate.totalCents == 6_400)
    }

    @Test("trial sessions and pre-billing dates are excluded from normal tuition")
    func trialConversion() {
        let fixture = Fixture()
        let sessions = fixture.sessions(count: 5)
        var enrollment = fixture.enrollment(unitPriceCents: 3_000)
        enrollment.billingStartsOn = sessions[2].startsAt
        enrollment.trialFeeCents = 1_500

        let estimate = BillingCalculator.estimate(
            enrollment: enrollment,
            sessions: sessions,
            trialSessionIDs: [sessions[2].id],
            calendar: fixture.calendar
        )

        #expect(estimate.normalSessionCount == 2)
        #expect(estimate.tuitionBeforeDiscountCents == 6_000)
        #expect(estimate.totalCents == 7_500)
    }

    @Test("percentage and fixed discounts apply only to normal tuition")
    func discounts() {
        let fixture = Fixture()
        var percentage = fixture.enrollment(unitPriceCents: 2_000)
        percentage.trialFeeCents = 1_200
        percentage.discountKind = .percentage
        percentage.discountValue = 1_500

        let percentageEstimate = BillingCalculator.estimate(
            enrollment: percentage,
            sessions: fixture.sessions(count: 4),
            calendar: fixture.calendar
        )
        #expect(percentageEstimate.discountCents == 1_200)
        #expect(percentageEstimate.totalCents == 8_000)

        var fixed = percentage
        fixed.discountKind = .fixedAmount
        fixed.discountValue = 20_000
        let fixedEstimate = BillingCalculator.estimate(
            enrollment: fixed,
            sessions: fixture.sessions(count: 4),
            calendar: fixture.calendar
        )
        #expect(fixedEstimate.discountCents == 8_000)
        #expect(fixedEstimate.totalCents == 1_200)
    }

    @Test("card fee is rounded to the nearest cent and remains separate")
    func cardFee() {
        #expect(BillingCalculator.cardFeeCents(for: 10_000) == 350)
        #expect(BillingCalculator.cardFeeCents(for: 1) == 0)
        #expect(BillingCalculator.cardFeeCents(for: 15) == 1)
    }

    @Test("issued invoices, payments, and correction versions remain append-only")
    func invoiceLifecycle() async throws {
        let guardian = Guardian(displayName: "测试家庭")
        let termID = TermID()
        let store = PreviewMasterDanceStore(
            data: PreviewData(guardians: [guardian])
        )
        let first = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            invoiceNumber: "INV-2026-0001",
            schoolYearLabel: "2026–2027",
            amountDueCents: 10_000
        )
        let firstItem = BillingInvoiceLineItem(
            invoiceID: first.id,
            kind: .tuition,
            title: "秋季学费",
            unitAmountCents: 10_000,
            amountCents: 10_000
        )
        _ = try await store.issueBillingInvoice(
            invoice: first,
            lineItems: [firstItem],
            artifact: BillingArtifact(
                invoiceID: first.id,
                kind: .invoice,
                storagePath: "preview/invoice.png"
            ),
            pngData: Data([1, 2, 3])
        )

        let payment = BillingPayment(
            invoiceID: first.id,
            amountCents: 5_000,
            processingFeeCents: 175,
            method: .card
        )
        _ = try await store.recordBillingPayment(
            payment: payment,
            artifact: BillingArtifact(
                invoiceID: first.id,
                paymentID: payment.id,
                kind: .receipt,
                storagePath: "preview/receipt.png"
            ),
            pngData: Data([4, 5, 6])
        )

        let second = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            invoiceNumber: first.invoiceNumber,
            version: 2,
            schoolYearLabel: first.schoolYearLabel,
            amountDueCents: 9_000,
            supersedesInvoiceID: first.id
        )
        let secondItem = BillingInvoiceLineItem(
            invoiceID: second.id,
            kind: .tuition,
            title: "修订学费",
            unitAmountCents: 9_000,
            amountCents: 9_000
        )
        _ = try await store.issueBillingInvoice(
            invoice: second,
            lineItems: [secondItem],
            artifact: BillingArtifact(
                invoiceID: second.id,
                kind: .invoice,
                storagePath: "preview/invoice-v2.png"
            ),
            pngData: Data([7, 8, 9])
        )

        let invoices = await store.listBillingInvoices()
        let storedFirst = try #require(invoices.first { $0.id == first.id })
        #expect(storedFirst.supersededByInvoiceID == second.id)
        #expect(storedFirst.displayStatus(payments: [payment]) == .superseded)
        #expect(first.outstandingCents(payments: [payment]) == 5_000)
        #expect(await store.listBillingPayments().map(\.id) == [payment.id])
        #expect(await store.listBillingArtifacts().count == 3)
    }

    @Test("a family and term can only start one invoice series")
    func invoiceSeriesIsUniquePerFamilyAndTerm() async throws {
        let guardian = Guardian(displayName: "测试家庭")
        let termID = TermID()
        let store = PreviewMasterDanceStore(data: PreviewData(guardians: [guardian]))
        let first = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            invoiceNumber: "INV-2026-0001",
            schoolYearLabel: "2026–2027",
            amountDueCents: 1_000
        )
        let duplicateRoot = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            invoiceNumber: "INV-2026-0002",
            schoolYearLabel: "2026–2027",
            amountDueCents: 1_000
        )

        _ = try await store.issueBillingInvoice(
            invoice: first,
            lineItems: [invoiceItem(invoiceID: first.id, amountCents: 1_000)],
            artifact: BillingArtifact(invoiceID: first.id, kind: .invoice),
            pngData: Data([1])
        )

        await #expect(throws: PreviewRepositoryError.self) {
            try await store.issueBillingInvoice(
                invoice: duplicateRoot,
                lineItems: [invoiceItem(invoiceID: duplicateRoot.id, amountCents: 1_000)],
                artifact: BillingArtifact(invoiceID: duplicateRoot.id, kind: .invoice),
                pngData: Data([2])
            )
        }
    }

    private func invoiceItem(invoiceID: BillingInvoiceID, amountCents: Int) -> BillingInvoiceLineItem {
        BillingInvoiceLineItem(
            invoiceID: invoiceID,
            kind: .manual,
            title: "收费项目",
            unitAmountCents: amountCents,
            amountCents: amountCents
        )
    }
}

private struct Fixture {
    let calendar: Calendar
    let courseID = CourseID()
    let termID = TermID()
    let studentID = StudentID()

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
    }

    func enrollment(unitPriceCents: Int) -> Enrollment {
        Enrollment(
            termID: termID,
            courseID: courseID,
            studentID: studentID,
            enrolledAt: date(day: 1),
            pricingStatus: .ready,
            billingStartsOn: date(day: 1),
            unitPriceCents: unitPriceCents
        )
    }

    func sessions(count: Int) -> [ClassSession] {
        (0..<count).map { offset in
            let start = calendar.date(byAdding: .day, value: offset * 7, to: date(day: 1))!
            return ClassSession(
                courseID: courseID,
                startsAt: start,
                endsAt: calendar.date(byAdding: .hour, value: 1, to: start)!
            )
        }
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 16))!
    }
}
