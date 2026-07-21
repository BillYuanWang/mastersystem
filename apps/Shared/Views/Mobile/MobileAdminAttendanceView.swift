#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileAttendanceHomeView: View {
    let model: AppModel
    @State private var selectedDate = Self.initialDate
    @State private var wheelDate = Self.initialDate
    @State private var isShowingDateWheel = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        List {
            Section {
                HStack(spacing: 12) {
                    Button {
                        moveDay(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("前一天")

                    Spacer(minLength: 4)

                    HStack(spacing: 6) {
                        DatePicker(
                            "签到日期",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))

                        Button {
                            wheelDate = Calendar.masterDance.startOfDay(for: selectedDate)
                            isShowingDateWheel = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(theme.accent.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .accessibilityLabel("滚轮选择日期")
                    }

                    Spacer(minLength: 4)

                    Button {
                        moveDay(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("后一天")
                }
                .foregroundStyle(theme.primaryText)
            }

            if sessionsForDay.isEmpty {
                ContentUnavailableView(
                    "这一天没有课程",
                    systemImage: "calendar",
                    description: Text("可以从上方选择其他日期。")
                )
                .listRowBackground(Color.clear)
            } else {
                Section("当天课程") {
                    ForEach(sessionsForDay) { session in
                        NavigationLink {
                            MobileAttendanceSessionView(model: model, sessionID: session.id)
                        } label: {
                            MobileSessionRow(
                                session: session,
                                course: model.course(id: session.courseID),
                                room: model.effectiveRoom(for: session),
                                instructor: model.effectiveInstructor(for: session),
                                trailingText: attendanceProgress(for: session)
                            )
                        }
                        .disabled(session.status == .cancelled)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("签到")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("今天") {
                    selectedDate = Calendar.masterDance.startOfDay(for: Date())
                }
                .disabled(Calendar.masterDance.isDateInToday(selectedDate))
            }
        }
        .refreshable { await model.refreshFromCloud() }
        .task {
            await model.synchronizeRemoteChanges()
        }
        .sheet(isPresented: $isShowingDateWheel) {
            MobileAttendanceDateWheel(
                draftDate: $wheelDate,
                anchorDate: selectedDate
            ) {
                selectedDate = Calendar.masterDance.startOfDay(for: wheelDate)
            }
            .presentationDetents([.height(370)])
            .presentationDragIndicator(.visible)
        }
    }

    private var sessionsForDay: [ClassSession] {
        model.sessions
            .filter { Calendar.masterDance.isDate($0.startsAt, inSameDayAs: selectedDate) }
            .sorted { $0.startsAt < $1.startsAt }
    }

    private func attendanceProgress(for session: ClassSession) -> String {
        let enrolledIDs = Set(model.enrollments(forCourse: session.courseID).map(\.studentID))
        let attendanceIDs: Set<StudentID> = Set(model.attendance.compactMap { record in
            guard record.sessionID == session.id, enrolledIDs.contains(record.studentID) else {
                return nil
            }
            return record.studentID
        })
        let leaveIDs: Set<StudentID> = Set(model.leaveRequests.compactMap { request in
            guard request.sessionID == session.id, enrolledIDs.contains(request.studentID) else {
                return nil
            }
            return request.studentID
        })
        return "\(attendanceIDs.union(leaveIDs).count)/\(enrolledIDs.count) · 请假 \(leaveIDs.count)"
    }

    private func moveDay(_ offset: Int) {
        selectedDate = Calendar.masterDance.date(
            byAdding: .day,
            value: offset,
            to: selectedDate
        ) ?? selectedDate
    }

    private static var initialDate: Date {
        let calendar = Calendar.masterDance
        let today = calendar.startOfDay(for: Date())
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--md-preview-admin") {
            switch calendar.component(.weekday, from: today) {
            case 1:
                return calendar.date(byAdding: .day, value: -2, to: today) ?? today
            case 7:
                return calendar.date(byAdding: .day, value: -1, to: today) ?? today
            default:
                break
            }
        }
#endif
        return today
    }
}

@MainActor
private struct MobileAttendanceDateWheel: View {
    @Binding var draftDate: Date
    let onCommit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let dates: [Date]

    init(
        draftDate: Binding<Date>,
        anchorDate: Date,
        onCommit: @escaping () -> Void
    ) {
        _draftDate = draftDate
        self.onCommit = onCommit
        let calendar = Calendar.masterDance
        let anchor = calendar.startOfDay(for: anchorDate)
        dates = (-366...366).compactMap {
            calendar.date(byAdding: .day, value: $0, to: anchor)
        }
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            Picker("签到日期", selection: $draftDate) {
                ForEach(dates, id: \.self) { date in
                    Text(dateLabel(date))
                        .mdFont(.bodyStrong)
                        .tag(date)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipped()
            .navigationTitle("滚轮选日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onCommit()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(theme.accent)
            .background(theme.background)
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.masterDance
        let formatted = date.mdChineseFormatted(
            .dateTime.year().month().day().weekday(.wide)
        )
        if calendar.isDateInToday(date) { return "今天 · \(formatted)" }
        if calendar.isDateInTomorrow(date) { return "明天 · \(formatted)" }
        if calendar.isDateInYesterday(date) { return "昨天 · \(formatted)" }
        return formatted
    }
}

@MainActor
private struct MobileAttendanceSessionView: View {
    let model: AppModel
    let sessionID: ClassSessionID

    @State private var guestMode: AttendanceStatus?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        Group {
            if let session = model.session(id: sessionID),
               let course = model.course(id: session.courseID) {
                List {
                    Section {
                        MobileSessionRow(
                            session: session,
                            course: course,
                            room: model.effectiveRoom(for: session),
                            instructor: model.effectiveInstructor(for: session),
                            trailingText: nil
                        )
                    }

                    Section("报名学员 · \(enrolledStudents.count)") {
                        ForEach(enrolledStudents) { student in
                            enrolledStudentRow(student, session: session, theme: theme)
                        }
                    }

                    guestSection(
                        title: "试课学员",
                        status: .trial,
                        records: guestRecords(status: .trial),
                        session: session,
                        theme: theme
                    )

                    guestSection(
                        title: "补课学员",
                        status: .makeup,
                        records: guestRecords(status: .makeup),
                        session: session,
                        theme: theme
                    )
                }
                .listStyle(.insetGrouped)
                .navigationTitle(course.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                guestMode = .trial
                            } label: {
                                Label("添加试课学员", systemImage: "sparkles")
                            }
                            Button {
                                guestMode = .makeup
                            } label: {
                                Label("添加补课学员", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        .accessibilityLabel("添加临时学员")
                    }
                }
            } else {
                ContentUnavailableView("课程不存在", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .sheet(isPresented: guestModePresentation) {
            if let mode = guestMode, let session = model.session(id: sessionID) {
                MobileGuestAttendancePicker(
                    model: model,
                    session: session,
                    mode: mode
                )
            }
        }
    }

    private var guestModePresentation: Binding<Bool> {
        Binding(
            get: { guestMode != nil },
            set: { isPresented in
                if !isPresented { guestMode = nil }
            }
        )
    }

    private var enrolledStudents: [Student] {
        guard let session = model.session(id: sessionID) else { return [] }
        let studentIDs = Set(model.enrollments(forCourse: session.courseID).map(\.studentID))
        return model.students
            .filter { studentIDs.contains($0.id) }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private func enrolledStudentRow(
        _ student: Student,
        session: ClassSession,
        theme: MDTheme
    ) -> some View {
        let record = model.attendanceRecord(sessionID: session.id, studentID: student.id)
        let leaveRequest = model.leaveRequest(sessionID: session.id, studentID: student.id)
        let effectiveStatus = model.effectiveAttendanceStatus(
            sessionID: session.id,
            studentID: student.id
        )
        let derivedLeaveTitle = record == nil
            ? leaveRequest.map { $0.source == .app ? "家长请假" : "教务请假" }
            : nil
        let leaveTitle = derivedLeaveTitle ?? "请假"
        return HStack(spacing: 10) {
            Button {
                setAttendance(record == nil ? .present : nil, student: student, session: session)
            } label: {
                Image(systemName: effectiveStatus?.mobileSystemImage ?? "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(effectiveStatus?.mobileColor(theme: theme) ?? theme.secondaryText)
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                record == nil
                    ? (derivedLeaveTitle == nil ? "标记出勤" : "\(leaveTitle)，点按改为出勤")
                    : (leaveRequest == nil
                        ? "取消\(record!.status.mobileTitle)，恢复为未记录"
                        : "取消\(record!.status.mobileTitle)，恢复显示请假")
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(student.displayName)
                    .mdFont(.bodyStrong)
                Text(model.guardian(id: student.guardianID)?.displayName ?? "")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer()

            Menu {
                ForEach([AttendanceStatus.present, .excused, .absent], id: \.self) { status in
                    Button {
                        setAttendance(
                            record?.status == status ? nil : status,
                            student: student,
                            session: session
                        )
                    } label: {
                        Label(
                            derivedLeaveTitle != nil && status == .excused
                                ? leaveTitle
                                : status.mobileTitle,
                            systemImage: effectiveStatus == status
                                ? "checkmark.circle.fill"
                                : status.mobileSystemImage
                        )
                    }
                    .disabled(derivedLeaveTitle != nil && status == .excused)
                }
                if record != nil {
                    Divider()
                    Button {
                        setAttendance(nil, student: student, session: session)
                    } label: {
                        Label("取消签到状态", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                if let effectiveStatus {
                    MobileStatusPill(
                        title: derivedLeaveTitle ?? effectiveStatus.mobileTitle,
                        systemImage: effectiveStatus.mobileSystemImage,
                        color: effectiveStatus.mobileColor(theme: theme)
                    )
                } else {
                    Text("未记录")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            if record != nil {
                Button {
                    setAttendance(nil, student: student, session: session)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryText)
                .accessibilityLabel(
                    leaveRequest == nil
                        ? "取消签到状态，恢复为未记录"
                        : "取消签到覆盖，恢复显示请假"
                )
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func guestSection(
        title: String,
        status: AttendanceStatus,
        records: [Attendance],
        session: ClassSession,
        theme: MDTheme
    ) -> some View {
        Section {
            if records.isEmpty {
                Button {
                    guestMode = status
                } label: {
                    Label("添加\(title)", systemImage: "person.badge.plus")
                }
            } else {
                ForEach(records) { record in
                    HStack {
                        Image(systemName: status.mobileSystemImage)
                            .foregroundStyle(status.mobileColor(theme: theme))
                            .frame(width: 24)
                        Text(model.student(id: record.studentID)?.displayName ?? "学员")
                            .mdFont(.bodyStrong)
                        Spacer()
                        Button(role: .destructive) {
                            removeAttendance(record)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.secondaryText)
                        .accessibilityLabel("取消\(status.mobileTitle)，恢复为未记录")
                    }
                }
                Button {
                    guestMode = status
                } label: {
                    Label("继续添加", systemImage: "plus")
                        .mdFont(.compactStrong)
                }
            }
        } header: {
            Text("\(title) · \(records.count)")
        }
    }

    private func guestRecords(status: AttendanceStatus) -> [Attendance] {
        model.attendance
            .filter { $0.sessionID == sessionID && $0.status == status }
            .sorted {
                (model.student(id: $0.studentID)?.displayName ?? "")
                    .localizedCompare(model.student(id: $1.studentID)?.displayName ?? "") == .orderedAscending
            }
    }

    private func setAttendance(
        _ status: AttendanceStatus?,
        student: Student,
        session: ClassSession
    ) {
        if let status {
            model.performBackgroundOperation(
                label: "记录\(status.mobileTitle)",
                successMessage: "\(student.displayName)已标记为\(status.mobileTitle)"
            ) {
                try await model.recordAttendance(
                    sessionID: session.id,
                    studentID: student.id,
                    status: status
                )
            }
        } else if let record = model.attendanceRecord(sessionID: session.id, studentID: student.id) {
            removeAttendance(record)
        }
    }

    private func removeAttendance(_ record: Attendance) {
        let studentName = model.student(id: record.studentID)?.displayName ?? "学员"
        let restoresLeave = model.leaveRequest(
            sessionID: record.sessionID,
            studentID: record.studentID
        ) != nil
        model.performBackgroundOperation(
            label: "取消签到状态",
            successMessage: restoresLeave
                ? "\(studentName)已恢复显示请假"
                : "\(studentName)已恢复为未记录"
        ) {
            try await model.deleteAttendance(id: record.id)
        }
    }
}

@MainActor
private struct MobileGuestAttendancePicker: View {
    let model: AppModel
    let session: ClassSession
    let mode: AttendanceStatus

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            List(filteredCandidates) { student in
                candidateAction(student, theme: theme)
            }
            .searchable(text: $searchText, prompt: "搜索学员或监护人")
            .overlay {
                if filteredCandidates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle(mode == .trial ? "添加试课学员" : "添加补课学员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func candidateAction(_ student: Student, theme: MDTheme) -> some View {
        if mode == .makeup {
            let sources = model.availableMakeupSourceSessions(forStudent: student.id)
            NavigationLink {
                MobileMakeupSourcePicker(
                    model: model,
                    student: student,
                    sources: sources,
                    onSelect: { sourceSessionID in
                        add(student, sourceSessionID: sourceSessionID)
                        dismiss()
                    }
                )
            } label: {
                candidateRow(
                    student,
                    detail: sources.isEmpty ? "没有待补的请假或缺席" : "可对应 \(sources.count) 次请假或缺席",
                    theme: theme
                )
            }
            .disabled(existingStudentIDs.contains(student.id) || sources.isEmpty)
        } else {
            Button {
                add(student, sourceSessionID: nil)
            } label: {
                candidateRow(
                    student,
                    detail: model.guardian(id: student.guardianID)?.displayName ?? "",
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .disabled(existingStudentIDs.contains(student.id))
        }
    }

    private func candidateRow(
        _ student: Student,
        detail: String,
        theme: MDTheme
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(student.displayName)
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Text(detail)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if existingStudentIDs.contains(student.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(mode.mobileColor(theme: theme))
            } else if mode != .makeup {
                Image(systemName: "plus.circle")
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private var enrolledStudentIDs: Set<StudentID> {
        Set(model.enrollments(forCourse: session.courseID).map(\.studentID))
    }

    private var existingStudentIDs: Set<StudentID> {
        Set(model.attendance.filter { $0.sessionID == session.id }.map(\.studentID))
    }

    private var filteredCandidates: [Student] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.students
            .filter { !enrolledStudentIDs.contains($0.id) }
            .filter { student in
                guard !query.isEmpty else { return true }
                let guardian = model.guardian(id: student.guardianID)
                return student.displayName.localizedCaseInsensitiveContains(query)
                    || guardian?.displayName.localizedCaseInsensitiveContains(query) == true
                    || guardian?.email?.localizedCaseInsensitiveContains(query) == true
                    || guardian?.phone?.localizedCaseInsensitiveContains(query) == true
            }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    private func add(_ student: Student, sourceSessionID: ClassSessionID?) {
        model.performBackgroundOperation(
            label: "添加\(mode.mobileTitle)",
            successMessage: "\(student.displayName)已加入\(mode.mobileTitle)"
        ) {
            try await model.recordAttendance(
                sessionID: session.id,
                studentID: student.id,
                status: mode,
                makeupForSessionID: sourceSessionID
            )
        }
    }
}

@MainActor
private struct MobileMakeupSourcePicker: View {
    let model: AppModel
    let student: Student
    let sources: [ClassSession]
    let onSelect: (ClassSessionID) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        List(sources) { source in
            Button {
                onSelect(source.id)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: sourceStatus(source) == .absent ? "xmark.circle.fill" : "calendar.badge.minus")
                        .foregroundStyle(sourceStatus(source) == .absent ? theme.danger : theme.warning)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.course(id: source.courseID)?.name ?? "课程")
                            .mdFont(.bodyStrong)
                            .foregroundStyle(theme.primaryText)
                        Text(source.startsAt.mdChineseFormatted(.dateTime.year().month().day().weekday(.wide).hour().minute()))
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    Text(sourceStatus(source) == .absent ? "缺席" : "请假")
                        .mdFont(.compactStrong)
                        .foregroundStyle(sourceStatus(source) == .absent ? theme.danger : theme.warning)
                }
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("选择要补的课次")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceStatus(_ session: ClassSession) -> AttendanceStatus? {
        model.effectiveAttendanceStatus(sessionID: session.id, studentID: student.id)
    }
}
#endif
