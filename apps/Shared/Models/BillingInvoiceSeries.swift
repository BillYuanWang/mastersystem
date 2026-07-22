import Foundation
import MasterDanceCore

struct BillingInvoiceSeriesKey: Hashable, Sendable {
    let guardianID: GuardianID
    let termID: TermID?
}

struct BillingInvoiceSeries: Identifiable, Sendable {
    let key: BillingInvoiceSeriesKey
    let invoices: [BillingInvoice]

    var id: String {
        key.guardianID.description + "-" + (key.termID?.description ?? "no-term")
    }

    var latestInvoice: BillingInvoice {
        invoices.first { $0.supersededByInvoiceID == nil } ?? invoices[0]
    }
}

enum BillingInvoiceSeriesResolver {
    static func series(from invoices: [BillingInvoice]) -> [BillingInvoiceSeries] {
        Dictionary(grouping: invoices) {
            BillingInvoiceSeriesKey(guardianID: $0.guardianID, termID: $0.termID)
        }
        .map { key, values in
            BillingInvoiceSeries(key: key, invoices: sortedVersions(values))
        }
        .sorted { lhs, rhs in
            let left = lhs.latestInvoice
            let right = rhs.latestInvoice
            if left.issuedAt != right.issuedAt { return left.issuedAt > right.issuedAt }
            return lhs.id < rhs.id
        }
    }

    static func series(
        guardianID: GuardianID,
        termID: TermID?,
        in invoices: [BillingInvoice]
    ) -> BillingInvoiceSeries? {
        series(from: invoices).first {
            $0.key.guardianID == guardianID && $0.key.termID == termID
        }
    }

    static func series(
        containing invoice: BillingInvoice,
        in invoices: [BillingInvoice]
    ) -> BillingInvoiceSeries? {
        series(guardianID: invoice.guardianID, termID: invoice.termID, in: invoices)
    }

    private static func sortedVersions(_ invoices: [BillingInvoice]) -> [BillingInvoice] {
        invoices.sorted { lhs, rhs in
            if lhs.version != rhs.version { return lhs.version > rhs.version }
            if lhs.issuedAt != rhs.issuedAt { return lhs.issuedAt > rhs.issuedAt }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
