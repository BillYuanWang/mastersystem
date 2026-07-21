#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct AdvertisementsWorkspaceView: View {
    let model: AppModel

    @State private var filter = AdvertisementWorkspaceFilter.all
    @State private var searchText = ""
    @State private var selectedAdvertisementID: AdvertisementID?
    @State private var editingAdvertisement: Advertisement?
    @State private var showingNewAdvertisement = false
    @State private var deletingAdvertisement: Advertisement?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)

            HSplitView {
                advertisementTable(theme: theme)
                    .frame(minWidth: 660)

                advertisementInspector(theme: theme)
                    .frame(minWidth: 300, idealWidth: 350, maxWidth: 410)
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .sheet(isPresented: $showingNewAdvertisement) {
            AdvertisementEditorView(model: model, advertisement: nil)
        }
        .sheet(item: $editingAdvertisement) { advertisement in
            AdvertisementEditorView(model: model, advertisement: advertisement)
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { deletingAdvertisement != nil },
                set: { if !$0 { deletingAdvertisement = nil } }
            ),
            presenting: deletingAdvertisement
        ) { advertisement in
            Button("删除", role: .destructive) { delete(advertisement) }
            Button("取消", role: .cancel) {}
        } message: { advertisement in
            Text("确定永久删除“\(advertisement.advertiserName)”及其两张广告图片吗？此操作无法撤销。")
        }
        .onChange(of: filteredAdvertisements.map(\.id), initial: true) { _, ids in
            if let selectedAdvertisementID, ids.contains(selectedAdvertisementID) { return }
            selectedAdvertisementID = ids.first
        }
    }

    private func header(theme: MDTheme) -> some View {
        HStack(spacing: 12) {
            MDSectionTitle(chinese: "广告")

            AdvertisementHeaderMetric(
                title: "投放中",
                value: activeAdvertisements.count,
                suffix: "/5",
                color: theme.success
            )
            AdvertisementHeaderMetric(
                title: "空余",
                value: max(0, 5 - Set(activeAdvertisements.map(\.slotNumber)).count),
                suffix: "位",
                color: theme.accent
            )
            HStack(spacing: 5) {
                Text("月单价")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                Text("$99")
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.warning)
            }

            Picker("状态", selection: $filter) {
                ForEach(AdvertisementWorkspaceFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 112)

            Spacer(minLength: 8)

            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
                    .lineLimit(1)
            }

            TextField("搜索广告", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.compact)
                .frame(width: 170)

            Button {
                showingNewAdvertisement = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("新建广告")
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func advertisementTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                advertisementCell("广告位", width: 72, strong: true)
                advertisementCell("客户 / 品牌", width: 190, strong: true)
                advertisementCell("投放日期", width: 205, strong: true)
                advertisementCell("状态", width: 88, strong: true)
                advertisementCell("预计费用", width: 105, strong: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.secondaryText)
            .frame(height: 34)
            .background(theme.subtleSurface)

            if filteredAdvertisements.isEmpty {
                ContentUnavailableView(
                    model.advertisements.isEmpty ? "暂无广告" : "没有符合条件的广告",
                    systemImage: "megaphone",
                    description: Text(model.advertisements.isEmpty ? "点击右上角加号创建第一个广告。" : "尝试更改筛选或搜索条件。")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredAdvertisements) { advertisement in
                            let state = AdvertisementPresentationState(advertisement: advertisement)
                            Button {
                                selectedAdvertisementID = advertisement.id
                            } label: {
                                HStack(spacing: 0) {
                                    advertisementCell("#\(advertisement.slotNumber)", width: 72, strong: true, mono: true)
                                    advertisementCell(advertisement.advertiserName, width: 190, strong: true)
                                    advertisementCell(dateRange(advertisement), width: 205, mono: true)
                                    advertisementCell(state.title, width: 88)
                                        .foregroundStyle(state.color(theme: theme))
                                    advertisementCell(currency(advertisement.estimatedTotalCents), width: 105, mono: true)
                                    Spacer(minLength: 0)
                                }
                                .frame(minHeight: 44)
                                .background(
                                    selectedAdvertisementID == advertisement.id
                                        ? theme.accent.opacity(colorScheme == .dark ? 0.18 : 0.09)
                                        : Color.clear
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded { editingAdvertisement = advertisement }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func advertisementInspector(theme: MDTheme) -> some View {
        if let advertisement = selectedAdvertisement {
            let state = AdvertisementPresentationState(advertisement: advertisement)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        AdvertisementMediaView(
                            model: model,
                            media: advertisement.thumbnail,
                            contentMode: .fit
                        )
                        .frame(width: 108, height: 108)
                        .background(theme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                        .overlay {
                            RoundedRectangle(cornerRadius: MDMetrics.radius)
                                .stroke(theme.faintSeparator, lineWidth: 1)
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            Text(advertisement.advertiserName)
                                .mdFont(size: 18, weight: .bold)
                                .fixedSize(horizontal: false, vertical: true)
                            Label(state.title, systemImage: state.systemImage)
                                .mdFont(.compactStrong)
                                .foregroundStyle(state.color(theme: theme))
                            Text("广告位 #\(advertisement.slotNumber)")
                                .mdFont(.mono)
                                .foregroundStyle(theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(advertisement.copyText)
                        .mdFont(.body)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    LabeledContent("起始日", value: advertisement.startsOn.formatted(date: .long, time: .omitted))
                    LabeledContent("终止日", value: advertisement.endsOn.formatted(date: .long, time: .omitted))
                    LabeledContent("计费月数", value: "\(advertisement.billableMonthCount) 个月")
                    LabeledContent("预计费用", value: currency(advertisement.estimatedTotalCents))

                    VStack(alignment: .leading, spacing: 7) {
                        Text("iPhone 竖版海报")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.secondaryText)
                        AdvertisementMediaView(
                            model: model,
                            media: advertisement.poster,
                            contentMode: .fit
                        )
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4 / 5, contentMode: .fit)
                        .background(theme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                        .overlay {
                            RoundedRectangle(cornerRadius: MDMetrics.radius)
                                .stroke(theme.faintSeparator, lineWidth: 1)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("编辑") { editingAdvertisement = advertisement }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)

                        if advertisement.status == .published {
                            Button("撤下") { archive(advertisement) }
                                .buttonStyle(.bordered)
                        }

                        Button("删除", role: .destructive) { deletingAdvertisement = advertisement }
                            .buttonStyle(.bordered)
                    }
                }
                .mdFont(.body)
                .padding(16)
            }
            .background(theme.raisedSurface)
        } else {
            ContentUnavailableView("选择一条广告", systemImage: "megaphone")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.raisedSurface)
        }
    }

    private var filteredAdvertisements: [Advertisement] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.advertisements.filter { advertisement in
            filter.matches(AdvertisementPresentationState(advertisement: advertisement))
                && (query.isEmpty || [advertisement.advertiserName, advertisement.copyText]
                    .contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private var selectedAdvertisement: Advertisement? {
        selectedAdvertisementID.flatMap { id in model.advertisements.first { $0.id == id } }
    }

    private var activeAdvertisements: [Advertisement] {
        model.activeAdvertisements()
    }

    private func archive(_ advertisement: Advertisement) {
        var archived = advertisement
        archived.status = .archived
        errorMessage = nil
        model.performBackgroundOperation(
            label: "撤下广告",
            successMessage: "广告已撤下",
            completion: { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
        ) {
            try await model.saveAdvertisement(archived, thumbnailData: nil, posterData: nil)
        }
    }

    private func delete(_ advertisement: Advertisement) {
        deletingAdvertisement = nil
        errorMessage = nil
        model.performBackgroundOperation(
            label: "删除广告",
            successMessage: "广告已删除",
            completion: { result in
                if case .failure(let error) = result { errorMessage = error.localizedDescription }
            }
        ) {
            try await model.deleteAdvertisement(advertisement)
        }
    }
}

private enum AdvertisementWorkspaceFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case scheduled
    case draft
    case ended
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .active: "投放中"
        case .scheduled: "待开始"
        case .draft: "草稿"
        case .ended: "已结束"
        case .archived: "已撤下"
        }
    }

    func matches(_ state: AdvertisementPresentationState) -> Bool {
        switch self {
        case .all: true
        case .active: state == .active
        case .scheduled: state == .scheduled
        case .draft: state == .draft
        case .ended: state == .ended
        case .archived: state == .archived
        }
    }
}

private enum AdvertisementPresentationState: Equatable {
    case active
    case scheduled
    case ended
    case draft
    case archived

    init(advertisement: Advertisement, now: Date = Date(), calendar: Calendar = .masterDance) {
        switch advertisement.status {
        case .draft:
            self = .draft
        case .archived:
            self = .archived
        case .published:
            let day = calendar.startOfDay(for: now)
            if day < calendar.startOfDay(for: advertisement.startsOn) {
                self = .scheduled
            } else if day > calendar.startOfDay(for: advertisement.endsOn) {
                self = .ended
            } else {
                self = .active
            }
        }
    }

    var title: String {
        switch self {
        case .active: "投放中"
        case .scheduled: "待开始"
        case .ended: "已结束"
        case .draft: "草稿"
        case .archived: "已撤下"
        }
    }

    var systemImage: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .scheduled: "clock.fill"
        case .ended: "calendar.badge.checkmark"
        case .draft: "square.and.pencil"
        case .archived: "archivebox"
        }
    }

    @MainActor
    func color(theme: MDTheme) -> Color {
        switch self {
        case .active: theme.success
        case .scheduled: theme.accent
        case .ended, .archived: theme.secondaryText
        case .draft: theme.warning
        }
    }
}

private struct AdvertisementHeaderMetric: View {
    let title: String
    let value: Int
    let suffix: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .mdFont(.compact)
                .foregroundStyle(.secondary)
            Text("\(value)\(suffix)")
                .mdFont(.monoStrong)
                .foregroundStyle(color)
        }
    }
}

@MainActor
private struct AdvertisementEditorView: View {
    let model: AppModel
    let original: Advertisement?

    @State private var draft: Advertisement
    @State private var thumbnailData: Data?
    @State private var posterData: Data?
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, advertisement: Advertisement?) {
        self.model = model
        original = advertisement
        let calendar = Calendar.masterDance
        let start = calendar.startOfDay(for: Date())
        let endExclusive = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? start
        let occupiedSlots = Set(model.activeAdvertisements(on: start).map(\.slotNumber))
        let defaultSlot = AdvertisementRules.slotRange.first { !occupiedSlots.contains($0) } ?? 1
        _draft = State(
            initialValue: advertisement ?? Advertisement(
                slotNumber: defaultSlot,
                advertiserName: "",
                copyText: "",
                startsOn: start,
                endsOn: end
            )
        )
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            editorHeader(theme: theme)
            Divider()

            HSplitView {
                detailsForm(theme: theme)
                    .frame(minWidth: 500)

                mediaForm(theme: theme)
                    .frame(minWidth: 320, idealWidth: 370, maxWidth: 430)
            }
        }
        .frame(minWidth: 920, idealWidth: 1_020, minHeight: 700, idealHeight: 780)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .onChange(of: draft.advertiserName) { _, value in
            if value.count > AdvertisementRules.maximumAdvertiserNameCount {
                draft.advertiserName = String(value.prefix(AdvertisementRules.maximumAdvertiserNameCount))
            }
        }
        .onChange(of: draft.copyText) { _, value in
            if value.count > AdvertisementRules.maximumCopyCount {
                draft.copyText = String(value.prefix(AdvertisementRules.maximumCopyCount))
            }
        }
        .onChange(of: draft.startsOn) { _, value in
            if draft.endsOn < value { setDuration(months: 1) }
        }
    }

    private func editorHeader(theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            MDSectionTitle(chinese: original == nil ? "新建广告" : "编辑广告")
            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(theme.danger)
                    .lineLimit(1)
            }

            Button("取消") { dismiss() }

            if original?.status == .published {
                Button("撤下") { save(status: .archived) }
                    .buttonStyle(.bordered)
                Button("保存投放") { save(status: .published) }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canPublish)
            } else {
                Button("保存草稿") { save(status: .draft) }
                    .buttonStyle(.bordered)
                    .disabled(!canSaveDraft)
                Button(original?.status == .archived ? "重新投放" : "发布") {
                    save(status: .published)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canPublish)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }

    private func detailsForm(theme: MDTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top, spacing: 16) {
                    editorField(title: "广告位", required: true) {
                        Picker("广告位", selection: $draft.slotNumber) {
                            ForEach(Array(AdvertisementRules.slotRange), id: \.self) { slot in
                                Text("#\(slot)").tag(slot)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }

                    editorField(title: "首页标题 / 品牌名称", required: true) {
                        VStack(alignment: .trailing, spacing: 5) {
                            TextField("例如：美西餐饮", text: $draft.advertiserName)
                                .textFieldStyle(.roundedBorder)
                            Text("\(draft.advertiserName.count) / \(AdvertisementRules.maximumAdvertiserNameCount)")
                                .mdFont(.mono)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                editorField(title: "广告正文", required: true) {
                    VStack(alignment: .trailing, spacing: 5) {
                        TextEditor(text: $draft.copyText)
                            .mdFont(.body)
                            .scrollContentBackground(.hidden)
                            .padding(9)
                            .frame(minHeight: 210)
                            .background(theme.raisedSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: MDMetrics.radius)
                                    .stroke(theme.separator, lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                        Text("\(draft.copyText.count) / \(AdvertisementRules.maximumCopyCount)")
                            .mdFont(.mono)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Divider()

                Text("投放日期")
                    .mdFont(.bodyStrong)

                HStack(spacing: 18) {
                    DatePicker("起始日", selection: $draft.startsOn, displayedComponents: .date)
                    DatePicker("终止日", selection: $draft.endsOn, displayedComponents: .date)
                }
                .datePickerStyle(.field)

                HStack(spacing: 8) {
                    Text("快捷设置")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                    ForEach([1, 3, 6, 12], id: \.self) { months in
                        Button(months == 12 ? "一年" : "\(months)个月") {
                            setDuration(months: months)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if hasSlotConflict {
                    Label("广告位 #\(draft.slotNumber) 在这段日期内已有其他投放。", systemImage: "exclamationmark.triangle.fill")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.danger)
                }

                Divider()

                HStack(spacing: 0) {
                    pricingMetric(title: "月单价", value: "$99", theme: theme)
                    pricingDivider(theme: theme)
                    pricingMetric(title: "计费月数", value: "\(draft.billableMonthCount) 个月", theme: theme)
                    pricingDivider(theme: theme)
                    pricingMetric(title: "预计费用", value: currency(draft.estimatedTotalCents), theme: theme, emphasized: true)
                }
                .padding(.vertical, 14)
                .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))

                Text("不足一个完整月按一个月计算；结束日包含在投放周期内。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(20)
        }
    }

    private func mediaForm(theme: MDTheme) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                mediaSection(
                    title: "方形缩略图",
                    detail: "1:1 · 最低 600×600 · 自动优化至 7 MB 内",
                    media: draft.thumbnail,
                    data: thumbnailData,
                    aspectRatio: 1,
                    action: { chooseImage(kind: .thumbnail) },
                    theme: theme
                )

                Divider()

                mediaSection(
                    title: "广告海报",
                    detail: "任意比例 · 自动按比例优化至 7 MB 内",
                    media: draft.poster,
                    data: posterData,
                    aspectRatio: posterPreviewAspectRatio,
                    action: { chooseImage(kind: .poster) },
                    theme: theme
                )

                Text("支持 JPEG、PNG、HEIC。超限时会按比例自动缩小和压缩，不会裁切。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(18)
        }
        .background(theme.raisedSurface)
    }

    private func mediaSection(
        title: String,
        detail: String,
        media: AdvertisementMedia?,
        data: Data?,
        aspectRatio: CGFloat,
        action: @escaping () -> Void,
        theme: MDTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).mdFont(.bodyStrong)
                    Text(detail)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Button {
                    action()
                } label: {
                    Label(media == nil ? "添加" : "更换", systemImage: "photo")
                }
                .buttonStyle(.borderless)
            }

            Button(action: action) {
                Group {
                    if let data {
                        AdvertisementDataImage(data: data, contentMode: .fit)
                    } else if media != nil {
                        AdvertisementMediaView(model: model, media: media, contentMode: .fit)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 28, weight: .light))
                            Text("选择图片")
                                .mdFont(.compactStrong)
                        }
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(aspectRatio, contentMode: .fit)
                .background(theme.subtleSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, style: StrokeStyle(lineWidth: 1, dash: media == nil ? [5] : []))
                }
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
            }
            .buttonStyle(.plain)

            if let media {
                Text("\(media.pixelWidth)×\(media.pixelHeight) · \(ByteCountFormatter.string(fromByteCount: Int64(media.byteCount), countStyle: .file))")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func editorField<Content: View>(
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

    private func pricingMetric(
        title: String,
        value: String,
        theme: MDTheme,
        emphasized: Bool = false
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .mdFont(.monoStrong)
                .foregroundStyle(emphasized ? theme.accent : theme.primaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func pricingDivider(theme: MDTheme) -> some View {
        Rectangle()
            .fill(theme.separator)
            .frame(width: 1, height: 34)
    }

    private var canSaveDraft: Bool {
        !draft.advertiserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.copyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.startsOn <= draft.endsOn
    }

    private var canPublish: Bool {
        canSaveDraft
            && draft.thumbnail != nil
            && draft.poster != nil
            && !hasSlotConflict
    }

    private var posterPreviewAspectRatio: CGFloat {
        guard let poster = draft.poster,
              poster.pixelWidth > 0,
              poster.pixelHeight > 0 else {
            return 4 / 5
        }
        let sourceRatio = CGFloat(poster.pixelWidth) / CGFloat(poster.pixelHeight)
        return min(max(sourceRatio, 0.5), 1.8)
    }

    private var hasSlotConflict: Bool {
        model.advertisements.contains {
            $0.id != draft.id
                && $0.status == .published
                && $0.slotNumber == draft.slotNumber
                && $0.startsOn <= draft.endsOn
                && $0.endsOn >= draft.startsOn
        }
    }

    private func setDuration(months: Int) {
        let calendar = Calendar.masterDance
        let start = calendar.startOfDay(for: draft.startsOn)
        let endExclusive = calendar.date(byAdding: .month, value: months, to: start) ?? start
        draft.endsOn = calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? start
    }

    private func chooseImage(kind: AdvertisementImageKind) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "选择"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let selection = try advertisementImageSelection(url: url, kind: kind)
            switch kind {
            case .thumbnail:
                draft.thumbnail = selection.media
                thumbnailData = selection.data
            case .poster:
                draft.poster = selection.media
                posterData = selection.data
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func advertisementImageSelection(
        url: URL,
        kind: AdvertisementImageKind
    ) throws -> AdvertisementImageSelection {
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? ""
        guard ["image/jpeg", "image/png", "image/heic", "image/heif"].contains(mimeType) else {
            throw AdvertisementImageError.unsupportedType
        }
        let prepared = try ImageUploadOptimizer.prepare(
            data: Data(contentsOf: url),
            sourceMimeType: mimeType,
            maximumByteCount: AdvertisementImageUploadRules.maximumFileByteCount,
            maximumPixelDimension: AdvertisementRules.maximumPixelDimension
        )

        let isValid = switch kind {
        case .thumbnail:
            AdvertisementRules.isValidThumbnail(
                width: prepared.pixelWidth,
                height: prepared.pixelHeight
            )
        case .poster:
            AdvertisementRules.isValidPoster(
                width: prepared.pixelWidth,
                height: prepared.pixelHeight
            )
        }
        guard isValid else {
            throw kind == .thumbnail ? AdvertisementImageError.invalidThumbnail : AdvertisementImageError.invalidPoster
        }

        let previousPath = switch kind {
        case .thumbnail: draft.thumbnail?.storagePath ?? ""
        case .poster: draft.poster?.storagePath ?? ""
        }
        return AdvertisementImageSelection(
            media: AdvertisementMedia(
                storagePath: previousPath,
                mimeType: prepared.mimeType,
                pixelWidth: prepared.pixelWidth,
                pixelHeight: prepared.pixelHeight,
                byteCount: prepared.data.count
            ),
            data: prepared.data
        )
    }

    private func save(status: AdvertisementStatus) {
        errorMessage = nil
        if status == .published, !canPublish {
            errorMessage = hasSlotConflict
                ? "这个广告位在所选日期内已有其他广告。"
                : "请完成文字、日期和两张广告图片。"
            return
        }
        guard canSaveDraft else {
            errorMessage = "请填写广告名称、文字和有效日期。"
            return
        }

        var saved = draft
        saved.status = status
        let successMessage = switch status {
        case .draft: "广告草稿已保存"
        case .published: original?.status == .published ? "广告投放已更新" : "广告已发布"
        case .archived: "广告已撤下"
        }
        model.performBackgroundOperation(label: "保存广告", successMessage: successMessage) {
            try await model.saveAdvertisement(
                saved,
                thumbnailData: thumbnailData,
                posterData: posterData
            )
        }
        dismiss()
    }
}

private enum AdvertisementImageKind {
    case thumbnail
    case poster
}

private enum AdvertisementImageUploadRules {
    // Leave headroom below the 8 MB bucket limit used by advertisement metadata validation.
    static let maximumFileByteCount = 7 * 1_024 * 1_024
}

private struct AdvertisementImageSelection {
    let media: AdvertisementMedia
    let data: Data
}

private enum AdvertisementImageError: LocalizedError {
    case unsupportedType
    case invalidThumbnail
    case invalidPoster

    var errorDescription: String? {
        switch self {
        case .unsupportedType: "仅支持 JPEG、PNG 和 HEIC 图片。"
        case .invalidThumbnail: "缩略图必须为 1:1，原图至少 600×600。"
        case .invalidPoster: "无法读取这张广告海报，请更换图片。"
        }
    }
}

@MainActor
private func advertisementCell(
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

private func dateRange(_ advertisement: Advertisement) -> String {
    let start = advertisement.startsOn.formatted(.dateTime.year().month().day())
    let end = advertisement.endsOn.formatted(.dateTime.year().month().day())
    return "\(start) – \(end)"
}

private func currency(_ cents: Int) -> String {
    String(format: "$%.0f", Double(cents) / 100)
}
#endif
