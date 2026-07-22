#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct SetupWorkspaceView: View {
    let model: AppModel

    @SceneStorage("md-desk.courses.selected-term-id") private var selectedTermIDStorage = ""
    @State private var searchText = ""
    @State private var showingCourseEditor = false
    @State private var editingCourse: Course?
    @State private var duplicatingCourse: Course?
    @State private var deletingCourse: Course?
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "课程")

                Spacer()

                if let errorMessage {
                    Text(errorMessage)
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                        .lineLimit(1)
                }

                Picker("学期", selection: selectedTermSelection) {
                    Text("全部学期").tag(Optional<TermID>.none)
                    ForEach(model.terms) { term in
                        Text(term.name).tag(Optional(term.id))
                    }
                }
                .labelsHidden()
                .mdFont(.body)
                .frame(width: 220)
                .help("选择要查看的学期；全部学期适合查找和复制历史课程")

                TextField("搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .mdFont(.compact)
                    .frame(width: 170)

                Button {
                    showingCourseEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("添加课程")
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            CourseSheetView(
                model: model,
                selectedTermID: selectedTermID,
                searchText: searchText,
                edit: { editingCourse = $0 },
                duplicate: { duplicatingCourse = $0 },
                delete: { deletingCourse = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
        .task(id: model.terms.map(\.id)) {
            chooseInitialTerm()
        }
        .sheet(isPresented: $showingCourseEditor) {
            CourseEditorView(model: model, initialTermID: selectedTermID)
        }
        .sheet(item: $editingCourse) { course in
            CourseEditorView(model: model, course: course)
        }
        .sheet(item: $duplicatingCourse) { course in
            CourseEditorView(model: model, duplicateOf: course)
        }
        .alert(
            "确认删除",
            isPresented: Binding(
                get: { deletingCourse != nil },
                set: { if !$0 { deletingCourse = nil } }
            ),
            presenting: deletingCourse
        ) { course in
            Button("删除", role: .destructive) {
                deletingCourse = nil
                Task {
                    do {
                        try await model.deleteCourse(id: course.id)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: { course in
            Text("确定删除“\(course.name)”吗？已有课次或报名的课程不会被删除，可以改为停用。")
        }
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

    private func chooseInitialTerm() {
        let preservesAllTerms = selectedTermIDStorage == "all"
        let hasValidTerm = selectedTermID.map { selectedID in
            model.terms.contains { $0.id == selectedID }
        } ?? false
        if selectedTermIDStorage.isEmpty || (!preservesAllTerms && !hasValidTerm) {
            selectedTermID = model.currentEnrollmentTerm?.id ?? model.terms.first?.id
        }
    }
}

private struct TermSheetView: View {
    let model: AppModel
    let searchText: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                headerCell("学期", width: 220)
                headerCell("开始日期", width: 150)
                headerCell("结束日期", width: 150)
                headerCell("自然周", width: 90)
                headerCell("状态", width: 100)
                Spacer()
            }
            .frame(height: 34)
            .background(theme.subtleSurface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredTerms) { term in
                        HStack(spacing: 0) {
                            dataCell(term.name, width: 220, strong: true)
                            dataCell(term.startsOn.formatted(date: .abbreviated, time: .omitted), width: 150)
                            dataCell(term.endsOn.formatted(date: .abbreviated, time: .omitted), width: 150)
                            dataCell("\(weekCount(term))", width: 90, monospaced: true)
                            dataCell(statusLabel(term.status), width: 100)
                            Spacer()
                        }
                        .frame(minHeight: 40)
                        Divider()
                    }
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private var filteredTerms: [Term] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? model.terms : model.terms.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private func weekCount(_ term: Term) -> Int {
        max(1, Int(term.endsOn.timeIntervalSince(term.startsOn) / (7 * 24 * 60 * 60)) + 1)
    }

    private func statusLabel(_ status: TermStatus) -> String {
        switch status {
        case .draft: "草稿"
        case .open: "开放"
        case .closed: "结束"
        }
    }
}

private struct ReferenceDataView: View {
    let model: AppModel
    let showAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 0) {
            referenceColumn(kind: .ageGroup, values: model.ageGroups.map(\.name), theme: theme)
            Divider()
            referenceColumn(kind: .room, values: model.rooms.map(\.name), theme: theme)
            Divider()
            referenceColumn(kind: .instructor, values: model.instructors.map(\.displayName), theme: theme)
        }
    }

    private func referenceColumn(kind: ReferenceKind, values: [String], theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label(kind.title, systemImage: kind.systemImage)
                    .mdFont(.bodyStrong)
                Spacer()
                Text("\(values.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                Button(action: showAdd) {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        HStack {
                            Text(value)
                                .mdFont(.body)
                            Spacer()
                            MDStatusDot(color: theme.success)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(theme.primaryText)
    }
}

private struct TermEditorView: View {
    let model: AppModel

    @State private var name = ""
    @State private var startsOn = Date()
    @State private var endsOn = Calendar.masterDance.date(byAdding: .month, value: 4, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加学期", english: "NEW TERM")
            TextField("学期名称", text: $name)
            DatePicker("开始日期", selection: $startsOn, displayedComponents: .date)
            DatePicker("结束日期", selection: $endsOn, displayedComponents: .date)
            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await model.createTerm(name: name, startsOn: startsOn, endsOn: endsOn)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct ReferenceEditorView: View {
    let model: AppModel

    @State private var kind = ReferenceKind.ageGroup
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加自定义资料", english: "NEW REFERENCE")
            Picker("资料类型", selection: $kind) {
                ForEach(ReferenceKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            TextField("名称", text: $name)
            Text("这里没有系统预设；年龄段、教室和老师都由你维护。")
                .mdFont(.compact)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage)
                    .mdFont(.compact)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await model.createReference(kind: kind, name: name)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

@MainActor
private func headerCell(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .mdFont(.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

@MainActor
private func dataCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    monospaced: Bool = false
) -> some View {
    Text(text)
        .mdFont(monospaced ? .mono : (strong ? .bodyStrong : .body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
