#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

private enum ReceiptBrand {
    static let legalName = "Starton EDU Irvine, Inc."
    static let schoolName = "Master Dance"
    static let taxID = "92-1606689"
    static let publicAddress = "2 Jenner St., Suite 180, Irvine, CA 92618"
}

private enum ReceiptPalette {
    static let ink = Color(red: 42 / 255, green: 31 / 255, blue: 36 / 255)
    static let muted = Color(red: 118 / 255, green: 94 / 255, blue: 104 / 255)
    static let accent = Color(red: 230 / 255, green: 92 / 255, blue: 151 / 255)
    static let accentDeep = Color(red: 194 / 255, green: 45 / 255, blue: 111 / 255)
    static let accentSoft = Color(red: 250 / 255, green: 216 / 255, blue: 231 / 255)
    static let paper = Color(red: 255 / 255, green: 251 / 255, blue: 253 / 255)
    static let paid = Color(red: 36 / 255, green: 126 / 255, blue: 92 / 255)
    static let unpaid = Color(red: 188 / 255, green: 58 / 255, blue: 86 / 255)
    static let waived = Color(red: 163 / 255, green: 65 / 255, blue: 132 / 255)
}

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

    func title(language: BillingArtifactLanguage) -> String {
        switch (self, language) {
        case (.invoice, .bilingual): "账单 / INVOICE"
        case (.receipt, .bilingual): "付款收据 / PAYMENT RECEIPT"
        case (.invoice, .english): "INVOICE"
        case (.receipt, .english): "PAYMENT RECEIPT"
        }
    }
}

enum ReceiptLineItemSection: Int, CaseIterable, Identifiable, Equatable {
    case fullTerm
    case perSession
    case miscellaneous
    case adjustments

    var id: Int { rawValue }

    func title(language: BillingArtifactLanguage) -> String {
        switch (self, language) {
        case (.fullTerm, .bilingual): "整期报名课程 / FULL-TERM ENROLLMENT"
        case (.perSession, .bilingual): "按次报名课程 / PER-SESSION ENROLLMENT"
        case (.miscellaneous, .bilingual): "其他收费 / OTHER CHARGES"
        case (.adjustments, .bilingual): "折扣与结余 / DISCOUNTS & CREDITS"
        case (.fullTerm, .english): "FULL-TERM ENROLLMENT"
        case (.perSession, .english): "PER-SESSION ENROLLMENT"
        case (.miscellaneous, .english): "OTHER CHARGES"
        case (.adjustments, .english): "DISCOUNTS & CREDITS"
        }
    }
}

struct ReceiptLineItem: Equatable {
    let kind: BillingLineItemKind
    let section: ReceiptLineItemSection
    let title: String
    let englishTitle: String
    let amount: Decimal
    let learnerName: String?
    let detail: String?
    let englishDetail: String?
    let settlementStatus: BillingLineItemSettlementStatus

    init(
        kind: BillingLineItemKind = .manual,
        section: ReceiptLineItemSection = .miscellaneous,
        title: String,
        englishTitle: String? = nil,
        amount: Decimal,
        learnerName: String? = nil,
        detail: String? = nil,
        englishDetail: String? = nil,
        settlementStatus: BillingLineItemSettlementStatus = .unpaid
    ) {
        self.kind = kind
        self.section = section
        self.title = title
        self.englishTitle = englishTitle ?? title
        self.amount = amount
        self.learnerName = learnerName
        self.detail = detail
        self.englishDetail = englishDetail
        self.settlementStatus = settlementStatus
    }

    init(
        kind: BillingLineItemKind = .manual,
        section: ReceiptLineItemSection = .miscellaneous,
        title: String,
        englishTitle: String? = nil,
        amount: Decimal,
        learnerName: String? = nil,
        detail: String? = nil,
        englishDetail: String? = nil,
        isPaid: Bool
    ) {
        self.init(
            kind: kind,
            section: section,
            title: title,
            englishTitle: englishTitle,
            amount: amount,
            learnerName: learnerName,
            detail: detail,
            englishDetail: englishDetail,
            settlementStatus: isPaid ? .paid : .unpaid
        )
    }

    func displayedTitle(language: BillingArtifactLanguage) -> String {
        language == .english ? englishTitle : title
    }

    func displayedDetail(language: BillingArtifactLanguage) -> String? {
        language == .english ? (englishDetail ?? detail) : detail
    }
}

struct ReceiptDocument: Equatable {
    let language: BillingArtifactLanguage
    let kind: ReceiptDocumentKind
    let receiptNumber: String
    let version: Int
    let termLabel: String
    let issuedOn: Date
    let guardianName: String
    let guardianEmail: String?
    let guardianPhone: String?
    let learnerName: String
    let currency: ReceiptCurrency
    let items: [ReceiptLineItem]
    let paymentMethod: String
    let paymentMethodEnglish: String
    let paymentAmount: Decimal?
    let processingFee: Decimal
    let outstandingAfterPayment: Decimal?
    let note: String

    init(
        language: BillingArtifactLanguage = .bilingual,
        kind: ReceiptDocumentKind,
        receiptNumber: String,
        version: Int,
        termLabel: String,
        issuedOn: Date,
        guardianName: String,
        guardianEmail: String?,
        guardianPhone: String?,
        learnerName: String,
        currency: ReceiptCurrency = .usd,
        items: [ReceiptLineItem],
        paymentMethod: String = "",
        paymentMethodEnglish: String = "",
        paymentAmount: Decimal? = nil,
        processingFee: Decimal = .zero,
        outstandingAfterPayment: Decimal? = nil,
        note: String = ""
    ) {
        self.language = language
        self.kind = kind
        self.receiptNumber = receiptNumber
        self.version = version
        self.termLabel = termLabel
        self.issuedOn = issuedOn
        self.guardianName = guardianName
        self.guardianEmail = guardianEmail
        self.guardianPhone = guardianPhone
        self.learnerName = learnerName
        self.currency = currency
        self.items = items
        self.paymentMethod = paymentMethod
        self.paymentMethodEnglish = paymentMethodEnglish
        self.paymentAmount = paymentAmount
        self.processingFee = processingFee
        self.outstandingAfterPayment = outstandingAfterPayment
        self.note = note
    }

    var chargeSubtotal: Decimal {
        items
            .filter { $0.section != .adjustments }
            .reduce(.zero) { $0 + $1.amount }
    }

    var paidItemTotal: Decimal {
        items
            .filter { $0.section != .adjustments && $0.settlementStatus == .paid }
            .reduce(.zero) { $0 + $1.amount }
    }

    var waivedItemTotal: Decimal {
        items
            .filter { $0.section != .adjustments && $0.settlementStatus == .waived }
            .reduce(.zero) { $0 + $1.amount }
    }

    var adjustmentTotal: Decimal {
        items
            .filter { $0.section == .adjustments }
            .reduce(.zero) { $0 + $1.amount }
    }

    var currentDue: Decimal {
        if kind == .receipt, let outstandingAfterPayment {
            return max(.zero, outstandingAfterPayment)
        }
        return max(
            .zero,
            items
                .filter { $0.settlementStatus.contributesToAmountDue }
                .reduce(.zero) { $0 + $1.amount }
        )
    }

    var groupedItems: [(section: ReceiptLineItemSection, items: [ReceiptLineItem])] {
        ReceiptLineItemSection.allCases.compactMap { section in
            let matches = items.filter { $0.section == section }
            return matches.isEmpty ? nil : (section, matches)
        }
    }

    func translated(to language: BillingArtifactLanguage) -> ReceiptDocument {
        ReceiptDocument(
            language: language,
            kind: kind,
            receiptNumber: receiptNumber,
            version: version,
            termLabel: termLabel,
            issuedOn: issuedOn,
            guardianName: guardianName,
            guardianEmail: guardianEmail,
            guardianPhone: guardianPhone,
            learnerName: learnerName,
            currency: currency,
            items: items,
            paymentMethod: paymentMethod,
            paymentMethodEnglish: paymentMethodEnglish,
            paymentAmount: paymentAmount,
            processingFee: processingFee,
            outstandingAfterPayment: outstandingAfterPayment,
            note: note
        )
    }
}

enum ReceiptRenderingError: LocalizedError {
    case imageRenderingFailed

    var errorDescription: String? { "PNG 账单生成失败，请重试。" }
}

@MainActor
enum ReceiptPNGRenderer {
    static let canvasWidth: CGFloat = 440

    static func canvasSize(for document: ReceiptDocument) -> CGSize {
        let itemHeight = CGFloat(document.items.count) * 54
        let sectionHeight = CGFloat(document.groupedItems.count) * 34
        let noteHeight: CGFloat = document.note.isEmpty ? 0 : 68
        let paymentHeight: CGFloat = document.paymentAmount == nil ? 0 : 92
        return CGSize(
            width: canvasWidth,
            height: max(760, 440 + itemHeight + sectionHeight + noteHeight + paymentHeight)
        )
    }

    static func render(_ document: ReceiptDocument) throws -> Data {
        let size = canvasSize(for: document)
        let renderer = ImageRenderer(
            content: ReceiptDocumentView(document: document)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ReceiptRenderingError.imageRenderingFailed
        }
        return data
    }
}

struct ReceiptPairPreviewPane: View {
    let bilingual: ReceiptDocument
    let english: ReceiptDocument

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        GeometryReader { proxy in
            let gap: CGFloat = 18
            let totalWidth = ReceiptPNGRenderer.canvasWidth * 2 + gap
            let scale = min(1, max(0.48, (proxy.size.width - 40) / totalWidth))
            ScrollView([.vertical, .horizontal]) {
                HStack(alignment: .top, spacing: gap) {
                    preview(document: bilingual, label: "主中文双语")
                    preview(document: english, label: "ENGLISH")
                }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: totalWidth * scale,
                    height: max(
                        ReceiptPNGRenderer.canvasSize(for: bilingual).height,
                        ReceiptPNGRenderer.canvasSize(for: english).height
                    ) * scale + 34 * scale,
                    alignment: .topLeading
                )
                .padding(20)
            }
            .background(theme.subtleSurface)
        }
    }

    private func preview(document: ReceiptDocument, label: String) -> some View {
        let size = ReceiptPNGRenderer.canvasSize(for: document)
        return VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            ReceiptDocumentView(document: document)
                .frame(width: size.width, height: size.height)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.38 : 0.14),
                    radius: 16,
                    y: 7
                )
        }
    }
}

struct ReceiptPreviewPane: View {
    let document: ReceiptDocument

    var body: some View {
        ReceiptPairPreviewPane(
            bilingual: document.translated(to: .bilingual),
            english: document.translated(to: .english)
        )
    }
}

private struct ReceiptDocumentView: View {
    let document: ReceiptDocument

    private var isEnglish: Bool { document.language == .english }

    var body: some View {
        ZStack {
            ReceiptPalette.paper
            ReceiptWaterSleeveWatermark()
                .frame(width: 390, height: 720)
                .offset(x: 50, y: 50)
            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle()
                    .fill(ReceiptPalette.accent)
                    .frame(height: 2)
                    .padding(.vertical, 14)
                recipientDetails
                lineItems.padding(.top, 18)
                totals.padding(.top, 16)
                paymentDetails.padding(.top, 14)
                Spacer(minLength: 20)
                footer
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
        }
        .foregroundStyle(ReceiptPalette.ink)
        .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            MasterDanceLogoView(.full)
                .frame(width: 225, height: 55, alignment: .leading)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(document.kind.title(language: document.language))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(ReceiptPalette.accentDeep)
                    Text(ReceiptBrand.legalName)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(ReceiptPalette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    meta(isEnglish ? "NO." : "编号 / NO.", document.receiptNumber + " · V\(document.version)")
                    meta(isEnglish ? "DATE" : "日期 / DATE", billingDateText(document.issuedOn))
                }
            }
        }
    }

    private var recipientDetails: some View {
        VStack(alignment: .leading, spacing: 7) {
            detailRow(isEnglish ? "GUARDIAN" : "监护人 / GUARDIAN", value: document.guardianName)
            detailRow(isEnglish ? "STUDENT(S)" : "学员 / STUDENT", value: document.learnerName)
            detailRow(isEnglish ? "TERM" : "学期 / TERM", value: document.termLabel)
            if let contact = contactText {
                detailRow(isEnglish ? "CONTACT" : "联系方式 / CONTACT", value: contact)
            }
        }
    }

    private var lineItems: some View {
        VStack(spacing: 0) {
            ForEach(document.groupedItems, id: \.section) { group in
                lineItemSectionHeader(group.section)
                ForEach(Array(group.items.enumerated()), id: \.offset) { index, item in
                    lineItemRow(item, striped: !index.isMultiple(of: 2))
                }
            }
        }
    }

    private func lineItemSectionHeader(_ section: ReceiptLineItemSection) -> some View {
        HStack(spacing: 8) {
            Text(section.title(language: document.language))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 238, alignment: .leading)
            Text(isEnglish ? "AMOUNT · STATUS" : "金额 · 状态")
                .frame(width: 118, alignment: .trailing)
        }
        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
        .foregroundStyle(ReceiptPalette.accentDeep)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(ReceiptPalette.accentSoft.opacity(0.72))
    }

    private func lineItemRow(_ item: ReceiptLineItem, striped: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayedTitle(language: document.language))
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                let detail = itemDetail(item)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 8.5, weight: .regular))
                        .foregroundStyle(ReceiptPalette.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: 248, alignment: .leading)
            VStack(alignment: .trailing, spacing: 3) {
                Text(document.currency.formatted(item.amount))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                statusLabel(item)
            }
            .frame(width: 108, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 54)
        .background(striped ? ReceiptPalette.accentSoft.opacity(0.19) : ReceiptPalette.paper.opacity(0.82))
        .overlay(alignment: .bottom) {
            Rectangle().fill(ReceiptPalette.accentSoft.opacity(0.78)).frame(height: 0.7)
        }
    }

    @ViewBuilder
    private func statusLabel(_ item: ReceiptLineItem) -> some View {
        if item.section == .adjustments || item.amount < 0 {
            Text(isEnglish ? "ADJUSTMENT" : "调整 / ADJUSTMENT")
                .foregroundStyle(ReceiptPalette.accentDeep)
        } else if resolvedSettlementStatus(item) == .waived {
            Label(isEnglish ? "WAIVED" : "免付 / WAIVED", systemImage: "gift.fill")
                .foregroundStyle(ReceiptPalette.waived)
        } else if resolvedSettlementStatus(item) == .paid {
            Label(isEnglish ? "PAID" : "已付 / PAID", systemImage: "checkmark.square.fill")
                .foregroundStyle(ReceiptPalette.paid)
        } else {
            Label(isEnglish ? "UNPAID" : "未付 / UNPAID", systemImage: "square")
                .foregroundStyle(ReceiptPalette.unpaid)
        }
    }

    private var totals: some View {
        VStack(alignment: .trailing, spacing: 7) {
            summaryRow(isEnglish ? "Semester charges" : "本学期收费", amount: document.chargeSubtotal)
            if document.paidItemTotal > 0 {
                summaryRow(isEnglish ? "Previously paid items" : "其中已付项目", amount: -document.paidItemTotal)
            }
            if document.waivedItemTotal > 0 {
                summaryRow(isEnglish ? "Waived items" : "其中免付项目", amount: -document.waivedItemTotal)
            }
            if document.adjustmentTotal != 0 {
                summaryRow(isEnglish ? "Discounts and credits" : "折扣与结余", amount: document.adjustmentTotal)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Spacer()
                Text(isEnglish ? "AMOUNT DUE NOW" : "本次应付 / AMOUNT DUE NOW")
                    .font(.system(size: 12, weight: .bold))
                Text(document.currency.formatted(document.currentDue))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(ReceiptPalette.accentDeep)
            }
            .padding(.top, 3)
        }
    }

    private var paymentDetails: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let paymentAmount = document.paymentAmount {
                Rectangle().fill(ReceiptPalette.accentSoft).frame(height: 1)
                detailRow(isEnglish ? "TOTAL PAID" : "累计付款 / TOTAL PAID", value: document.currency.formatted(paymentAmount))
                if document.processingFee > 0 {
                    detailRow(
                        isEnglish ? "TOTAL CARD FEES" : "累计银行卡手续费 / TOTAL CARD FEES",
                        value: document.currency.formatted(document.processingFee)
                    )
                }
                if let outstanding = document.outstandingAfterPayment {
                    detailRow(
                        isEnglish ? "BALANCE" : "付款后待付 / BALANCE",
                        value: document.currency.formatted(outstanding)
                    )
                }
            }
            if !document.paymentMethod.isEmpty {
                detailRow(
                    isEnglish ? "METHOD" : "支付方式 / METHOD",
                    value: isEnglish
                        ? (document.paymentMethodEnglish.nilIfEmpty ?? document.paymentMethod)
                        : document.paymentMethod
                )
            }
            if !document.note.isEmpty {
                detailRow(isEnglish ? "NOTE" : "备注 / NOTE", value: document.note, lineLimit: 4)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Rectangle().fill(ReceiptPalette.accentSoft).frame(height: 1)
            HStack(alignment: .top, spacing: 14) {
                Text(isEnglish ? "Thank you for choosing Master Dance." : "感谢您选择佳美舞蹈 / Thank you for choosing Master Dance.")
                    .font(.system(size: 8.5, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ReceiptBrand.legalName.uppercased())
                    Text("EIN \(ReceiptBrand.taxID)")
                    Text("\(ReceiptBrand.schoolName) · \(ReceiptBrand.publicAddress)")
                }
                .font(.system(size: 6.8, weight: .medium, design: .monospaced))
                .foregroundStyle(ReceiptPalette.muted)
                .multilineTextAlignment(.trailing)
            }
        }
    }

    private var contactText: String? {
        let parts = [document.guardianEmail, document.guardianPhone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func resolvedSettlementStatus(
        _ item: ReceiptLineItem
    ) -> BillingLineItemSettlementStatus {
        if item.settlementStatus == .waived {
            return .waived
        }
        if document.kind == .receipt, document.outstandingAfterPayment == 0 {
            return .paid
        }
        return item.settlementStatus
    }

    private func itemDetail(_ item: ReceiptLineItem) -> String {
        [item.learnerName, item.displayedDetail(language: document.language)]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
            .joined(separator: " · ")
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label).foregroundStyle(ReceiptPalette.muted)
            Text(value).lineLimit(1)
        }
        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
    }

    private func detailRow(_ label: String, value: String, lineLimit: Int = 2) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(ReceiptPalette.muted)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryRow(_ label: String, amount: Decimal) -> some View {
        HStack(spacing: 12) {
            Spacer()
            Text(label)
            Text(document.currency.formatted(amount))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .frame(width: 108, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .regular))
        .foregroundStyle(ReceiptPalette.muted)
    }
}

private struct ReceiptWaterSleeveWatermark: View {
    var body: some View {
        if let image = MasterDanceImageResource.image(named: "ReceiptWaterSleeveWatermark") {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(ReceiptPalette.accentDeep)
                .opacity(0.055)
        }
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
