import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Billing calculator")
struct BillingCalculatorTests {
    @Test("group per-session price stays five dollars above full-term unit price")
    func groupPerSessionPremium() {
        #expect(CoursePricingPolicy.perSessionUnitPriceCents(fullTermUnitPriceCents: 4_000) == 4_500)
        #expect(CoursePricingPolicy.perSessionUnitPriceCents(fullTermUnitPriceCents: 3_500) == 4_000)
        #expect(CoursePricingPolicy.perSessionUnitPriceCents(fullTermUnitPriceCents: nil) == nil)
        #expect(CoursePricingPolicy.perSessionUnitPriceCents(fullTermUnitPriceCents: 0) == nil)
    }

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

    @Test("paid and waived line items retain price without contributing to amount due")
    func settlementStates() throws {
        let invoiceID = BillingInvoiceID()
        let paidItem = BillingInvoiceLineItem(
            invoiceID: invoiceID,
            kind: .tuition,
            title: "已付课程",
            unitAmountCents: 5_000,
            amountCents: 5_000,
            isPaid: true
        )
        let waivedItem = BillingInvoiceLineItem(
            invoiceID: invoiceID,
            kind: .tuition,
            title: "免付课程",
            unitAmountCents: 5_000,
            amountCents: 5_000,
            settlementStatus: .waived
        )

        #expect(paidItem.isPaid)
        #expect(!paidItem.includedInAmountDue)
        #expect(waivedItem.isWaived)
        #expect(!waivedItem.isPaid)
        #expect(!waivedItem.includedInAmountDue)

        let encoded = try JSONEncoder().encode(waivedItem)
        let decoded = try JSONDecoder().decode(BillingInvoiceLineItem.self, from: encoded)
        #expect(decoded.settlementStatus == .waived)
        #expect(decoded.amountCents == 5_000)
        #expect(BillingArtifactLanguage.inferred(from: "invoice-v1-en.png") == .english)
        #expect(BillingArtifactLanguage.inferred(from: "invoice-v1-zh_en.png") == .bilingual)
    }

    @Test("legacy line item caches infer settlement status from the amount-due flag")
    func legacyLineItemSettlementDecoding() throws {
        let item = BillingInvoiceLineItem(
            invoiceID: BillingInvoiceID(),
            kind: .manual,
            title: "旧已付项目",
            unitAmountCents: 1_000,
            amountCents: 1_000,
            isPaid: true
        )
        let encoded = try JSONEncoder().encode(item)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "settlementStatus")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(BillingInvoiceLineItem.self, from: legacyData)

        #expect(decoded.settlementStatus == .paid)
        #expect(decoded.isPaid)
    }

    @Test("zero-due invoices are marked as requiring no payment")
    func noPaymentRequiredInvoiceStatus() {
        let invoice = BillingInvoice(
            guardianID: GuardianID(),
            termID: TermID(),
            invoiceNumber: "INV-WAIVED",
            schoolYearLabel: "2026 秋季学期",
            amountDueCents: 0
        )

        #expect(invoice.paymentProgress(payments: []) == .noPaymentRequired)
        #expect(invoice.displayStatus(payments: []) == .noPaymentRequired)
    }

    @Test("payment progress stays attached to one invoice version")
    func invoiceVersionPaymentProgress() {
        let invoice = BillingInvoice(
            guardianID: GuardianID(),
            termID: TermID(),
            invoiceNumber: "INV-PROGRESS",
            version: 3,
            schoolYearLabel: "2026 秋季学期",
            amountDueCents: 10_000
        )
        let unrelated = BillingPayment(
            invoiceID: BillingInvoiceID(),
            amountCents: 10_000,
            processingFeeCents: 0,
            method: .cash
        )
        let first = BillingPayment(
            invoiceID: invoice.id,
            amountCents: 4_000,
            processingFeeCents: 0,
            method: .zelle
        )
        let second = BillingPayment(
            invoiceID: invoice.id,
            amountCents: 6_000,
            processingFeeCents: 0,
            method: .check
        )

        #expect(invoice.paymentProgress(payments: [unrelated]) == .unpaid)
        #expect(invoice.paymentProgress(payments: [first, unrelated]) == .partiallyPaid)
        #expect(invoice.paidCents(payments: [first, unrelated]) == 4_000)
        #expect(invoice.outstandingCents(payments: [first, unrelated]) == 6_000)
        #expect(invoice.paymentProgress(payments: [first, second, unrelated]) == .paid)
        #expect(invoice.outstandingCents(payments: [first, second, unrelated]) == 0)
    }

    @Test("legacy cached invoices decode before learner scopes existed")
    func legacyInvoiceDecoding() throws {
        let invoice = BillingInvoice(
            guardianID: GuardianID(),
            termID: TermID(),
            learnerIDs: [StudentID()],
            invoiceNumber: "INV-LEGACY",
            schoolYearLabel: "2026 秋季学期",
            amountDueCents: 1_000
        )
        let encoded = try JSONEncoder().encode(invoice)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "learnerIDs")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(BillingInvoice.self, from: legacyData)

        #expect(decoded.learnerIDs.isEmpty)
        #expect(decoded.invoiceNumber == invoice.invoiceNumber)
    }

    @Test("issued invoices, payments, and correction versions remain append-only")
    func invoiceLifecycle() async throws {
        let guardian = Guardian(displayName: "测试家庭")
        let learner = Student(
            guardianID: guardian.id,
            displayName: "测试学员",
            kind: .child
        )
        let termID = TermID()
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [learner], guardians: [guardian])
        )
        let first = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            learnerIDs: [learner.id],
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
            artifactUploads: artifactUploads(
                invoiceID: first.id,
                kind: .invoice,
                data: Data([1, 2, 3])
            )
        )

        let payment = BillingPayment(
            invoiceID: first.id,
            amountCents: 5_000,
            processingFeeCents: 175,
            method: .card
        )
        _ = try await store.recordBillingPayment(
            payment: payment,
            artifactUploads: artifactUploads(
                invoiceID: first.id,
                paymentID: payment.id,
                kind: .receipt,
                data: Data([4, 5, 6])
            )
        )

        let second = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            learnerIDs: [learner.id],
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
            artifactUploads: artifactUploads(
                invoiceID: second.id,
                kind: .invoice,
                data: Data([7, 8, 9])
            )
        )

        let invoices = await store.listBillingInvoices()
        let storedFirst = try #require(invoices.first { $0.id == first.id })
        #expect(storedFirst.supersededByInvoiceID == second.id)
        #expect(storedFirst.displayStatus(payments: [payment]) == .superseded)
        #expect(first.outstandingCents(payments: [payment]) == 5_000)
        #expect(await store.listBillingPayments().map(\.id) == [payment.id])
        #expect(await store.listBillingArtifacts().count == 6)
    }

    @Test("invoice series are unique per family, term, and learner selection")
    func invoiceSeriesIsUniquePerLearnerScope() async throws {
        let guardian = Guardian(displayName: "测试家庭")
        let firstLearner = Student(
            guardianID: guardian.id,
            displayName: "学员甲",
            kind: .child
        )
        let secondLearner = Student(
            guardianID: guardian.id,
            displayName: "学员乙",
            kind: .child
        )
        let termID = TermID()
        let store = PreviewMasterDanceStore(
            data: PreviewData(students: [firstLearner, secondLearner], guardians: [guardian])
        )
        let first = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            learnerIDs: [firstLearner.id],
            invoiceNumber: "INV-2026-0001",
            schoolYearLabel: "2026–2027",
            amountDueCents: 1_000
        )
        let duplicateRoot = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            learnerIDs: [firstLearner.id],
            invoiceNumber: "INV-2026-0002",
            schoolYearLabel: "2026–2027",
            amountDueCents: 1_000
        )

        _ = try await store.issueBillingInvoice(
            invoice: first,
            lineItems: [invoiceItem(invoiceID: first.id, amountCents: 1_000)],
            artifactUploads: artifactUploads(invoiceID: first.id, kind: .invoice, data: Data([1]))
        )

        await #expect(throws: PreviewRepositoryError.self) {
            try await store.issueBillingInvoice(
                invoice: duplicateRoot,
                lineItems: [invoiceItem(invoiceID: duplicateRoot.id, amountCents: 1_000)],
                artifactUploads: artifactUploads(
                    invoiceID: duplicateRoot.id,
                    kind: .invoice,
                    data: Data([2])
                )
            )
        }

        let separateLearnerInvoice = BillingInvoice(
            guardianID: guardian.id,
            termID: termID,
            learnerIDs: [secondLearner.id],
            invoiceNumber: "INV-2026-0003",
            schoolYearLabel: "2026–2027",
            amountDueCents: 1_000
        )
        _ = try await store.issueBillingInvoice(
            invoice: separateLearnerInvoice,
            lineItems: [invoiceItem(invoiceID: separateLearnerInvoice.id, amountCents: 1_000)],
            artifactUploads: artifactUploads(
                invoiceID: separateLearnerInvoice.id,
                kind: .invoice,
                data: Data([3])
            )
        )

        #expect(await store.listBillingInvoices().filter { $0.version == 1 }.count == 2)
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

    private func artifactUploads(
        invoiceID: BillingInvoiceID,
        paymentID: BillingPaymentID? = nil,
        kind: BillingArtifactKind,
        data: Data
    ) -> [BillingArtifactUpload] {
        BillingArtifactLanguage.allCases.map { language in
            BillingArtifactUpload(
                artifact: BillingArtifact(
                    invoiceID: invoiceID,
                    paymentID: paymentID,
                    kind: kind,
                    language: language
                ),
                pngData: data
            )
        }
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
