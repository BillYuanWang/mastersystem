#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

private enum BillingWorkspaceMode: String, CaseIterable, Identifiable {
    case compose
    case history

    var id: String { rawValue }
    var title: String { self == .compose ? "新建账单" : "账单记录" }
}

private enum BillingWorkspaceError: LocalizedError {
    case missingFamily
    case missingTerm
    case missingLearners
    case missingInvoiceNumber
    case missingItems
    case missingEnrollmentCharges
    case incompleteItem
    case invalidAmount(String)
    case negativeTotal
    case invalidPayment
    case invoiceSeriesChanged
    case itemOutsideLearnerScope

    var errorDescription: String? {
        switch self {
        case .missingFamily: "请选择监护人。"
        case .missingTerm: "请选择账单所属学期。"
        case .missingLearners: "请至少勾选一名学员。"
        case .missingInvoiceNumber: "请输入账单编号。"
        case .missingItems: "请至少添加一个收费项目。"
        case .missingEnrollmentCharges: "账单必须列出所选学员在本学期的全部报名课程。请先点击“载入所选学员课程”。"
        case .incompleteItem: "每个收费项目都需要名称和正确金额。"
        case .invalidAmount(let value): "金额“\(value)”格式不正确。"
        case .negativeTotal: "本次应付合计不能小于 0。"
        case .invalidPayment: "付款金额必须大于 0，且不能超过待付金额。"
        case .invoiceSeriesChanged: "这份账单已经出现更新版本，请返回账单记录后基于最新版继续。"
        case .itemOutsideLearnerScope: "收费项目中的学员不属于本账单，请重新选择。"
        }
    }
}

private extension BillingLineItemSettlementStatus {
    var title: String {
        switch self {
        case .unpaid: "未付"
        case .paid: "已付"
        case .waived: "免付"
        }
    }

    var helpText: String {
        switch self {
        case .unpaid: "未付：计入本次应付"
        case .paid: "已付：保留原价，不再计入本次应付"
        case .waived: "免付：保留原价，记录减免但无需付款"
        }
    }
}

private struct BillingDraftLine: Identifiable, Equatable {
    let id: UUID
    var studentID: StudentID?
    var enrollmentID: EnrollmentID?
    var kind: BillingLineItemKind
    var title: String
    var detail: String
    var quantity: Int
    var unitAmountCents: Int
    var amountText: String
    var settlementStatus: BillingLineItemSettlementStatus

    init(
        id: UUID = UUID(),
        studentID: StudentID? = nil,
        enrollmentID: EnrollmentID? = nil,
        kind: BillingLineItemKind = .manual,
        title: String = "",
        detail: String = "",
        quantity: Int = 1,
        unitAmountCents: Int = 0,
        amountText: String = "",
        settlementStatus: BillingLineItemSettlementStatus = .unpaid
    ) {
        self.id = id
        self.studentID = studentID
        self.enrollmentID = enrollmentID
        self.kind = kind
        self.title = title
        self.detail = detail
        self.quantity = quantity
        self.unitAmountCents = unitAmountCents
        self.amountText = amountText
        self.settlementStatus = settlementStatus
    }
}

private struct GeneratedBillingFile {
    let data: Data
    let url: URL
}

private struct GeneratedBillingFiles {
    let bilingual: GeneratedBillingFile
    let english: GeneratedBillingFile
}

@MainActor
struct ReceiptWorkspaceView: View {
    let model: AppModel

    @State private var mode = BillingWorkspaceMode.compose
    @State private var correctionInvoice: BillingInvoice?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "账单与收据", english: "BILLING")
                Picker("页面", selection: $mode) {
                    ForEach(BillingWorkspaceMode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Spacer()

                Button(action: openBillingFolder) {
                    Image(systemName: "folder")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("打开 MD Desk Docs")
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            switch mode {
            case .compose:
                BillingComposerView(
                    model: model,
                    correctionInvoice: correctionInvoice,
                    didIssue: {
                        correctionInvoice = nil
                        mode = .history
                    }
                )
                .id(correctionInvoice?.id.description ?? "new")
            case .history:
                BillingHistoryView(
                    model: model,
                    createNewVersion: { invoice in
                        correctionInvoice = invoice
                        mode = .compose
                    }
                )
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
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

    private func openBillingFolder() {
        do {
            let store = try ReceiptFileStore.documents()
            NSWorkspace.shared.open(try store.prepareRootDirectory())
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
private struct BillingComposerView: View {
    let model: AppModel
    let correctionInvoice: BillingInvoice?
    let didIssue: () -> Void

    @State private var selectedGuardianID: GuardianID?
    @State private var selectedTermID: TermID?
    @State private var selectedLearnerIDs: Set<StudentID> = []
    @State private var revisionBaseInvoice: BillingInvoice?
    @State private var invoiceNumber = ""
    @State private var version = 1
    @State private var termLabel = ""
    @State private var issuedOn = Date()
    @State private var lines: [BillingDraftLine] = []
    @State private var note = ""
    @State private var generatedFiles: GeneratedBillingFiles?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isIssuing = false
    @State private var didConfigure = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        GeometryReader { proxy in
            let editorWidth = min(650, max(560, proxy.size.width * 0.46))
            HStack(spacing: 0) {
                editor(theme: theme)
                    .frame(width: editorWidth)

                Rectangle().fill(theme.separator).frame(width: 1)

                ReceiptPairPreviewPane(
                    bilingual: previewDocument.translated(to: .bilingual),
                    english: previewDocument.translated(to: .english)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { configureIfNeeded() }
        .onChange(of: selectedGuardianID) { _, _ in
            guard correctionInvoice == nil else { return }
            selectedLearnerIDs = Set(familyLearners.map(\.id))
            configureForSelectedSeries()
        }
        .onChange(of: selectedTermID) { _, termID in
            guard correctionInvoice == nil else { return }
            termLabel = termID.flatMap { model.term(id: $0) }?.name ?? ""
            configureForSelectedSeries()
        }
        .onChange(of: selectedLearnerIDs) { _, _ in
            guard correctionInvoice == nil else { return }
            configureForSelectedSeries()
        }
        .onChange(of: model.billingInvoices.map(\.id)) { _, _ in
            guard correctionInvoice == nil else { return }
            configureForSelectedSeries()
        }
        .alert(
            "无法签发",
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

    private func editor(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .mdFont(.compact)
                        .foregroundStyle(theme.success)
                        .lineLimit(1)
                } else if revisionBaseInvoice != nil {
                    Label("正在创建账单新版本", systemImage: "clock.arrow.circlepath")
                        .mdFont(.compact)
                        .foregroundStyle(theme.warning)
                }
                Spacer()

                if let generatedFiles {
                    Menu {
                        Button("复制主中文双语版") { copyPNG(generatedFiles.bilingual.data) }
                        Button("复制全英文版") { copyPNG(generatedFiles.english.data) }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .menuStyle(.borderlessButton)
                    .help("选择要复制的 PNG 版本")

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            generatedFiles.bilingual.url,
                            generatedFiles.english.url
                        ])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("在 Finder 中显示两份 PNG")
                }

                Button(action: issueInvoice) {
                    Label(revisionBaseInvoice == nil ? "签发账单" : "签发 V\(version)", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canIssue || isIssuing)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    familySection(theme: theme)
                    invoiceSection(theme: theme)
                    lineItemsSection(theme: theme)
                    noteSection(theme: theme)
                }
                .padding(18)
            }
        }
        .background(theme.surface)
    }

    private func familySection(theme: MDTheme) -> some View {
        formSection("账单对象", theme: theme) {
            formRow("监护人") {
                Picker("", selection: $selectedGuardianID) {
                    Text("选择监护人").tag(Optional<GuardianID>.none)
                    ForEach(sortedGuardians) { guardian in
                        Text(guardian.displayName).tag(Optional(guardian.id))
                    }
                }
                .labelsHidden()
                .disabled(correctionInvoice != nil)
            }
            formRow("账单学员") {
                VStack(alignment: .leading, spacing: 7) {
                    if familyLearners.isEmpty {
                        Text("暂无学员档案")
                            .mdFont(.body)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        HStack(spacing: 10) {
                            Text("已选 \(selectedLearnerIDs.count) / \(familyLearners.count)")
                                .mdFont(.compactStrong)
                                .foregroundStyle(selectedLearnerIDs.isEmpty ? theme.danger : theme.accent)
                            Spacer()
                            Button("全选") {
                                selectedLearnerIDs = Set(familyLearners.map(\.id))
                            }
                            .buttonStyle(.plain)
                            .disabled(correctionInvoice != nil)
                            Button("清空") {
                                selectedLearnerIDs.removeAll()
                            }
                            .buttonStyle(.plain)
                            .disabled(correctionInvoice != nil)
                        }

                        ForEach(familyLearners) { learner in
                            Toggle(isOn: learnerSelectionBinding(learner.id)) {
                                HStack(spacing: 7) {
                                    Text(learner.displayName)
                                        .mdFont(.bodyStrong)
                                    Text(learner.kind == .child ? "少儿" : "成人")
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(correctionInvoice != nil)
                        }
                    }
                }
            }
            formRow("学期") {
                Picker("", selection: $selectedTermID) {
                    Text("选择学期").tag(Optional<TermID>.none)
                    ForEach(model.terms) { term in
                        Text(term.name).tag(Optional(term.id))
                    }
                }
                .labelsHidden()
                .disabled(correctionInvoice != nil)
            }
        }
    }

    private func invoiceSection(theme: MDTheme) -> some View {
        formSection("账单资料", theme: theme) {
            formRow("编号") {
                HStack(spacing: 8) {
                    TextField("账单编号", text: $invoiceNumber)
                        .textFieldStyle(.roundedBorder)
                        .disabled(revisionBaseInvoice != nil)
                        .help(revisionBaseInvoice == nil ? "新账单主线编号" : "同一家庭与学期沿用原账单编号")
                    Text("V\(version)")
                        .mdFont(.monoStrong)
                        .foregroundStyle(theme.accent)
                }
            }
            formRow("账单学期") {
                Text(termLabel.nilIfEmpty ?? "请先选择学期")
                    .mdFont(.body)
                    .foregroundStyle(termLabel.isEmpty ? theme.secondaryText : theme.primaryText)
            }
            formRow("签发日期") {
                DatePicker("", selection: $issuedOn, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    private func lineItemsSection(theme: MDTheme) -> some View {
        formSection("收费项目", theme: theme) {
            HStack(spacing: 8) {
                Button {
                    generateFromEnrollments()
                } label: {
                    Label("载入所选学员课程", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .disabled(selectedGuardianID == nil || selectedTermID == nil || selectedLearnerIDs.isEmpty)

                Menu {
                    Button("注册费") { appendPreset(.registration) }
                    Button("上期结余（抵扣）") { appendPreset(.balanceCredit) }
                    Button("上期欠款") { appendPreset(.priorBalance) }
                    Button("其他项目") { appendPreset(.manual) }
                } label: {
                    Label("添加项目", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                Text("本次应付 $\(MoneyTextParser.dollars(from: amountDueCents))")
                    .mdFont(.monoStrong)
                    .foregroundStyle(amountDueCents < 0 ? theme.danger : theme.accent)
            }

            if lines.isEmpty {
                Text("选择监护人、学期和账单学员后，可载入所选学员的课程，也可手动添加项目。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            } else {
                HStack(spacing: 7) {
                    Text("学员").frame(width: 105, alignment: .leading)
                    Text("类别").frame(width: 70, alignment: .leading)
                    Text("项目").frame(maxWidth: .infinity, alignment: .leading)
                    Text("金额").frame(width: 92, alignment: .leading)
                    Text("状态").frame(width: 68)
                    Color.clear.frame(width: 28)
                }
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)

                ForEach($lines) { $line in
                    billingLineRow($line, theme: theme)
                }
            }
        }
    }

    private func billingLineRow(_ line: Binding<BillingDraftLine>, theme: MDTheme) -> some View {
        HStack(spacing: 7) {
            Picker("", selection: line.studentID) {
                Text("家庭").tag(Optional<StudentID>.none)
                ForEach(selectedLearners) { student in
                    Text(student.displayName).tag(Optional(student.id))
                }
            }
            .labelsHidden()
            .frame(width: 105)

            Text(sectionTitle(for: line.wrappedValue))
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                TextField("收费项目", text: line.title)
                    .textFieldStyle(.roundedBorder)
                if !line.wrappedValue.detail.isEmpty {
                    Text(line.wrappedValue.detail)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
            }

            TextField("0.00", text: line.amountText)
                .textFieldStyle(.roundedBorder)
                .monospacedDigit()
                .frame(width: 92)

            if receiptSection(for: line.wrappedValue) == .adjustments {
                Text("—")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 68)
                    .help("折扣与结余直接调整本次应付，不使用结算状态")
            } else {
                Picker("", selection: line.settlementStatus) {
                    ForEach(BillingLineItemSettlementStatus.allCases, id: \.rawValue) { status in
                        Text(status.title).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 68)
                .help(line.wrappedValue.settlementStatus.helpText)
            }

            Button {
                lines.removeAll { $0.id == line.wrappedValue.id }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("删除项目")
            .frame(width: 28)
        }
    }

    private func noteSection(theme: MDTheme) -> some View {
        formSection("备注", theme: theme) {
            TextEditor(text: $note)
                .mdFont(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .frame(minHeight: 72)
                .background(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
        }
    }

    private var sortedGuardians: [Guardian] {
        model.guardians.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private var selectedGuardian: Guardian? {
        selectedGuardianID.flatMap { model.guardian(id: $0) }
    }

    private var familyLearners: [Student] {
        guard let selectedGuardianID else { return [] }
        return model.students(for: selectedGuardianID)
    }

    private var selectedLearners: [Student] {
        familyLearners.filter { selectedLearnerIDs.contains($0.id) }
    }

    private var selectedLearnerIDList: [StudentID] {
        BillingInvoice.normalizedLearnerIDs(Array(selectedLearnerIDs))
    }

    private var selectedLearnerNames: String {
        selectedLearners.map(\.displayName).joined(separator: "、")
    }

    private func learnerSelectionBinding(_ learnerID: StudentID) -> Binding<Bool> {
        Binding(
            get: { selectedLearnerIDs.contains(learnerID) },
            set: { isSelected in
                if isSelected {
                    selectedLearnerIDs.insert(learnerID)
                } else {
                    selectedLearnerIDs.remove(learnerID)
                }
            }
        )
    }

    private var selectedInvoiceSeries: BillingInvoiceSeries? {
        guard let selectedGuardianID, let selectedTermID, !selectedLearnerIDs.isEmpty else { return nil }
        return BillingInvoiceSeriesResolver.series(
            guardianID: selectedGuardianID,
            termID: selectedTermID,
            learnerIDs: selectedLearnerIDList,
            in: model.billingInvoices
        )
    }

    private var selectedLearnerTermEnrollments: [Enrollment] {
        guard selectedGuardianID != nil, let selectedTermID else { return [] }
        return model.enrollments.filter {
            $0.termID == selectedTermID
                && $0.status == .active
                && selectedLearnerIDs.contains($0.studentID)
        }
    }

    private var includesEveryTermEnrollment: Bool {
        let includedEnrollmentIDs = Set(lines.compactMap(\.enrollmentID))
        return selectedLearnerTermEnrollments.allSatisfy {
            includedEnrollmentIDs.contains($0.id)
        }
    }

    private var lineItemsStayWithinLearnerScope: Bool {
        lines.allSatisfy { line in
            line.studentID.map(selectedLearnerIDs.contains) ?? true
        }
    }

    private var amountDueCents: Int {
        lines.reduce(0) { result, line in
            guard line.settlementStatus.contributesToAmountDue,
                  let cents = MoneyTextParser.cents(from: line.amountText) else { return result }
            return result + cents
        }
    }

    private var canIssue: Bool {
        selectedGuardianID != nil
            && selectedTermID != nil
            && !selectedLearnerIDs.isEmpty
            && !invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !termLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lines.isEmpty
            && lines.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && MoneyTextParser.cents(from: $0.amountText) != nil
            }
            && lineItemsStayWithinLearnerScope
            && amountDueCents >= 0
            && revisionBaseInvoice?.id == selectedInvoiceSeries?.latestInvoice.id
    }

    private var previewDocument: ReceiptDocument {
        ReceiptDocument(
            kind: .invoice,
            receiptNumber: invoiceNumber.nilIfEmpty ?? "—",
            version: version,
            termLabel: termLabel,
            issuedOn: issuedOn,
            guardianName: selectedGuardian?.displayName ?? "请选择监护人",
            guardianEmail: selectedGuardian?.email,
            guardianPhone: selectedGuardian?.phone,
            learnerName: selectedLearnerNames.nilIfEmpty ?? "请选择账单学员",
            items: previewReceiptItems,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var previewReceiptItems: [ReceiptLineItem] {
        let values = lines.compactMap { line -> ReceiptLineItem? in
            guard !line.title.isEmpty || !line.amountText.isEmpty else { return nil }
            return ReceiptLineItem(
                kind: line.kind,
                section: receiptSection(for: line),
                title: line.title.nilIfEmpty ?? "收费项目",
                englishTitle: englishBillingTitle(for: line),
                amount: decimal(cents: MoneyTextParser.cents(from: line.amountText) ?? 0),
                learnerName: line.studentID.flatMap { model.student(id: $0)?.displayName },
                detail: line.detail.nilIfEmpty,
                englishDetail: englishBillingDetail(for: line),
                settlementStatus: line.settlementStatus
            )
        }
        return values.isEmpty
            ? [ReceiptLineItem(title: "收费项目", englishTitle: "Charge", amount: .zero)]
            : values
    }

    private func receiptSection(for line: BillingDraftLine) -> ReceiptLineItemSection {
        switch line.kind {
        case .tuition:
            let mode = line.enrollmentID.flatMap { enrollmentID in
                model.enrollments.first { $0.id == enrollmentID }?.registrationMode
            }
            return mode == .perSession ? .perSession : .fullTerm
        case .trial:
            return .perSession
        case .discount, .balanceCredit:
            return .adjustments
        case .registration, .priorBalance, .manual:
            return .miscellaneous
        }
    }

    private func sectionTitle(for line: BillingDraftLine) -> String {
        switch receiptSection(for: line) {
        case .fullTerm: "整期"
        case .perSession: "按次"
        case .miscellaneous: "其他"
        case .adjustments: "优惠"
        }
    }

    private func englishBillingTitle(for line: BillingDraftLine) -> String {
        let courseName = line.enrollmentID.flatMap { enrollmentID in
            model.enrollments.first { $0.id == enrollmentID }
        }.flatMap { model.course(id: $0.courseID)?.name }
        switch line.kind {
        case .tuition:
            let label = receiptSection(for: line) == .perSession
                ? "Per-Session Tuition"
                : "Full-Term Tuition"
            return [courseName, label].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
        case .trial:
            return [courseName, "Trial Class Fee"].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
        case .registration:
            return "Annual Registration Fee"
        case .discount:
            return "Course Discount"
        case .balanceCredit:
            return "Prior Credit"
        case .priorBalance:
            return "Prior Balance"
        case .manual:
            return line.title.unicodeScalars.contains(where: { $0.value > 127 })
                ? "Additional Charge"
                : (line.title.nilIfEmpty ?? "Additional Charge")
        }
    }

    private func englishBillingDetail(for line: BillingDraftLine) -> String? {
        switch line.kind {
        case .tuition:
            guard line.quantity > 1, line.unitAmountCents != 0 else { return nil }
            return "\(line.quantity) sessions × $\(MoneyTextParser.dollars(from: line.unitAmountCents))"
        case .trial:
            return "Trial class fee"
        case .discount:
            return "Applied to course tuition"
        case .balanceCredit:
            return "Applied to the current amount due"
        case .priorBalance:
            return "Balance from a prior term"
        case .registration:
            return "Annual student registration"
        case .manual:
            return line.detail.unicodeScalars.contains(where: { $0.value > 127 })
                ? nil
                : line.detail.nilIfEmpty
        }
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        if let correctionInvoice {
            let latest = BillingInvoiceSeriesResolver.series(
                containing: correctionInvoice,
                in: model.billingInvoices
            )?.latestInvoice ?? correctionInvoice
            applyRevision(from: latest)
        } else {
            selectedGuardianID = sortedGuardians.first?.id
            selectedTermID = model.currentEnrollmentTerm?.id ?? model.terms.first?.id
            selectedLearnerIDs = Set(familyLearners.map(\.id))
            configureForSelectedSeries()
        }
    }

    private func configureForSelectedSeries() {
        generatedFiles = nil
        statusMessage = nil
        errorMessage = nil

        if let latest = selectedInvoiceSeries?.latestInvoice {
            applyRevision(from: latest, updateSelection: false)
            return
        }

        revisionBaseInvoice = nil
        invoiceNumber = Self.nextInvoiceNumber(from: model.billingInvoices)
        version = 1
        note = ""
        lines.removeAll()
        if let term = selectedTermID.flatMap({ model.term(id: $0) }) {
            termLabel = term.name
        } else {
            termLabel = ""
        }
    }

    private func applyRevision(from invoice: BillingInvoice, updateSelection: Bool = true) {
        revisionBaseInvoice = invoice
        let storedItems = model.billingItems(for: invoice.id)
        let itemLearnerIDs = Set(storedItems.compactMap(\.studentID))
        let invoiceLearnerIDs = Set(invoice.learnerIDs)
        if updateSelection {
            selectedGuardianID = invoice.guardianID
            selectedTermID = invoice.termID
        }
        selectedLearnerIDs = invoiceLearnerIDs.isEmpty ? itemLearnerIDs : invoiceLearnerIDs
        invoiceNumber = invoice.invoiceNumber
        version = invoice.version + 1
        termLabel = invoice.termID.flatMap(model.term(id:))?.name ?? invoice.schoolYearLabel
        note = invoice.notes ?? ""
        lines = storedItems.map(draftLine)
    }

    private func generateFromEnrollments() {
        guard selectedGuardianID != nil, selectedTermID != nil else { return }
        let manualLines = lines.filter { $0.enrollmentID == nil }
        let enrollments = selectedLearnerTermEnrollments
            .sorted { lhs, rhs in
                let leftStudent = model.student(id: lhs.studentID)?.displayName ?? ""
                let rightStudent = model.student(id: rhs.studentID)?.displayName ?? ""
                if leftStudent != rightStudent {
                    return leftStudent.localizedStandardCompare(rightStudent) == .orderedAscending
                }
                let leftCourse = model.course(id: lhs.courseID)?.name ?? ""
                let rightCourse = model.course(id: rhs.courseID)?.name ?? ""
                return leftCourse.localizedStandardCompare(rightCourse) == .orderedAscending
            }

        let enrollmentLines = enrollments.flatMap { enrollment -> [BillingDraftLine] in
            let estimate = model.billingEstimate(for: enrollment)
            let courseName = model.course(id: enrollment.courseID)?.name ?? "课程"
            guard let tuition = estimate.tuitionBeforeDiscountCents,
                  let unit = estimate.unitPriceCents else {
                return [
                    BillingDraftLine(
                        studentID: enrollment.studentID,
                        enrollmentID: enrollment.id,
                        kind: .tuition,
                        title: courseName + "（待定价）",
                        detail: "请先在报名页完成计费设置",
                        amountText: "0.00"
                    )
                ]
            }

            var result = [
                BillingDraftLine(
                    studentID: enrollment.studentID,
                    enrollmentID: enrollment.id,
                    kind: .tuition,
                    title: courseName + (enrollment.registrationMode == .perSession ? " 按次学费" : " 整期学费"),
                    detail: billingDetail(
                        enrollment: enrollment,
                        sessionCount: estimate.normalSessionCount,
                        unitPriceCents: unit
                    ),
                    quantity: max(1, estimate.normalSessionCount),
                    unitAmountCents: unit,
                    amountText: MoneyTextParser.dollars(from: tuition)
                )
            ]
            if estimate.trialFeeCents > 0 {
                result.append(
                    BillingDraftLine(
                        studentID: enrollment.studentID,
                        enrollmentID: enrollment.id,
                        kind: .trial,
                        title: courseName + " 试课费",
                        detail: "试课费用单独计算",
                        unitAmountCents: estimate.trialFeeCents,
                        amountText: MoneyTextParser.dollars(from: estimate.trialFeeCents)
                    )
                )
            }
            if estimate.discountCents > 0 {
                result.append(
                    BillingDraftLine(
                        studentID: enrollment.studentID,
                        enrollmentID: enrollment.id,
                        kind: .discount,
                        title: enrollment.discountName ?? "课程折扣",
                        detail: courseName,
                        unitAmountCents: -estimate.discountCents,
                        amountText: MoneyTextParser.dollars(from: -estimate.discountCents)
                    )
                )
            }
            return result
        }
        lines = enrollmentLines + manualLines
        generatedFiles = nil
        statusMessage = enrollments.isEmpty ? "所选学员本学期暂无报名" : "已载入所选学员全部课程"
    }

    private func billingDetail(
        enrollment: Enrollment,
        sessionCount: Int,
        unitPriceCents: Int
    ) -> String {
        let calculation = "\(sessionCount) 次 × $\(MoneyTextParser.dollars(from: unitPriceCents))"
        guard enrollment.registrationMode == .perSession else {
            return "整期报名 · " + calculation
        }
        let dates = model.sessions(for: enrollment)
            .filter { $0.status != .cancelled }
            .map { $0.startsAt.formatted(.dateTime.month().day()) }
            .joined(separator: "、")
        return dates.isEmpty
            ? "按次报名 · " + calculation
            : "按次报名 · " + calculation + " · " + dates
    }

    private func appendPreset(_ kind: BillingLineItemKind) {
        let firstMinorID = selectedLearners.first(where: { $0.kind == .child })?.id
        let onlyLearnerID = selectedLearners.count == 1 ? selectedLearners[0].id : nil
        let line: BillingDraftLine
        switch kind {
        case .registration:
            line = BillingDraftLine(
                studentID: firstMinorID,
                kind: .registration,
                title: "年度注册费"
            )
        case .balanceCredit:
            line = BillingDraftLine(
                kind: .balanceCredit,
                title: "上期结余",
                detail: "抵扣本次应付",
                amountText: "-0.00"
            )
        case .priorBalance:
            line = BillingDraftLine(studentID: onlyLearnerID, kind: .priorBalance, title: "上期欠款")
        default:
            line = BillingDraftLine(studentID: onlyLearnerID, kind: .manual)
        }
        lines.append(line)
    }

    private func issueInvoice() {
        guard !isIssuing else { return }
        isIssuing = true
        errorMessage = nil
        statusMessage = nil

        Task { @MainActor in
            defer { isIssuing = false }
            do {
                let package = try validatedPackage()
                let bilingualDocument = previewDocument.translated(to: .bilingual)
                let englishDocument = previewDocument.translated(to: .english)
                let bilingualPNG = try ReceiptPNGRenderer.render(bilingualDocument)
                let englishPNG = try ReceiptPNGRenderer.render(englishDocument)
                let artifactUploads = package.artifacts.map { artifact in
                    BillingArtifactUpload(
                        artifact: artifact,
                        pngData: artifact.resolvedLanguage == .english ? englishPNG : bilingualPNG
                    )
                }
                _ = try await model.issueBillingInvoice(
                    package.invoice,
                    lineItems: package.items,
                    artifactUploads: artifactUploads
                )
                let store = try ReceiptFileStore.documents()
                let baseName = "\(billingDateText(bilingualDocument.issuedOn))-\(selectedLearnerNames)-\(bilingualDocument.receiptNumber)-V\(bilingualDocument.version)"
                let bilingualDestination = try store.savePNG(
                    bilingualPNG,
                    learnerName: bilingualDocument.guardianName,
                    filenameStem: "账单-\(baseName)-中英"
                )
                let englishDestination = try store.savePNG(
                    englishPNG,
                    learnerName: bilingualDocument.guardianName,
                    filenameStem: "Invoice-\(baseName)-English"
                )
                generatedFiles = GeneratedBillingFiles(
                    bilingual: GeneratedBillingFile(data: bilingualPNG, url: bilingualDestination),
                    english: GeneratedBillingFile(data: englishPNG, url: englishDestination)
                )
                statusMessage = "两份账单已签发并同步"
                try? await Task.sleep(nanoseconds: 650_000_000)
                didIssue()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func validatedPackage() throws -> (
        invoice: BillingInvoice,
        items: [BillingInvoiceLineItem],
        artifacts: [BillingArtifact]
    ) {
        guard let guardian = selectedGuardian else { throw BillingWorkspaceError.missingFamily }
        guard let selectedTermID else { throw BillingWorkspaceError.missingTerm }
        guard !selectedLearnerIDs.isEmpty else { throw BillingWorkspaceError.missingLearners }
        guard revisionBaseInvoice?.id == selectedInvoiceSeries?.latestInvoice.id else {
            throw BillingWorkspaceError.invoiceSeriesChanged
        }
        let number = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty else { throw BillingWorkspaceError.missingInvoiceNumber }
        if let revisionBaseInvoice {
            guard
                number == revisionBaseInvoice.invoiceNumber,
                version == revisionBaseInvoice.version + 1,
                revisionBaseInvoice.guardianID == guardian.id,
                revisionBaseInvoice.termID == selectedTermID,
                revisionBaseInvoice.learnerIDs == selectedLearnerIDList
            else { throw BillingWorkspaceError.invoiceSeriesChanged }
        } else {
            guard version == 1, selectedInvoiceSeries == nil else {
                throw BillingWorkspaceError.invoiceSeriesChanged
            }
        }
        guard !lines.isEmpty else { throw BillingWorkspaceError.missingItems }
        guard lineItemsStayWithinLearnerScope else {
            throw BillingWorkspaceError.itemOutsideLearnerScope
        }
        guard includesEveryTermEnrollment else {
            throw BillingWorkspaceError.missingEnrollmentCharges
        }
        guard amountDueCents >= 0 else { throw BillingWorkspaceError.negativeTotal }

        let invoiceID = BillingInvoiceID()
        let items = try lines.enumerated().map { index, line in
            let title = line.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { throw BillingWorkspaceError.incompleteItem }
            guard let amount = MoneyTextParser.cents(from: line.amountText) else {
                throw BillingWorkspaceError.invalidAmount(line.amountText)
            }
            return BillingInvoiceLineItem(
                invoiceID: invoiceID,
                studentID: line.studentID,
                enrollmentID: line.enrollmentID,
                kind: line.kind,
                title: title,
                detail: line.detail.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                quantity: max(1, line.quantity),
                unitAmountCents: line.quantity > 1 ? line.unitAmountCents : amount,
                amountCents: amount,
                settlementStatus: line.settlementStatus,
                sortOrder: index
            )
        }
        let invoice = BillingInvoice(
            id: invoiceID,
            guardianID: guardian.id,
            termID: selectedTermID,
            learnerIDs: selectedLearnerIDList,
            invoiceNumber: number,
            version: version,
            schoolYearLabel: termLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            issuedAt: issuedOn,
            amountDueCents: amountDueCents,
            notes: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            supersedesInvoiceID: revisionBaseInvoice?.id
        )
        return (
            invoice,
            items,
            BillingArtifactLanguage.allCases.map { language in
                BillingArtifact(invoiceID: invoiceID, kind: .invoice, language: language)
            }
        )
    }

    private func draftLine(_ item: BillingInvoiceLineItem) -> BillingDraftLine {
        BillingDraftLine(
            studentID: item.studentID,
            enrollmentID: item.enrollmentID,
            kind: item.kind,
            title: item.title,
            detail: item.detail ?? "",
            quantity: item.quantity,
            unitAmountCents: item.unitAmountCents,
            amountText: MoneyTextParser.dollars(from: item.amountCents),
            settlementStatus: item.settlementStatus
        )
    }

    private static func nextInvoiceNumber(from invoices: [BillingInvoice], now: Date = Date()) -> String {
        let year = Calendar.current.component(.year, from: now)
        let prefix = "INV-\(year)-"
        let maximum = invoices.compactMap { invoice -> Int? in
            guard invoice.invoiceNumber.hasPrefix(prefix) else { return nil }
            return Int(invoice.invoiceNumber.dropFirst(prefix.count))
        }.max() ?? 0
        return prefix + String(format: "%04d", maximum + 1)
    }

    private func copyPNG(_ data: Data) {
        do {
            try ReceiptClipboard.copyPNG(data)
            statusMessage = "PNG 已复制"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func formSection<Content: View>(
        _ title: String,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).mdFont(.bodyStrong)
            content()
        }
    }

    private func formRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .mdFont(.compact)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
private struct BillingHistoryView: View {
    let model: AppModel
    let createNewVersion: (BillingInvoice) -> Void

    @SceneStorage("md-desk.billing.history.selected-term-id") private var selectedTermIDStorage = ""
    @State private var selectedInvoiceID: BillingInvoiceID?
    @State private var searchText = ""
    @State private var paymentInvoice: BillingInvoice?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Picker("学期", selection: selectedTermSelection) {
                        Text("全部学期").tag(Optional<TermID>.none)
                        ForEach(model.terms) { term in
                            Text(term.name).tag(Optional(term.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 145)

                    TextField("搜索家庭或账单编号", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Text("\(filteredSeries.count)")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSeries) { series in
                            invoiceRow(series.latestInvoice, theme: theme)
                            Divider()
                        }
                    }
                }
            }
            .frame(width: 400)
            .background(theme.surface)

            Rectangle().fill(theme.separator).frame(width: 1)

            if let selectedInvoice {
                invoiceDetail(selectedInvoice, theme: theme)
            } else {
                ContentUnavailableView("选择一份账单", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: model.terms.map(\.id)) {
            chooseInitialTerm()
            chooseInitialInvoice()
        }
        .onChange(of: model.billingInvoices.map(\.id)) { _, _ in chooseInitialInvoice() }
        .onChange(of: selectedTermID) { _, _ in chooseInitialInvoice() }
        .onChange(of: searchText) { _, _ in chooseInitialInvoice() }
        .sheet(item: $paymentInvoice) { invoice in
            BillingPaymentSheet(model: model, invoice: invoice)
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

    private var filteredSeries: [BillingInvoiceSeries] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return BillingInvoiceSeriesResolver.series(from: model.billingInvoices).filter { series in
            guard selectedTermID == nil || series.key.termID == selectedTermID else { return false }
            guard !query.isEmpty else { return true }
            let family = model.guardian(id: series.key.guardianID)?.displayName ?? ""
            let term = series.key.termID.flatMap(model.term(id:))?.name ?? ""
            let learners = series.latestInvoice.learnerIDs.compactMap {
                model.student(id: $0)?.displayName
            }.joined(separator: "、")
            return family.localizedCaseInsensitiveContains(query)
                || term.localizedCaseInsensitiveContains(query)
                || learners.localizedCaseInsensitiveContains(query)
                || series.invoices.contains {
                    $0.invoiceNumber.localizedCaseInsensitiveContains(query)
                        || $0.schoolYearLabel.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var selectedInvoice: BillingInvoice? {
        selectedInvoiceID.flatMap { id in model.billingInvoices.first { $0.id == id } }
    }

    private var selectedSeries: BillingInvoiceSeries? {
        selectedInvoice.flatMap {
            BillingInvoiceSeriesResolver.series(containing: $0, in: model.billingInvoices)
        }
    }

    private func invoiceRow(_ invoice: BillingInvoice, theme: MDTheme) -> some View {
        let payments = model.payments(for: invoice.id)
        let selected = selectedInvoiceID == invoice.id
        return Button {
            selectedInvoiceID = invoice.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: statusSymbol(invoice.displayStatus(payments: payments)))
                    .foregroundStyle(statusColor(invoice.displayStatus(payments: payments), theme: theme))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(model.guardian(id: invoice.guardianID)?.displayName ?? "家庭")
                            .mdFont(.bodyStrong)
                            .lineLimit(1)
                        Spacer()
                        Text("$" + MoneyTextParser.dollars(from: invoice.amountDueCents))
                            .mdFont(.monoStrong)
                    }
                    HStack(spacing: 6) {
                        Text(invoice.invoiceNumber + " · V\(invoice.version)")
                        Spacer()
                        Text(invoice.termID.flatMap(model.term(id:))?.name ?? "未分学期")
                            .lineLimit(1)
                    }
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    Text(learnerNames(for: invoice))
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 66)
            .background(selected ? theme.accent.opacity(colorScheme == .dark ? 0.20 : 0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func invoiceDetail(_ invoice: BillingInvoice, theme: MDTheme) -> some View {
        let payments = model.payments(for: invoice.id)
        let status = invoice.displayStatus(payments: payments)
        let outstanding = invoice.outstandingCents(payments: payments)
        let items = model.billingItems(for: invoice.id)
        let waivedTotal = items
            .filter(\.isWaived)
            .reduce(0) { $0 + max(0, $1.amountCents) }
        let latestInvoice = selectedSeries?.latestInvoice ?? invoice
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(invoice.invoiceNumber + " · V\(invoice.version)")
                        .mdFont(.bodyStrong)
                    Text([
                        model.guardian(id: invoice.guardianID)?.displayName ?? "家庭",
                        learnerNames(for: invoice),
                    ].filter { !$0.isEmpty }.joined(separator: " · "))
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text(statusTitle(status))
                    .mdFont(.compactStrong)
                    .foregroundStyle(statusColor(status, theme: theme))

                Picker("历史版本", selection: selectedInvoiceBinding(fallback: invoice.id)) {
                    ForEach(selectedSeries?.invoices ?? [invoice]) { versionInvoice in
                        Text("V\(versionInvoice.version) · \(billingDateText(versionInvoice.issuedAt))")
                            .tag(versionInvoice.id)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                .help("查看这份账单的历史版本")

                Button {
                    createNewVersion(latestInvoice)
                } label: {
                    Label("新版本", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(invoice.id == latestInvoice.id
                    ? "基于当前版本继续修改"
                    : "将基于最新版 V\(latestInvoice.version) 继续修改")

                Button {
                    paymentInvoice = invoice
                } label: {
                    Label("记录付款", systemImage: "dollarsign.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(outstanding == 0 || status == .superseded)
            }
            .padding(.horizontal, 16)
            .frame(height: 58)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 28) {
                        metric("账单金额", "$" + MoneyTextParser.dollars(from: invoice.amountDueCents), theme: theme)
                        metric("已付款", "$" + MoneyTextParser.dollars(from: invoice.amountDueCents - outstanding), theme: theme)
                        metric("待付金额", "$" + MoneyTextParser.dollars(from: outstanding), theme: theme, emphasized: outstanding > 0)
                        if waivedTotal > 0 {
                            metric("免付金额", "$" + MoneyTextParser.dollars(from: waivedTotal), theme: theme)
                        }
                        metric(
                            "学期",
                            invoice.termID.flatMap(model.term(id:))?.name ?? invoice.schoolYearLabel,
                            theme: theme
                        )
                        Spacer()
                    }

                    detailSection("收费项目", theme: theme) {
                        ForEach(items) { item in
                            let displaySettlementStatus: BillingLineItemSettlementStatus = {
                                if item.isWaived { return .waived }
                                if status == .paid { return .paid }
                                return item.settlementStatus
                            }()
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).mdFont(.bodyStrong)
                                    Text(itemDetail(item))
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if item.kind == .discount || item.kind == .balanceCredit || item.amountCents < 0 {
                                    Text("调整")
                                        .mdFont(.compactStrong)
                                        .foregroundStyle(theme.accent)
                                } else {
                                    Label(
                                        displaySettlementStatus.title,
                                        systemImage: settlementSymbol(displaySettlementStatus)
                                    )
                                    .mdFont(.compactStrong)
                                    .foregroundStyle(settlementColor(displaySettlementStatus, theme: theme))
                                }
                                Text("$" + MoneyTextParser.dollars(from: item.amountCents))
                                    .mdFont(.monoStrong)
                                    .frame(width: 110, alignment: .trailing)
                            }
                            .frame(minHeight: 40)
                            Divider()
                        }
                    }

                    if !payments.isEmpty {
                        detailSection("付款记录", theme: theme) {
                            ForEach(payments) { payment in
                                HStack(spacing: 14) {
                                    Text(paymentMethodTitle(payment.method))
                                        .mdFont(.bodyStrong)
                                    Text(billingDateText(payment.receivedAt))
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
                                    Spacer()
                                    if payment.processingFeeCents > 0 {
                                        Text("手续费 $" + MoneyTextParser.dollars(from: payment.processingFeeCents))
                                            .mdFont(.compact)
                                            .foregroundStyle(theme.secondaryText)
                                    }
                                    Text("收取 $" + MoneyTextParser.dollars(from: payment.chargedAmountCents))
                                        .mdFont(.monoStrong)
                                }
                                .frame(minHeight: 36)
                                Divider()
                            }
                        }
                    }

                    detailSection("账单与付款收据 PNG", theme: theme) {
                        BillingVersionDocumentGrid(
                            invoice: invoice,
                            payments: payments,
                            artifacts: model.artifacts(for: invoice.id),
                            copyArtifact: copyArtifact
                        )
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectedTermID: TermID? {
        get {
            guard selectedTermIDStorage != "all" else { return nil }
            return try? TermID(uuidString: selectedTermIDStorage)
        }
        nonmutating set {
            selectedTermIDStorage = newValue?.description ?? "all"
        }
    }

    private var selectedTermSelection: Binding<TermID?> {
        Binding(
            get: { selectedTermID },
            set: { selectedTermID = $0 }
        )
    }

    private func selectedInvoiceBinding(fallback: BillingInvoiceID) -> Binding<BillingInvoiceID> {
        Binding(
            get: { selectedInvoiceID ?? fallback },
            set: { selectedInvoiceID = $0 }
        )
    }

    private func chooseInitialTerm() {
        let preservesAllTerms = selectedTermIDStorage == "all"
        let hasValidTerm = selectedTermID.map { selectedID in
            model.terms.contains { $0.id == selectedID }
        } ?? false
        if selectedTermIDStorage.isEmpty || (!preservesAllTerms && !hasValidTerm) {
            selectedTermID = model.currentEnrollmentTerm?.id ?? model.terms.first?.id
        }
    }

    private func chooseInitialInvoice() {
        if let selectedSeries,
           filteredSeries.contains(where: { $0.id == selectedSeries.id }) {
            return
        }
        selectedInvoiceID = filteredSeries.first?.latestInvoice.id
    }

    private func copyArtifact(_ artifact: BillingArtifact) {
        Task { @MainActor in
            do {
                let data = try await model.billingArtifactData(storagePath: artifact.storagePath)
                try ReceiptClipboard.copyPNG(data)
                statusMessage = "PNG 已复制"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func itemDetail(_ item: BillingInvoiceLineItem) -> String {
        let learner = item.studentID.flatMap { model.student(id: $0)?.displayName }
        return [learner, item.detail].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
    }

    private func learnerNames(for invoice: BillingInvoice) -> String {
        let names = invoice.learnerIDs.compactMap { model.student(id: $0)?.displayName }
        return names.joined(separator: "、").nilIfEmpty ?? "未记录学员范围"
    }

    private func statusTitle(_ status: BillingInvoiceDisplayStatus) -> String {
        switch status {
        case .issued: "待付款"
        case .partiallyPaid: "部分付款"
        case .paid: "已付款"
        case .noPaymentRequired: "无需付款"
        case .superseded: "已被新版本替代"
        }
    }

    private func statusSymbol(_ status: BillingInvoiceDisplayStatus) -> String {
        switch status {
        case .issued: "clock"
        case .partiallyPaid: "circle.lefthalf.filled"
        case .paid: "checkmark.circle.fill"
        case .noPaymentRequired: "checkmark.seal.fill"
        case .superseded: "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    private func statusColor(_ status: BillingInvoiceDisplayStatus, theme: MDTheme) -> Color {
        switch status {
        case .issued: theme.warning
        case .partiallyPaid: theme.warning
        case .paid: theme.success
        case .noPaymentRequired: theme.accent
        case .superseded: theme.secondaryText
        }
    }

    private func settlementSymbol(_ status: BillingLineItemSettlementStatus) -> String {
        switch status {
        case .unpaid: "square"
        case .paid: "checkmark.square.fill"
        case .waived: "gift.fill"
        }
    }

    private func settlementColor(
        _ status: BillingLineItemSettlementStatus,
        theme: MDTheme
    ) -> Color {
        switch status {
        case .unpaid: theme.danger
        case .paid: theme.success
        case .waived: theme.accent
        }
    }

    private func metric(
        _ title: String,
        _ value: String,
        theme: MDTheme,
        emphasized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).mdFont(.compact).foregroundStyle(theme.secondaryText)
            Text(value)
                .mdFont(.monoStrong)
                .foregroundStyle(emphasized ? theme.accent : theme.primaryText)
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).mdFont(.bodyStrong)
            content()
        }
    }
}

@MainActor
private struct BillingPaymentSheet: View {
    let model: AppModel
    let invoice: BillingInvoice

    @State private var amountText = ""
    @State private var method = BillingPaymentMethod.zelle
    @State private var receivedOn = Date()
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: "记录付款", english: "PAYMENT")
                Spacer()
                Text(invoice.invoiceNumber + " · V\(invoice.version)")
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 17) {
                LabeledContent("家庭", value: model.guardian(id: invoice.guardianID)?.displayName ?? "—")
                LabeledContent("待付金额", value: "$" + MoneyTextParser.dollars(from: outstandingCents))

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow {
                        label("本次付款")
                        HStack(spacing: 7) {
                            Text("$").mdFont(.monoStrong).foregroundStyle(theme.secondaryText)
                            TextField("0.00", text: $amountText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 160)
                            Button("付清") {
                                amountText = MoneyTextParser.dollars(from: outstandingCents)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    GridRow {
                        label("支付方式")
                        Picker("", selection: $method) {
                            ForEach(BillingPaymentMethod.allCases, id: \.self) { method in
                                Text(paymentMethodTitle(method)).tag(method)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 200)
                    }
                    GridRow {
                        label("付款日期")
                        DatePicker("", selection: $receivedOn, displayedComponents: .date)
                            .labelsHidden()
                    }
                    GridRow {
                        label("手续费")
                        Text(method == .card ? "$\(MoneyTextParser.dollars(from: processingFeeCents))（3.5%，独立收取）" : "$0.00")
                            .mdFont(.mono)
                    }
                    GridRow {
                        label("实际收取")
                        Text("$" + MoneyTextParser.dollars(from: paymentAmountCents + processingFeeCents))
                            .mdFont(.monoStrong)
                            .foregroundStyle(theme.accent)
                    }
                }

                TextEditor(text: $note)
                    .mdFont(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 74)
                    .padding(6)
                    .background(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .stroke(theme.separator, lineWidth: 1)
                    }
            }
            .padding(20)

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("生成付款收据并记录") { recordPayment() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!paymentIsValid || isSaving)
            }
            .padding(14)
        }
        .frame(width: 590, height: 530)
        .background(theme.background)
        .onAppear {
            amountText = MoneyTextParser.dollars(from: outstandingCents)
        }
        .alert(
            "无法记录付款",
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

    private var outstandingCents: Int {
        invoice.outstandingCents(payments: model.payments(for: invoice.id))
    }

    private var paymentAmountCents: Int {
        MoneyTextParser.cents(from: amountText) ?? 0
    }

    private var processingFeeCents: Int {
        method == .card ? BillingCalculator.cardFeeCents(for: paymentAmountCents) : 0
    }

    private var paymentIsValid: Bool {
        paymentAmountCents > 0 && paymentAmountCents <= outstandingCents
    }

    private func recordPayment() {
        guard paymentIsValid else { return }
        isSaving = true
        errorMessage = nil
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let payment = BillingPayment(
                    invoiceID: invoice.id,
                    amountCents: paymentAmountCents,
                    processingFeeCents: processingFeeCents,
                    method: method,
                    receivedAt: receivedOn,
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                )
                let bilingualDocument = receiptDocument(payment: payment).translated(to: .bilingual)
                let englishDocument = bilingualDocument.translated(to: .english)
                let bilingualPNG = try ReceiptPNGRenderer.render(bilingualDocument)
                let englishPNG = try ReceiptPNGRenderer.render(englishDocument)
                let artifactUploads = BillingArtifactLanguage.allCases.map { language in
                    BillingArtifactUpload(
                        artifact: BillingArtifact(
                            invoiceID: invoice.id,
                            paymentID: payment.id,
                            kind: .receipt,
                            language: language
                        ),
                        pngData: language == .english ? englishPNG : bilingualPNG
                    )
                }
                _ = try await model.recordBillingPayment(
                    payment,
                    artifactUploads: artifactUploads
                )
                let store = try ReceiptFileStore.documents()
                let baseName = "\(billingDateText(payment.receivedAt))-\(bilingualDocument.learnerName)-\(invoice.invoiceNumber)-V\(invoice.version)"
                _ = try store.savePNG(
                    bilingualPNG,
                    learnerName: bilingualDocument.guardianName,
                    filenameStem: "付款收据-\(baseName)-中英"
                )
                _ = try store.savePNG(
                    englishPNG,
                    learnerName: bilingualDocument.guardianName,
                    filenameStem: "Payment-Receipt-\(baseName)-English"
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func receiptDocument(payment: BillingPayment) -> ReceiptDocument {
        let guardian = model.guardian(id: invoice.guardianID)
        let items = model.billingItems(for: invoice.id)
        let learnerNames = invoice.learnerIDs.compactMap {
            model.student(id: $0)?.displayName
        }
        let paymentLedger = (model.payments(for: invoice.id).filter { $0.id != payment.id } + [payment])
            .sorted { lhs, rhs in
                if lhs.receivedAt != rhs.receivedAt { return lhs.receivedAt < rhs.receivedAt }
                return lhs.createdAt < rhs.createdAt
            }
        let cumulativePaymentCents = paymentLedger.reduce(0) { $0 + $1.amountCents }
        let cumulativeFeeCents = paymentLedger.reduce(0) { $0 + $1.processingFeeCents }
        let methods = paymentLedger.reduce(into: [BillingPaymentMethod]()) { result, entry in
            if !result.contains(entry.method) { result.append(entry.method) }
        }
        return ReceiptDocument(
            kind: .receipt,
            receiptNumber: invoice.invoiceNumber,
            version: invoice.version,
            termLabel: invoice.termID.flatMap(model.term(id:))?.name ?? invoice.schoolYearLabel,
            issuedOn: payment.receivedAt,
            guardianName: guardian?.displayName ?? "家庭",
            guardianEmail: guardian?.email,
            guardianPhone: guardian?.phone,
            learnerName: learnerNames.joined(separator: "、"),
            items: items.map { item in
                ReceiptLineItem(
                    kind: item.kind,
                    section: receiptSection(for: item),
                    title: item.title,
                    englishTitle: englishBillingTitle(for: item),
                    amount: decimal(cents: item.amountCents),
                    learnerName: item.studentID.flatMap { model.student(id: $0)?.displayName },
                    detail: item.detail,
                    englishDetail: englishBillingDetail(for: item),
                    settlementStatus: item.settlementStatus
                )
            },
            paymentMethod: methods.map(paymentMethodTitle).joined(separator: "、"),
            paymentMethodEnglish: methods.map(paymentMethodEnglishTitle).joined(separator: " + "),
            paymentAmount: decimal(cents: cumulativePaymentCents),
            processingFee: decimal(cents: cumulativeFeeCents),
            outstandingAfterPayment: decimal(cents: max(0, invoice.amountDueCents - cumulativePaymentCents)),
            note: payment.note ?? invoice.notes ?? ""
        )
    }

    private func receiptSection(for item: BillingInvoiceLineItem) -> ReceiptLineItemSection {
        switch item.kind {
        case .tuition:
            let mode = item.enrollmentID.flatMap { enrollmentID in
                model.enrollments.first { $0.id == enrollmentID }?.registrationMode
            }
            return mode == .perSession ? .perSession : .fullTerm
        case .trial:
            return .perSession
        case .discount, .balanceCredit:
            return .adjustments
        case .registration, .priorBalance, .manual:
            return .miscellaneous
        }
    }

    private func englishBillingTitle(for item: BillingInvoiceLineItem) -> String {
        let courseName = item.enrollmentID.flatMap { enrollmentID in
            model.enrollments.first { $0.id == enrollmentID }
        }.flatMap { model.course(id: $0.courseID)?.name }
        switch item.kind {
        case .tuition:
            let label = receiptSection(for: item) == .perSession
                ? "Per-Session Tuition"
                : "Full-Term Tuition"
            return [courseName, label].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
        case .trial:
            return [courseName, "Trial Class Fee"].compactMap { $0?.nilIfEmpty }.joined(separator: " · ")
        case .registration: return "Annual Registration Fee"
        case .discount: return "Course Discount"
        case .balanceCredit: return "Prior Credit"
        case .priorBalance: return "Prior Balance"
        case .manual:
            return item.title.unicodeScalars.contains(where: { $0.value > 127 })
                ? "Additional Charge"
                : item.title
        }
    }

    private func englishBillingDetail(for item: BillingInvoiceLineItem) -> String? {
        switch item.kind {
        case .tuition:
            guard item.quantity > 1 else { return nil }
            return "\(item.quantity) sessions × $\(MoneyTextParser.dollars(from: item.unitAmountCents))"
        case .trial: return "Trial class fee"
        case .discount: return "Applied to course tuition"
        case .balanceCredit: return "Applied to the current amount due"
        case .priorBalance: return "Balance from a prior term"
        case .registration: return "Annual student registration"
        case .manual:
            guard let detail = item.detail,
                  !detail.unicodeScalars.contains(where: { $0.value > 127 }) else { return nil }
            return detail
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .mdFont(.compact)
            .foregroundStyle(.secondary)
            .frame(width: 82, alignment: .leading)
    }
}

private func paymentMethodTitle(_ method: BillingPaymentMethod) -> String {
    switch method {
    case .cash: "现金"
    case .check: "支票"
    case .zelle: "Zelle"
    case .card: "银行卡"
    }
}

private func paymentMethodEnglishTitle(_ method: BillingPaymentMethod) -> String {
    switch method {
    case .cash: "Cash"
    case .check: "Check"
    case .zelle: "Zelle"
    case .card: "Card"
    }
}

private func decimal(cents: Int) -> Decimal {
    Decimal(cents) / 100
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
