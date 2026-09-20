#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct BillingVersionDocumentGrid: View {
    let invoice: BillingInvoice
    let payments: [BillingPayment]
    let artifacts: [BillingArtifact]
    let copyArtifact: (BillingArtifact) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let documents = BillingVersionDocuments(
            invoiceID: invoice.id,
            payments: payments,
            artifacts: artifacts
        )
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                invoiceCell(
                    language: .bilingual,
                    artifact: documents.invoice(language: .bilingual)
                )
                invoiceCell(
                    language: .english,
                    artifact: documents.invoice(language: .english)
                )
            }
            HStack(spacing: 10) {
                receiptCell(
                    language: .bilingual,
                    artifact: documents.receipt(language: .bilingual)
                )
                receiptCell(
                    language: .english,
                    artifact: documents.receipt(language: .english)
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func invoiceCell(
        language: BillingArtifactLanguage,
        artifact: BillingArtifact?
    ) -> some View {
        documentCell(
            title: "V\(invoice.version) 账单 · \(languageTitle(language))",
            subtitle: artifact.map { billingDateText($0.generatedAt) } ?? "账单文件缺失",
            symbol: "doc.text.image",
            titleColor: theme.primaryText,
            artifact: artifact
        )
    }

    private func receiptCell(
        language: BillingArtifactLanguage,
        artifact: BillingArtifact?
    ) -> some View {
        let progress = invoice.paymentProgress(payments: payments)
        return documentCell(
            title: "V\(invoice.version) 付款收据 · \(languageTitle(language))",
            subtitle: receiptSubtitle(progress: progress, artifact: artifact),
            symbol: receiptSymbol(progress),
            titleColor: receiptColor(progress),
            artifact: artifact
        )
    }

    private func documentCell(
        title: String,
        subtitle: String,
        symbol: String,
        titleColor: Color,
        artifact: BillingArtifact?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(titleColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .mdFont(.bodyStrong)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if let artifact {
                Button {
                    copyArtifact(artifact)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("复制 \(title) PNG")
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(theme.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(theme.faintSeparator, lineWidth: 1)
        }
    }

    private var theme: MDTheme { MDTheme(scheme: colorScheme) }

    private func languageTitle(_ language: BillingArtifactLanguage) -> String {
        language == .bilingual ? "中英" : "英文"
    }

    private func receiptSubtitle(
        progress: BillingPaymentProgress,
        artifact: BillingArtifact?
    ) -> String {
        if let artifact {
            return "\(receiptProgressTitle(progress)) · \(billingDateText(artifact.generatedAt))"
        }
        switch progress {
        case .unpaid:
            return "未付款，尚未生成收据"
        case .partiallyPaid, .paid:
            return "\(receiptProgressTitle(progress))，收据文件缺失"
        case .noPaymentRequired:
            return "免付项目，无需生成付款收据"
        }
    }

    private func receiptProgressTitle(_ progress: BillingPaymentProgress) -> String {
        switch progress {
        case .unpaid: "未付款"
        case .partiallyPaid: "部分付款"
        case .paid: "已付清"
        case .noPaymentRequired: "无需付款"
        }
    }

    private func receiptSymbol(_ progress: BillingPaymentProgress) -> String {
        switch progress {
        case .unpaid: "exclamationmark.circle"
        case .partiallyPaid: "circle.lefthalf.filled"
        case .paid: "checkmark.circle.fill"
        case .noPaymentRequired: "gift.fill"
        }
    }

    private func receiptColor(_ progress: BillingPaymentProgress) -> Color {
        switch progress {
        case .unpaid:
            return colorScheme == .dark
                ? theme.danger
                : Color(red: 0.76, green: 0.16, blue: 0.23)
        case .partiallyPaid:
            return colorScheme == .dark
                ? theme.warning
                : Color(red: 0.72, green: 0.35, blue: 0.02)
        case .paid:
            return theme.success
        case .noPaymentRequired:
            return theme.accent
        }
    }
}
#endif
