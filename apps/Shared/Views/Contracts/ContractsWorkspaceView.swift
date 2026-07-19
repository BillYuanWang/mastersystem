#if os(macOS)
import MasterDanceCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct ContractsWorkspaceView: View {
    let model: AppModel

    @State private var section = ContractSection.documents
    @State private var searchText = ""
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

                Picker("合同内容", selection: $section) {
                    Text("合同文件").tag(ContractSection.documents)
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
                    .help("添加合同")
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
            contractHeader(
                [("合同名称", 220), ("版本", 110), ("学期", 170), ("状态", 90), ("发布时间", 150), ("文件", 70)],
                theme: theme
            )
            if filteredDocuments.isEmpty {
                ContentUnavailableView(
                    "暂无合同文件",
                    systemImage: "doc.text",
                    description: Text("点击右上角加号上传 PDF 合同。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredDocuments) { document in
                            HStack(spacing: 0) {
                                contractCell(document.title, width: 220, strong: true)
                                contractCell(document.version, width: 110, mono: true)
                                contractCell(model.term(id: document.termID)?.name ?? "—", width: 170)
                                contractCell(statusLabel(document.status), width: 90)
                                contractCell(
                                    document.publishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—",
                                    width: 150,
                                    mono: true
                                )
                                contractCell(document.storagePath.isEmpty ? "缺少" : "PDF", width: 70)
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
                            .help(document.storagePath)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func consentList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            contractHeader(
                [("签署人", 200), ("合同版本", 130), ("范围", 120), ("同意时间", 190)],
                theme: theme
            )
            if filteredConsents.isEmpty {
                ContentUnavailableView("暂无签署记录", systemImage: "signature")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConsents) { consent in
                            HStack(spacing: 0) {
                                contractCell(consent.signerDisplayName, width: 200, strong: true)
                                contractCell(consent.contractVersion, width: 130, mono: true)
                                contractCell(consent.enrollmentID == nil ? "整个学期" : "单门报名", width: 120)
                                contractCell(
                                    consent.consentedAt.formatted(date: .abbreviated, time: .shortened),
                                    width: 190,
                                    mono: true
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 42)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func contractHeader(_ columns: [(String, CGFloat)], theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                contractCell(column.0, width: column.1, strong: true)
                    .foregroundStyle(theme.secondaryText)
            }
            if section == .documents {
                Text("操作")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 70)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private var filteredDocuments: [ContractDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.contractDocuments }
        return model.contractDocuments.filter { document in
            [
                document.title,
                document.version,
                model.term(id: document.termID)?.name ?? ""
            ].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var filteredConsents: [ContractConsent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.contractConsents }
        return model.contractConsents.filter {
            $0.signerDisplayName.localizedCaseInsensitiveContains(query)
                || $0.contractVersion.localizedCaseInsensitiveContains(query)
        }
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

private enum ContractSection {
    case documents
    case consents
}

private struct ContractDocumentEditorView: View {
    let model: AppModel
    let original: ContractDocument?

    @State private var termID: TermID?
    @State private var title: String
    @State private var version: String
    @State private var status: ContractDocumentStatus
    @State private var fileData: Data?
    @State private var fileName: String?
    @State private var showingFileImporter = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, document: ContractDocument?) {
        self.model = model
        original = document
        _termID = State(initialValue: document?.termID ?? model.terms.first?.id)
        _title = State(initialValue: document?.title ?? "")
        _version = State(initialValue: document?.version ?? "")
        _status = State(initialValue: document?.status ?? .draft)
    }

    var body: some View {
        Form {
            MDSectionTitle(chinese: original == nil ? "添加合同" : "编辑合同")
            Picker("所属学期", selection: $termID) {
                ForEach(model.terms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            TextField("合同名称", text: $title)
            TextField("版本", text: $version)
            Picker("状态", selection: $status) {
                Text("草稿").tag(ContractDocumentStatus.draft)
                Text("已发布").tag(ContractDocumentStatus.published)
                Text("已停用").tag(ContractDocumentStatus.retired)
            }
            HStack {
                Text("PDF 文件")
                Spacer()
                Text(fileName ?? (original?.storagePath.isEmpty == false ? "已上传" : "未选择"))
                    .mdFont(.compact)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button("选择文件") { showingFileImporter = true }
            }
            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(8)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
    }

    private var canSave: Bool {
        termID != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (fileData != nil || original?.storagePath.isEmpty == false)
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            fileData = try Data(contentsOf: url)
            fileName = url.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = "无法读取这个 PDF：\(error.localizedDescription)"
        }
    }

    private func save() {
        guard let termID else { return }
        var document = original ?? ContractDocument(
            termID: termID,
            version: version,
            title: title
        )
        document.termID = termID
        document.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        document.version = version.trimmingCharacters(in: .whitespacesAndNewlines)
        document.status = status
        let fileDataSnapshot = fileData
        let isCreating = original == nil
        model.performBackgroundOperation(
            label: isCreating ? "上传合同" : "更新合同",
            successMessage: isCreating ? "合同已添加" : "合同已更新"
        ) {
            try await model.saveContractDocument(document, fileData: fileDataSnapshot)
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
