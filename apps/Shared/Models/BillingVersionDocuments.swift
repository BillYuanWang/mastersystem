import Foundation
import MasterDanceCore

struct BillingVersionDocuments: Equatable {
    let invoiceArtifacts: [BillingArtifactLanguage: BillingArtifact]
    let receiptArtifacts: [BillingArtifactLanguage: BillingArtifact]
    let latestPaymentID: BillingPaymentID?

    init(
        invoiceID: BillingInvoiceID,
        payments: [BillingPayment],
        artifacts: [BillingArtifact]
    ) {
        let scopedArtifacts = artifacts.filter { $0.invoiceID == invoiceID }
        invoiceArtifacts = Self.newestByLanguage(
            scopedArtifacts.filter { $0.kind == .invoice }
        )

        let latestPayment = payments
            .filter { $0.invoiceID == invoiceID }
            .max(by: Self.paymentPrecedes)
        latestPaymentID = latestPayment?.id
        receiptArtifacts = Self.newestByLanguage(
            scopedArtifacts.filter {
                $0.kind == .receipt && $0.paymentID == latestPayment?.id
            }
        )
    }

    func invoice(language: BillingArtifactLanguage) -> BillingArtifact? {
        invoiceArtifacts[language]
    }

    func receipt(language: BillingArtifactLanguage) -> BillingArtifact? {
        receiptArtifacts[language]
    }

    private static func newestByLanguage(
        _ artifacts: [BillingArtifact]
    ) -> [BillingArtifactLanguage: BillingArtifact] {
        Dictionary(grouping: artifacts, by: \.resolvedLanguage).compactMapValues { matches in
            matches.max(by: artifactPrecedes)
        }
    }

    private static func paymentPrecedes(_ lhs: BillingPayment, _ rhs: BillingPayment) -> Bool {
        if lhs.receivedAt != rhs.receivedAt { return lhs.receivedAt < rhs.receivedAt }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.description < rhs.id.description
    }

    private static func artifactPrecedes(_ lhs: BillingArtifact, _ rhs: BillingArtifact) -> Bool {
        if lhs.generatedAt != rhs.generatedAt { return lhs.generatedAt < rhs.generatedAt }
        return lhs.id.description < rhs.id.description
    }
}
