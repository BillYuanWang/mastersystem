#if os(macOS)
import MasterDanceCore
import SwiftUI

enum StudentWorkspaceSelection: Hashable {
    case guardian(GuardianID)
    case unassigned(StudentID)
}

private enum GuardianAccountFilter: String, CaseIterable, Identifiable {
    case all
    case linked
    case pending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .linked: "已连接"
        case .pending: "待认领"
        }
    }
}

@MainActor
struct StudentsWorkspaceView: View {
    let model: AppModel

    @State private var searchText = ""
    @State private var selection: StudentWorkspaceSelection?
    @State private var showingGuardianEditor = false
    @State private var accountFilter: GuardianAccountFilter = .all

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 0) {
                familyTable(theme: theme)

                Rectangle().fill(theme.separator).frame(width: 1)

                inspector
                    .frame(width: 390)
            }
        }
        .background(theme.background)
        .task(id: model.guardians.count + model.students.count) {
            chooseInitialSelection()
        }
        .onChange(of: accountFilter) { _, _ in
            chooseInitialSelection()
        }
        .onChange(of: searchText) { _, _ in
            chooseInitialSelection()
        }
        .onChange(of: model.guardians.map { $0.profileUserID }) { _, _ in
            chooseInitialSelection()
        }
        .sheet(isPresented: $showingGuardianEditor) {
            GuardianEditorView(model: model)
        }
    }

    private func header(theme: MDTheme) -> some View {
        HStack(spacing: 12) {
            MDSectionTitle(chinese: "家庭与学员")
            Text("\(model.guardians.count) 户 · \(model.students.count) 人")
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Picker("帐号状态", selection: $accountFilter) {
                ForEach(GuardianAccountFilter.allCases) { filter in
                    Text(filterTitle(for: filter)).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .mdFont(.compact)
            .frame(width: 250)
            TextField("搜索监护人、学员或课程", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.compact)
                .frame(width: 220)
            Button {
                Task { await model.refreshFromCloud() }
            } label: {
                Group {
                    if model.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 16, height: 16)
            }
            .buttonStyle(MDIconButtonStyle())
            .disabled(model.isLoading)
            .help("立即刷新云端资料")
            Button {
                showingGuardianEditor = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("添加监护人")
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func familyTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            tableHeader(theme: theme)

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    switch accountFilter {
                    case .all:
                        guardianSection(
                            title: "已连接家庭",
                            guardians: linkedGuardians,
                            isLinked: true,
                            theme: theme
                        )
                        guardianSection(
                            title: "待认领家庭",
                            guardians: pendingGuardians,
                            isLinked: false,
                            theme: theme
                        )
                    case .linked:
                        guardianSection(
                            title: "已连接家庭",
                            guardians: linkedGuardians,
                            isLinked: true,
                            theme: theme
                        )
                    case .pending:
                        guardianSection(
                            title: "待认领家庭",
                            guardians: pendingGuardians,
                            isLinked: false,
                            theme: theme
                        )
                    }

                    if !filteredUnassignedStudents.isEmpty {
                        HStack(spacing: 7) {
                            Image(systemName: "tray")
                            Text("待归档学员")
                            Text("\(filteredUnassignedStudents.count)")
                                .mdFont(.monoStrong)
                            Spacer()
                        }
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 820, minHeight: 34, alignment: .leading)
                        .background(theme.subtleSurface)

                        ForEach(filteredUnassignedStudents) { student in
                            unassignedRow(student, theme: theme)
                            Divider()
                        }
                    }

                    if filteredGuardians.isEmpty && filteredUnassignedStudents.isEmpty {
                        HStack {
                            Spacer()
                            ContentUnavailableView(
                                normalizedSearch.isEmpty ? "暂无家庭" : "没有搜索结果",
                                systemImage: "person.2",
                                description: Text(
                                    normalizedSearch.isEmpty
                                        ? "当前筛选下没有家庭记录。"
                                        : "请尝试其他姓名、联系方式或课程。"
                                )
                            )
                            Spacer()
                        }
                        .frame(minWidth: 820, minHeight: 220)
                    }
                }
                .frame(minWidth: 820, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(theme.primaryText)
    }

    private func tableHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            familyHeader("监护人", width: 150)
            familyHeader("联系方式", width: 210)
            familyHeader("学员档案", width: 280)
            familyHeader("帐号", width: 105)
            familyHeader("报名", width: 65)
            Spacer(minLength: 0)
        }
        .frame(minWidth: 820, minHeight: 34)
        .background(theme.subtleSurface)
    }

    private func guardianRow(_ guardian: Guardian, theme: MDTheme) -> some View {
        Button {
            selection = .guardian(guardian.id)
        } label: {
            HStack(spacing: 0) {
                familyCell(guardian.displayName, width: 150, strong: true)
                familyCell(contactSummary(for: guardian), width: 210)
                familyCell(learnerSummary(for: guardian), width: 280)
                accountCell(guardian, theme: theme)
                familyCell("\(enrollmentCount(for: guardian))", width: 65, mono: true)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 820, minHeight: 42)
            .contentShape(Rectangle())
            .background(
                selection == .guardian(guardian.id) ? theme.accent.opacity(0.11) : .clear
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func guardianSection(
        title: String,
        guardians: [Guardian],
        isLinked: Bool,
        theme: MDTheme
    ) -> some View {
        if !guardians.isEmpty {
            HStack(spacing: 7) {
                Circle()
                    .fill(isLinked ? theme.success : theme.warning)
                    .frame(width: 7, height: 7)
                Text(title)
                Text("\(guardians.count)")
                    .mdFont(.monoStrong)
                Spacer()
            }
            .mdFont(.compactStrong)
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, 10)
            .frame(minWidth: 820, minHeight: 34, alignment: .leading)
            .background(theme.subtleSurface)

            ForEach(guardians) { guardian in
                guardianRow(guardian, theme: theme)
                Divider()
            }
        }
    }

    private func unassignedRow(_ student: Student, theme: MDTheme) -> some View {
        Button {
            selection = .unassigned(student.id)
        } label: {
            HStack(spacing: 0) {
                familyCell("—", width: 150)
                familyCell("尚未关联", width: 210)
                familyCell(
                    student.displayName + (student.kind == .adult ? " · 成人" : " · 少儿"),
                    width: 280,
                    strong: true
                )
                familyCell("待归档", width: 105)
                familyCell("\(model.enrollments(for: student.id).count)", width: 65, mono: true)
                Spacer(minLength: 0)
            }
            .frame(minWidth: 820, minHeight: 42)
            .contentShape(Rectangle())
            .background(
                selection == .unassigned(student.id) ? theme.accent.opacity(0.11) : .clear
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var inspector: some View {
        switch selection {
        case .guardian(let guardianID):
            if let guardian = model.guardian(id: guardianID) {
                GuardianInspectorView(model: model, guardian: guardian)
                    .id(guardian.id)
            } else {
                emptyInspector
            }
        case .unassigned(let studentID):
            if let student = model.student(id: studentID) {
                UnassignedStudentInspectorView(
                    model: model,
                    student: student,
                    onLinked: { guardianID in
                        selection = .guardian(guardianID)
                    }
                )
                .id(student.id)
            } else {
                emptyInspector
            }
        case nil:
            emptyInspector
        }
    }

    private var emptyInspector: some View {
        ContentUnavailableView(
            "选择一个家庭",
            systemImage: "person.2",
            description: Text("查看帐号、学员档案和课程报名。")
        )
    }

    private var filteredGuardians: [Guardian] {
        switch accountFilter {
        case .all:
            searchedGuardians
        case .linked:
            linkedGuardians
        case .pending:
            pendingGuardians
        }
    }

    private var searchedGuardians: [Guardian] {
        let query = normalizedSearch
        guard !query.isEmpty else { return model.guardians }
        return model.guardians.filter { guardian in
            let learners = model.students(for: guardian.id)
            return guardian.displayName.localizedCaseInsensitiveContains(query)
                || guardian.email?.localizedCaseInsensitiveContains(query) == true
                || guardian.phone?.localizedCaseInsensitiveContains(query) == true
                || learners.contains { learner in
                    learner.displayName.localizedCaseInsensitiveContains(query)
                        || courseSummary(for: learner).localizedCaseInsensitiveContains(query)
                }
        }
    }

    private var linkedGuardians: [Guardian] {
        searchedGuardians.filter(\.isAccountLinked)
    }

    private var pendingGuardians: [Guardian] {
        searchedGuardians.filter { !$0.isAccountLinked }
    }

    private var filteredUnassignedStudents: [Student] {
        guard accountFilter != .linked else { return [] }
        let query = normalizedSearch
        guard !query.isEmpty else { return model.unassignedStudents }
        return model.unassignedStudents.filter { student in
            student.displayName.localizedCaseInsensitiveContains(query)
                || courseSummary(for: student).localizedCaseInsensitiveContains(query)
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chooseInitialSelection() {
        switch selection {
        case .guardian(let id) where filteredGuardians.contains(where: { $0.id == id }):
            return
        case .unassigned(let id) where filteredUnassignedStudents.contains(where: { $0.id == id }):
            return
        default:
            break
        }

        if let guardian = filteredGuardians.first {
            selection = .guardian(guardian.id)
        } else if let student = filteredUnassignedStudents.first {
            selection = .unassigned(student.id)
        } else {
            selection = nil
        }
    }

    private func contactSummary(for guardian: Guardian) -> String {
        [guardian.email, guardian.phone]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func learnerSummary(for guardian: Guardian) -> String {
        let names = model.students(for: guardian.id).map(\.displayName)
        return names.isEmpty ? "尚无学员" : names.joined(separator: "，")
    }

    private func enrollmentCount(for guardian: Guardian) -> Int {
        model.students(for: guardian.id)
            .reduce(0) { $0 + model.enrollments(for: $1.id).count }
    }

    private func courseSummary(for student: Student) -> String {
        model.enrollments(for: student.id)
            .compactMap { model.course(id: $0.courseID)?.name }
            .joined(separator: "，")
    }

    private func accountCell(_ guardian: Guardian, theme: MDTheme) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(guardian.isAccountLinked ? theme.success : theme.warning)
                .frame(width: 6, height: 6)
            Text(guardian.isAccountLinked ? "已连接" : "待认领")
                .mdFont(.compact)
                .lineLimit(1)
        }
        .frame(width: 105, alignment: .leading)
        .padding(.leading, 10)
    }

    private func filterTitle(for filter: GuardianAccountFilter) -> String {
        let count: Int
        switch filter {
        case .all:
            count = model.guardians.count
        case .linked:
            count = model.guardians.filter(\.isAccountLinked).count
        case .pending:
            count = model.guardians.filter { !$0.isAccountLinked }.count
        }
        return "\(filter.title) \(count)"
    }
}

@MainActor
private func familyHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .mdFont(.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

@MainActor
private func familyCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text.isEmpty ? "—" : text)
        .mdFont(mono ? .mono : (strong ? .bodyStrong : .body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
