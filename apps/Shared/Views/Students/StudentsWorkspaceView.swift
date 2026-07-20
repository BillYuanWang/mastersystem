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

    func includes(_ guardian: Guardian) -> Bool {
        switch self {
        case .all: true
        case .linked: guardian.isAccountLinked
        case .pending: !guardian.isAccountLinked
        }
    }
}

private enum EnrollmentCountFilter: String, CaseIterable, Identifiable {
    case all
    case none
    case oneOrMore
    case threeOrMore
    case fiveOrMore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .none: "0"
        case .oneOrMore: "1+"
        case .threeOrMore: "3+"
        case .fiveOrMore: "5+"
        }
    }

    func includes(_ count: Int) -> Bool {
        switch self {
        case .all: true
        case .none: count == 0
        case .oneOrMore: count >= 1
        case .threeOrMore: count >= 3
        case .fiveOrMore: count >= 5
        }
    }
}

private enum FamilyTableMetrics {
    static let guardian: CGFloat = 132
    static let email: CGFloat = 195
    static let phone: CGFloat = 150
    static let learners: CGFloat = 200
    static let account: CGFloat = 98
    static let totalEnrollments: CGFloat = 78
    static let termEnrollments: CGFloat = 86
    static let rowHeight: CGFloat = 39
    static let headerHeight: CGFloat = 31
    static let filterHeight: CGFloat = 38

    static let totalWidth = guardian + email + phone + learners + account
        + totalEnrollments + termEnrollments
}

@MainActor
struct StudentsWorkspaceView: View {
    let model: AppModel

    @State private var searchText = ""
    @State private var guardianFilter = ""
    @State private var emailFilter = ""
    @State private var phoneFilter = ""
    @State private var learnerFilter = ""
    @State private var accountFilter: GuardianAccountFilter = .all
    @State private var totalEnrollmentFilter: EnrollmentCountFilter = .all
    @State private var termEnrollmentFilter: EnrollmentCountFilter = .all
    @State private var selectedTermID: TermID?
    @State private var selectedGuardianID: GuardianID?
    @State private var hoveredGuardianID: GuardianID?
    @State private var showingGuardianEditor = false

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
                    .frame(width: 410)
            }
        }
        .background(theme.background)
        .task(id: model.terms.map(\.id)) {
            chooseStatisticsTerm()
        }
        .task(id: model.guardians.map(\.id)) {
            chooseInitialSelection()
        }
        .onChange(of: visibleGuardianIDs) { _, _ in
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
            Text(recordSummary)
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)

            Spacer()

            Picker("统计学期", selection: $selectedTermID) {
                Text("选择统计学期").tag(Optional<TermID>.none)
                ForEach(sortedTerms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            .labelsHidden()
            .mdFont(.body)
            .frame(width: 220)
            .help("选择“学期报名”列的统计学期")

            TextField("搜索全部家庭资料", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.body)
                .frame(width: 220)

            if hasActiveColumnFilters {
                Button {
                    clearColumnFilters()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("清除列筛选")
            }

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
        GeometryReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    tableHeader(theme: theme)
                    tableFilters(theme: theme)

                    ForEach(filteredGuardians) { guardian in
                        familyRow(guardian, theme: theme)
                    }
                }
                .frame(
                    minWidth: max(FamilyTableMetrics.totalWidth, proxy.size.width),
                    minHeight: proxy.size.height,
                    alignment: .topLeading
                )
            }
            .defaultScrollAnchor(.topLeading)
            .background(theme.surface)
            .overlay {
                if filteredGuardians.isEmpty {
                    ContentUnavailableView(
                        hasAnySearchOrFilter ? "没有筛选结果" : "暂无家庭",
                        systemImage: "person.2",
                        description: Text(
                            hasAnySearchOrFilter
                                ? "请调整列筛选或搜索内容。"
                                : "添加监护人后，家庭资料会显示在这里。"
                        )
                    )
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func tableHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            headerCell("监护人", width: FamilyTableMetrics.guardian, theme: theme)
            headerCell("邮箱", width: FamilyTableMetrics.email, theme: theme)
            headerCell("电话", width: FamilyTableMetrics.phone, theme: theme)
            headerCell("学员档案", width: FamilyTableMetrics.learners, theme: theme)
            headerCell("帐号", width: FamilyTableMetrics.account, theme: theme)
            headerCell(
                "总报名",
                width: FamilyTableMetrics.totalEnrollments,
                alignment: .center,
                help: "系统累计报名数，自 2026 年秋季开始",
                theme: theme
            )
            headerCell(
                "学期报名",
                width: FamilyTableMetrics.termEnrollments,
                alignment: .center,
                help: selectedTerm?.name ?? "请先在页眉选择统计学期",
                theme: theme
            )
        }
        .frame(height: FamilyTableMetrics.headerHeight)
        .background(theme.subtleSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func tableFilters(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            textFilterCell("筛选姓名", text: $guardianFilter, width: FamilyTableMetrics.guardian, theme: theme)
            textFilterCell("筛选邮箱", text: $emailFilter, width: FamilyTableMetrics.email, theme: theme)
            textFilterCell("筛选电话", text: $phoneFilter, width: FamilyTableMetrics.phone, theme: theme)
            textFilterCell("筛选学员", text: $learnerFilter, width: FamilyTableMetrics.learners, theme: theme)
            menuFilterCell(
                selection: $accountFilter,
                values: GuardianAccountFilter.allCases,
                width: FamilyTableMetrics.account,
                theme: theme
            )
            menuFilterCell(
                selection: $totalEnrollmentFilter,
                values: EnrollmentCountFilter.allCases,
                width: FamilyTableMetrics.totalEnrollments,
                theme: theme
            )
            menuFilterCell(
                selection: $termEnrollmentFilter,
                values: EnrollmentCountFilter.allCases,
                width: FamilyTableMetrics.termEnrollments,
                theme: theme
            )
        }
        .frame(height: FamilyTableMetrics.filterHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func familyRow(_ guardian: Guardian, theme: MDTheme) -> some View {
        Button {
            selectedGuardianID = guardian.id
        } label: {
            HStack(spacing: 0) {
                tableCell(width: FamilyTableMetrics.guardian, theme: theme) {
                    Text(guardian.displayName)
                        .mdFont(.bodyStrong)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                tableCell(width: FamilyTableMetrics.email, theme: theme) {
                    Text(displayValue(guardian.email))
                        .mdFont(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                tableCell(width: FamilyTableMetrics.phone, theme: theme) {
                    Text(displayValue(guardian.phone))
                        .mdFont(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                tableCell(width: FamilyTableMetrics.learners, theme: theme) {
                    Text(learnerSummary(for: guardian))
                        .mdFont(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                tableCell(width: FamilyTableMetrics.account, theme: theme) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(guardian.isAccountLinked ? theme.success : theme.warning)
                            .frame(width: 7, height: 7)
                        Text(guardian.isAccountLinked ? "已连接" : "待认领")
                            .mdFont(.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                tableCell(
                    width: FamilyTableMetrics.totalEnrollments,
                    alignment: .center,
                    theme: theme
                ) {
                    Text("\(totalEnrollmentCount(for: guardian))")
                        .mdFont(.body)
                        .lineLimit(1)
                }
                tableCell(
                    width: FamilyTableMetrics.termEnrollments,
                    alignment: .center,
                    theme: theme
                ) {
                    Text(selectedTermID == nil ? "—" : "\(termEnrollmentCount(for: guardian))")
                        .mdFont(.body)
                        .lineLimit(1)
                }
            }
            .frame(width: FamilyTableMetrics.totalWidth, height: FamilyTableMetrics.rowHeight)
            .foregroundStyle(theme.primaryText)
            .background(rowBackground(for: guardian, theme: theme))
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.faintSeparator).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            hoveredGuardianID = isHovering ? guardian.id : nil
        }
        .accessibilityLabel(familyAccessibilityLabel(for: guardian))
    }

    private func headerCell(
        _ title: String,
        width: CGFloat,
        alignment: Alignment = .leading,
        help: String? = nil,
        theme: MDTheme
    ) -> some View {
        Text(title)
            .mdFont(.bodyStrong)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 10)
            .frame(width: width, height: FamilyTableMetrics.headerHeight)
            .foregroundStyle(theme.primaryText)
            .overlay(alignment: .trailing) {
                Rectangle().fill(theme.faintSeparator).frame(width: 1)
            }
            .help(help ?? "按此列筛选")
    }

    private func textFilterCell(
        _ prompt: String,
        text: Binding<String>,
        width: CGFloat,
        theme: MDTheme
    ) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .mdFont(.body)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(width: width - 12, height: 27)
            .background(theme.background, in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.separator, lineWidth: 1)
            }
            .frame(width: width, height: FamilyTableMetrics.filterHeight)
            .overlay(alignment: .trailing) {
                Rectangle().fill(theme.faintSeparator).frame(width: 1)
            }
    }

    private func menuFilterCell<Value>(
        selection: Binding<Value>,
        values: [Value],
        width: CGFloat,
        theme: MDTheme
    ) -> some View where Value: Hashable & Identifiable {
        Picker("筛选", selection: selection) {
            ForEach(values) { value in
                Text(filterMenuTitle(value)).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .mdFont(.body)
        .frame(width: width - 10)
        .frame(width: width, height: FamilyTableMetrics.filterHeight)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.faintSeparator).frame(width: 1)
        }
    }

    private func tableCell<Content: View>(
        width: CGFloat,
        alignment: Alignment = .leading,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.horizontal, 10)
            .frame(width: width, height: FamilyTableMetrics.rowHeight, alignment: alignment)
            .clipped()
            .overlay(alignment: .trailing) {
                Rectangle().fill(theme.faintSeparator).frame(width: 1)
            }
    }

    @ViewBuilder
    private var inspector: some View {
        if let selectedGuardianID,
           let guardian = model.guardian(id: selectedGuardianID) {
            GuardianInspectorView(model: model, guardian: guardian)
                .id(guardian.id)
        } else {
            ContentUnavailableView(
                "选择一个家庭",
                systemImage: "person.2",
                description: Text("查看帐号、家庭资料、学员档案和课程报名。")
            )
        }
    }

    private var filteredGuardians: [Guardian] {
        model.guardians.filter { guardian in
            matchesGlobalSearch(guardian)
                && matches(guardian.displayName, filter: guardianFilter)
                && matches(guardian.email, filter: emailFilter)
                && matchesPhone(guardian.phone, filter: phoneFilter)
                && matches(learnerSummary(for: guardian), filter: learnerFilter)
                && accountFilter.includes(guardian)
                && totalEnrollmentFilter.includes(totalEnrollmentCount(for: guardian))
                && termEnrollmentFilter.includes(termEnrollmentCount(for: guardian))
        }
    }

    private var visibleGuardianIDs: [GuardianID] {
        filteredGuardians.map(\.id)
    }

    private var sortedTerms: [Term] {
        model.terms.sorted { $0.startsOn > $1.startsOn }
    }

    private var selectedTerm: Term? {
        selectedTermID.flatMap(model.term(id:))
    }

    private var recordSummary: String {
        let total = "\(model.guardians.count) 户 · \(model.students.count) 人"
        guard filteredGuardians.count != model.guardians.count else { return total }
        return "\(total) · 显示 \(filteredGuardians.count) 户"
    }

    private var hasActiveColumnFilters: Bool {
        !normalized(guardianFilter).isEmpty
            || !normalized(emailFilter).isEmpty
            || !normalized(phoneFilter).isEmpty
            || !normalized(learnerFilter).isEmpty
            || accountFilter != .all
            || totalEnrollmentFilter != .all
            || termEnrollmentFilter != .all
    }

    private var hasAnySearchOrFilter: Bool {
        !normalized(searchText).isEmpty || hasActiveColumnFilters
    }

    private var enrollmentHistoryStart: Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: 1)
        ) ?? .distantPast
    }

    private func chooseStatisticsTerm() {
        if let selectedTermID, model.term(id: selectedTermID) != nil {
            return
        }

        let today = Date()
        selectedTermID = model.terms.first {
            $0.startsOn <= today && today <= $0.endsOn
        }?.id ?? model.terms.first(where: { $0.status == .open })?.id ?? sortedTerms.first?.id
    }

    private func chooseInitialSelection() {
        if let selectedGuardianID, visibleGuardianIDs.contains(selectedGuardianID) {
            return
        }
        selectedGuardianID = visibleGuardianIDs.first
    }

    private func clearColumnFilters() {
        guardianFilter = ""
        emailFilter = ""
        phoneFilter = ""
        learnerFilter = ""
        accountFilter = .all
        totalEnrollmentFilter = .all
        termEnrollmentFilter = .all
    }

    private func matchesGlobalSearch(_ guardian: Guardian) -> Bool {
        let query = normalized(searchText)
        guard !query.isEmpty else { return true }
        let learners = model.students(for: guardian.id)
        return guardian.displayName.localizedCaseInsensitiveContains(query)
            || guardian.email?.localizedCaseInsensitiveContains(query) == true
            || guardian.phone?.localizedCaseInsensitiveContains(query) == true
            || guardian.address?.localizedCaseInsensitiveContains(query) == true
            || learners.contains { learner in
                learner.displayName.localizedCaseInsensitiveContains(query)
                    || learner.legalName?.localizedCaseInsensitiveContains(query) == true
                    || courseSummary(for: learner).localizedCaseInsensitiveContains(query)
            }
    }

    private func matches(_ value: String?, filter: String) -> Bool {
        let query = normalized(filter)
        guard !query.isEmpty else { return true }
        return value?.localizedCaseInsensitiveContains(query) == true
    }

    private func matchesPhone(_ value: String?, filter: String) -> Bool {
        let query = normalized(filter)
        guard !query.isEmpty else { return true }
        guard let value else { return false }
        if value.localizedCaseInsensitiveContains(query) {
            return true
        }
        let digits = value.filter(\.isNumber)
        let queryDigits = query.filter(\.isNumber)
        return !queryDigits.isEmpty && digits.contains(queryDigits)
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func learnerSummary(for guardian: Guardian) -> String {
        let names = model.students(for: guardian.id).map(\.displayName)
        return names.isEmpty ? "尚无学员" : names.joined(separator: "，")
    }

    private func totalEnrollmentCount(for guardian: Guardian) -> Int {
        let countedTerms = Set(
            model.terms
                .filter { $0.startsOn >= enrollmentHistoryStart }
                .map(\.id)
        )
        return model.students(for: guardian.id).reduce(0) { result, student in
            result + model.enrollments(for: student.id)
                .filter { countedTerms.contains($0.termID) }
                .count
        }
    }

    private func termEnrollmentCount(for guardian: Guardian) -> Int {
        guard let selectedTermID else { return 0 }
        return model.students(for: guardian.id).reduce(0) { result, student in
            result + model.enrollments(for: student.id)
                .filter { $0.termID == selectedTermID }
                .count
        }
    }

    private func courseSummary(for student: Student) -> String {
        model.enrollments(for: student.id)
            .compactMap { model.course(id: $0.courseID)?.name }
            .joined(separator: "，")
    }

    private func displayValue(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "—" }
        return value
    }

    private func rowBackground(for guardian: Guardian, theme: MDTheme) -> Color {
        if guardian.id == selectedGuardianID {
            return Color(red: 0.22, green: 0.56, blue: 0.96)
                .opacity(colorScheme == .dark ? 0.24 : 0.15)
        }
        if guardian.id == hoveredGuardianID {
            return theme.subtleSurface.opacity(0.8)
        }
        return theme.surface
    }

    private func familyAccessibilityLabel(for guardian: Guardian) -> String {
        "\(guardian.displayName)，\(learnerSummary(for: guardian))，总报名 \(totalEnrollmentCount(for: guardian))，学期报名 \(termEnrollmentCount(for: guardian))"
    }

    private func filterMenuTitle<Value>(_ value: Value) -> String {
        if let value = value as? GuardianAccountFilter {
            return value.title
        }
        if let value = value as? EnrollmentCountFilter {
            return value.title
        }
        return "全部"
    }
}
#endif
