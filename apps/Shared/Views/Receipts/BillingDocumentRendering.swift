#if os(macOS)
import AppKit
import SwiftUI

enum ReceiptCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case cny = "CNY"

    var id: String { rawValue }

    func formatted(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = rawValue
        formatter.locale = Locale(identifier: self == .usd ? "en_US" : "zh_CN")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(rawValue) \(NSDecimalNumber(decimal: amount).stringValue)"
    }
}

enum ReceiptDocumentKind: Equatable {
    case invoice
    case receipt

    var chineseTitle: String { self == .invoice ? "账单" : "收据" }
    var englishTitle: String { self == .invoice ? "INVOICE" : "RECEIPT" }
}

struct ReceiptLineItem: Equatable {
    let title: String
    let amount: Decimal
    let learnerName: String?
    let detail: String?
    let includedInAmountDue: Bool

    init(
        title: String,
        amount: Decimal,
        learnerName: String? = nil,
        detail: String? = nil,
        includedInAmountDue: Bool = true
    ) {
        self.title = title
        self.amount = amount
        self.learnerName = learnerName
        self.detail = detail
        self.includedInAmountDue = includedInAmountDue
    }
}

struct ReceiptDocument: Equatable {
    let kind: ReceiptDocumentKind
    let receiptNumber: String
    let version: Int
    let schoolYearLabel: String
    let issuedOn: Date
    let guardianName: String
    let guardianEmail: String?
    let guardianPhone: String?
    let learnerName: String
    let currency: ReceiptCurrency
    let items: [ReceiptLineItem]
    let paymentMethod: String
    let paymentAmount: Decimal?
    let processingFee: Decimal
    let outstandingAfterPayment: Decimal?
    let note: String

    init(
        kind: ReceiptDocumentKind,
        receiptNumber: String,
        version: Int,
        schoolYearLabel: String,
        issuedOn: Date,
        guardianName: String,
        guardianEmail: String?,
        guardianPhone: String?,
        learnerName: String,
        currency: ReceiptCurrency = .usd,
        items: [ReceiptLineItem],
        paymentMethod: String = "",
        paymentAmount: Decimal? = nil,
        processingFee: Decimal = .zero,
        outstandingAfterPayment: Decimal? = nil,
        note: String = ""
    ) {
        self.kind = kind
        self.receiptNumber = receiptNumber
        self.version = version
        self.schoolYearLabel = schoolYearLabel
        self.issuedOn = issuedOn
        self.guardianName = guardianName
        self.guardianEmail = guardianEmail
        self.guardianPhone = guardianPhone
        self.learnerName = learnerName
        self.currency = currency
        self.items = items
        self.paymentMethod = paymentMethod
        self.paymentAmount = paymentAmount
        self.processingFee = processingFee
        self.outstandingAfterPayment = outstandingAfterPayment
        self.note = note
    }

    init(
        receiptNumber: String,
        issuedOn: Date,
        guardianName: String,
        guardianEmail: String?,
        guardianPhone: String?,
        learnerName: String,
        currency: ReceiptCurrency,
        items: [ReceiptLineItem],
        paymentMethod: String,
        note: String
    ) {
        self.init(
            kind: .receipt,
            receiptNumber: receiptNumber,
            version: 1,
            schoolYearLabel: "",
            issuedOn: issuedOn,
            guardianName: guardianName,
            guardianEmail: guardianEmail,
            guardianPhone: guardianPhone,
            learnerName: learnerName,
            currency: currency,
            items: items,
            paymentMethod: paymentMethod,
            note: note
        )
    }

    var total: Decimal {
        items
            .filter(\.includedInAmountDue)
            .reduce(Decimal.zero) { $0 + $1.amount }
    }
}

enum ReceiptRenderingError: LocalizedError {
    case imageRenderingFailed

    var errorDescription: String? { "PNG 账单生成失败，请重试。" }
}

@MainActor
enum ReceiptPNGRenderer {
    static let canvasSize = CGSize(width: 720, height: 960)

    static func render(_ document: ReceiptDocument) throws -> Data {
        let renderer = ImageRenderer(
            content: ReceiptDocumentView(document: document)
                .frame(width: canvasSize.width, height: canvasSize.height)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(
            width: canvasSize.width,
            height: canvasSize.height
        )
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ReceiptRenderingError.imageRenderingFailed
        }
        return data
    }
}

struct ReceiptPreviewPane: View {
    let document: ReceiptDocument

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 48
            let verticalPadding: CGFloat = 36
            let scale = min(
                1,
                max(
                    0.35,
                    min(
                        (proxy.size.width - horizontalPadding) / ReceiptPNGRenderer.canvasSize.width,
                        (proxy.size.height - verticalPadding) / ReceiptPNGRenderer.canvasSize.height
                    )
                )
            )
            let scaledWidth = ReceiptPNGRenderer.canvasSize.width * scale
            let scaledHeight = ReceiptPNGRenderer.canvasSize.height * scale

            VStack {
                Spacer(minLength: 12)
                HStack {
                    Spacer(minLength: 12)
                    ReceiptDocumentView(document: document)
                        .frame(
                            width: ReceiptPNGRenderer.canvasSize.width,
                            height: ReceiptPNGRenderer.canvasSize.height
                        )
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.38 : 0.15),
                            radius: 18,
                            y: 8
                        )
                    Spacer(minLength: 12)
                }
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.subtleSurface)
        }
    }
}

private struct ReceiptDocumentView: View {
    let document: ReceiptDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider.padding(.vertical, 18)
            recipientDetails
            lineItems.padding(.top, 22)
            totals.padding(.top, 13)
            paymentDetails.padding(.top, 17)
            Spacer(minLength: 16)
            footer
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 40)
        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.12))
        .background(Color.white)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            MasterDanceLogoView()
                .frame(width: 62, height: 62)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("MASTER DANCE")
                    .font(.system(size: 23, weight: .bold, design: .monospaced))
                Text("佳美舞蹈")
                    .font(.system(size: 16, weight: .semibold))
                Text("Starton EDU Irvine, Inc. & Master Dance")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(document.kind.chineseTitle)
                    .font(.system(size: 27, weight: .bold))
                Text(document.kind.englishTitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
                meta("编号", value: document.receiptNumber + " · v\(document.version)")
                meta("日期", value: billingDateText(document.issuedOn))
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(red: 0.12, green: 0.13, blue: 0.14))
            .frame(height: 2)
    }

    private var recipientDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("监护人", value: document.guardianName)
            detailRow("学员", value: document.learnerName)
            if !document.schoolYearLabel.isEmpty {
                detailRow("学年", value: document.schoolYearLabel)
            }
            if let contact = contactText {
                detailRow("联系方式", value: contact)
            }
        }
    }

    private var lineItems: some View {
        let count = max(1, document.items.count)
        let rowHeight = max(28, min(42, 360 / CGFloat(count)))
        let itemFont = max(10, min(14, rowHeight * 0.34))
        return VStack(spacing: 0) {
            HStack {
                Text("收费项目")
                Spacer()
                Text("金额 · \(document.currency.rawValue)")
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 13)
            .frame(height: 35)
            .foregroundStyle(Color.white)
            .background(Color(red: 0.12, green: 0.13, blue: 0.14))

            ForEach(Array(document.items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text(item.title)
                                .lineLimit(1)
                            if !item.includedInAmountDue {
                                Text("已付 · 仅展示")
                                    .font(.system(size: max(8, itemFont - 3), weight: .semibold))
                                    .foregroundStyle(Color.gray)
                            }
                        }
                        let detail = [item.learnerName, item.detail]
                            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
                            .joined(separator: " · ")
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: max(8, itemFont - 3)))
                                .foregroundStyle(Color.gray)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(document.currency.formatted(item.amount))
                        .font(.system(size: itemFont, weight: .medium, design: .monospaced))
                        .foregroundStyle(
                            item.includedInAmountDue
                                ? Color(red: 0.10, green: 0.11, blue: 0.12)
                                : Color.gray
                        )
                        .frame(width: 160, alignment: .trailing)
                }
                .font(.system(size: itemFont))
                .padding(.horizontal, 13)
                .frame(height: rowHeight)
                .background(index.isMultiple(of: 2) ? Color.white : Color.black.opacity(0.035))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
                }
            }
        }
        .overlay(Rectangle().stroke(Color.black.opacity(0.16), lineWidth: 1))
    }

    private var totals: some View {
        VStack(alignment: .trailing, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Spacer()
                Text(document.kind == .invoice ? "本次应付" : "账单金额")
                    .font(.system(size: 15, weight: .semibold))
                Text(document.currency.formatted(document.total))
                    .font(.system(size: 23, weight: .bold, design: .monospaced))
            }
            if let paymentAmount = document.paymentAmount {
                totalRow("本次付款", amount: paymentAmount)
                if document.processingFee > 0 {
                    totalRow("银行卡手续费 3.5%", amount: document.processingFee)
                    totalRow("实际收取", amount: paymentAmount + document.processingFee, strong: true)
                }
                if let outstanding = document.outstandingAfterPayment {
                    totalRow("付款后待付", amount: outstanding, strong: outstanding > 0)
                }
            }
        }
    }

    private var paymentDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !document.paymentMethod.isEmpty {
                detailRow("支付方式", value: document.paymentMethod)
            }
            if !document.note.isEmpty {
                detailRow("备注", value: document.note, lineLimit: 3)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 9) {
            Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("感谢您选择佳美舞蹈")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Thank you for choosing Master Dance.")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                Text("STARTON EDU IRVINE, INC.")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
            }
        }
    }

    private var contactText: String? {
        let parts = [document.guardianEmail, document.guardianPhone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private func meta(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(Color.gray)
            Text(value).lineLimit(1)
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
    }

    private func detailRow(_ label: String, value: String, lineLimit: Int = 2) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.gray)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func totalRow(_ label: String, amount: Decimal, strong: Bool = false) -> some View {
        HStack(spacing: 16) {
            Spacer()
            Text(label)
            Text(document.currency.formatted(amount))
                .font(.system(size: strong ? 14 : 12, weight: strong ? .bold : .medium, design: .monospaced))
                .frame(width: 145, alignment: .trailing)
        }
        .font(.system(size: 12, weight: strong ? .semibold : .regular))
    }
}

func billingDateText(_ date: Date) -> String {
    let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(
        format: "%04d-%02d-%02d",
        components.year ?? 0,
        components.month ?? 0,
        components.day ?? 0
    )
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
