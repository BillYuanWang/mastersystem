#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct NewsWorkspaceView: View {
    let model: AppModel

    @State private var filter = NewsWorkspaceFilter.all
    @State private var searchText = ""
    @State private var selectedArticleID: NewsArticleID?
    @State private var editingArticle: NewsArticle?
    @State private var showingNewArticle = false
    @State private var deletingArticle: NewsArticle?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)

            HSplitView {
                articleTable(theme: theme)
                    .frame(minWidth: 560)

                articleInspector(theme: theme)
                    .frame(minWidth: 280, idealWidth: 330, maxWidth: 390)
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .sheet(isPresented: $showingNewArticle) {
            NewsArticleEditorView(model: model, article: nil)
        }
        .sheet(item: $editingArticle) { article in
            NewsArticleEditorView(model: model, article: article)
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { deletingArticle != nil },
                set: { if !$0 { deletingArticle = nil } }
            ),
            presenting: deletingArticle
        ) { article in
            Button("删除", role: .destructive) { delete(article) }
            Button("取消", role: .cancel) {}
        } message: { article in
            Text("确定永久删除“\(article.title)”及其全部图片吗？此操作无法撤销。")
        }
        .onChange(of: filteredArticles.map(\.id), initial: true) { _, ids in
            if let selectedArticleID, ids.contains(selectedArticleID) { return }
            selectedArticleID = ids.first
        }
    }

    private func header(theme: MDTheme) -> some View {
        HStack(spacing: 12) {
            MDSectionTitle(chinese: "新闻")

            HStack(spacing: 8) {
                NewsHeaderMetric(title: "已发布", value: publishedCount, color: theme.success)
                NewsHeaderMetric(title: "草稿", value: draftCount, color: theme.warning)
            }

            Picker("状态", selection: $filter) {
                ForEach(NewsWorkspaceFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 270)

            Spacer(minLength: 8)

            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
                    .lineLimit(1)
            }

            TextField("搜索新闻", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.compact)
                .frame(width: 180)

            Button {
                showingNewArticle = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("新建新闻")
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func articleTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                newsCell("标题", width: 300, strong: true)
                newsCell("状态", width: 82, strong: true)
                newsCell("作者", width: 110, strong: true)
                newsCell("发布日期", width: 145, strong: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.secondaryText)
            .frame(height: 34)
            .background(theme.subtleSurface)

            if filteredArticles.isEmpty {
                ContentUnavailableView(
                    "暂无新闻",
                    systemImage: "newspaper",
                    description: Text("点击右上角加号创建第一篇新闻。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredArticles) { article in
                            Button {
                                selectedArticleID = article.id
                            } label: {
                                HStack(spacing: 0) {
                                    newsCell(article.title, width: 300, strong: true)
                                    newsCell(statusTitle(article.status), width: 82)
                                        .foregroundStyle(statusColor(article.status, theme: theme))
                                    newsCell(article.authorName, width: 110)
                                    newsCell(
                                        article.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "—",
                                        width: 145,
                                        mono: true
                                    )
                                    Spacer(minLength: 0)
                                }
                                .frame(minHeight: 44)
                                .background(
                                    selectedArticleID == article.id
                                        ? theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.09)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded { editingArticle = article }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func articleInspector(theme: MDTheme) -> some View {
        if let article = selectedArticle {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NewsMediaView(
                        model: model,
                        image: model.newsCover(for: article.id),
                        contentMode: .fit
                    )
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(theme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

                    HStack {
                        Label(statusTitle(article.status), systemImage: statusImage(article.status))
                            .mdFont(.compactStrong)
                            .foregroundStyle(statusColor(article.status, theme: theme))
                        Spacer()
                        Text("\(model.newsImages(for: article.id).count) 张图")
                            .mdFont(.mono)
                            .foregroundStyle(theme.secondaryText)
                    }

                    Text(article.title)
                        .mdFont(size: 18, weight: .bold)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(article.previewText)
                        .mdFont(.body)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(5)

                    Divider()

                    LabeledContent("作者", value: article.authorName)
                    LabeledContent(
                        "发布时间",
                        value: article.publishedAt?.formatted(date: .long, time: .shortened) ?? "尚未发布"
                    )
                    LabeledContent(
                        "最后修改",
                        value: article.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent("正文", value: "\(article.bodyText.count) 字")

                    HStack(spacing: 8) {
                        Button("编辑") { editingArticle = article }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)

                        Button("删除", role: .destructive) { deletingArticle = article }
                            .buttonStyle(.bordered)
                    }
                }
                .mdFont(.body)
                .padding(16)
            }
            .background(theme.raisedSurface)
        } else {
            ContentUnavailableView("选择一篇新闻", systemImage: "newspaper")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.raisedSurface)
        }
    }

    private var filteredArticles: [NewsArticle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.newsArticles.filter { article in
            filter.matches(article.status)
                && (query.isEmpty || [article.title, article.authorName, article.previewText]
                    .contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private var selectedArticle: NewsArticle? {
        selectedArticleID.flatMap { id in model.newsArticles.first { $0.id == id } }
    }

    private var publishedCount: Int {
        model.newsArticles.filter { $0.status == .published }.count
    }

    private var draftCount: Int {
        model.newsArticles.filter { $0.status == .draft }.count
    }

    private func delete(_ article: NewsArticle) {
        deletingArticle = nil
        errorMessage = nil
        model.performBackgroundOperation(
            label: "删除新闻",
            successMessage: "新闻已删除",
            completion: { result in
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        ) {
            try await model.deleteNewsArticle(article)
        }
    }

    private func statusTitle(_ status: NewsArticleStatus) -> String {
        switch status {
        case .draft: "草稿"
        case .published: "已发布"
        case .archived: "已撤回"
        }
    }

    private func statusImage(_ status: NewsArticleStatus) -> String {
        switch status {
        case .draft: "square.and.pencil"
        case .published: "checkmark.circle.fill"
        case .archived: "archivebox"
        }
    }

    private func statusColor(_ status: NewsArticleStatus, theme: MDTheme) -> Color {
        switch status {
        case .draft: theme.warning
        case .published: theme.success
        case .archived: theme.secondaryText
        }
    }
}

private enum NewsWorkspaceFilter: String, CaseIterable, Identifiable {
    case all
    case published
    case draft
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .published: "已发布"
        case .draft: "草稿"
        case .archived: "已撤回"
        }
    }

    func matches(_ status: NewsArticleStatus) -> Bool {
        switch self {
        case .all: true
        case .published: status == .published
        case .draft: status == .draft
        case .archived: status == .archived
        }
    }
}

private struct NewsHeaderMetric: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .mdFont(.compact)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .mdFont(.monoStrong)
                .foregroundStyle(color)
        }
    }
}

@MainActor
private struct NewsArticleEditorView: View {
    let model: AppModel
    let original: NewsArticle?

    @State private var title: String
    @State private var summary: String
    @State private var bodyText: String
    @State private var authorName: String
    @State private var imageDrafts: [NewsImageEditorDraft]
    @State private var deletedImages: [NewsArticleImage] = []
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, article: NewsArticle?) {
        self.model = model
        original = article
        _title = State(initialValue: article?.title ?? "")
        _summary = State(initialValue: article?.summary ?? "")
        _bodyText = State(initialValue: article?.bodyText ?? "")
        _authorName = State(initialValue: article?.authorName ?? "Master Dance")
        _imageDrafts = State(
            initialValue: article.map { article in
                model.newsImages(for: article.id).map { NewsImageEditorDraft(image: $0) }
            } ?? []
        )
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            editorHeader(theme: theme)
            Divider()

            HSplitView {
                articleFields(theme: theme)
                    .frame(minWidth: 540)

                mediaFields(theme: theme)
                    .frame(minWidth: 290, idealWidth: 330, maxWidth: 390)
            }
        }
        .frame(minWidth: 900, idealWidth: 980, minHeight: 690, idealHeight: 760)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func editorHeader(theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            MDSectionTitle(chinese: original == nil ? "新建新闻" : "编辑新闻")
            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
                    .lineLimit(1)
            }

            Button("取消") { dismiss() }

            if original?.status == .published {
                Button("撤回") { save(status: .archived) }
                    .buttonStyle(.bordered)
                Button("保存修改") { save(status: .published) }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave || coverDraft == nil)
            } else {
                Button("保存草稿") { save(status: .draft) }
                    .buttonStyle(.bordered)
                    .disabled(!canSave)
                Button(original?.status == .archived ? "重新发布" : "发布") {
                    save(status: .published)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave || coverDraft == nil)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    private func articleFields(theme: MDTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    field(title: "标题", required: true) {
                        TextField("例如：秋季课程开放报名", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: .infinity)

                    field(title: "作者", required: true) {
                        TextField("例如：Master Dance", text: $authorName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(width: 210)
                }

                field(title: "首页摘要", required: false) {
                    TextField("不填写时自动采用正文首行", text: $summary)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("正文")
                        .mdFont(.bodyStrong)
                    Text("必填")
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                    Spacer()
                    Text("\(paragraphCount) 段 · \(bodyText.count) 字")
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
                    .frame(minHeight: 470)

                Text("正文中用空行分段；右侧可指定每张图片插在第几段之后。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(18)
        }
    }

    private func mediaFields(theme: MDTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("封面图")
                        .mdFont(.bodyStrong)
                    Text("发布必填")
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                    Text("建议 1:1")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Button {
                        chooseCover()
                    } label: {
                        Label(coverDraft == nil ? "添加" : "更换", systemImage: "photo")
                    }
                    .buttonStyle(.borderless)
                }

                coverPreview(theme: theme)

                Text("封面用于新闻列表缩略图；建议使用 1:1 图片，系统会完整显示，不会裁切。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)

                Divider()

                HStack {
                    Text("正文图片")
                        .mdFont(.bodyStrong)
                    Spacer()
                    Button {
                        addBodyImages()
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                if bodyImageDrafts.isEmpty {
                    Text("可添加多张图片，并指定图片在正文中的位置。")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .center)
                } else {
                    ForEach($imageDrafts) { $draft in
                        if draft.image.kind == .body {
                            bodyImageEditor(draft: $draft, theme: theme)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(theme.raisedSurface)
    }

    @ViewBuilder
    private func coverPreview(theme: MDTheme) -> some View {
        if let coverDraft {
            ZStack(alignment: .topTrailing) {
                draftImage(coverDraft, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(theme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

                Button {
                    removeImage(id: coverDraft.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.65))
                }
                .buttonStyle(.plain)
                .padding(7)
                .help("移除封面")
            }
        } else {
            Button {
                chooseCover()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 28, weight: .light))
                    Text("选择封面图")
                        .mdFont(.compactStrong)
                }
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(theme.subtleSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, style: StrokeStyle(lineWidth: 1, dash: [5]))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func bodyImageEditor(
        draft: Binding<NewsImageEditorDraft>,
        theme: MDTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                draftImage(draft.wrappedValue)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(theme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

                Button {
                    removeImage(id: draft.wrappedValue.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.65))
                }
                .buttonStyle(.plain)
                .padding(7)
                .help("移除图片")
            }

            TextField(
                "图片说明（选填）",
                text: Binding(
                    get: { draft.wrappedValue.image.caption ?? "" },
                    set: { draft.wrappedValue.image.caption = $0 }
                )
            )
            .textFieldStyle(.roundedBorder)

            Stepper(
                value: Binding(
                    get: { min(draft.wrappedValue.image.placementAfterParagraph ?? lastParagraphIndex, lastParagraphIndex) },
                    set: { draft.wrappedValue.image.placementAfterParagraph = $0 }
                ),
                in: 0...lastParagraphIndex
            ) {
                Text("放在第 \(min(draft.wrappedValue.image.placementAfterParagraph ?? lastParagraphIndex, lastParagraphIndex) + 1) 段后")
                    .mdFont(.compact)
            }
        }
        .padding(10)
        .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
    }

    @ViewBuilder
    private func draftImage(
        _ draft: NewsImageEditorDraft,
        contentMode: ContentMode = .fill
    ) -> some View {
        if let data = draft.fileData {
            NewsDataImage(data: data, contentMode: contentMode)
        } else {
            NewsMediaView(model: model, image: draft.image, contentMode: contentMode)
        }
    }

    private func field<Content: View>(
        title: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Text(title)
                    .mdFont(.compactStrong)
                    .foregroundStyle(.secondary)
                if required {
                    Text("必填")
                        .mdFont(.compact)
                        .foregroundStyle(.red)
                }
            }
            content()
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var articleID: NewsArticleID {
        original?.id ?? pendingArticleID
    }

    private var pendingArticleID: NewsArticleID {
        // The view lifetime owns the draft identity through the first image or save.
        if let id = imageDrafts.first?.image.articleID { return id }
        return generatedArticleID
    }

    @State private var generatedArticleID = NewsArticleID()

    private var coverDraft: NewsImageEditorDraft? {
        imageDrafts.first { $0.image.kind == .cover }
    }

    private var bodyImageDrafts: [NewsImageEditorDraft] {
        imageDrafts.filter { $0.image.kind == .body }
    }

    private var paragraphCount: Int {
        max(1, draftArticle.paragraphs.count)
    }

    private var lastParagraphIndex: Int {
        max(0, paragraphCount - 1)
    }

    private var draftArticle: NewsArticle {
        NewsArticle(
            id: original?.id ?? generatedArticleID,
            title: title,
            summary: summary,
            bodyText: bodyText,
            authorName: authorName,
            status: original?.status ?? .draft,
            publishedAt: original?.publishedAt,
            createdAt: original?.createdAt ?? Date(),
            updatedAt: original?.updatedAt ?? Date()
        )
    }

    private func chooseCover() {
        guard let selection = chooseImages(allowsMultipleSelection: false).first else { return }
        if let index = imageDrafts.firstIndex(where: { $0.image.kind == .cover }) {
            imageDrafts[index].fileData = selection.data
            imageDrafts[index].image.mimeType = selection.mimeType
        } else {
            imageDrafts.insert(
                NewsImageEditorDraft(
                    image: NewsArticleImage(
                        articleID: articleID,
                        kind: .cover,
                        mimeType: selection.mimeType
                    ),
                    fileData: selection.data
                ),
                at: 0
            )
        }
    }

    private func addBodyImages() {
        let selections = chooseImages(allowsMultipleSelection: true)
        guard !selections.isEmpty else { return }
        let startingOrder = bodyImageDrafts.count
        imageDrafts.append(contentsOf: selections.enumerated().map { offset, selection in
            NewsImageEditorDraft(
                image: NewsArticleImage(
                    articleID: articleID,
                    kind: .body,
                    mimeType: selection.mimeType,
                    sortOrder: startingOrder + offset,
                    placementAfterParagraph: lastParagraphIndex
                ),
                fileData: selection.data
            )
        })
    }

    private func chooseImages(allowsMultipleSelection: Bool) -> [NewsImageSelection] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "选择"
        guard panel.runModal() == .OK else { return [] }

        let allowed = Set(["image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"])
        var selections: [NewsImageSelection] = []
        for url in panel.urls {
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? ""
            guard allowed.contains(mimeType) else {
                errorMessage = "仅支持 JPEG、PNG、HEIC 和 WebP 图片。"
                continue
            }
            do {
                let prepared = try ImageUploadOptimizer.prepare(
                    data: Data(contentsOf: url),
                    sourceMimeType: mimeType,
                    maximumByteCount: NewsImageUploadRules.maximumFileByteCount,
                    maximumPixelDimension: NewsImageUploadRules.maximumPixelDimension
                )
                selections.append(
                    NewsImageSelection(data: prepared.data, mimeType: prepared.mimeType)
                )
            } catch {
                errorMessage = "\(url.lastPathComponent)：\(error.localizedDescription)"
            }
        }
        return selections
    }

    private func removeImage(id: NewsArticleImageID) {
        guard let index = imageDrafts.firstIndex(where: { $0.id == id }) else { return }
        let removed = imageDrafts.remove(at: index)
        if !removed.image.storagePath.isEmpty {
            deletedImages.append(removed.image)
        }
    }

    private func save(status: NewsArticleStatus) {
        errorMessage = nil
        guard canSave else {
            errorMessage = "请填写标题、作者和正文。"
            return
        }
        if status == .published, coverDraft == nil {
            errorMessage = "发布前请添加封面图。"
            return
        }

        var article = draftArticle
        article.status = status
        article.publishedAt = status == .published ? (original?.publishedAt ?? Date()) : original?.publishedAt

        let uploads = imageDrafts.enumerated().map { index, draft -> NewsImageUpload in
            var image = draft.image
            image.sortOrder = image.kind == .cover ? 0 : index
            if image.kind == .body {
                image.placementAfterParagraph = min(
                    image.placementAfterParagraph ?? lastParagraphIndex,
                    lastParagraphIndex
                )
            }
            return NewsImageUpload(image: image, fileData: draft.fileData)
        }

        let label: String
        switch status {
        case .draft: label = "新闻草稿已保存"
        case .published: label = original?.status == .published ? "新闻修改已发布" : "新闻已发布"
        case .archived: label = "新闻已撤回"
        }
        model.performBackgroundOperation(label: "保存新闻", successMessage: label) {
            try await model.saveNewsArticle(article, images: uploads, deletedImages: deletedImages)
        }
        dismiss()
    }
}

private struct NewsImageEditorDraft: Identifiable {
    var image: NewsArticleImage
    var fileData: Data?

    var id: NewsArticleImageID { image.id }
}

private struct NewsImageSelection {
    let data: Data
    let mimeType: String
}

private enum NewsImageUploadRules {
    // Keep a margin below the live Storage limit so upload framing never crosses it.
    static let maximumFileByteCount = 8 * 1_024 * 1_024
    static let maximumPixelDimension = 4_096
}

@MainActor
private func newsCell(
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
