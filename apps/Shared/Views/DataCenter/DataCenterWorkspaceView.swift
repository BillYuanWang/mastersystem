#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct DataCenterWorkspaceView: View {
    let model: AppModel

    @State private var section = DataCenterSection.terms
    @State private var searchText = ""
    @State private var editor: DataCenterEditor?
    @State private var deletion: DataCenterDeletion?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "数据中心")

                Picker("资料类别", selection: $section) {
                    ForEach(DataCenterSection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 650)

                Spacer(minLength: 8)

                if let errorMessage {
                    Text(errorMessage)
                        .font(MDType.compact)
                        .foregroundStyle(theme.danger)
                        .lineLimit(1)
                }

                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(MDType.compact)
                    .frame(width: 150)

                Menu {
                    if section == .terms {
                        Button("添加学期") { editor = .term(nil) }
                        Button("添加假期") { editor = .holiday(nil) }
                    } else {
                        Button("添加\(section.singularTitle)") {
                            editor = section.newEditor
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .buttonStyle(MDIconButtonStyle())
                .help("添加资料")
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            content(theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .sheet(item: $editor) { item in
            editorView(item)
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { deletion != nil },
                set: { if !$0 { deletion = nil } }
            ),
            presenting: deletion
        ) { item in
            Button("删除", role: .destructive) { performDelete(item) }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("确定删除“\(item.name)”吗？已被其他资料使用的项目不会被删除。")
        }
    }

    @ViewBuilder
    private func content(theme: MDTheme) -> some View {
        switch section {
        case .terms:
            termsAndHolidays(theme: theme)
        case .instructors:
            referenceTable(
                headers: [("老师", 200), ("备注", 260), ("状态", 90)],
                rows: filtered(model.instructors, text: { [$0.displayName, $0.notes ?? ""] }),
                name: { $0.displayName },
                values: { [$0.displayName, $0.notes ?? "—", $0.isActive ? "启用" : "停用"] },
                edit: { editor = .instructor($0) },
                delete: { deletion = .instructor($0.id, $0.displayName) },
                theme: theme
            )
        case .ageGroups:
            referenceTable(
                headers: [("年龄段", 200), ("备注", 260), ("状态", 90)],
                rows: filtered(model.ageGroups, text: { [$0.name, $0.notes ?? ""] }),
                name: { $0.name },
                values: { [$0.name, $0.notes ?? "—", $0.isActive ? "启用" : "停用"] },
                edit: { editor = .ageGroup($0) },
                delete: { deletion = .ageGroup($0.id, $0.name) },
                theme: theme
            )
        case .rooms:
            referenceTable(
                headers: [("教室", 240), ("状态", 90)],
                rows: filtered(model.rooms, text: { [$0.name] }),
                name: { $0.name },
                values: { [$0.name, $0.isActive ? "启用" : "停用"] },
                edit: { editor = .room($0) },
                delete: { deletion = .room($0.id, $0.name) },
                theme: theme
            )
        case .categories:
            referenceTable(
                headers: [("课程分类", 240), ("状态", 90)],
                rows: filtered(model.categories, text: { [$0.name] }),
                name: { $0.name },
                values: { [$0.name, $0.isActive ? "启用" : "停用"] },
                edit: { editor = .category($0) },
                delete: { deletion = .category($0.id, $0.name) },
                theme: theme
            )
        case .courseTypes:
            referenceTable(
                headers: [("课程种类", 180), ("属性", 90), ("备注", 240), ("状态", 90)],
                rows: filtered(model.courseTypes, text: { [$0.name, $0.notes ?? ""] }),
                name: { $0.name },
                values: {
                    [$0.name, $0.isPrivate ? "私课" : "组课", $0.notes ?? "—", $0.isActive ? "启用" : "停用"]
                },
                edit: { editor = .courseType($0) },
                delete: { deletion = .courseType($0.id, $0.name) },
                theme: theme
            )
        }
    }

    private func termsAndHolidays(theme: MDTheme) -> some View {
        HSplitView {
            VStack(spacing: 0) {
                dataHeader(
                    title: "学期",
                    count: model.terms.count,
                    action: { editor = .term(nil) },
                    theme: theme
                )
                rowHeader([("名称", 150), ("开始", 92), ("结束", 92), ("状态", 66)], theme: theme)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered(model.terms, text: { [$0.name] })) { term in
                            HStack(spacing: 0) {
                                dataCell(term.name, width: 150, strong: true)
                                dataCell(shortDate(term.startsOn), width: 92, mono: true)
                                dataCell(shortDate(term.endsOn), width: 92, mono: true)
                                dataCell(termStatus(term.status), width: 66)
                                rowActions(
                                    edit: { editor = .term(term) },
                                    delete: { deletion = .term(term.id, term.name) }
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 40)
                            Divider()
                        }
                    }
                }
            }
            .frame(minWidth: 470)

            VStack(spacing: 0) {
                dataHeader(
                    title: "假期",
                    count: model.termHolidays.count,
                    action: { editor = .holiday(nil) },
                    theme: theme
                )
                rowHeader([("假期", 150), ("所属学期", 140), ("开始", 92), ("结束", 92)], theme: theme)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredHolidays) { holiday in
                            HStack(spacing: 0) {
                                dataCell(holiday.name, width: 150, strong: true)
                                dataCell(model.term(id: holiday.termID)?.name ?? "—", width: 140)
                                dataCell(shortDate(holiday.startsOn), width: 92, mono: true)
                                dataCell(shortDate(holiday.endsOn), width: 92, mono: true)
                                rowActions(
                                    edit: { editor = .holiday(holiday) },
                                    delete: { deletion = .holiday(holiday.id, holiday.name) }
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 40)
                            .help(holiday.notes ?? "")
                            Divider()
                        }
                    }
                }
            }
            .frame(minWidth: 540)
        }
    }

    private func referenceTable<Value: Identifiable>(
        headers: [(String, CGFloat)],
        rows: [Value],
        name: @escaping (Value) -> String,
        values: @escaping (Value) -> [String],
        edit: @escaping (Value) -> Void,
        delete: @escaping (Value) -> Void,
        theme: MDTheme
    ) -> some View {
        VStack(spacing: 0) {
            rowHeader(headers, theme: theme)
            if rows.isEmpty {
                ContentUnavailableView(
                    "暂无\(section.singularTitle)",
                    systemImage: section.systemImage,
                    description: Text("点击右上角加号创建。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            HStack(spacing: 0) {
                                ForEach(Array(zip(values(row), headers).enumerated()), id: \.offset) { index, pair in
                                    dataCell(
                                        pair.0,
                                        width: pair.1.1,
                                        strong: index == 0
                                    )
                                }
                                rowActions(
                                    edit: { edit(row) },
                                    delete: { delete(row) }
                                )
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 40)
                            .help(name(row))
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func dataHeader(
        title: String,
        count: Int,
        action: @escaping () -> Void,
        theme: MDTheme
    ) -> some View {
        HStack {
            Text(title).font(MDType.bodyStrong)
            Text("\(count)").font(MDType.mono).foregroundStyle(theme.secondaryText)
            Spacer()
            Button(action: action) { Image(systemName: "plus") }
                .buttonStyle(MDIconButtonStyle())
                .help("添加\(title)")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
    }

    private func rowHeader(_ columns: [(String, CGFloat)], theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                dataCell(column.0, width: column.1, strong: true)
                    .foregroundStyle(theme.secondaryText)
            }
            Text("操作")
                .font(MDType.compactStrong)
                .foregroundStyle(theme.secondaryText)
                .frame(width: 70)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private func rowActions(edit: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        HStack(spacing: 3) {
            Button(action: edit) { Image(systemName: "pencil") }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑")
            Button(action: delete) { Image(systemName: "trash") }
                .buttonStyle(MDIconButtonStyle())
                .help("删除")
        }
        .frame(width: 70)
    }

    private func filtered<Value>(_ values: [Value], text: (Value) -> [String]) -> [Value] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return values }
        return values.filter { value in
            text(value).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var filteredHolidays: [TermHoliday] {
        filtered(model.termHolidays) {
            [$0.name, $0.notes ?? "", model.term(id: $0.termID)?.name ?? ""]
        }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private func termStatus(_ status: TermStatus) -> String {
        switch status {
        case .draft: "草稿"
        case .open: "开放"
        case .closed: "结束"
        }
    }

    @ViewBuilder
    private func editorView(_ item: DataCenterEditor) -> some View {
        switch item {
        case let .term(term):
            TermDataEditorView(model: model, term: term)
        case let .holiday(holiday):
            HolidayDataEditorView(model: model, holiday: holiday)
        case let .category(value):
            ReferenceDataEditorView(model: model, target: .category(value))
        case let .courseType(value):
            ReferenceDataEditorView(model: model, target: .courseType(value))
        case let .ageGroup(value):
            ReferenceDataEditorView(model: model, target: .ageGroup(value))
        case let .room(value):
            ReferenceDataEditorView(model: model, target: .room(value))
        case let .instructor(value):
            ReferenceDataEditorView(model: model, target: .instructor(value))
        }
    }

    private func performDelete(_ item: DataCenterDeletion) {
        deletion = nil
        errorMessage = nil
        Task {
            do {
                switch item {
                case let .term(id, _): try await model.deleteTerm(id: id)
                case let .holiday(id, _): try await model.deleteTermHoliday(id: id)
                case let .category(id, _): try await model.deleteCourseCategory(id: id)
                case let .courseType(id, _): try await model.deleteCourseType(id: id)
                case let .ageGroup(id, _): try await model.deleteAgeGroup(id: id)
                case let .room(id, _): try await model.deleteRoom(id: id)
                case let .instructor(id, _): try await model.deleteInstructor(id: id)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum DataCenterSection: String, CaseIterable, Identifiable {
    case terms
    case instructors
    case ageGroups
    case rooms
    case categories
    case courseTypes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: "学期与假期"
        case .instructors: "老师"
        case .ageGroups: "年龄段"
        case .rooms: "教室"
        case .categories: "课程分类"
        case .courseTypes: "课程种类"
        }
    }

    var singularTitle: String { title }

    var systemImage: String {
        switch self {
        case .terms: "calendar"
        case .instructors: "person.crop.rectangle"
        case .ageGroups: "person.2"
        case .rooms: "door.left.hand.open"
        case .categories: "square.grid.2x2"
        case .courseTypes: "tag"
        }
    }

    var newEditor: DataCenterEditor? {
        switch self {
        case .terms: nil
        case .instructors: .instructor(nil)
        case .ageGroups: .ageGroup(nil)
        case .rooms: .room(nil)
        case .categories: .category(nil)
        case .courseTypes: .courseType(nil)
        }
    }
}

private enum DataCenterEditor: Identifiable {
    case term(Term?)
    case holiday(TermHoliday?)
    case category(CourseCategory?)
    case courseType(CourseType?)
    case ageGroup(AgeGroup?)
    case room(Room?)
    case instructor(Instructor?)

    var id: String {
        switch self {
        case let .term(value): "term-\(value?.id.description ?? "new")"
        case let .holiday(value): "holiday-\(value?.id.description ?? "new")"
        case let .category(value): "category-\(value?.id.description ?? "new")"
        case let .courseType(value): "type-\(value?.id.description ?? "new")"
        case let .ageGroup(value): "age-\(value?.id.description ?? "new")"
        case let .room(value): "room-\(value?.id.description ?? "new")"
        case let .instructor(value): "instructor-\(value?.id.description ?? "new")"
        }
    }
}

private enum DataCenterDeletion {
    case term(TermID, String)
    case holiday(TermHolidayID, String)
    case category(CourseCategoryID, String)
    case courseType(CourseTypeID, String)
    case ageGroup(AgeGroupID, String)
    case room(RoomID, String)
    case instructor(InstructorID, String)

    var name: String {
        switch self {
        case let .term(_, name),
             let .holiday(_, name),
             let .category(_, name),
             let .courseType(_, name),
             let .ageGroup(_, name),
             let .room(_, name),
             let .instructor(_, name):
            name
        }
    }
}

private struct TermDataEditorView: View {
    let model: AppModel
    let original: Term?

    @State private var name: String
    @State private var startsOn: Date
    @State private var endsOn: Date
    @State private var status: TermStatus
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, term: Term?) {
        self.model = model
        original = term
        _name = State(initialValue: term?.name ?? "")
        _startsOn = State(initialValue: term?.startsOn ?? Date())
        _endsOn = State(
            initialValue: term?.endsOn
                ?? Calendar.masterDance.date(byAdding: .month, value: 4, to: Date())
                ?? Date()
        )
        _status = State(initialValue: term?.status ?? .draft)
    }

    var body: some View {
        Form {
            MDSectionTitle(chinese: original == nil ? "添加学期" : "编辑学期")
            TextField("学期名称", text: $name)
            DatePicker("开始日期", selection: $startsOn, displayedComponents: .date)
            DatePicker("结束日期", selection: $endsOn, displayedComponents: .date)
            Picker("状态", selection: $status) {
                Text("草稿").tag(TermStatus.draft)
                Text("开放").tag(TermStatus.open)
                Text("结束").tag(TermStatus.closed)
            }
            editorError(errorMessage)
            editorButtons(isSaving: isSaving, canSave: canSave, dismiss: dismiss, save: save)
        }
        .formStyle(.grouped)
        .frame(width: 430)
        .padding(8)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startsOn <= endsOn
    }

    private func save() {
        isSaving = true
        var value = original ?? Term(name: name, startsOn: startsOn, endsOn: endsOn, status: status)
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.startsOn = startsOn
        value.endsOn = endsOn
        value.status = status
        Task {
            do {
                try await model.saveTerm(value)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct HolidayDataEditorView: View {
    let model: AppModel
    let original: TermHoliday?

    @State private var termID: TermID?
    @State private var name: String
    @State private var startsOn: Date
    @State private var endsOn: Date
    @State private var notes: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, holiday: TermHoliday?) {
        self.model = model
        original = holiday
        let term = holiday.flatMap { value in model.term(id: value.termID) } ?? model.terms.first
        _termID = State(initialValue: holiday?.termID ?? term?.id)
        _name = State(initialValue: holiday?.name ?? "")
        _startsOn = State(initialValue: holiday?.startsOn ?? term?.startsOn ?? Date())
        _endsOn = State(initialValue: holiday?.endsOn ?? term?.startsOn ?? Date())
        _notes = State(initialValue: holiday?.notes ?? "")
    }

    var body: some View {
        Form {
            MDSectionTitle(chinese: original == nil ? "添加假期" : "编辑假期")
            Picker("所属学期", selection: $termID) {
                ForEach(model.terms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            TextField("假期名称", text: $name)
            DatePicker("开始日期", selection: $startsOn, displayedComponents: .date)
            DatePicker("结束日期", selection: $endsOn, displayedComponents: .date)
            TextField("备注", text: $notes, axis: .vertical)
                .lineLimit(2...4)
            editorError(errorMessage)
            editorButtons(isSaving: isSaving, canSave: canSave, dismiss: dismiss, save: save)
        }
        .formStyle(.grouped)
        .frame(width: 430)
        .padding(8)
    }

    private var canSave: Bool {
        termID != nil
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && startsOn <= endsOn
    }

    private func save() {
        guard let termID else { return }
        isSaving = true
        var value = original ?? TermHoliday(
            termID: termID,
            name: name,
            startsOn: startsOn,
            endsOn: endsOn
        )
        value.termID = termID
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.startsOn = startsOn
        value.endsOn = endsOn
        value.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        Task {
            do {
                try await model.saveTermHoliday(value)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private enum ReferenceEditorTarget {
    case category(CourseCategory?)
    case courseType(CourseType?)
    case ageGroup(AgeGroup?)
    case room(Room?)
    case instructor(Instructor?)

    var title: String {
        switch self {
        case .category: "课程分类"
        case .courseType: "课程种类"
        case .ageGroup: "年龄段"
        case .room: "教室"
        case .instructor: "老师"
        }
    }
}

private struct ReferenceDataEditorView: View {
    let model: AppModel
    let target: ReferenceEditorTarget

    @State private var name: String
    @State private var notes: String
    @State private var isActive: Bool
    @State private var isPrivate: Bool
    @State private var errorMessage: String?
    @State private var isSaving = false

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, target: ReferenceEditorTarget) {
        self.model = model
        self.target = target
        switch target {
        case let .category(value):
            _name = State(initialValue: value?.name ?? "")
            _notes = State(initialValue: "")
            _isActive = State(initialValue: value?.isActive ?? true)
            _isPrivate = State(initialValue: false)
        case let .courseType(value):
            _name = State(initialValue: value?.name ?? "")
            _notes = State(initialValue: value?.notes ?? "")
            _isActive = State(initialValue: value?.isActive ?? true)
            _isPrivate = State(initialValue: value?.isPrivate ?? false)
        case let .ageGroup(value):
            _name = State(initialValue: value?.name ?? "")
            _notes = State(initialValue: value?.notes ?? "")
            _isActive = State(initialValue: value?.isActive ?? true)
            _isPrivate = State(initialValue: false)
        case let .room(value):
            _name = State(initialValue: value?.name ?? "")
            _notes = State(initialValue: "")
            _isActive = State(initialValue: value?.isActive ?? true)
            _isPrivate = State(initialValue: false)
        case let .instructor(value):
            _name = State(initialValue: value?.displayName ?? "")
            _notes = State(initialValue: value?.notes ?? "")
            _isActive = State(initialValue: value?.isActive ?? true)
            _isPrivate = State(initialValue: false)
        }
    }

    var body: some View {
        Form {
            MDSectionTitle(chinese: "编辑\(target.title)")
            TextField("名称", text: $name)
            if showsNotes {
                TextField("备注", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            if case .courseType = target {
                Toggle("属于私课", isOn: $isPrivate)
            }
            Toggle("启用", isOn: $isActive)
            editorError(errorMessage)
            editorButtons(
                isSaving: isSaving,
                canSave: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                dismiss: dismiss,
                save: save
            )
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding(8)
    }

    private var showsNotes: Bool {
        switch target {
        case .courseType, .ageGroup, .instructor: true
        case .category, .room: false
        }
    }

    private func save() {
        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        Task {
            do {
                switch target {
                case let .category(original):
                    var value = original ?? CourseCategory(name: trimmedName)
                    value.name = trimmedName
                    value.isActive = isActive
                    try await model.saveCourseCategory(value)
                case let .courseType(original):
                    var value = original ?? CourseType(name: trimmedName, isPrivate: isPrivate)
                    value.name = trimmedName
                    value.isPrivate = isPrivate
                    value.notes = trimmedNotes
                    value.isActive = isActive
                    try await model.saveCourseType(value)
                case let .ageGroup(original):
                    var value = original ?? AgeGroup(name: trimmedName)
                    value.name = trimmedName
                    value.notes = trimmedNotes
                    value.isActive = isActive
                    try await model.saveAgeGroup(value)
                case let .room(original):
                    var value = original ?? Room(name: trimmedName)
                    value.name = trimmedName
                    value.isActive = isActive
                    try await model.saveRoom(value)
                case let .instructor(original):
                    var value = original ?? Instructor(displayName: trimmedName)
                    value.displayName = trimmedName
                    value.notes = trimmedNotes
                    value.isActive = isActive
                    try await model.saveInstructor(value)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

@ViewBuilder
private func editorError(_ message: String?) -> some View {
    if let message {
        Text(message)
            .font(MDType.compact)
            .foregroundStyle(.red)
    }
}

@MainActor
private func editorButtons(
    isSaving: Bool,
    canSave: Bool,
    dismiss: DismissAction,
    save: @escaping () -> Void
) -> some View {
    HStack {
        Spacer()
        Button("取消") { dismiss() }
        Button("保存", action: save)
            .keyboardShortcut(.defaultAction)
            .disabled(isSaving || !canSave)
    }
}

private func dataCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text)
        .font(mono ? MDType.mono : (strong ? MDType.bodyStrong : MDType.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
