#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct RequestsWorkspaceView: View {
    let model: AppModel

    @SceneStorage("md-desk.requests.selected-date") private var selectedDateStorage = Calendar.masterDance
        .startOfDay(for: Date())
        .timeIntervalSinceReferenceDate
    @SceneStorage("md-desk.requests.date-filter-enabled") private var dateFilterEnabled = false
    @SceneStorage("md-desk.requests.sort-column") private var sortColumnStorage = ""
    @SceneStorage("md-desk.requests.sort-ascending") private var sortAscending = true
    @SceneStorage("md-desk.requests.column-filters") private var columnFiltersStorage = ""
    @State private var showingNewRequest = false
    @State private var editingRequest: LeaveRequest?
    @State private var deletingRequest: LeaveRequest?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            toolbar(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)
            leaveList(theme: theme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
        .sheet(isPresented: $showingNewRequest) {
            LeaveRequestEditorView(
                model: model,
                request: nil,
                initialDate: dateFilterEnabled ? selectedDate : Date()
            )
        }
        .sheet(item: $editingRequest) { request in
            LeaveRequestEditorView(
                model: model,
                request: request,
                initialDate: model.session(id: request.sessionID)?.startsAt ?? selectedDate
            )
        }
        .alert(
            "删除请假记录",
            isPresented: Binding(
                get: { deletingRequest != nil },
                set: { if !$0 { deletingRequest = nil } }
            ),
            presenting: deletingRequest
        ) { request in
            Button("删除", role: .destructive) { delete(request) }
            Button("取消", role: .cancel) {}
        } message: { request in
            let student = model.student(id: request.studentID)?.displayName ?? "该学员"
            let session = model.session(id: request.sessionID)
            let date = session?.startsAt.formatted(date: .abbreviated, time: .shortened) ?? "该课次"
            Text("确定删除 \(student) 在 \(date) 的请假记录吗？")
        }
        .task {
            await model.synchronizeRemoteChanges()
        }
    }

    private func toolbar(theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            MDSectionTitle(chinese: "请假")
            Spacer()

            Button {
                toggleTodayFilter()
            } label: {
                Label("仅今天", systemImage: "calendar")
            }
            .buttonStyle(MDHeaderActionButtonStyle(isActive: isFilteringToday))
            .help(isFilteringToday ? "再次点击显示全部日期" : "仅显示今天上课的请假")

            DatePicker("选择日期", selection: selectedDateSelection, displayedComponents: .date)
                .labelsHidden()
                .fixedSize()
                .opacity(dateFilterEnabled ? 1 : 0.72)
                .help("选择某一天的请假记录")

            Button {
                dateFilterEnabled = false
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(MDIconButtonStyle())
            .opacity(dateFilterEnabled ? 1 : 0)
            .disabled(!dateFilterEnabled)
            .accessibilityHidden(!dateFilterEnabled)
            .help("清除日期筛选，显示全部")

            Button {
                showingNewRequest = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("新增请假")
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func leaveList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            requestHeader(theme: theme)

            if visibleLeaveRequests.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "calendar.badge.checkmark",
                    description: Text("可以用右上角加号替家长录入请假。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleLeaveRequests) { request in
                            let session = model.session(id: request.sessionID)
                            let course = session.flatMap { model.course(id: $0.courseID) }
                            HStack(spacing: 0) {
                                requestCell(
                                    model.student(id: request.studentID)?.displayName ?? "—",
                                    width: 140,
                                    strong: true
                                )
                                requestCell(course?.name ?? "—", width: 210)
                                requestCell(
                                    session?.startsAt.formatted(date: .abbreviated, time: .shortened) ?? "—",
                                    width: 180,
                                    mono: true
                                )
                                requestCell(leaveRequestSourceLabel(request.source), width: 90)
                                requestCell(request.note ?? "—", width: 260)
                                leaveActions(request)
                                    .frame(width: 100, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button("编辑") { editingRequest = request }
                                Button("删除", role: .destructive) { deletingRequest = request }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var visibleLeaveRequests: [LeaveRequest] {
        var filtered = dateFilteredLeaveRequests.filter(matchesColumnFilters)

        guard let sortColumn else {
            return filtered.sorted { left, right in
                let leftDate = model.session(id: left.sessionID)?.startsAt ?? left.submittedAt
                let rightDate = model.session(id: right.sessionID)?.startsAt ?? right.submittedAt
                if leftDate == rightDate { return left.submittedAt > right.submittedAt }
                return dateFilterEnabled ? leftDate < rightDate : leftDate > rightDate
            }
        }
        filtered.sort { requestOrderedBefore($0, $1, by: sortColumn) }
        return filtered
    }

    private var dateFilteredLeaveRequests: [LeaveRequest] {
        dateFilterEnabled
            ? model.leaveRequests.filter { request in
                guard let session = model.session(id: request.sessionID) else { return false }
                return Calendar.masterDance.isDate(session.startsAt, inSameDayAs: selectedDate)
            }
            : model.leaveRequests
    }

    private var emptyTitle: String {
        guard dateFilterEnabled else { return "暂无请假记录" }
        if isFilteringToday { return "今天没有请假记录" }
        return "\(selectedDate.formatted(.dateTime.month().day())) 没有请假记录"
    }

    private var selectedDate: Date {
        get { Date(timeIntervalSinceReferenceDate: selectedDateStorage) }
        nonmutating set {
            selectedDateStorage = Calendar.masterDance
                .startOfDay(for: newValue)
                .timeIntervalSinceReferenceDate
        }
    }

    private var selectedDateSelection: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { value in
                selectedDate = value
                dateFilterEnabled = true
            }
        )
    }

    private var isFilteringToday: Bool {
        dateFilterEnabled && Calendar.masterDance.isDateInToday(selectedDate)
    }

    private func toggleTodayFilter() {
        if isFilteringToday {
            dateFilterEnabled = false
        } else {
            selectedDate = Date()
            dateFilterEnabled = true
        }
    }

    @ViewBuilder
    private func leaveActions(_ request: LeaveRequest) -> some View {
        HStack(spacing: 2) {
            Button {
                editingRequest = request
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("编辑请假")

            Button {
                deletingRequest = request
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("删除请假")
        }
        .padding(.horizontal, 2)
    }

    private func delete(_ request: LeaveRequest) {
        deletingRequest = nil
        model.performBackgroundOperation(
            label: "删除请假",
            successMessage: "请假已删除"
        ) {
            try await model.deleteLeaveRequest(id: request.id)
        }
    }

    private func requestHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(LeaveRequestTableColumn.allCases) { column in
                MDTableColumnHeader(
                    title: column.title,
                    width: column.width,
                    isSorted: sortColumn == column,
                    ascending: sortAscending,
                    options: requestFilterOptions(for: column),
                    selectedValues: mdTableFilterSelection(
                        storage: $columnFiltersStorage,
                        key: column.rawValue
                    ),
                    onSort: { toggleSort(column) }
                )
            }
            HStack(spacing: 5) {
                if hasActiveColumnFilters {
                    Button {
                        columnFiltersStorage = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("清除全部列筛选")
                }
                Text("操作")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(width: 100)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private var sortColumn: LeaveRequestTableColumn? {
        get { LeaveRequestTableColumn(rawValue: sortColumnStorage) }
        nonmutating set { sortColumnStorage = newValue?.rawValue ?? "" }
    }

    private var hasActiveColumnFilters: Bool {
        LeaveRequestTableColumn.allCases.contains {
            !MDTableFilterCodec.selection(in: columnFiltersStorage, for: $0.rawValue).isEmpty
        }
    }

    private func toggleSort(_ column: LeaveRequestTableColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }

    private func requestFilterOptions(for column: LeaveRequestTableColumn) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            dateFilteredLeaveRequests,
            key: { requestColumnKey($0, column: column) },
            label: { requestColumnLabel($0, column: column) }
        )
    }

    private func matchesColumnFilters(_ request: LeaveRequest) -> Bool {
        LeaveRequestTableColumn.allCases.allSatisfy { column in
            let values = MDTableFilterCodec.selection(in: columnFiltersStorage, for: column.rawValue)
            return values.isEmpty || values.contains(requestColumnKey(request, column: column))
        }
    }

    private func requestColumnKey(_ request: LeaveRequest, column: LeaveRequestTableColumn) -> String {
        let session = model.session(id: request.sessionID)
        return switch column {
        case .student: request.studentID.description
        case .course: session?.courseID.description ?? "none"
        case .session: request.sessionID.description
        case .source: request.source.rawValue
        case .note: request.note ?? ""
        }
    }

    private func requestColumnLabel(_ request: LeaveRequest, column: LeaveRequestTableColumn) -> String {
        let session = model.session(id: request.sessionID)
        return switch column {
        case .student: model.student(id: request.studentID)?.displayName ?? "—"
        case .course: session.flatMap { model.course(id: $0.courseID) }?.name ?? "—"
        case .session: session?.startsAt.formatted(date: .abbreviated, time: .shortened) ?? "—"
        case .source: leaveRequestSourceLabel(request.source)
        case .note: request.note ?? "—"
        }
    }

    private func requestOrderedBefore(
        _ lhs: LeaveRequest,
        _ rhs: LeaveRequest,
        by column: LeaveRequestTableColumn
    ) -> Bool {
        if column == .session {
            let left = model.session(id: lhs.sessionID)?.startsAt ?? lhs.submittedAt
            let right = model.session(id: rhs.sessionID)?.startsAt ?? rhs.submittedAt
            if left != right { return sortAscending ? left < right : left > right }
        }
        let comparison = requestColumnLabel(lhs, column: column)
            .localizedStandardCompare(requestColumnLabel(rhs, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }
}

private enum LeaveRequestTableColumn: String, CaseIterable, Identifiable {
    case student
    case course
    case session
    case source
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: "学员"
        case .course: "课程"
        case .session: "课次"
        case .source: "来源"
        case .note: "备注"
        }
    }

    var width: CGFloat {
        switch self {
        case .student: 140
        case .course: 210
        case .session: 180
        case .source: 90
        case .note: 260
        }
    }
}

private struct LeaveRequestEditorView: View {
    let model: AppModel
    let original: LeaveRequest?

    @State private var selectedDate: Date
    @State private var sessionID: ClassSessionID?
    @State private var studentID: StudentID?
    @State private var note: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, request: LeaveRequest?, initialDate: Date) {
        self.model = model
        original = request
        let requestDate = request.flatMap { model.session(id: $0.sessionID)?.startsAt }
        _selectedDate = State(
            initialValue: Calendar.masterDance.startOfDay(for: requestDate ?? initialDate)
        )
        _sessionID = State(initialValue: request?.sessionID)
        _studentID = State(initialValue: request?.studentID)
        _note = State(initialValue: request?.note ?? "")
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: original == nil ? "新增请假" : "编辑请假")
                Spacer()
                Text(leaveRequestSourceLabel(original?.source ?? .administrator))
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorSection("课次与学员") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                fieldLabel("上课日期")
                                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                    .labelsHidden()
                            }

                            GridRow {
                                fieldLabel("具体课次")
                                Picker("", selection: $sessionID) {
                                    Text("请选择").tag(Optional<ClassSessionID>.none)
                                    ForEach(sessionsForDate) { session in
                                        Text(sessionLabel(session)).tag(Optional(session.id))
                                    }
                                }
                                .labelsHidden()
                                .frame(minWidth: 430, alignment: .leading)
                            }

                            GridRow {
                                fieldLabel("请假学员")
                                Picker("", selection: $studentID) {
                                    Text("请选择").tag(Optional<StudentID>.none)
                                    ForEach(candidateStudents) { student in
                                        Text(studentLabel(student)).tag(Optional(student.id))
                                    }
                                }
                                .labelsHidden()
                                .frame(minWidth: 430, alignment: .leading)
                            }
                        }

                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                                .mdFont(.compact)
                                .foregroundStyle(theme.danger)
                        }
                    }

                    editorSection("备注") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow(alignment: .top) {
                                fieldLabel("备注")
                                TextField("选填，例如家长来电说明", text: $note, axis: .vertical)
                                    .lineLimit(3...6)
                                    .frame(minWidth: 430)
                            }
                        }
                    }
                }
                .padding(18)
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(original == nil ? "新增请假" : "保存修改") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(14)
        }
        .frame(width: 680, height: 520)
        .background(theme.background)
        .onAppear(perform: synchronizeSelections)
        .onChange(of: selectedDate) { _, _ in
            sessionID = sessionsForDate.first?.id
            studentID = nil
            synchronizeStudentSelection()
        }
        .onChange(of: sessionID) { _, _ in
            synchronizeStudentSelection()
        }
    }

    private var sessionsForDate: [ClassSession] {
        model.sessions
            .filter { session in
                Calendar.masterDance.isDate(session.startsAt, inSameDayAs: selectedDate)
                    && (session.status != .cancelled || session.id == original?.sessionID)
            }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private var candidateEnrollments: [Enrollment] {
        guard let sessionID, let session = model.session(id: sessionID) else { return [] }
        return model.enrollments
            .filter { enrollment in
                enrollment.courseID == session.courseID
                    && enrollment.includes(sessionID: session.id)
                    && (enrollment.status != .withdrawn || enrollment.id == original?.enrollmentID)
            }
            .sorted { left, right in
                let leftName = model.student(id: left.studentID)?.displayName ?? ""
                let rightName = model.student(id: right.studentID)?.displayName ?? ""
                return leftName.localizedCompare(rightName) == .orderedAscending
            }
    }

    private var candidateStudents: [Student] {
        var seen = Set<StudentID>()
        var students = candidateEnrollments.compactMap { enrollment -> Student? in
            guard seen.insert(enrollment.studentID).inserted else { return nil }
            return model.student(id: enrollment.studentID)
        }
        if let original,
           seen.insert(original.studentID).inserted,
           let originalStudent = model.student(id: original.studentID) {
            students.append(originalStudent)
        }
        return students.sorted {
            $0.displayName.localizedCompare($1.displayName) == .orderedAscending
        }
    }

    private var selectedEnrollmentID: EnrollmentID? {
        guard let studentID else { return nil }
        return candidateEnrollments.first { $0.studentID == studentID }?.id
            ?? (studentID == original?.studentID ? original?.enrollmentID : nil)
    }

    private var hasDuplicate: Bool {
        guard let sessionID, let studentID else { return false }
        return model.leaveRequests.contains {
            $0.id != original?.id && $0.sessionID == sessionID && $0.studentID == studentID
        }
    }

    private var validationMessage: String? {
        if sessionsForDate.isEmpty { return "这一天没有可请假的课次。" }
        if sessionID != nil && candidateStudents.isEmpty { return "这门课没有可请假的报名学员。" }
        if hasDuplicate { return "该学员在这个课次已有请假记录。" }
        return nil
    }

    private var canSave: Bool {
        sessionID != nil && studentID != nil && !hasDuplicate
    }

    private func sessionLabel(_ session: ClassSession) -> String {
        let course = model.course(id: session.courseID)?.name ?? "课程"
        let room = model.effectiveRoom(for: session)?.name ?? "未定教室"
        let time = session.startsAt.formatted(date: .omitted, time: .shortened)
        return "\(time) · \(course) · \(room)"
    }

    private func studentLabel(_ student: Student) -> String {
        let family = model.guardian(id: student.guardianID)?.displayName ?? "未知家庭"
        return "\(student.displayName) · \(family)"
    }

    private func synchronizeSelections() {
        if sessionID == nil || !sessionsForDate.contains(where: { $0.id == sessionID }) {
            sessionID = sessionsForDate.first?.id
        }
        synchronizeStudentSelection()
    }

    private func synchronizeStudentSelection() {
        if studentID == nil || !candidateStudents.contains(where: { $0.id == studentID }) {
            studentID = candidateStudents.first?.id
        }
    }

    @ViewBuilder
    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .mdFont(.bodyStrong)
            content()
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .mdFont(.compact)
            .foregroundStyle(.secondary)
            .frame(width: 82, alignment: .leading)
    }

    private func save() {
        guard let sessionID, let studentID else { return }
        let now = Date()
        let normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = LeaveRequest(
            id: original?.id ?? LeaveRequestID(),
            sessionID: sessionID,
            studentID: studentID,
            enrollmentID: selectedEnrollmentID,
            source: original?.source ?? .administrator,
            status: .approved,
            submittedAt: original?.submittedAt ?? now,
            resolvedAt: nil,
            note: normalizedNote.isEmpty ? nil : normalizedNote
        )

        model.performBackgroundOperation(
            label: original == nil ? "新增请假" : "更新请假",
            successMessage: original == nil ? "请假已新增" : "请假已更新"
        ) {
            try await model.saveLeaveRequest(request)
        }
        dismiss()
    }
}

private func leaveRequestSourceLabel(_ source: LeaveRequestSource) -> String {
    switch source {
    case .app: "手机端"
    case .administrator: "教务代办"
    }
}

@MainActor
private func requestCell(
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
