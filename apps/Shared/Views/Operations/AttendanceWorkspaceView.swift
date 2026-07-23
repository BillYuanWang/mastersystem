#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct AttendanceWorkspaceView: View {
    let model: AppModel

    @SceneStorage("md-desk.attendance.selected-date") private var selectedDateStorage = Calendar.masterDance.startOfDay(for: Date()).timeIntervalSinceReferenceDate
    @SceneStorage("md-desk.attendance.selected-session-id") private var selectedSessionIDStorage = ""
    @SceneStorage("md-desk.attendance.search") private var searchText = ""
    @SceneStorage("md-desk.attendance.regular-sort-column") private var regularSortColumnStorage = ""
    @SceneStorage("md-desk.attendance.regular-sort-ascending") private var regularSortAscending = true
    @SceneStorage("md-desk.attendance.regular-filters") private var regularFiltersStorage = ""
    @SceneStorage("md-desk.attendance.trial-sort-column") private var trialSortColumnStorage = ""
    @SceneStorage("md-desk.attendance.trial-sort-ascending") private var trialSortAscending = true
    @SceneStorage("md-desk.attendance.trial-filters") private var trialFiltersStorage = ""
    @SceneStorage("md-desk.attendance.makeup-sort-column") private var makeupSortColumnStorage = ""
    @SceneStorage("md-desk.attendance.makeup-sort-ascending") private var makeupSortAscending = true
    @SceneStorage("md-desk.attendance.makeup-filters") private var makeupFiltersStorage = ""
    @State private var addingGuestKind: AttendanceGuestKind?
    @State private var deletingAttendanceID: AttendanceID?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            toolbar
            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 0) {
                sessionList(theme: theme)
                    .frame(width: 260)

                Rectangle().fill(theme.separator).frame(width: 1)
                attendanceContent(theme: theme)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.background)
        .task(id: model.sessions.count) {
            if let focused = model.focusedSessionID, let session = model.session(id: focused) {
                selectedDate = session.startsAt
                selectedSessionID = focused
                model.focusedSessionID = nil
            } else if selectedSessionID == nil || !sessionsForDate.contains(where: { $0.id == selectedSessionID }) {
                selectedSessionID = sessionsForDate.first?.id
            }
        }
        .onChange(of: selectedDate) { _, _ in
            selectedSessionID = sessionsForDate.first?.id
            addingGuestKind = nil
        }
        .onChange(of: selectedSessionID) { _, _ in
            addingGuestKind = nil
        }
        .sheet(item: $addingGuestKind) { kind in
            if
                let selectedSessionID,
                let session = model.session(id: selectedSessionID),
                let course = model.course(id: session.courseID)
            {
                AttendanceGuestPicker(
                    model: model,
                    kind: kind,
                    candidates: guestCandidates(course: course, session: session),
                    add: { studentID, sourceSessionID in
                        addGuest(
                            studentID,
                            kind: kind,
                            session: session,
                            sourceSessionID: sourceSessionID
                        )
                    }
                )
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            MDSectionTitle(chinese: "签到", english: "ATTENDANCE")
            Spacer()
            Button {
                selectedDate = Calendar.masterDance.startOfDay(for: Date())
            } label: {
                Label("今天", systemImage: "calendar.badge.clock")
            }
            .buttonStyle(MDHeaderActionButtonStyle(isActive: isShowingToday))
            .help(isShowingToday ? "当前正在显示今天" : "返回今天")

            DatePicker("日期", selection: selectedDateSelection, displayedComponents: .date)
                .labelsHidden()
            TextField("搜索学员或家庭", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.compact)
                .frame(width: 190)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
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
            set: { selectedDate = $0 }
        )
    }

    private var selectedSessionID: ClassSessionID? {
        get { try? ClassSessionID(uuidString: selectedSessionIDStorage) }
        nonmutating set { selectedSessionIDStorage = newValue?.description ?? "" }
    }

    private var isShowingToday: Bool {
        Calendar.masterDance.isDateInToday(selectedDate)
    }

    private func sessionList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("当日课程")
                    .mdFont(.bodyStrong)
                Spacer()
                Text("\(sessionsForDate.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(theme.subtleSurface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sessionsForDate) { session in
                        Button {
                            selectedSessionID = session.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.course(id: session.courseID)?.name ?? "课程")
                                    .mdFont(.bodyStrong)
                                    .lineLimit(1)
                                HStack {
                                    Text(session.startsAt.formatted(date: .omitted, time: .shortened))
                                    Text(model.effectiveRoom(for: session)?.name ?? "")
                                        .lineLimit(1)
                                }
                                .mdFont(.compact)
                                .foregroundStyle(theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(selectedSessionID == session.id ? theme.accent.opacity(0.12) : .clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .background(theme.surface)
    }

    @ViewBuilder
    private func attendanceContent(theme: MDTheme) -> some View {
        if
            let selectedSessionID,
            let session = model.session(id: selectedSessionID),
            let course = model.course(id: session.courseID)
        {
            let regularRoster = regularRoster(course: course, session: session)
            let trials = specialRecords(session: session, status: .trial)
            let makeups = specialRecords(session: session, status: .makeup)

            VStack(spacing: 0) {
                sessionHeader(
                    course: course,
                    session: session,
                    regularCount: regularRoster.count,
                    leaveCount: leaveCount(session),
                    trialCount: trials.count,
                    makeupCount: makeups.count,
                    theme: theme
                )
                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        regularRosterSection(
                            regularRoster,
                            session: session,
                            theme: theme
                        )

                        specialAttendanceSection(
                            kind: .trial,
                            records: trials,
                            theme: theme
                        )

                        specialAttendanceSection(
                            kind: .makeup,
                            records: makeups,
                            theme: theme
                        )
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "当天没有课程",
                systemImage: "checkmark.circle",
                description: Text("可以选择其他日期补录签到。")
            )
        }
    }

    private func sessionHeader(
        course: Course,
        session: ClassSession,
        regularCount: Int,
        leaveCount: Int,
        trialCount: Int,
        makeupCount: Int,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)
                    .mdFont(.bodyStrong)
                Text(session.startsAt.formatted(date: .long, time: .shortened))
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Label("出勤 \(presentCount(session))/\(regularCount)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            Label("请假 \(leaveCount)", systemImage: "calendar.badge.minus")
                .foregroundStyle(theme.warning)
            Label("试课 \(trialCount)", systemImage: "sparkles")
                .foregroundStyle(theme.accent)
            Label("补课 \(makeupCount)", systemImage: "arrow.clockwise")
                .foregroundStyle(theme.success)
        }
        .mdFont(.compactStrong)
        .padding(.horizontal, 16)
        .frame(height: 58)
    }

    private func regularRosterSection(
        _ roster: [Enrollment],
        session: ClassSession,
        theme: MDTheme
    ) -> some View {
        let filtered = filteredRegularRoster(roster, session: session)
        return VStack(spacing: 0) {
            attendanceSectionHeader(
                title: "报名学员",
                count: roster.count,
                systemImage: "person.2",
                tint: theme.secondaryText,
                theme: theme
            )

            HStack(spacing: 0) {
                ForEach(RegularAttendanceColumn.allCases) { column in
                    MDTableColumnHeader(
                        title: column.title,
                        width: column.width,
                        isSorted: regularSortColumn == column,
                        ascending: regularSortAscending,
                        options: regularFilterOptions(roster, session: session, column: column),
                        selectedValues: mdTableFilterSelection(
                            storage: $regularFiltersStorage,
                            key: column.rawValue
                        ),
                        onSort: { toggleRegularSort(column) }
                    )
                }
                Spacer()
            }
            .frame(height: 34)
            .background(theme.subtleSurface.opacity(0.72))

            if filtered.isEmpty {
                attendanceEmptyRow(searchText.isEmpty ? "暂无报名学员" : "没有匹配的报名学员", theme: theme)
            } else {
                ForEach(filtered) { enrollment in
                    AttendanceRow(
                        model: model,
                        session: session,
                        enrollment: enrollment
                    )
                    Divider()
                }
            }
        }
    }

    private func specialAttendanceSection(
        kind: AttendanceGuestKind,
        records: [Attendance],
        theme: MDTheme
    ) -> some View {
        let filtered = filteredSpecialRecords(records, kind: kind)
        return VStack(spacing: 0) {
            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 8) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(kind.color(theme: theme))
                Text(kind.sectionTitle)
                    .mdFont(.bodyStrong)
                Text("\(records.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Button {
                    addingGuestKind = kind
                } label: {
                    Label(kind.addTitle, systemImage: "plus")
                        .mdFont(.compactStrong)
                }
                .buttonStyle(.borderless)
                .help(kind.addTitle)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(kind.color(theme: theme).opacity(colorScheme == .dark ? 0.08 : 0.045))

            HStack(spacing: 0) {
                ForEach(GuestAttendanceColumn.allCases) { column in
                    MDTableColumnHeader(
                        title: column.title,
                        width: column.width,
                        isSorted: guestSortColumn(for: kind) == column,
                        ascending: guestSortAscending(for: kind),
                        options: guestFilterOptions(records, kind: kind, column: column),
                        selectedValues: guestFilterSelection(kind: kind, column: column),
                        onSort: { toggleGuestSort(column, kind: kind) }
                    )
                }
                Spacer()
                Text("操作")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: AttendanceColumns.action)
            }
            .frame(height: 32)
            .background(theme.subtleSurface.opacity(0.72))

            if filtered.isEmpty {
                attendanceEmptyRow(
                    searchText.isEmpty ? "暂无\(kind.sectionTitle)" : "没有匹配的\(kind.sectionTitle)",
                    theme: theme
                )
            } else {
                ForEach(filtered) { record in
                    specialAttendanceRow(record, kind: kind, theme: theme)
                    Divider()
                }
            }
        }
    }

    private func specialAttendanceRow(
        _ record: Attendance,
        kind: AttendanceGuestKind,
        theme: MDTheme
    ) -> some View {
        let student = model.student(id: record.studentID)
        let guardian = student.flatMap { model.guardian(id: $0.guardianID) }
        return HStack(spacing: 0) {
            attendanceCell(student?.displayName ?? "学员", width: AttendanceColumns.student, strong: true)
            attendanceCell(guardian?.displayName ?? "未知家庭", width: AttendanceColumns.family)
            HStack(spacing: 6) {
                Image(systemName: kind.systemImage)
                Text(kind.shortTitle)
            }
            .mdFont(.compactStrong)
            .foregroundStyle(kind.color(theme: theme))
            .padding(.leading, 10)
            .frame(width: AttendanceColumns.guestStatus, alignment: .leading)
            attendanceCell(
                record.recordedAt.formatted(date: .omitted, time: .shortened),
                width: AttendanceColumns.time,
                mono: true,
                secondary: true
            )
            Spacer()

            if deletingAttendanceID == record.id {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: AttendanceColumns.action)
            } else {
                Button {
                    deleteSpecialAttendance(record, kind: kind)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("取消\(kind.shortTitle)，恢复为未记录")
                .frame(width: AttendanceColumns.action)
            }
        }
        .frame(minHeight: 42)
    }

    private func attendanceSectionHeader(
        title: String,
        count: Int,
        systemImage: String,
        tint: Color,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(title)
                .mdFont(.bodyStrong)
            Text("\(count)")
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(theme.surface)
    }

    private func attendanceEmptyRow(_ title: String, theme: MDTheme) -> some View {
        Text(title)
            .mdFont(.compact)
            .foregroundStyle(theme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
    }

    private var sessionsForDate: [ClassSession] {
        model.sessions
            .filter { Calendar.masterDance.isDate($0.startsAt, inSameDayAs: selectedDate) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func regularRoster(course: Course, session: ClassSession) -> [Enrollment] {
        model.enrollments(forSession: session.id).filter { enrollment in
            guard let record = attendanceRecord(sessionID: session.id, studentID: enrollment.studentID) else {
                return true
            }
            return !record.status.isGuestAttendance
        }
    }

    private func filteredRegularRoster(
        _ roster: [Enrollment],
        session: ClassSession
    ) -> [Enrollment] {
        let query = normalizedSearchText
        var result = roster.filter { enrollment in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else if let student = model.student(id: enrollment.studentID) {
                let guardian = model.guardian(id: student.guardianID)
                matchesSearch = student.displayName.localizedCaseInsensitiveContains(query)
                    || guardian?.displayName.localizedCaseInsensitiveContains(query) == true
            } else {
                matchesSearch = false
            }
            return matchesSearch && matchesRegularFilters(enrollment, session: session)
        }
        guard let regularSortColumn else { return result }
        result.sort { regularOrderedBefore($0, $1, session: session, by: regularSortColumn) }
        return result
    }

    private func specialRecords(session: ClassSession, status: AttendanceStatus) -> [Attendance] {
        model.attendance
            .filter { $0.sessionID == session.id && $0.status == status }
            .sorted { lhs, rhs in
                let left = model.student(id: lhs.studentID)?.displayName ?? ""
                let right = model.student(id: rhs.studentID)?.displayName ?? ""
                return left.localizedCompare(right) == .orderedAscending
            }
    }

    private func filteredSpecialRecords(
        _ records: [Attendance],
        kind: AttendanceGuestKind
    ) -> [Attendance] {
        let query = normalizedSearchText
        var result = records.filter { record in
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else if let student = model.student(id: record.studentID) {
                let guardian = model.guardian(id: student.guardianID)
                matchesSearch = student.displayName.localizedCaseInsensitiveContains(query)
                    || guardian?.displayName.localizedCaseInsensitiveContains(query) == true
            } else {
                matchesSearch = false
            }
            return matchesSearch && matchesGuestFilters(record, kind: kind)
        }
        guard let sortColumn = guestSortColumn(for: kind) else { return result }
        result.sort { guestOrderedBefore($0, $1, kind: kind, by: sortColumn) }
        return result
    }

    private var regularSortColumn: RegularAttendanceColumn? {
        get { RegularAttendanceColumn(rawValue: regularSortColumnStorage) }
        nonmutating set { regularSortColumnStorage = newValue?.rawValue ?? "" }
    }

    private func toggleRegularSort(_ column: RegularAttendanceColumn) {
        if regularSortColumn == column {
            regularSortAscending.toggle()
        } else {
            regularSortColumn = column
            regularSortAscending = true
        }
    }

    private func regularFilterOptions(
        _ roster: [Enrollment],
        session: ClassSession,
        column: RegularAttendanceColumn
    ) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            roster,
            key: { regularColumnKey($0, session: session, column: column) },
            label: { regularColumnLabel($0, session: session, column: column) }
        )
    }

    private func matchesRegularFilters(_ enrollment: Enrollment, session: ClassSession) -> Bool {
        RegularAttendanceColumn.allCases.allSatisfy { column in
            let values = MDTableFilterCodec.selection(in: regularFiltersStorage, for: column.rawValue)
            return values.isEmpty
                || values.contains(regularColumnKey(enrollment, session: session, column: column))
        }
    }

    private func regularColumnKey(
        _ enrollment: Enrollment,
        session: ClassSession,
        column: RegularAttendanceColumn
    ) -> String {
        let record = attendanceRecord(sessionID: session.id, studentID: enrollment.studentID)
        let leaveRequest = model.leaveRequest(sessionID: session.id, studentID: enrollment.studentID)
        return switch column {
        case .student: enrollment.studentID.description
        case .status:
            model.effectiveAttendanceStatus(
                sessionID: session.id,
                studentID: enrollment.studentID
            )?.rawValue ?? "unrecorded"
        case .time:
            (record?.recordedAt ?? leaveRequest?.submittedAt)?
                .formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)) ?? "unrecorded"
        }
    }

    private func regularColumnLabel(
        _ enrollment: Enrollment,
        session: ClassSession,
        column: RegularAttendanceColumn
    ) -> String {
        let record = attendanceRecord(sessionID: session.id, studentID: enrollment.studentID)
        let leaveRequest = model.leaveRequest(sessionID: session.id, studentID: enrollment.studentID)
        return switch column {
        case .student: model.student(id: enrollment.studentID)?.displayName ?? "—"
        case .status:
            model.effectiveAttendanceStatus(
                sessionID: session.id,
                studentID: enrollment.studentID
            ).map(attendanceStatusLabel) ?? "未记录"
        case .time:
            (record?.recordedAt ?? leaveRequest?.submittedAt)?
                .formatted(date: .omitted, time: .shortened) ?? "未记录"
        }
    }

    private func regularOrderedBefore(
        _ lhs: Enrollment,
        _ rhs: Enrollment,
        session: ClassSession,
        by column: RegularAttendanceColumn
    ) -> Bool {
        if column == .time {
            let left = attendanceRecord(sessionID: session.id, studentID: lhs.studentID)?.recordedAt
                ?? model.leaveRequest(sessionID: session.id, studentID: lhs.studentID)?.submittedAt
                ?? .distantFuture
            let right = attendanceRecord(sessionID: session.id, studentID: rhs.studentID)?.recordedAt
                ?? model.leaveRequest(sessionID: session.id, studentID: rhs.studentID)?.submittedAt
                ?? .distantFuture
            if left != right { return regularSortAscending ? left < right : left > right }
        }
        let comparison = regularColumnLabel(lhs, session: session, column: column)
            .localizedStandardCompare(regularColumnLabel(rhs, session: session, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return regularSortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func guestSortColumn(for kind: AttendanceGuestKind) -> GuestAttendanceColumn? {
        let raw = kind == .trial ? trialSortColumnStorage : makeupSortColumnStorage
        return GuestAttendanceColumn(rawValue: raw)
    }

    private func guestSortAscending(for kind: AttendanceGuestKind) -> Bool {
        kind == .trial ? trialSortAscending : makeupSortAscending
    }

    private func setGuestSortColumn(_ column: GuestAttendanceColumn?, kind: AttendanceGuestKind) {
        if kind == .trial {
            trialSortColumnStorage = column?.rawValue ?? ""
        } else {
            makeupSortColumnStorage = column?.rawValue ?? ""
        }
    }

    private func toggleGuestSort(_ column: GuestAttendanceColumn, kind: AttendanceGuestKind) {
        if guestSortColumn(for: kind) == column {
            if kind == .trial {
                trialSortAscending.toggle()
            } else {
                makeupSortAscending.toggle()
            }
        } else {
            setGuestSortColumn(column, kind: kind)
            if kind == .trial {
                trialSortAscending = true
            } else {
                makeupSortAscending = true
            }
        }
    }

    private func guestFilterStorage(for kind: AttendanceGuestKind) -> Binding<String> {
        kind == .trial ? $trialFiltersStorage : $makeupFiltersStorage
    }

    private func guestFilterSelection(
        kind: AttendanceGuestKind,
        column: GuestAttendanceColumn
    ) -> Binding<Set<String>> {
        mdTableFilterSelection(storage: guestFilterStorage(for: kind), key: column.rawValue)
    }

    private func guestFilterOptions(
        _ records: [Attendance],
        kind: AttendanceGuestKind,
        column: GuestAttendanceColumn
    ) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            records,
            key: { guestColumnKey($0, kind: kind, column: column) },
            label: { guestColumnLabel($0, kind: kind, column: column) }
        )
    }

    private func matchesGuestFilters(_ record: Attendance, kind: AttendanceGuestKind) -> Bool {
        let storage = guestFilterStorage(for: kind).wrappedValue
        return GuestAttendanceColumn.allCases.allSatisfy { column in
            let values = MDTableFilterCodec.selection(in: storage, for: column.rawValue)
            return values.isEmpty || values.contains(guestColumnKey(record, kind: kind, column: column))
        }
    }

    private func guestColumnKey(
        _ record: Attendance,
        kind: AttendanceGuestKind,
        column: GuestAttendanceColumn
    ) -> String {
        let student = model.student(id: record.studentID)
        return switch column {
        case .student: record.studentID.description
        case .family: student?.guardianID.description ?? "none"
        case .type: kind.rawValue
        case .time:
            record.recordedAt.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        }
    }

    private func guestColumnLabel(
        _ record: Attendance,
        kind: AttendanceGuestKind,
        column: GuestAttendanceColumn
    ) -> String {
        let student = model.student(id: record.studentID)
        return switch column {
        case .student: student?.displayName ?? "—"
        case .family: student.flatMap { model.guardian(id: $0.guardianID) }?.displayName ?? "未知家庭"
        case .type: kind.shortTitle
        case .time: record.recordedAt.formatted(date: .omitted, time: .shortened)
        }
    }

    private func guestOrderedBefore(
        _ lhs: Attendance,
        _ rhs: Attendance,
        kind: AttendanceGuestKind,
        by column: GuestAttendanceColumn
    ) -> Bool {
        let ascending = guestSortAscending(for: kind)
        if column == .time, lhs.recordedAt != rhs.recordedAt {
            return ascending ? lhs.recordedAt < rhs.recordedAt : lhs.recordedAt > rhs.recordedAt
        }
        let comparison = guestColumnLabel(lhs, kind: kind, column: column)
            .localizedStandardCompare(guestColumnLabel(rhs, kind: kind, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func guestCandidates(course: Course, session: ClassSession) -> [Student] {
        let enrolledStudentIDs = Set(model.enrollments(forSession: session.id).map(\.studentID))
        let recordedStudentIDs = Set(
            model.attendance
                .filter { $0.sessionID == session.id }
                .map(\.studentID)
        )
        return model.students
            .filter {
                $0.isActive
                    && !enrolledStudentIDs.contains($0.id)
                    && !recordedStudentIDs.contains($0.id)
            }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private func attendanceRecord(sessionID: ClassSessionID, studentID: StudentID) -> Attendance? {
        model.attendance.first { $0.sessionID == sessionID && $0.studentID == studentID }
    }

    private func presentCount(_ session: ClassSession) -> Int {
        model.attendance.filter { $0.sessionID == session.id && $0.status == .present }.count
    }

    private func leaveCount(_ session: ClassSession) -> Int {
        model.leaveRequests.filter { $0.sessionID == session.id }.count
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addGuest(
        _ studentID: StudentID,
        kind: AttendanceGuestKind,
        session: ClassSession,
        sourceSessionID: ClassSessionID?
    ) {
        addingGuestKind = nil
        model.performBackgroundOperation(
            label: kind.addTitle,
            successMessage: "已添加\(kind.shortTitle)学员"
        ) {
            try await model.recordAttendance(
                sessionID: session.id,
                studentID: studentID,
                status: kind.status,
                makeupForSessionID: sourceSessionID
            )
        }
    }

    private func deleteSpecialAttendance(_ record: Attendance, kind: AttendanceGuestKind) {
        deletingAttendanceID = record.id
        model.performBackgroundOperation(
            label: "取消\(kind.shortTitle)",
            successMessage: "已取消\(kind.shortTitle)，恢复为未记录",
            completion: { _ in deletingAttendanceID = nil }
        ) {
            try await model.deleteAttendance(id: record.id)
        }
    }
}

@MainActor
private struct AttendanceRow: View {
    let model: AppModel
    let session: ClassSession
    let enrollment: Enrollment

    @State private var isSaving = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let record = model.attendance.first {
            $0.sessionID == session.id && $0.studentID == enrollment.studentID
        }
        let leaveRequest = model.leaveRequest(
            sessionID: session.id,
            studentID: enrollment.studentID
        )
        let effectiveStatus = model.effectiveAttendanceStatus(
            sessionID: session.id,
            studentID: enrollment.studentID
        )
        let derivedLeaveLabel = record == nil
            ? leaveRequest.map { $0.source == .app ? "家长请假" : "教务请假" }
            : nil
        HStack(spacing: 0) {
            attendanceCell(
                model.student(id: enrollment.studentID)?.displayName ?? "学员",
                width: AttendanceColumns.student,
                strong: true
            )

            HStack(spacing: 12) {
                statusButton(
                    .present,
                    record: record,
                    effectiveStatus: effectiveStatus,
                    derivedLeaveLabel: derivedLeaveLabel,
                    color: theme.success
                )
                statusButton(
                    .excused,
                    record: record,
                    effectiveStatus: effectiveStatus,
                    derivedLeaveLabel: derivedLeaveLabel,
                    color: theme.warning
                )
                statusButton(
                    .absent,
                    record: record,
                    effectiveStatus: effectiveStatus,
                    derivedLeaveLabel: derivedLeaveLabel,
                    color: theme.danger
                )
                if let record {
                    Button {
                        updateAttendance(nil, record: record)
                    } label: {
                        Label("取消", systemImage: "arrow.uturn.backward")
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                    .help("取消签到状态，恢复为未记录")
                }
            }
            .padding(.leading, 10)
            .frame(width: AttendanceColumns.regularStatus, alignment: .leading)

            attendanceCell(
                (record?.recordedAt ?? leaveRequest?.submittedAt)?
                    .formatted(date: .omitted, time: .shortened) ?? "—",
                width: AttendanceColumns.time,
                mono: true,
                secondary: true
            )

            Spacer()
            if isSaving {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 12)
            }
        }
        .frame(minHeight: 42)
    }

    private func statusButton(
        _ status: AttendanceStatus,
        record: Attendance?,
        effectiveStatus: AttendanceStatus?,
        derivedLeaveLabel: String?,
        color: Color
    ) -> some View {
        let isCurrent = effectiveStatus == status
        let isReadOnlyLeave = derivedLeaveLabel != nil && status == .excused
        return Button {
            guard !isReadOnlyLeave else { return }
            updateAttendance(isCurrent ? nil : status, record: record)
        } label: {
            Label(
                isReadOnlyLeave ? (derivedLeaveLabel ?? "请假") : attendanceStatusLabel(status),
                systemImage: isCurrent ? "checkmark.circle.fill" : "circle"
            )
                .mdFont(.compact)
                .foregroundStyle(isCurrent ? color : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .help(
            isReadOnlyLeave
                ? "这是请假记录；请到“请假”页编辑或删除"
                : (isCurrent
                    ? "再次点击取消\(attendanceStatusLabel(status))"
                    : "标记为\(attendanceStatusLabel(status))")
        )
    }

    private func updateAttendance(_ status: AttendanceStatus?, record: Attendance?) {
        guard status != nil || record != nil else { return }
        isSaving = true
        if let status {
            model.performBackgroundOperation(
                label: "记录签到",
                successMessage: "签到已记录",
                completion: { _ in isSaving = false }
            ) {
                try await model.recordAttendance(
                    sessionID: session.id,
                    studentID: enrollment.studentID,
                    status: status
                )
            }
        } else if let record {
            model.performBackgroundOperation(
                label: "取消签到状态",
                successMessage: "已恢复为未记录",
                completion: { _ in isSaving = false }
            ) {
                try await model.deleteAttendance(id: record.id)
            }
        }
    }
}

@MainActor
private struct AttendanceGuestPicker: View {
    let model: AppModel
    let kind: AttendanceGuestKind
    let candidates: [Student]
    let add: (StudentID, ClassSessionID?) -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(kind.color(theme: theme))
                Text(kind.addTitle)
                    .mdFont(.bodyStrong)
                Text("\(filteredCandidates.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("关闭")
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.secondaryText)
                TextField("搜索学员、监护人、邮箱或电话", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            Divider()

            if groups.isEmpty {
                ContentUnavailableView("没有可添加的学员", systemImage: "person.slash")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            HStack(spacing: 7) {
                                Text(group.guardianName)
                                    .mdFont(.compactStrong)
                                if !group.contact.isEmpty {
                                    Text(group.contact)
                                        .mdFont(.compact)
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(group.students.count)")
                                    .mdFont(.mono)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(theme.subtleSurface)

                            ForEach(group.students) { student in
                                studentAction(student, theme: theme)
                                Divider().padding(.leading, 46)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 560, height: 570)
        .background(theme.background)
        .onAppear { searchFocused = true }
    }

    @ViewBuilder
    private func studentAction(_ student: Student, theme: MDTheme) -> some View {
        if kind == .makeup {
            let sources = model.availableMakeupSourceSessions(forStudent: student.id)
            Menu {
                ForEach(sources) { source in
                    Button(model.makeupSourceDescription(source, forStudent: student.id)) {
                        add(student.id, source.id)
                        dismiss()
                    }
                }
            } label: {
                studentRow(
                    student,
                    trailing: sources.isEmpty ? "无待补课次" : "选择要补的 \(sources.count) 次",
                    theme: theme
                )
            }
            .menuStyle(.borderlessButton)
            .disabled(sources.isEmpty)
            .help(sources.isEmpty ? "这名学员目前没有可对应的请假或缺席" : "选择这次补课对应的原课次")
        } else {
            Button {
                add(student.id, nil)
                dismiss()
            } label: {
                studentRow(
                    student,
                    trailing: "已报 \(model.enrollments(for: student.id).count) 门课",
                    theme: theme
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func studentRow(
        _ student: Student,
        trailing: String,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: student.kind == .adult ? "person.crop.circle" : "figure.child.circle")
                .font(.system(size: 17))
                .foregroundStyle(kind.color(theme: theme))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(student.displayName)
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Text(student.kind == .adult ? "成人学员" : "少儿学员")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Text(trailing)
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
            Image(systemName: kind == .makeup ? "chevron.down.circle" : "plus.circle")
                .foregroundStyle(kind.color(theme: theme))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private var filteredCandidates: [Student] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter { student in
            let guardian = model.guardian(id: student.guardianID)
            return student.displayName.localizedCaseInsensitiveContains(query)
                || student.legalName?.localizedCaseInsensitiveContains(query) == true
                || guardian?.displayName.localizedCaseInsensitiveContains(query) == true
                || guardian?.email?.localizedCaseInsensitiveContains(query) == true
                || guardian?.phone?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var groups: [AttendanceStudentGroup] {
        Dictionary(grouping: filteredCandidates, by: \.guardianID)
            .map { guardianID, students in
                let guardian = model.guardian(id: guardianID)
                return AttendanceStudentGroup(
                    id: guardianID,
                    guardianName: guardian?.displayName ?? "未知家庭",
                    contact: [guardian?.email, guardian?.phone]
                        .compactMap { $0 }
                        .joined(separator: " · "),
                    students: students.sorted {
                        $0.displayName.localizedCompare($1.displayName) == .orderedAscending
                    }
                )
            }
            .sorted { $0.guardianName.localizedCompare($1.guardianName) == .orderedAscending }
    }
}

private struct AttendanceStudentGroup: Identifiable {
    let id: GuardianID
    let guardianName: String
    let contact: String
    let students: [Student]
}

private enum RegularAttendanceColumn: String, CaseIterable, Identifiable {
    case student
    case status
    case time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: "学员"
        case .status: "状态"
        case .time: "记录时间"
        }
    }

    var width: CGFloat {
        switch self {
        case .student: AttendanceColumns.student
        case .status: AttendanceColumns.regularStatus
        case .time: AttendanceColumns.time
        }
    }
}

private enum GuestAttendanceColumn: String, CaseIterable, Identifiable {
    case student
    case family
    case type
    case time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: "学员"
        case .family: "家庭"
        case .type: "类型"
        case .time: "记录时间"
        }
    }

    var width: CGFloat {
        switch self {
        case .student: AttendanceColumns.student
        case .family: AttendanceColumns.family
        case .type: AttendanceColumns.guestStatus
        case .time: AttendanceColumns.time
        }
    }
}

private enum AttendanceGuestKind: String, Identifiable {
    case trial
    case makeup

    var id: String { rawValue }

    var status: AttendanceStatus {
        switch self {
        case .trial: .trial
        case .makeup: .makeup
        }
    }

    var shortTitle: String {
        switch self {
        case .trial: "试课"
        case .makeup: "补课"
        }
    }

    var sectionTitle: String { shortTitle + "学员" }
    var addTitle: String { "添加" + shortTitle + "学员" }

    var systemImage: String {
        switch self {
        case .trial: "sparkles"
        case .makeup: "arrow.clockwise"
        }
    }

    @MainActor
    func color(theme: MDTheme) -> Color {
        switch self {
        case .trial: theme.accent
        case .makeup: theme.success
        }
    }
}

private enum AttendanceColumns {
    static let student: CGFloat = 190
    static let regularStatus: CGFloat = 300
    static let family: CGFloat = 190
    static let guestStatus: CGFloat = 110
    static let time: CGFloat = 150
    static let action: CGFloat = 50
}

private func attendanceStatusLabel(_ status: AttendanceStatus) -> String {
    switch status {
    case .present: "出勤"
    case .excused: "请假"
    case .absent: "缺席"
    case .makeup: "补课"
    case .trial: "试课"
    }
}

@MainActor
private func attendanceHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .mdFont(.compactStrong)
        .foregroundStyle(.secondary)
        .padding(.leading, 10)
        .frame(width: width, alignment: .leading)
}

@MainActor
private func attendanceCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false,
    secondary: Bool = false
) -> some View {
    Text(text)
        .mdFont(mono ? .mono : (strong ? .bodyStrong : .body))
        .foregroundStyle(secondary ? Color.secondary : Color.primary)
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.leading, 10)
        .frame(width: width, alignment: .leading)
}
#endif
