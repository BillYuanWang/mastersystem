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
    case missingInvoiceNumber
    case missingItems
    case incompleteItem
    case invalidAmount(String)
    case negativeTotal
    case invalidPayment

    var errorDescription: String? {
        switch self {
        case .missingFamily: "请选择监护人。"
        case .missingTerm: "请选择账单所属学期。"
        case .missingInvoiceNumber: "请输入账单编号。"
        case .missingItems: "请至少添加一个收费项目。"
        case .incompleteItem: "每个收费项目都需要名称和正确金额。"
        case .invalidAmount(let value): "金额“\(value)”格式不正确。"
        case .negativeTotal: "本次应付合计不能小于 0。"
        case .invalidPayment: "付款金额必须大于 0，且不能超过待付金额。"
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
    var includedInAmountDue: Bool

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
        includedInAmountDue: Bool = true
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
        self.includedInAmountDue = includedInAmountDue
    }
}

private struct GeneratedBillingFile {
    let data: Data
    let url: URL
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
    @State private var invoiceNumber = ""
    @State private var version = 1
    @State private var schoolYearLabel = ""
    @State private var issuedOn = Date()
    @State private var lines: [BillingDraftLine] = []
    @State private var note = ""
    @State private var generatedFile: GeneratedBillingFile?
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

                ReceiptPreviewPane(document: previewDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { configureIfNeeded() }
        .onChange(of: selectedGuardianID) { _, _ in
            generatedFile = nil
            statusMessage = nil
            if correctionInvoice == nil { lines.removeAll() }
        }
        .onChange(of: selectedTermID) { _, termID in
            guard correctionInvoice == nil else { return }
            schoolYearLabel = termID.flatMap { model.term(id: $0) }.map(defaultSchoolYearLabel) ?? ""
            lines.removeAll()
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
                } else if correctionInvoice != nil {
                    Label("正在创建修订版本", systemImage: "clock.arrow.circlepath")
                        .mdFont(.compact)
                        .foregroundStyle(theme.warning)
                }
                Spacer()

                if let generatedFile {
                    Button {
                        copyPNG(generatedFile.data)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("复制 PNG")

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([generatedFile.url])
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("在 Finder 中显示")
                }

                Button(action: issueInvoice) {
                    Label(correctionInvoice == nil ? "签发账单" : "签发 v\(version)", systemImage: "paperplane")
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
            formRow("学员档案") {
                Text(familyLearners.map(\.displayName).joined(separator: "、").nilIfEmpty ?? "暂无学员")
                    .mdFont(.body)
                    .foregroundStyle(familyLearners.isEmpty ? theme.secondaryText : theme.primaryText)
                    .lineLimit(2)
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
                    Text("v\(version)")
                        .mdFont(.monoStrong)
                        .foregroundStyle(theme.accent)
                }
            }
            formRow("学年") {
                TextField("例如 2026–2027", text: $schoolYearLabel)
                    .textFieldStyle(.roundedBorder)
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
                    Label("按报名生成", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .disabled(selectedGuardianID == nil || selectedTermID == nil)

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
                Text("选择家庭和学期后，可按现有报名自动生成学费，也可手动添加项目。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            } else {
                HStack(spacing: 7) {
                    Text("学员").frame(width: 105, alignment: .leading)
                    Text("项目").frame(maxWidth: .infinity, alignment: .leading)
                    Text("金额").frame(width: 92, alignment: .leading)
                    Text("应付").frame(width: 38)
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
                ForEach(familyLearners) { student in
                    Text(student.displayName).tag(Optional(student.id))
                }
            }
            .labelsHidden()
            .frame(width: 105)

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

            Toggle("", isOn: line.includedInAmountDue)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 38)
                .help(line.wrappedValue.includedInAmountDue ? "计入本次应付" : "仅展示，不计入应付")

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

    private var amountDueCents: Int {
        lines.reduce(0) { result, line in
            guard line.includedInAmountDue,
                  let cents = MoneyTextParser.cents(from: line.amountText) else { return result }
            return result + cents
        }
    }

    private var canIssue: Bool {
        selectedGuardianID != nil
            && selectedTermID != nil
            && !invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !schoolYearLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lines.isEmpty
            && lines.allSatisfy {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && MoneyTextParser.cents(from: $0.amountText) != nil
            }
            && amountDueCents >= 0
    }

    private var previewDocument: ReceiptDocument {
        ReceiptDocument(
            kind: .invoice,
            receiptNumber: invoiceNumber.nilIfEmpty ?? "—",
            version: version,
            schoolYearLabel: schoolYearLabel,
            issuedOn: issuedOn,
            guardianName: selectedGuardian?.displayName ?? "请选择监护人",
            guardianEmail: selectedGuardian?.email,
            guardianPhone: selectedGuardian?.phone,
            learnerName: familyLearners.map(\.displayName).joined(separator: "、").nilIfEmpty ?? "请选择家庭",
            items: previewReceiptItems,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var previewReceiptItems: [ReceiptLineItem] {
        let values = lines.compactMap { line -> ReceiptLineItem? in
            guard !line.title.isEmpty || !line.amountText.isEmpty else { return nil }
            return ReceiptLineItem(
                title: line.title.nilIfEmpty ?? "收费项目",
                amount: decimal(cents: MoneyTextParser.cents(from: line.amountText) ?? 0),
                learnerName: line.studentID.flatMap { model.student(id: $0)?.displayName },
                detail: line.detail.nilIfEmpty,
                includedInAmountDue: line.includedInAmountDue
            )
        }
        return values.isEmpty ? [ReceiptLineItem(title: "收费项目", amount: .zero)] : values
    }

    private func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        if let correctionInvoice {
            selectedGuardianID = correctionInvoice.guardianID
            selectedTermID = correctionInvoice.termID
            invoiceNumber = correctionInvoice.invoiceNumber
            version = correctionInvoice.version + 1
            schoolYearLabel = correctionInvoice.schoolYearLabel
            note = correctionInvoice.notes ?? ""
            lines = model.billingItems(for: correctionInvoice.id).map(draftLine)
        } else {
            selectedGuardianID = sortedGuardians.first?.id
            selectedTermID = model.currentEnrollmentTerm?.id ?? model.terms.first?.id
            invoiceNumber = Self.nextInvoiceNumber(from: model.billingInvoices)
            if let term = selectedTermID.flatMap({ model.term(id: $0) }) {
                schoolYearLabel = defaultSchoolYearLabel(term)
            }
        }
    }

    private func generateFromEnrollments() {
        guard let selectedGuardianID, let selectedTermID else { return }
        let studentIDs = Set(model.students(for: selectedGuardianID).map(\.id))
        let enrollments = model.enrollments
            .filter {
                $0.termID == selectedTermID
                    && $0.status == .active
                    && studentIDs.contains($0.studentID)
            }
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

        lines = enrollments.flatMap { enrollment -> [BillingDraftLine] in
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
                        amountText: "0.00",
                        includedInAmountDue: false
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
        generatedFile = nil
        statusMessage = enrollments.isEmpty ? "该家庭本学期暂无报名" : "已按报名生成"
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
        let firstMinorID = familyLearners.first(where: { $0.kind == .child })?.id
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
            line = BillingDraftLine(kind: .priorBalance, title: "上期欠款")
        default:
            line = BillingDraftLine(kind: .manual)
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
                let document = previewDocument
                let png = try ReceiptPNGRenderer.render(document)
                _ = try await model.issueBillingInvoice(
                    package.invoice,
                    lineItems: package.items,
                    artifact: package.artifact,
                    pngData: png
                )
                let store = try ReceiptFileStore.documents()
                let destination = try store.savePNG(
                    png,
                    learnerName: document.guardianName,
                    filenameStem: "账单-\(billingDateText(document.issuedOn))-\(document.receiptNumber)-v\(document.version)"
                )
                generatedFile = GeneratedBillingFile(data: png, url: destination)
                statusMessage = "账单已签发并同步"
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
        artifact: BillingArtifact
    ) {
        guard let guardian = selectedGuardian else { throw BillingWorkspaceError.missingFamily }
        guard let selectedTermID else { throw BillingWorkspaceError.missingTerm }
        let number = invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !number.isEmpty else { throw BillingWorkspaceError.missingInvoiceNumber }
        guard !lines.isEmpty else { throw BillingWorkspaceError.missingItems }
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
                includedInAmountDue: line.includedInAmountDue,
                sortOrder: index
            )
        }
        let invoice = BillingInvoice(
            id: invoiceID,
            guardianID: guardian.id,
            termID: selectedTermID,
            invoiceNumber: number,
            version: version,
            schoolYearLabel: schoolYearLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            issuedAt: issuedOn,
            amountDueCents: amountDueCents,
            notes: note.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            supersedesInvoiceID: correctionInvoice?.id
        )
        return (
            invoice,
            items,
            BillingArtifact(invoiceID: invoiceID, kind: .invoice)
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
            includedInAmountDue: item.includedInAmountDue
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

    private func defaultSchoolYearLabel(_ term: Term) -> String {
        let year = Calendar.masterDance.component(.year, from: term.startsOn)
        return "\(year)–\(year + 1)"
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
                    TextField("搜索家庭或账单编号", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Text("\(filteredInvoices.count)")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredInvoices) { invoice in
                            invoiceRow(invoice, theme: theme)
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
        .task { chooseInitialInvoice() }
        .onChange(of: model.billingInvoices.map(\.id)) { _, _ in chooseInitialInvoice() }
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

    private var filteredInvoices: [BillingInvoice] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.billingInvoices.filter { invoice in
            guard !query.isEmpty else { return true }
            let family = model.guardian(id: invoice.guardianID)?.displayName ?? ""
            return family.localizedCaseInsensitiveContains(query)
                || invoice.invoiceNumber.localizedCaseInsensitiveContains(query)
                || invoice.schoolYearLabel.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedInvoice: BillingInvoice? {
        selectedInvoiceID.flatMap { id in model.billingInvoices.first { $0.id == id } }
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
                        Text(invoice.invoiceNumber + " · v\(invoice.version)")
                        Spacer()
                        Text(billingDateText(invoice.issuedAt))
                    }
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 54)
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
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(invoice.invoiceNumber + " · v\(invoice.version)")
                        .mdFont(.bodyStrong)
                    Text(model.guardian(id: invoice.guardianID)?.displayName ?? "家庭")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text(statusTitle(status))
                    .mdFont(.compactStrong)
                    .foregroundStyle(statusColor(status, theme: theme))
                Button {
                    createNewVersion(invoice)
                } label: {
                    Label("新版本", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(status == .superseded)

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
                        metric("学年", invoice.schoolYearLabel, theme: theme)
                        Spacer()
                    }

                    detailSection("收费项目", theme: theme) {
                        ForEach(items) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).mdFont(.bodyStrong)
                                    Text(itemDetail(item))
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if !item.includedInAmountDue {
                                    Text("仅展示")
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
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

                    detailSection("PNG 文件", theme: theme) {
                        ForEach(model.artifacts(for: invoice.id)) { artifact in
                            HStack(spacing: 10) {
                                Image(systemName: artifact.kind == .invoice ? "doc.text.image" : "receipt")
                                    .foregroundStyle(theme.accent)
                                Text(artifact.kind == .invoice ? "账单 v\(invoice.version)" : "付款收据")
                                    .mdFont(.body)
                                Text(billingDateText(artifact.generatedAt))
                                    .mdFont(.compact)
                                    .foregroundStyle(theme.secondaryText)
                                Spacer()
                                Button {
                                    copyArtifact(artifact)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(MDIconButtonStyle())
                                .help("复制 PNG")
                            }
                            .frame(minHeight: 38)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func chooseInitialInvoice() {
        if selectedInvoice == nil { selectedInvoiceID = filteredInvoices.first?.id }
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

    private func statusTitle(_ status: BillingInvoiceDisplayStatus) -> String {
        switch status {
        case .issued: "待付款"
        case .partiallyPaid: "部分付款"
        case .paid: "已付款"
        case .superseded: "已被新版本替代"
        }
    }

    private func statusSymbol(_ status: BillingInvoiceDisplayStatus) -> String {
        switch status {
        case .issued: "clock"
        case .partiallyPaid: "circle.lefthalf.filled"
        case .paid: "checkmark.circle.fill"
        case .superseded: "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    private func statusColor(_ status: BillingInvoiceDisplayStatus, theme: MDTheme) -> Color {
        switch status {
        case .issued: theme.warning
        case .partiallyPaid: theme.warning
        case .paid: theme.success
        case .superseded: theme.secondaryText
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
                Text(invoice.invoiceNumber + " · v\(invoice.version)")
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
                Button("生成收据并记录") { recordPayment() }
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
                let document = receiptDocument(payment: payment)
                let png = try ReceiptPNGRenderer.render(document)
                let artifact = BillingArtifact(
                    invoiceID: invoice.id,
                    paymentID: payment.id,
                    kind: .receipt
                )
                _ = try await model.recordBillingPayment(
                    payment,
                    artifact: artifact,
                    pngData: png
                )
                let store = try ReceiptFileStore.documents()
                _ = try store.savePNG(
                    png,
                    learnerName: document.guardianName,
                    filenameStem: "收据-\(billingDateText(payment.receivedAt))-\(invoice.invoiceNumber)-v\(invoice.version)"
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
        let learnerNames = Set(items.compactMap { item in
            item.studentID.flatMap { model.student(id: $0)?.displayName }
        }).sorted()
        return ReceiptDocument(
            kind: .receipt,
            receiptNumber: invoice.invoiceNumber,
            version: invoice.version,
            schoolYearLabel: invoice.schoolYearLabel,
            issuedOn: payment.receivedAt,
            guardianName: guardian?.displayName ?? "家庭",
            guardianEmail: guardian?.email,
            guardianPhone: guardian?.phone,
            learnerName: learnerNames.joined(separator: "、"),
            items: items.map { item in
                ReceiptLineItem(
                    title: item.title,
                    amount: decimal(cents: item.amountCents),
                    learnerName: item.studentID.flatMap { model.student(id: $0)?.displayName },
                    detail: item.detail,
                    includedInAmountDue: item.includedInAmountDue
                )
            },
            paymentMethod: paymentMethodTitle(payment.method),
            paymentAmount: decimal(cents: payment.amountCents),
            processingFee: decimal(cents: payment.processingFeeCents),
            outstandingAfterPayment: decimal(cents: outstandingCents - payment.amountCents),
            note: payment.note ?? invoice.notes ?? ""
        )
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

private func decimal(cents: Int) -> Decimal {
    Decimal(cents) / 100
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
