#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct SetupWorkspaceView: View {
    let model: AppModel

    @State private var section = SetupSection.courses
    @State private var searchText = ""
    @State private var showingCourseEditor = false
    @State private var showingTermEditor = false
    @State private var showingReferenceEditor = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "课程", english: "COURSES")

                Picker("设置", selection: $section) {
                    ForEach(SetupSection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Spacer()

                if section != .references {
                    TextField("搜索", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .font(MDType.compact)
                        .frame(width: 170)
                }

                Button {
                    showEditorForCurrentSection()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help(addButtonHelp)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            Group {
                switch section {
                case .courses:
                    CourseSheetView(model: model, searchText: searchText)
                case .terms:
                    TermSheetView(model: model, searchText: searchText)
                case .references:
                    ReferenceDataView(model: model, showAdd: { showingReferenceEditor = true })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
        .sheet(isPresented: $showingCourseEditor) {
            CourseEditorView(model: model)
        }
        .sheet(isPresented: $showingTermEditor) {
            TermEditorView(model: model)
        }
        .sheet(isPresented: $showingReferenceEditor) {
            ReferenceEditorView(model: model)
        }
    }

    private var addButtonHelp: String {
        switch section {
        case .courses: "添加课程"
        case .terms: "添加学期"
        case .references: "添加自定义资料"
        }
    }

    private func showEditorForCurrentSection() {
        switch section {
        case .courses: showingCourseEditor = true
        case .terms: showingTermEditor = true
        case .references: showingReferenceEditor = true
        }
    }
}

private struct CourseSheetView: View {
    let model: AppModel
    let searchText: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            courseHeader(theme: theme)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCourses) { course in
                        courseRow(course, theme: theme)
                        Rectangle()
                            .fill(theme.faintSeparator)
                            .frame(height: 1)
                    }
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private func courseHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            headerCell("课程名称", width: 190)
            headerCell("分类", width: 105)
            headerCell("年龄段", width: 95)
            headerCell("教室", width: 85)
            headerCell("老师", width: 90)
            headerCell("每周时间", width: 155)
            headerCell("课次", width: 60)
            headerCell("类型", width: 55)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func courseRow(_ course: Course, theme: MDTheme) -> some View {
        let courseSessions = model.sessions(forCourse: course.id)
        let firstSession = courseSessions.first
        return HStack(spacing: 0) {
            dataCell(course.name, width: 190, strong: true)
            dataCell(model.category(id: course.categoryID)?.name ?? "—", width: 105)
            dataCell(model.ageGroup(id: course.ageGroupID)?.name ?? "—", width: 95)
            dataCell(model.room(id: course.defaultRoomID)?.name ?? "—", width: 85)
            dataCell(model.instructor(id: course.defaultInstructorID)?.displayName ?? "—", width: 90)
            dataCell(firstSession.map(scheduleLabel) ?? "未排课", width: 155)
            dataCell("\(courseSessions.count)", width: 60, monospaced: true)
            HStack {
                Text(course.format == .privateLesson ? "私" : "组")
                    .font(MDType.compactStrong)
                    .frame(width: 21, height: 21)
                    .overlay(Circle().stroke(theme.secondaryText, lineWidth: 1))
            }
            .frame(width: 55)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .help(course.notes ?? "")
    }

    private var filteredCourses: [Course] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.courses }
        return model.courses.filter { course in
            let values = [
                course.name,
                model.category(id: course.categoryID)?.name ?? "",
                model.ageGroup(id: course.ageGroupID)?.name ?? "",
                model.room(id: course.defaultRoomID)?.name ?? "",
                model.instructor(id: course.defaultInstructorID)?.displayName ?? ""
            ]
            return values.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func scheduleLabel(_ session: ClassSession) -> String {
        let weekday = session.startsAt.formatted(.dateTime.weekday(.abbreviated))
        let start = session.startsAt.formatted(date: .omitted, time: .shortened)
        let end = session.endsAt.formatted(date: .omitted, time: .shortened)
        return "\(weekday) \(start)–\(end)"
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
            referenceColumn(kind: .category, values: model.categories.map(\.name), theme: theme)
            Divider()
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
                    .font(MDType.bodyStrong)
                Spacer()
                Text("\(values.count)")
                    .font(MDType.mono)
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
                                .font(MDType.body)
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
                    .font(MDType.compact)
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

    @State private var kind = ReferenceKind.category
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
            Text("这里没有系统预设；分类、年龄段、教室和老师都由你维护。")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
            if let errorMessage {
                Text(errorMessage)
                    .font(MDType.compact)
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

private func headerCell(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .font(MDType.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

private func dataCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    monospaced: Bool = false
) -> some View {
    Text(text)
        .font(monospaced ? MDType.mono : (strong ? MDType.bodyStrong : MDType.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
