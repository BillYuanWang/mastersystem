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

public enum BillingLineItemSettlementStatus: String, Codable, CaseIterable, Sendable {
    case unpaid
    case paid
    case waived

    public var contributesToAmountDue: Bool { self == .unpaid }
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

public enum BillingArtifactLanguage: String, Codable, CaseIterable, Hashable, Sendable {
    case bilingual = "zh_en"
    case english = "en"

    public var storageSuffix: String { rawValue }

    public static func inferred(from storagePath: String) -> BillingArtifactLanguage {
        let filename = URL(fileURLWithPath: storagePath).lastPathComponent.lowercased()
        return filename.contains("-en.") || filename.hasSuffix("-en.png") ? .english : .bilingual
    }
}

public enum BillingInvoiceDisplayStatus: String, Codable, CaseIterable, Sendable {
    case issued
    case partiallyPaid
    case paid
    case noPaymentRequired = "no_payment_required"
    case superseded
}

public enum BillingPaymentProgress: String, Codable, CaseIterable, Sendable {
    case unpaid
    case partiallyPaid = "partially_paid"
    case paid
    case noPaymentRequired = "no_payment_required"
}

public enum CoursePricingPolicy {
    public static let perSessionPremiumCents = 500

    public static func perSessionUnitPriceCents(
        fullTermUnitPriceCents: Int?
    ) -> Int? {
        guard let fullTermUnitPriceCents, fullTermUnitPriceCents > 0 else {
            return nil
        }
        let (price, overflow) = fullTermUnitPriceCents.addingReportingOverflow(perSessionPremiumCents)
        return overflow ? nil : price
    }
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
    public let learnerIDs: [StudentID]
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
        learnerIDs: [StudentID] = [],
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
        self.learnerIDs = Self.normalizedLearnerIDs(learnerIDs)
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

    public var learnerScopeKey: String {
        learnerIDs.isEmpty
            ? "legacy-family"
            : learnerIDs.map(\.description).joined(separator: "|")
    }

    public static func normalizedLearnerIDs(_ learnerIDs: [StudentID]) -> [StudentID] {
        Array(Set(learnerIDs)).sorted { $0.description < $1.description }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case guardianID
        case termID
        case learnerIDs
        case invoiceNumber
        case version
        case schoolYearLabel
        case issuedAt
        case currency
        case amountDueCents
        case notes
        case supersedesInvoiceID
        case supersededByInvoiceID
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(BillingInvoiceID.self, forKey: .id)
        guardianID = try container.decode(GuardianID.self, forKey: .guardianID)
        termID = try container.decodeIfPresent(TermID.self, forKey: .termID)
        learnerIDs = Self.normalizedLearnerIDs(
            try container.decodeIfPresent([StudentID].self, forKey: .learnerIDs) ?? []
        )
        invoiceNumber = try container.decode(String.self, forKey: .invoiceNumber)
        version = try container.decode(Int.self, forKey: .version)
        schoolYearLabel = try container.decode(String.self, forKey: .schoolYearLabel)
        issuedAt = try container.decode(Date.self, forKey: .issuedAt)
        currency = try container.decode(BillingCurrency.self, forKey: .currency)
        amountDueCents = try container.decode(Int.self, forKey: .amountDueCents)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        supersedesInvoiceID = try container.decodeIfPresent(BillingInvoiceID.self, forKey: .supersedesInvoiceID)
        supersededByInvoiceID = try container.decodeIfPresent(BillingInvoiceID.self, forKey: .supersededByInvoiceID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(guardianID, forKey: .guardianID)
        try container.encodeIfPresent(termID, forKey: .termID)
        try container.encode(learnerIDs, forKey: .learnerIDs)
        try container.encode(invoiceNumber, forKey: .invoiceNumber)
        try container.encode(version, forKey: .version)
        try container.encode(schoolYearLabel, forKey: .schoolYearLabel)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encode(currency, forKey: .currency)
        try container.encode(amountDueCents, forKey: .amountDueCents)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(supersedesInvoiceID, forKey: .supersedesInvoiceID)
        try container.encodeIfPresent(supersededByInvoiceID, forKey: .supersededByInvoiceID)
        try container.encode(createdAt, forKey: .createdAt)
    }

    public func displayStatus(payments: [BillingPayment]) -> BillingInvoiceDisplayStatus {
        if supersededByInvoiceID != nil { return .superseded }
        switch paymentProgress(payments: payments) {
        case .unpaid: return .issued
        case .partiallyPaid: return .partiallyPaid
        case .paid: return .paid
        case .noPaymentRequired: return .noPaymentRequired
        }
    }

    public func paymentProgress(payments: [BillingPayment]) -> BillingPaymentProgress {
        if amountDueCents == 0 { return .noPaymentRequired }
        let paid = paidCents(payments: payments)
        if paid >= amountDueCents { return .paid }
        if paid > 0 { return .partiallyPaid }
        return .unpaid
    }

    public func paidCents(payments: [BillingPayment]) -> Int {
        payments
            .filter { $0.invoiceID == id }
            .reduce(0) { $0 + $1.amountCents }
    }

    public func outstandingCents(payments: [BillingPayment]) -> Int {
        max(0, amountDueCents - paidCents(payments: payments))
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
    public let settlementStatus: BillingLineItemSettlementStatus
    public let sortOrder: Int

    /// Compatibility bridge for callers that still use the original boolean.
    public var isPaid: Bool { settlementStatus == .paid }
    public var isWaived: Bool { settlementStatus == .waived }

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
        settlementStatus: BillingLineItemSettlementStatus? = nil,
        sortOrder: Int = 0
    ) {
        let resolvedStatus = settlementStatus
            ?? (includedInAmountDue ? .unpaid : .paid)
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
        self.includedInAmountDue = resolvedStatus.contributesToAmountDue
        self.settlementStatus = resolvedStatus
        self.sortOrder = sortOrder
    }

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
        isPaid: Bool,
        sortOrder: Int = 0
    ) {
        self.init(
            id: id,
            invoiceID: invoiceID,
            studentID: studentID,
            enrollmentID: enrollmentID,
            kind: kind,
            title: title,
            detail: detail,
            quantity: quantity,
            unitAmountCents: unitAmountCents,
            amountCents: amountCents,
            settlementStatus: isPaid ? .paid : .unpaid,
            sortOrder: sortOrder
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case invoiceID
        case studentID
        case enrollmentID
        case kind
        case title
        case detail
        case quantity
        case unitAmountCents
        case amountCents
        case includedInAmountDue
        case settlementStatus
        case sortOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(BillingInvoiceLineItemID.self, forKey: .id)
        invoiceID = try container.decode(BillingInvoiceID.self, forKey: .invoiceID)
        studentID = try container.decodeIfPresent(StudentID.self, forKey: .studentID)
        enrollmentID = try container.decodeIfPresent(EnrollmentID.self, forKey: .enrollmentID)
        kind = try container.decode(BillingLineItemKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        quantity = try container.decode(Int.self, forKey: .quantity)
        unitAmountCents = try container.decode(Int.self, forKey: .unitAmountCents)
        amountCents = try container.decode(Int.self, forKey: .amountCents)
        let legacyIncluded = try container.decodeIfPresent(
            Bool.self,
            forKey: .includedInAmountDue
        ) ?? true
        settlementStatus = try container.decodeIfPresent(
            BillingLineItemSettlementStatus.self,
            forKey: .settlementStatus
        ) ?? (legacyIncluded ? .unpaid : .paid)
        includedInAmountDue = settlementStatus.contributesToAmountDue
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(invoiceID, forKey: .invoiceID)
        try container.encodeIfPresent(studentID, forKey: .studentID)
        try container.encodeIfPresent(enrollmentID, forKey: .enrollmentID)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unitAmountCents, forKey: .unitAmountCents)
        try container.encode(amountCents, forKey: .amountCents)
        try container.encode(includedInAmountDue, forKey: .includedInAmountDue)
        try container.encode(settlementStatus, forKey: .settlementStatus)
        try container.encode(sortOrder, forKey: .sortOrder)
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
    public let language: BillingArtifactLanguage?

    public init(
        id: BillingArtifactID = BillingArtifactID(),
        invoiceID: BillingInvoiceID,
        paymentID: BillingPaymentID? = nil,
        kind: BillingArtifactKind,
        storagePath: String = "",
        mimeType: String = "image/png",
        generatedAt: Date = Date(),
        language: BillingArtifactLanguage = .bilingual
    ) {
        self.id = id
        self.invoiceID = invoiceID
        self.paymentID = paymentID
        self.kind = kind
        self.storagePath = storagePath
        self.mimeType = mimeType
        self.generatedAt = generatedAt
        self.language = language
    }

    public var resolvedLanguage: BillingArtifactLanguage {
        language ?? BillingArtifactLanguage.inferred(from: storagePath)
    }
}

public struct BillingArtifactUpload: Equatable, Sendable {
    public let artifact: BillingArtifact
    public let pngData: Data

    public init(artifact: BillingArtifact, pngData: Data) {
        self.artifact = artifact
        self.pngData = pngData
    }
}
