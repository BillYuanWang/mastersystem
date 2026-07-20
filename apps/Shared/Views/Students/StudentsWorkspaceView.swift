#if os(macOS)
import MasterDanceCore
import SwiftUI

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
    @State private var selectedGuardianID: GuardianID?
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
        Table(filteredGuardians, selection: $selectedGuardianID) {
            TableColumn("监护人") { guardian in
                Text(guardian.displayName)
                    .mdFont(.bodyStrong)
                    .lineLimit(1)
            }
            .width(min: 120, ideal: 155, max: 220)

            TableColumn("联系方式") { guardian in
                Text(displayValue(contactSummary(for: guardian)))
                    .mdFont(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 180, ideal: 235, max: 320)

            TableColumn("学员档案") { guardian in
                Text(learnerSummary(for: guardian))
                    .mdFont(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .width(min: 170, ideal: 245, max: 360)

            TableColumn("帐号") { guardian in
                accountStatusCell(guardian, theme: theme)
            }
            .width(min: 82, ideal: 96, max: 110)

            TableColumn("报名") { guardian in
                Text("\(enrollmentCount(for: guardian))")
                    .mdFont(.mono)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .width(min: 48, ideal: 56, max: 70)
        }
        .foregroundStyle(theme.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if filteredGuardians.isEmpty {
                ContentUnavailableView(
                    normalizedSearch.isEmpty ? "暂无家庭" : "没有搜索结果",
                    systemImage: "person.2",
                    description: Text(
                        normalizedSearch.isEmpty
                            ? "当前筛选下没有家庭记录。"
                            : "请尝试其他姓名、联系方式或课程。"
                    )
                )
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedGuardianID,
           let guardian = model.guardian(id: selectedGuardianID) {
            GuardianInspectorView(model: model, guardian: guardian)
                .id(guardian.id)
        } else {
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
            searchedGuardians.filter(\.isAccountLinked)
        case .pending:
            searchedGuardians.filter { !$0.isAccountLinked }
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

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func chooseInitialSelection() {
        if let selectedGuardianID,
           filteredGuardians.contains(where: { $0.id == selectedGuardianID }) {
            return
        }
        selectedGuardianID = filteredGuardians.first?.id
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

    private func accountStatusCell(_ guardian: Guardian, theme: MDTheme) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(guardian.isAccountLinked ? theme.success : theme.warning)
                .frame(width: 7, height: 7)
            Text(guardian.isAccountLinked ? "已连接" : "待认领")
                .mdFont(.compact)
                .lineLimit(1)
        }
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

    private func displayValue(_ value: String) -> String {
        value.isEmpty ? "—" : value
    }
}
#endif
