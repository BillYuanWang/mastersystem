#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

@MainActor
struct ContractsWorkspaceView: View {
    let model: AppModel

    @SceneStorage("md-desk.contracts.section") private var sectionStorage = ContractSection.documents.rawValue
    @SceneStorage("md-desk.contracts.search") private var searchText = ""
    @SceneStorage("md-desk.contracts.document-sort-column") private var documentSortColumnStorage = ""
    @SceneStorage("md-desk.contracts.document-sort-ascending") private var documentSortAscending = true
    @SceneStorage("md-desk.contracts.document-filters") private var documentFiltersStorage = ""
    @SceneStorage("md-desk.contracts.consent-sort-column") private var consentSortColumnStorage = ""
    @SceneStorage("md-desk.contracts.consent-sort-ascending") private var consentSortAscending = true
    @SceneStorage("md-desk.contracts.consent-filters") private var consentFiltersStorage = ""
    @State private var editorDocument: ContractDocument?
    @State private var showingNewDocument = false
    @State private var deletion: ContractDocument?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "合同")

                Picker("合同内容", selection: sectionSelection) {
                    Text("协议版本").tag(ContractSection.documents)
                    Text("签署记录").tag(ContractSection.consents)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                        .lineLimit(1)
                }

                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .mdFont(.compact)
                    .frame(width: 160)

                if section == .documents {
                    Button {
                        showingNewDocument = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("发布新协议")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            switch section {
            case .documents:
                documentList(theme: theme)
            case .consents:
                consentList(theme: theme)
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .sheet(isPresented: $showingNewDocument) {
            ContractDocumentEditorView(model: model, document: nil)
        }
        .sheet(item: $editorDocument) { document in
            ContractDocumentEditorView(model: model, document: document)
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { deletion != nil },
                set: { if !$0 { deletion = nil } }
            ),
            presenting: deletion
        ) { document in
            Button("删除", role: .destructive) { delete(document) }
            Button("取消", role: .cancel) {}
        } message: { document in
            Text("确定删除“\(document.title)”吗？已有签署记录的合同不会被删除。")
        }
    }

    private func documentList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            documentHeader(theme: theme)
            if filteredDocuments.isEmpty {
                ContentUnavailableView(
                    "暂无协议",
                    systemImage: "doc.text",
                    description: Text("点击右上角加号创建并发布文字协议。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredDocuments) { document in
                            HStack(spacing: 0) {
                                contractCell(document.title, width: 250, strong: true)
                                contractCell(document.version, width: 90, mono: true)
                                contractCell(model.term(id: document.termID)?.name ?? "—", width: 170)
                                contractCell(statusLabel(document.status), width: 90)
                                contractCell(
                                    document.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—",
                                    width: 150,
                                    mono: true
                                )
                                contractCell("\(document.bodyText.count)", width: 70, mono: true)
                                HStack(spacing: 3) {
                                    Button {
                                        editorDocument = document
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .buttonStyle(MDIconButtonStyle())
                                    .help("编辑")

                                    Button {
                                        deletion = document
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(MDIconButtonStyle())
                                    .help("删除")
                                }
                                .frame(width: 70)
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 42)
                            .help(
                                String(document.bodyText.prefix(180))
                                    + (document.bodyText.count > 180 ? "…" : "")
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func consentList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            consentHeader(theme: theme)
            if filteredConsents.isEmpty {
                ContentUnavailableView("暂无签署记录", systemImage: "signature")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConsents) { consent in
                            HStack(spacing: 0) {
                                contractCell(consent.signerDisplayName, width: 190, strong: true)
                                ContractSignatureThumbnail(signaturePNG: consent.signaturePNG)
                                    .frame(width: 130)
                                contractCell(consent.contractVersion, width: 120, mono: true)
                                contractCell(consent.enrollmentID == nil ? "整个学期" : "单门报名", width: 110)
                                contractCell(
                                    consent.consentedAt.formatted(date: .abbreviated, time: .shortened),
                                    width: 190,
                                    mono: true
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 54)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func documentHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(ContractDocumentColumn.allCases) { column in
                MDTableColumnHeader(
                    title: column.title,
                    width: column.width,
                    isSorted: documentSortColumn == column,
                    ascending: documentSortAscending,
                    options: documentFilterOptions(for: column),
                    selectedValues: mdTableFilterSelection(
                        storage: $documentFiltersStorage,
                        key: column.rawValue
                    ),
                    onSort: { toggleDocumentSort(column) }
                )
            }
            Text("操作")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 70)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private func consentHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(ContractConsentColumn.allCases) { column in
                MDTableColumnHeader(
                    title: column.title,
                    width: column.width,
                    isSorted: consentSortColumn == column,
                    ascending: consentSortAscending,
                    options: consentFilterOptions(for: column),
                    selectedValues: mdTableFilterSelection(
                        storage: $consentFiltersStorage,
                        key: column.rawValue
                    ),
                    onSort: { toggleConsentSort(column) }
                )
            }
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private var filteredDocuments: [ContractDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = model.contractDocuments.filter { document in
            let matchesSearch = query.isEmpty || [
                document.title,
                document.version,
                document.bodyText,
                model.term(id: document.termID)?.name ?? ""
            ].contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesSearch && matchesDocumentFilters(document)
        }
        guard let documentSortColumn else { return result }
        result.sort { documentOrderedBefore($0, $1, by: documentSortColumn) }
        return result
    }

    private var filteredConsents: [ContractConsent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = model.contractConsents.filter { consent in
            let matchesSearch = query.isEmpty
                || consent.signerDisplayName.localizedCaseInsensitiveContains(query)
                || consent.contractVersion.localizedCaseInsensitiveContains(query)
            return matchesSearch && matchesConsentFilters(consent)
        }
        guard let consentSortColumn else { return result }
        result.sort { consentOrderedBefore($0, $1, by: consentSortColumn) }
        return result
    }

    private var section: ContractSection {
        get { ContractSection(rawValue: sectionStorage) ?? .documents }
        nonmutating set { sectionStorage = newValue.rawValue }
    }

    private var sectionSelection: Binding<ContractSection> {
        Binding(get: { section }, set: { section = $0 })
    }

    private var documentSortColumn: ContractDocumentColumn? {
        get { ContractDocumentColumn(rawValue: documentSortColumnStorage) }
        nonmutating set { documentSortColumnStorage = newValue?.rawValue ?? "" }
    }

    private var consentSortColumn: ContractConsentColumn? {
        get { ContractConsentColumn(rawValue: consentSortColumnStorage) }
        nonmutating set { consentSortColumnStorage = newValue?.rawValue ?? "" }
    }

    private func toggleDocumentSort(_ column: ContractDocumentColumn) {
        if documentSortColumn == column {
            documentSortAscending.toggle()
        } else {
            documentSortColumn = column
            documentSortAscending = true
        }
    }

    private func toggleConsentSort(_ column: ContractConsentColumn) {
        if consentSortColumn == column {
            consentSortAscending.toggle()
        } else {
            consentSortColumn = column
            consentSortAscending = true
        }
    }

    private func documentFilterOptions(for column: ContractDocumentColumn) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            model.contractDocuments,
            key: { documentColumnKey($0, column: column) },
            label: { documentColumnLabel($0, column: column) }
        )
    }

    private func consentFilterOptions(for column: ContractConsentColumn) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            model.contractConsents,
            key: { consentColumnKey($0, column: column) },
            label: { consentColumnLabel($0, column: column) }
        )
    }

    private func matchesDocumentFilters(_ document: ContractDocument) -> Bool {
        ContractDocumentColumn.allCases.allSatisfy { column in
            let values = MDTableFilterCodec.selection(in: documentFiltersStorage, for: column.rawValue)
            return values.isEmpty || values.contains(documentColumnKey(document, column: column))
        }
    }

    private func matchesConsentFilters(_ consent: ContractConsent) -> Bool {
        ContractConsentColumn.allCases.allSatisfy { column in
            let values = MDTableFilterCodec.selection(in: consentFiltersStorage, for: column.rawValue)
            return values.isEmpty || values.contains(consentColumnKey(consent, column: column))
        }
    }

    private func documentColumnKey(
        _ document: ContractDocument,
        column: ContractDocumentColumn
    ) -> String {
        switch column {
        case .title: document.title
        case .version: document.version
        case .term: document.termID.description
        case .status: document.status.rawValue
        case .publishedAt: document.publishedAt?.formatted(.iso8601.year().month().day()) ?? "unpublished"
        case .wordCount: String(document.bodyText.count)
        }
    }

    private func documentColumnLabel(
        _ document: ContractDocument,
        column: ContractDocumentColumn
    ) -> String {
        switch column {
        case .title: document.title
        case .version: document.version
        case .term: model.term(id: document.termID)?.name ?? "—"
        case .status: statusLabel(document.status)
        case .publishedAt: document.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "未发布"
        case .wordCount: "\(document.bodyText.count) 字"
        }
    }

    private func consentColumnKey(
        _ consent: ContractConsent,
        column: ContractConsentColumn
    ) -> String {
        switch column {
        case .signer: consent.signerDisplayName
        case .signature: consent.signaturePNG == nil ? "missing" : "stored"
        case .version: consent.contractVersion
        case .scope: consent.enrollmentID == nil ? "term" : "enrollment"
        case .consentedAt: consent.consentedAt.formatted(.iso8601.year().month().day())
        }
    }

    private func consentColumnLabel(
        _ consent: ContractConsent,
        column: ContractConsentColumn
    ) -> String {
        switch column {
        case .signer: consent.signerDisplayName
        case .signature: consent.signaturePNG == nil ? "未存档" : "已存档"
        case .version: consent.contractVersion
        case .scope: consent.enrollmentID == nil ? "整个学期" : "单门报名"
        case .consentedAt: consent.consentedAt.formatted(date: .abbreviated, time: .shortened)
        }
    }

    private func documentOrderedBefore(
        _ lhs: ContractDocument,
        _ rhs: ContractDocument,
        by column: ContractDocumentColumn
    ) -> Bool {
        if column == .wordCount, lhs.bodyText.count != rhs.bodyText.count {
            return documentSortAscending
                ? lhs.bodyText.count < rhs.bodyText.count
                : lhs.bodyText.count > rhs.bodyText.count
        }
        if column == .publishedAt {
            let left = lhs.publishedAt ?? .distantFuture
            let right = rhs.publishedAt ?? .distantFuture
            if left != right { return documentSortAscending ? left < right : left > right }
        }
        let comparison = documentColumnLabel(lhs, column: column)
            .localizedStandardCompare(documentColumnLabel(rhs, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return documentSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func consentOrderedBefore(
        _ lhs: ContractConsent,
        _ rhs: ContractConsent,
        by column: ContractConsentColumn
    ) -> Bool {
        if column == .consentedAt, lhs.consentedAt != rhs.consentedAt {
            return consentSortAscending ? lhs.consentedAt < rhs.consentedAt : lhs.consentedAt > rhs.consentedAt
        }
        let comparison = consentColumnLabel(lhs, column: column)
            .localizedStandardCompare(consentColumnLabel(rhs, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return consentSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func statusLabel(_ status: ContractDocumentStatus) -> String {
        switch status {
        case .draft: "草稿"
        case .published: "已发布"
        case .retired: "已停用"
        }
    }

    private func delete(_ document: ContractDocument) {
        deletion = nil
        errorMessage = nil
        Task {
            do {
                try await model.deleteContractDocument(document)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum ContractSection: String {
    case documents
    case consents
}

private enum ContractDocumentColumn: String, CaseIterable, Identifiable {
    case title
    case version
    case term
    case status
    case publishedAt
    case wordCount

    var id: String { rawValue }

    var title: String {
        switch self {
        case .title: "协议名称"
        case .version: "版本"
        case .term: "学期"
        case .status: "状态"
        case .publishedAt: "发布时间"
        case .wordCount: "字数"
        }
    }

    var width: CGFloat {
        switch self {
        case .title: 250
        case .version: 90
        case .term: 170
        case .status: 90
        case .publishedAt: 150
        case .wordCount: 70
        }
    }
}

private enum ContractConsentColumn: String, CaseIterable, Identifiable {
    case signer
    case signature
    case version
    case scope
    case consentedAt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signer: "签署人"
        case .signature: "签字"
        case .version: "合同版本"
        case .scope: "范围"
        case .consentedAt: "同意时间"
        }
    }

    var width: CGFloat {
        switch self {
        case .signer: 190
        case .signature: 130
        case .version: 120
        case .scope: 110
        case .consentedAt: 190
        }
    }
}

private struct ContractSignatureThumbnail: View {
    let signaturePNG: Data?

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        if let image = signaturePNG.flatMap(NSImage.init(data:)) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(4)
                .frame(width: 108, height: 36)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isHovering ? theme.accent : theme.separator, lineWidth: 1)
                }
                .scaleEffect(isHovering ? 1.04 : 1)
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
                .popover(isPresented: $isHovering, arrowEdge: .trailing) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("签字原图")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.primaryText)

                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .padding(14)
                            .frame(width: 340, height: 160)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.separator, lineWidth: 1)
                            }
                    }
                    .padding(12)
                }
                .help("悬停查看大图")
                .accessibilityLabel("签字缩略图")
        } else {
            Text("未存档")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 108, height: 36)
        }
    }
}

private struct ContractDocumentEditorView: View {
    let model: AppModel
    let original: ContractDocument?

    @State private var termID: TermID?
    @State private var title: String
    @State private var bodyText: String
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, document: ContractDocument?) {
        self.model = model
        original = document
        _termID = State(initialValue: document?.termID ?? model.terms.first?.id)
        _title = State(initialValue: document?.title ?? ContractAgreementTemplate.placeholderTitle)
        _bodyText = State(
            initialValue: document?.bodyText.isEmpty == false
                ? document?.bodyText ?? ContractAgreementTemplate.placeholderBody
                : ContractAgreementTemplate.placeholderBody
        )
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: original == nil ? "发布协议" : "发布协议新版本")
                Spacer()
                Button("取消") { dismiss() }
                Button("保存并发布") { save() }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("所属学期")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.secondaryText)
                        Picker("所属学期", selection: $termID) {
                            ForEach(model.terms) { term in
                                Text(term.name).tag(Optional(term.id))
                            }
                        }
                        .labelsHidden()
                        .frame(minWidth: 220)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("协议名称")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.secondaryText)
                        TextField("协议名称", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 360)
                    }
                }

                HStack {
                    Text("协议正文")
                        .mdFont(.bodyStrong)
                    Spacer()
                    Text("\(bodyText.count) 字")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }

                TextEditor(text: $bodyText)
                    .mdFont(.body)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(theme.raisedSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .stroke(theme.separator, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .frame(minHeight: 440)

                Label(
                    "保存后会发布新版本；所有监护人下次登录时都需要重新阅读并签名。",
                    systemImage: "signature"
                )
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)

                if let errorMessage {
                    Text(errorMessage)
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 650)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private var canSave: Bool {
        termID != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20
    }

    private func save() {
        guard let termID else { return }
        let isCreating = original == nil
        model.performBackgroundOperation(
            label: isCreating ? "发布协议" : "发布协议新版本",
            successMessage: isCreating ? "协议已发布" : "协议新版本已发布"
        ) {
            try await model.publishContractRevision(
                termID: termID,
                title: title,
                bodyText: bodyText
            )
        }
        dismiss()
    }
}

@MainActor
private func contractCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text)
        .mdFont(mono ? .mono : (strong ? .bodyStrong : .body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
