import Foundation

public enum CoursePricingStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case priced
    case free
    case reviewRequired = "review_required"
}

public enum EnrollmentPricingStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case ready
    case reviewRequired = "review_required"
}

public enum EnrollmentRegistrationMode: String, Codable, CaseIterable, Sendable {
    case fullTerm = "full_term"
    case perSession = "per_session"
}

public enum BillingDiscountKind: String, Codable, CaseIterable, Sendable {
    case percentage
    case fixedAmount = "fixed_amount"
}

public enum BillingCurrency: String, Codable, CaseIterable, Sendable {
    case usd = "USD"
}

public enum BillingLineItemKind: String, Codable, CaseIterable, Sendable {
    case tuition
    case trial
    case registration
    case discount
    case balanceCredit = "balance_credit"
    case priorBalance = "prior_balance"
    case manual
}

public enum BillingPaymentMethod: String, Codable, CaseIterable, Sendable {
    case cash
    case check
    case zelle
    case card
}

public enum BillingArtifactKind: String, Codable, CaseIterable, Sendable {
    case invoice
    case receipt
}

public enum BillingInvoiceDisplayStatus: String, Codable, CaseIterable, Sendable {
    case issued
    case partiallyPaid
    case paid
    case superseded
}

public struct EnrollmentChargeEstimate: Equatable, Sendable {
    public let normalSessionCount: Int
    public let unitPriceCents: Int?
    public let tuitionBeforeDiscountCents: Int?
    public let discountCents: Int
    public let trialFeeCents: Int
    public let totalCents: Int?

    public init(
        normalSessionCount: Int,
        unitPriceCents: Int?,
        tuitionBeforeDiscountCents: Int?,
        discountCents: Int,
        trialFeeCents: Int,
        totalCents: Int?
    ) {
        self.normalSessionCount = normalSessionCount
        self.unitPriceCents = unitPriceCents
        self.tuitionBeforeDiscountCents = tuitionBeforeDiscountCents
        self.discountCents = discountCents
        self.trialFeeCents = trialFeeCents
        self.totalCents = totalCents
    }
}

public enum BillingCalculator {
    public static let cardFeeBasisPoints = 350

    public static func courseTotalCents(
        unitPriceCents: Int?,
        scheduledSessionCount: Int
    ) -> Int? {
        guard let unitPriceCents, unitPriceCents >= 0, scheduledSessionCount >= 0 else {
            return nil
        }
        return unitPriceCents * scheduledSessionCount
    }

    public static func estimate(
        enrollment: Enrollment,
        sessions: [ClassSession],
        trialSessionIDs: Set<ClassSessionID> = [],
        calendar: Calendar = .current
    ) -> EnrollmentChargeEstimate {
        let startDay = enrollment.billingStartsOn.map(calendar.startOfDay(for:))
        let normalSessionCount = sessions.reduce(into: 0) { count, session in
            guard session.status != .cancelled,
                  !trialSessionIDs.contains(session.id),
                  enrollment.includes(sessionID: session.id) else { return }
            if let startDay,
               calendar.startOfDay(for: session.startsAt) < startDay {
                return
            }
            count += 1
        }

        guard let unitPriceCents = enrollment.unitPriceCents else {
            return EnrollmentChargeEstimate(
                normalSessionCount: normalSessionCount,
                unitPriceCents: nil,
                tuitionBeforeDiscountCents: nil,
                discountCents: 0,
                trialFeeCents: enrollment.trialFeeCents,
                totalCents: nil
            )
        }

        let tuition = max(0, unitPriceCents) * normalSessionCount
        let discount = discountCents(
            subtotalCents: tuition,
            kind: enrollment.discountKind,
            value: enrollment.discountValue
        )
        return EnrollmentChargeEstimate(
            normalSessionCount: normalSessionCount,
            unitPriceCents: unitPriceCents,
            tuitionBeforeDiscountCents: tuition,
            discountCents: discount,
            trialFeeCents: enrollment.trialFeeCents,
            totalCents: max(0, tuition - discount) + enrollment.trialFeeCents
        )
    }

    public static func discountCents(
        subtotalCents: Int,
        kind: BillingDiscountKind?,
        value: Int?
    ) -> Int {
        guard subtotalCents > 0, let kind, let value, value > 0 else { return 0 }
        switch kind {
        case .percentage:
            let basisPoints = min(value, 10_000)
            return min(subtotalCents, (subtotalCents * basisPoints + 5_000) / 10_000)
        case .fixedAmount:
            return min(subtotalCents, value)
        }
    }

    public static func cardFeeCents(for paymentAmountCents: Int) -> Int {
        guard paymentAmountCents > 0 else { return 0 }
        return (paymentAmountCents * cardFeeBasisPoints + 5_000) / 10_000
    }
}

public enum MoneyTextParser {
    public static func cents(from text: String) -> Int? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "USD", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dollars = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        var value = dollars * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != .notANumber else { return nil }
        return number.intValue
    }

    public static func dollars(from cents: Int?) -> String {
        guard let cents else { return "" }
        return String(format: "%.2f", Double(cents) / 100)
    }
}

public struct BillingInvoice: Identifiable, Codable, Equatable, Sendable {
    public let id: BillingInvoiceID
    public let guardianID: GuardianID
    public let termID: TermID?
    public let invoiceNumber: String
    public let version: Int
    public let schoolYearLabel: String
    public let issuedAt: Date
    public let currency: BillingCurrency
    public let amountDueCents: Int
    public let notes: String?
    public let supersedesInvoiceID: BillingInvoiceID?
    public let supersededByInvoiceID: BillingInvoiceID?
    public let createdAt: Date

    public init(
        id: BillingInvoiceID = BillingInvoiceID(),
        guardianID: GuardianID,
        termID: TermID?,
        invoiceNumber: String,
        version: Int = 1,
        schoolYearLabel: String,
        issuedAt: Date = Date(),
        currency: BillingCurrency = .usd,
        amountDueCents: Int,
        notes: String? = nil,
        supersedesInvoiceID: BillingInvoiceID? = nil,
        supersededByInvoiceID: BillingInvoiceID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.guardianID = guardianID
        self.termID = termID
        self.invoiceNumber = invoiceNumber
        self.version = version
        self.schoolYearLabel = schoolYearLabel
        self.issuedAt = issuedAt
        self.currency = currency
        self.amountDueCents = amountDueCents
        self.notes = notes
        self.supersedesInvoiceID = supersedesInvoiceID
        self.supersededByInvoiceID = supersededByInvoiceID
        self.createdAt = createdAt
    }

    public func displayStatus(payments: [BillingPayment]) -> BillingInvoiceDisplayStatus {
        if supersededByInvoiceID != nil { return .superseded }
        let paid = payments
            .filter { $0.invoiceID == id }
            .reduce(0) { $0 + $1.amountCents }
        if paid >= amountDueCents, amountDueCents > 0 { return .paid }
        if paid > 0 { return .partiallyPaid }
        return .issued
    }

    public func outstandingCents(payments: [BillingPayment]) -> Int {
        let paid = payments
            .filter { $0.invoiceID == id }
            .reduce(0) { $0 + $1.amountCents }
        return max(0, amountDueCents - paid)
    }
}

public struct BillingInvoiceLineItem: Identifiable, Codable, Equatable, Sendable {
    public let id: BillingInvoiceLineItemID
    public let invoiceID: BillingInvoiceID
    public let studentID: StudentID?
    public let enrollmentID: EnrollmentID?
    public let kind: BillingLineItemKind
    public let title: String
    public let detail: String?
    public let quantity: Int
    public let unitAmountCents: Int
    public let amountCents: Int
    public let includedInAmountDue: Bool
    public let sortOrder: Int

    public init(
        id: BillingInvoiceLineItemID = BillingInvoiceLineItemID(),
        invoiceID: BillingInvoiceID,
        studentID: StudentID? = nil,
        enrollmentID: EnrollmentID? = nil,
        kind: BillingLineItemKind,
        title: String,
        detail: String? = nil,
        quantity: Int = 1,
        unitAmountCents: Int,
        amountCents: Int,
        includedInAmountDue: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.invoiceID = invoiceID
        self.studentID = studentID
        self.enrollmentID = enrollmentID
        self.kind = kind
        self.title = title
        self.detail = detail
        self.quantity = quantity
        self.unitAmountCents = unitAmountCents
        self.amountCents = amountCents
        self.includedInAmountDue = includedInAmountDue
        self.sortOrder = sortOrder
    }
}

public struct BillingPayment: Identifiable, Codable, Equatable, Sendable {
    public let id: BillingPaymentID
    public let invoiceID: BillingInvoiceID
    public let amountCents: Int
    public let processingFeeCents: Int
    public let method: BillingPaymentMethod
    public let receivedAt: Date
    public let note: String?
    public let createdAt: Date

    public init(
        id: BillingPaymentID = BillingPaymentID(),
        invoiceID: BillingInvoiceID,
        amountCents: Int,
        processingFeeCents: Int,
        method: BillingPaymentMethod,
        receivedAt: Date = Date(),
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.invoiceID = invoiceID
        self.amountCents = amountCents
        self.processingFeeCents = processingFeeCents
        self.method = method
        self.receivedAt = receivedAt
        self.note = note
        self.createdAt = createdAt
    }

    public var chargedAmountCents: Int {
        amountCents + processingFeeCents
    }
}

public struct BillingArtifact: Identifiable, Codable, Equatable, Sendable {
    public let id: BillingArtifactID
    public let invoiceID: BillingInvoiceID
    public let paymentID: BillingPaymentID?
    public let kind: BillingArtifactKind
    public let storagePath: String
    public let mimeType: String
    public let generatedAt: Date

    public init(
        id: BillingArtifactID = BillingArtifactID(),
        invoiceID: BillingInvoiceID,
        paymentID: BillingPaymentID? = nil,
        kind: BillingArtifactKind,
        storagePath: String = "",
        mimeType: String = "image/png",
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.invoiceID = invoiceID
        self.paymentID = paymentID
        self.kind = kind
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.generatedAt = generatedAt
    }
}
