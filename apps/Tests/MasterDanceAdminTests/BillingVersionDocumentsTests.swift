import AppKit
import Foundation
import MasterDanceCore
import SwiftUI
import Testing
@testable import MasterDanceAdmin

@Suite("Billing version documents")
struct BillingVersionDocumentsTests {
    @Test("one invoice version presents its invoice pair and latest cumulative receipt pair")
    func resolvesLatestReceiptPair() throws {
        let invoiceID = BillingInvoiceID()
        let firstPayment = BillingPayment(
            invoiceID: invoiceID,
            amountCents: 4_000,
            processingFeeCents: 0,
            method: .zelle,
            receivedAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let finalPayment = BillingPayment(
            invoiceID: invoiceID,
            amountCents: 6_000,
            processingFeeCents: 0,
            method: .check,
            receivedAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let bilingualInvoice = artifact(
            invoiceID: invoiceID,
            kind: .invoice,
            language: .bilingual,
            generatedAt: 50
        )
        let englishInvoice = artifact(
            invoiceID: invoiceID,
            kind: .invoice,
            language: .english,
            generatedAt: 50
        )
        let firstReceipt = artifact(
            invoiceID: invoiceID,
            paymentID: firstPayment.id,
            kind: .receipt,
            language: .bilingual,
            generatedAt: 100
        )
        let finalBilingualReceipt = artifact(
            invoiceID: invoiceID,
            paymentID: finalPayment.id,
            kind: .receipt,
            language: .bilingual,
            generatedAt: 200
        )
        let finalEnglishReceipt = artifact(
            invoiceID: invoiceID,
            paymentID: finalPayment.id,
            kind: .receipt,
            language: .english,
            generatedAt: 200
        )

        let documents = BillingVersionDocuments(
            invoiceID: invoiceID,
            payments: [finalPayment, firstPayment],
            artifacts: [
                firstReceipt,
                finalEnglishReceipt,
                bilingualInvoice,
                finalBilingualReceipt,
                englishInvoice,
            ]
        )

        #expect(documents.invoice(language: .bilingual) == bilingualInvoice)
        #expect(documents.invoice(language: .english) == englishInvoice)
        #expect(documents.latestPaymentID == finalPayment.id)
        #expect(documents.receipt(language: .bilingual) == finalBilingualReceipt)
        #expect(documents.receipt(language: .english) == finalEnglishReceipt)
        #expect(documents.receipt(language: .bilingual) != firstReceipt)
    }

    @Test("an unpaid invoice keeps both receipt slots empty")
    func unpaidReceiptSlotsAreEmpty() {
        let invoiceID = BillingInvoiceID()
        let documents = BillingVersionDocuments(
            invoiceID: invoiceID,
            payments: [],
            artifacts: [
                artifact(
                    invoiceID: invoiceID,
                    kind: .invoice,
                    language: .bilingual,
                    generatedAt: 50
                )
            ]
        )

        #expect(documents.latestPaymentID == nil)
        #expect(documents.receipt(language: .bilingual) == nil)
        #expect(documents.receipt(language: .english) == nil)
    }

    @Test("the version document grid renders as two stable columns")
    @MainActor
    func rendersVersionDocumentGrid() throws {
        let invoice = BillingInvoice(
            guardianID: GuardianID(),
            termID: TermID(),
            invoiceNumber: "MD-2026-0088",
            version: 2,
            schoolYearLabel: "2026 秋季学期",
            amountDueCents: 10_000
        )
        let payment = BillingPayment(
            invoiceID: invoice.id,
            amountCents: 4_000,
            processingFeeCents: 0,
            method: .zelle,
            receivedAt: Date(timeIntervalSince1970: 200),
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let artifacts = BillingArtifactLanguage.allCases.flatMap { language in
            [
                artifact(
                    invoiceID: invoice.id,
                    kind: .invoice,
                    language: language,
                    generatedAt: 100
                ),
                artifact(
                    invoiceID: invoice.id,
                    paymentID: payment.id,
                    kind: .receipt,
                    language: language,
                    generatedAt: 200
                ),
            ]
        }
        let size = CGSize(width: 900, height: 170)
        let renderer = ImageRenderer(
            content: BillingVersionDocumentGrid(
                invoice: invoice,
                payments: [payment],
                artifacts: artifacts,
                copyArtifact: { _ in }
            )
            .padding(18)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiff))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        #expect(bitmap.pixelsWide == Int(size.width * 2))
        #expect(bitmap.pixelsHigh == Int(size.height * 2))
        if let path = ProcessInfo.processInfo.environment["MD_BILLING_GRID_SNAPSHOT_PATH"] {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    private func artifact(
        invoiceID: BillingInvoiceID,
        paymentID: BillingPaymentID? = nil,
        kind: BillingArtifactKind,
        language: BillingArtifactLanguage,
        generatedAt: TimeInterval
    ) -> BillingArtifact {
        BillingArtifact(
            invoiceID: invoiceID,
            paymentID: paymentID,
            kind: kind,
            storagePath: "billing/\(UUID().uuidString)-\(language.storageSuffix).png",
            generatedAt: Date(timeIntervalSince1970: generatedAt),
            language: language
        )
    }
}
