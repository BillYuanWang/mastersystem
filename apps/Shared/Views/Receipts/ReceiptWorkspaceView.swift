#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

enum ReceiptCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case cny = "CNY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usd: "美元 USD"
        case .cny: "人民币 CNY"
        }
    }

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

struct ReceiptLineItem: Equatable {
    let title: String
    let amount: Decimal
}

struct ReceiptDocument: Equatable {
    let receiptNumber: String
    let issuedOn: Date
    let guardianName: String
    let guardianEmail: String?
    let guardianPhone: String?
    let learnerName: String
    let currency: ReceiptCurrency
    let items: [ReceiptLineItem]
    let paymentMethod: String
    let note: String

    var total: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.amount }
    }
}

private struct ReceiptEditableItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var amountText: String

    init(id: UUID = UUID(), title: String = "", amountText: String = "") {
        self.id = id
        self.title = title
        self.amountText = amountText
    }
}

private struct GeneratedReceipt {
    let document: ReceiptDocument
    let data: Data
    let url: URL
}

private enum ReceiptWorkspaceError: LocalizedError {
    case missingFamily
    case missingLearner
    case missingReceiptNumber
    case missingLineItems
    case incompleteLineItem
    case invalidAmount(String)
    case imageRenderingFailed

    var errorDescription: String? {
        switch self {
        case .missingFamily: "请选择监护人。"
        case .missingLearner: "请选择学员。"
        case .missingReceiptNumber: "请输入收据编号。"
        case .missingLineItems: "请至少填写一个收费项目。"
        case .incompleteLineItem: "每个收费项目都需要填写名称和金额。"
        case .invalidAmount(let value): "金额“\(value)”格式不正确。"
        case .imageRenderingFailed: "PNG 收据生成失败，请重试。"
        }
    }
}

@MainActor
struct ReceiptWorkspaceView: View {
    let model: AppModel

    @State private var selectedGuardianID: GuardianID?
    @State private var selectedStudentID: StudentID?
    @State private var receiptNumber = Self.makeReceiptNumber()
    @State private var issuedOn = Date()
    @State private var currency = ReceiptCurrency.usd
    @State private var items = [ReceiptEditableItem(title: "学费", amountText: "")]
    @State private var paymentMethod = ""
    @State private var note = ""
    @State private var generatedReceipt: GeneratedReceipt?
    @State private var isGenerating = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)

            GeometryReader { proxy in
                let editorWidth = min(520, max(400, proxy.size.width * 0.36))
                HStack(spacing: 0) {
                    editor(theme: theme)
                        .frame(width: editorWidth)

                    Rectangle().fill(theme.separator).frame(width: 1)

                    ReceiptPreviewPane(document: previewDocument)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .onChange(of: model.guardians.map(\.id), initial: true) { _, _ in
            chooseInitialFamily()
        }
        .onChange(of: model.students.map { "\($0.id):\($0.guardianID)" }, initial: true) { _, _ in
            chooseInitialFamily()
        }
        .onChange(of: selectedGuardianID) { _, _ in
            chooseLearnerForSelectedFamily()
        }
        .onChange(of: draftFingerprint) { _, _ in
            generatedReceipt = nil
            statusMessage = nil
        }
        .alert(
            "无法完成",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func header(theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            MDSectionTitle(chinese: "收据")

            if let statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .mdFont(.compact)
                    .foregroundStyle(theme.success)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: openReceiptFolder) {
                Image(systemName: "folder")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("打开 MD Desk Docs")

            if let generatedReceipt {
                Button {
                    copyToClipboard(generatedReceipt)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("复制 PNG，可直接粘贴到微信")

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([generatedReceipt.url])
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("在 Finder 中显示")
            }

            Button(action: generateAndSave) {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "photo.badge.arrow.down")
                    }
                    Text("生成并保存")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isGenerating)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func editor(theme: MDTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                formSection("收据对象", theme: theme) {
                    formRow("监护人") {
                        Picker("监护人", selection: $selectedGuardianID) {
                            Text("选择监护人").tag(Optional<GuardianID>.none)
                            ForEach(sortedGuardians) { guardian in
                                Text(guardian.displayName).tag(Optional(guardian.id))
                            }
                        }
                        .labelsHidden()
                    }

                    formRow("学员") {
                        Picker("学员", selection: $selectedStudentID) {
                            Text("选择学员").tag(Optional<StudentID>.none)
                            ForEach(studentsForSelectedFamily) { student in
                                Text(student.isActive ? student.displayName : "\(student.displayName)（停用）")
                                    .tag(Optional(student.id))
                            }
                        }
                        .labelsHidden()
                        .disabled(studentsForSelectedFamily.isEmpty)
                    }
                }

                formSection("收据信息", theme: theme) {
                    formRow("编号") {
                        TextField("收据编号", text: $receiptNumber)
                            .textFieldStyle(.roundedBorder)
                    }

                    formRow("日期") {
                        DatePicker(
                            "日期",
                            selection: $issuedOn,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                    }

                    formRow("币种") {
                        Picker("币种", selection: $currency) {
                            ForEach(ReceiptCurrency.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                    }

                    formRow("支付方式") {
                        TextField("例如：Zelle、支票、现金", text: $paymentMethod)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                formSection("收费项目", theme: theme) {
                    HStack(spacing: 8) {
                        Text("项目")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("金额")
                            .frame(width: 112, alignment: .leading)
                        Color.clear.frame(width: 30, height: 1)
                    }
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)

                    ForEach($items) { $item in
                        HStack(spacing: 8) {
                            TextField("收费项目", text: $item.title)
                                .textFieldStyle(.roundedBorder)
                            TextField("0.00", text: $item.amountText)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                                .frame(width: 112)
                            Button {
                                removeItem(item.id)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(MDIconButtonStyle())
                            .disabled(items.count == 1)
                            .help("删除收费项目")
                        }
                    }

                    Button {
                        items.append(ReceiptEditableItem())
                    } label: {
                        Label("添加项目", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(items.count >= 8)
                }

                formSection("备注", theme: theme) {
                    TextEditor(text: $note)
                        .mdFont(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(minHeight: 76)
                        .background(theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: MDMetrics.radius)
                                .stroke(theme.separator, lineWidth: 1)
                        }
                }
            }
            .padding(18)
        }
        .background(theme.surface)
    }

    private func formSection<Content: View>(
        _ title: String,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)
            content()
        }
    }

    private func formRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .mdFont(.body)
                .frame(width: 64, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sortedGuardians: [Guardian] {
        model.guardians.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var studentsForSelectedFamily: [Student] {
        guard let selectedGuardianID else { return [] }
        return model.students
            .filter { $0.guardianID == selectedGuardianID }
            .sorted {
                if $0.isActive != $1.isActive { return $0.isActive }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
    }

    private var selectedGuardian: Guardian? {
        guard let selectedGuardianID else { return nil }
        return model.guardians.first { $0.id == selectedGuardianID }
    }

    private var selectedStudent: Student? {
        guard let selectedStudentID else { return nil }
        return model.students.first { $0.id == selectedStudentID }
    }

    private var previewDocument: ReceiptDocument {
        ReceiptDocument(
            receiptNumber: receiptNumber.trimmed.nilIfEmpty ?? "—",
            issuedOn: issuedOn,
            guardianName: selectedGuardian?.displayName ?? "请选择监护人",
            guardianEmail: selectedGuardian?.email,
            guardianPhone: selectedGuardian?.phone,
            learnerName: selectedStudent?.displayName ?? "请选择学员",
            currency: currency,
            items: previewLineItems,
            paymentMethod: paymentMethod.trimmed,
            note: note.trimmed
        )
    }

    private var previewLineItems: [ReceiptLineItem] {
        let parsed = items.compactMap { item -> ReceiptLineItem? in
            let title = item.title.trimmed
            guard !title.isEmpty || !item.amountText.trimmed.isEmpty else { return nil }
            return ReceiptLineItem(
                title: title.nilIfEmpty ?? "收费项目",
                amount: Self.parseAmount(item.amountText) ?? .zero
            )
        }
        return parsed.isEmpty ? [ReceiptLineItem(title: "收费项目", amount: .zero)] : parsed
    }

    private var draftFingerprint: String {
        let itemValue = items.map { "\($0.id.uuidString)|\($0.title)|\($0.amountText)" }.joined(separator: "|")
        return [
            selectedGuardianID?.description ?? "",
            selectedStudentID?.description ?? "",
            receiptNumber,
            String(issuedOn.timeIntervalSinceReferenceDate),
            currency.rawValue,
            itemValue,
            paymentMethod,
            note,
        ].joined(separator: "¦")
    }

    private func chooseInitialFamily() {
        if selectedGuardian == nil {
            selectedGuardianID = sortedGuardians.first(where: { guardian in
                model.students.contains { $0.guardianID == guardian.id }
            })?.id ?? sortedGuardians.first?.id
        }
        chooseLearnerForSelectedFamily()
    }

    private func chooseLearnerForSelectedFamily() {
        let validIDs = Set(studentsForSelectedFamily.map(\.id))
        if let selectedStudentID, validIDs.contains(selectedStudentID) { return }
        selectedStudentID = studentsForSelectedFamily.first?.id
    }

    private func removeItem(_ id: UUID) {
        guard items.count > 1 else { return }
        items.removeAll { $0.id == id }
    }

    private func generateAndSave() {
        isGenerating = true
        errorMessage = nil
        statusMessage = nil

        Task { @MainActor in
            await Task.yield()
            defer { isGenerating = false }
            do {
                let document = try validatedDocument()
                let data = try ReceiptPNGRenderer.render(document)
                let store = try ReceiptFileStore.documents()
                let destination = try store.savePNG(
                    data,
                    learnerName: document.learnerName,
                    filenameStem: "收据-\(Self.dateText(document.issuedOn))-\(document.receiptNumber)"
                )
                generatedReceipt = GeneratedReceipt(
                    document: document,
                    data: data,
                    url: destination
                )
                statusMessage = "已保存到 \(document.learnerName) 文件夹"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatedDocument() throws -> ReceiptDocument {
        guard let guardian = selectedGuardian else { throw ReceiptWorkspaceError.missingFamily }
        guard let student = selectedStudent,
              student.guardianID == guardian.id else {
            throw ReceiptWorkspaceError.missingLearner
        }
        let number = receiptNumber.trimmed
        guard !number.isEmpty else { throw ReceiptWorkspaceError.missingReceiptNumber }

        let enteredItems = items.filter {
            !$0.title.trimmed.isEmpty || !$0.amountText.trimmed.isEmpty
        }
        guard !enteredItems.isEmpty else { throw ReceiptWorkspaceError.missingLineItems }
        let lineItems = try enteredItems.map { item in
            let title = item.title.trimmed
            let amountText = item.amountText.trimmed
            guard !title.isEmpty, !amountText.isEmpty else {
                throw ReceiptWorkspaceError.incompleteLineItem
            }
            guard let amount = Self.parseAmount(amountText) else {
                throw ReceiptWorkspaceError.invalidAmount(amountText)
            }
            return ReceiptLineItem(title: title, amount: amount)
        }

        return ReceiptDocument(
            receiptNumber: number,
            issuedOn: issuedOn,
            guardianName: guardian.displayName,
            guardianEmail: guardian.email,
            guardianPhone: guardian.phone,
            learnerName: student.displayName,
            currency: currency,
            items: lineItems,
            paymentMethod: paymentMethod.trimmed,
            note: note.trimmed
        )
    }

    private func copyToClipboard(_ receipt: GeneratedReceipt) {
        do {
            try ReceiptClipboard.copyPNG(receipt.data)
            statusMessage = "PNG 已复制"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openReceiptFolder() {
        do {
            let store = try ReceiptFileStore.documents()
            let directory = try store.prepareRootDirectory()
            NSWorkspace.shared.open(directory)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func parseAmount(_ text: String) -> Decimal? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "USD", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "CNY", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func makeReceiptNumber(now: Date = Date()) -> String {
        let day = dateText(now).replacingOccurrences(of: "-", with: "")
        let suffix = UUID().uuidString.prefix(4).uppercased()
        return "MD-\(day)-\(suffix)"
    }

    fileprivate static func dateText(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
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
            throw ReceiptWorkspaceError.imageRenderingFailed
        }
        return data
    }
}

private struct ReceiptPreviewPane: View {
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
            divider
                .padding(.vertical, 22)
            recipientDetails
            lineItems
                .padding(.top, 28)
            total
                .padding(.top, 14)
            paymentDetails
                .padding(.top, 24)
            Spacer(minLength: 22)
            footer
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 46)
        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.12))
        .background(Color.white)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            MasterDanceLogoView()
                .frame(width: 66, height: 66)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("MASTER DANCE")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                Text("佳美舞蹈")
                    .font(.system(size: 17, weight: .semibold))
                Text("Starton EDU Irvine, Inc. & Master Dance")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text("收据")
                    .font(.system(size: 28, weight: .bold))
                Text("RECEIPT")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
                receiptMeta("编号", value: document.receiptNumber)
                receiptMeta("日期", value: ReceiptWorkspaceView.dateText(document.issuedOn))
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(red: 0.12, green: 0.13, blue: 0.14))
            .frame(height: 2)
    }

    private var recipientDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow("监护人", value: document.guardianName)
            detailRow("学员", value: document.learnerName)
            if let contact = contactText {
                detailRow("联系方式", value: contact)
            }
        }
    }

    private var lineItems: some View {
        VStack(spacing: 0) {
            HStack {
                Text("收费项目")
                Spacer()
                Text("金额 · \(document.currency.rawValue)")
            }
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(height: 38)
            .foregroundStyle(Color.white)
            .background(Color(red: 0.12, green: 0.13, blue: 0.14))

            ForEach(Array(document.items.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 16) {
                    Text(item.title)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(document.currency.formatted(item.amount))
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .frame(width: 170, alignment: .trailing)
                }
                .font(.system(size: 15))
                .padding(.horizontal, 14)
                .frame(minHeight: document.items.count > 5 ? 36 : 43)
                .background(index.isMultiple(of: 2) ? Color.white : Color.black.opacity(0.035))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
                }
            }
        }
        .overlay {
            Rectangle()
                .stroke(Color.black.opacity(0.16), lineWidth: 1)
        }
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Spacer()
            Text("合计")
                .font(.system(size: 16, weight: .semibold))
            Text(document.currency.formatted(document.total))
                .font(.system(size: 24, weight: .bold, design: .monospaced))
        }
    }

    private var paymentDetails: some View {
        VStack(alignment: .leading, spacing: 9) {
            if !document.paymentMethod.isEmpty {
                detailRow("支付方式", value: document.paymentMethod)
            }
            if !document.note.isEmpty {
                detailRow("备注", value: document.note, lineLimit: 4)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.black.opacity(0.14)).frame(height: 1)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("感谢您选择佳美舞蹈")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Thank you for choosing Master Dance.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.gray)
                }
                Spacer()
                Text("STARTON EDU IRVINE, INC.")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.gray)
            }
        }
    }

    private var contactText: String? {
        let parts = [document.guardianEmail, document.guardianPhone]
            .compactMap { $0?.trimmed.nilIfEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }

    private func receiptMeta(_ label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(Color.gray)
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
    }

    private func detailRow(_ label: String, value: String, lineLimit: Int = 2) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .lineLimit(lineLimit)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
