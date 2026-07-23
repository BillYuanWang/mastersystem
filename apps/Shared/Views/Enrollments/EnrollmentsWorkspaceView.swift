#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct EnrollmentsWorkspaceView: View {
    let model: AppModel

    @SceneStorage("md-desk.enrollments.selected-term-id") private var selectedTermIDStorage = ""
    @SceneStorage("md-desk.enrollments.search") private var searchText = ""
    @SceneStorage("md-desk.enrollments.sort-column") private var sortColumnStorage = ""
    @SceneStorage("md-desk.enrollments.sort-ascending") private var sortAscending = true
    @SceneStorage("md-desk.enrollments.column-filters") private var columnFiltersStorage = ""
    @State private var draftStudentID: StudentID?
    @State private var draftCourseID: CourseID?
    @State private var draftRegistrationMode = EnrollmentRegistrationMode.fullTerm
    @State private var draftSelectedSessionIDs: Set<ClassSessionID> = []
    @State private var showingStudentPicker = false
    @State private var showingCoursePicker = false
    @State private var showingRegistrationPicker = false
    @State private var pendingEnrollments: [PendingEnrollmentSubmission] = []
    @State private var deletingID: EnrollmentID?
    @State private var editingEnrollment: Enrollment?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            header(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)
            enrollmentTable(theme: theme)
        }
        .background(theme.background)
        .task(id: model.terms.map(\.id)) {
            guard !model.terms.isEmpty else { return }
            let preservesAllTerms = selectedTermIDStorage == "all"
            let hasValidTerm = selectedTermID.map { selectedID in
                model.terms.contains { $0.id == selectedID }
            } ?? false
            if selectedTermIDStorage.isEmpty || (!preservesAllTerms && !hasValidTerm) {
                selectedTermID = model.currentEnrollmentTerm?.id ?? model.terms.first?.id
            }
        }
        .onChange(of: selectedTermID) { _, termID in
            guard let termID, let course = draftCourse, course.termID != termID else { return }
            draftCourseID = nil
            draftRegistrationMode = .fullTerm
            draftSelectedSessionIDs.removeAll()
        }
        .sheet(item: $editingEnrollment) { enrollment in
            EnrollmentBillingEditorView(model: model, enrollment: enrollment)
        }
    }

    private func header(theme: MDTheme) -> some View {
        let summary = enrollmentSummary
        return HStack(spacing: 10) {
            MDSectionTitle(chinese: "报名", english: "ENROLLMENT")
            headerMetric("总报名", value: summary.totalEnrollmentCount, color: theme.accent, theme: theme)
            headerDivider(theme: theme)
            headerMetric("大课报名", value: summary.groupEnrollmentCount, color: theme.success, theme: theme)
            headerDivider(theme: theme)
            headerMetric("私课报名", value: summary.privateEnrollmentCount, color: theme.warning, theme: theme)
            Spacer()
            Picker("学期", selection: selectedTermSelection) {
                Text("全部学期").tag(Optional<TermID>.none)
                ForEach(model.terms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            .labelsHidden()
            .frame(width: 150)
            TextField("搜索学员、家庭或课程", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .mdFont(.compact)
                .frame(width: 230)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func headerMetric(
        _ title: String,
        value: Int,
        color: Color,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
            Text("\(value)")
                .mdFont(.monoStrong)
                .foregroundStyle(color)
        }
    }

    private func headerDivider(theme: MDTheme) -> some View {
        Rectangle()
            .fill(theme.separator)
            .frame(width: 1, height: 16)
    }

    private func enrollmentTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            tableHeader(theme: theme)
            draftRow(theme: theme)
            Rectangle().fill(theme.separator).frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pendingEnrollments) { submission in
                        pendingRow(submission, theme: theme)
                        Divider()
                    }

                    ForEach(filteredEnrollments) { enrollment in
                        enrollmentRow(enrollment, theme: theme)
                        Divider()
                    }
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private func tableHeader(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(EnrollmentTableColumn.allCases) { column in
                enrollmentColumnHeader(column)
            }
            Spacer(minLength: 0)
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
            .frame(width: EnrollmentColumns.action)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private func enrollmentColumnHeader(_ column: EnrollmentTableColumn) -> some View {
        MDTableColumnHeader(
            title: column.title,
            width: column.width,
            isSorted: sortColumn == column,
            ascending: sortAscending,
            options: enrollmentFilterOptions(for: column),
            selectedValues: mdTableFilterSelection(
                storage: $columnFiltersStorage,
                key: column.rawValue
            ),
            onSort: { toggleSort(column) }
        )
    }

    private func draftRow(theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            Button {
                showingStudentPicker = true
            } label: {
                selectionLabel(
                    title: draftStudent?.displayName ?? "选择学员",
                    subtitle: draftStudent.map(studentSubtitle) ?? "按家庭查找",
                    systemImage: "person.crop.circle",
                    width: EnrollmentColumns.student,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingStudentPicker, arrowEdge: .bottom) {
                StudentEnrollmentPicker(
                    model: model,
                    selectedID: draftStudentID,
                    select: selectStudent
                )
            }
            .help("选择学员")

            Button {
                showingCoursePicker = true
            } label: {
                selectionLabel(
                    title: draftCourse?.name ?? "选择课程",
                    subtitle: draftCourse.map(courseSelectorSubtitle) ?? "按星期和时间查找",
                    systemImage: "calendar.badge.plus",
                    width: EnrollmentColumns.course,
                    theme: theme
                )
            }
            .buttonStyle(.plain)
            .disabled(draftStudentID == nil)
            .popover(isPresented: $showingCoursePicker, arrowEdge: .bottom) {
                CourseEnrollmentPicker(
                    model: model,
                    courses: availableDraftCourses,
                    selectedID: draftCourseID,
                    select: selectCourse
                )
            }
            .help(draftStudentID == nil ? "请先选择学员" : "选择课程")

            enrollmentCell(draftCourse.flatMap { model.term(id: $0.termID) }?.name ?? "—", width: EnrollmentColumns.term)
            enrollmentCell(draftCourse.map(scheduleLabel) ?? "—", width: EnrollmentColumns.schedule, mono: draftCourse != nil)
            enrollmentCell(draftCourse.map(staffAndRoom) ?? "—", width: EnrollmentColumns.staff)
            Button {
                showingRegistrationPicker = true
            } label: {
                enrollmentCell(draftRegistrationLabel, width: EnrollmentColumns.mode, strong: true)
            }
            .buttonStyle(.plain)
            .disabled(draftCourse == nil)
            .popover(isPresented: $showingRegistrationPicker, arrowEdge: .bottom) {
                if let course = draftCourse {
                    DraftEnrollmentRegistrationPicker(
                        model: model,
                        course: course,
                        mode: $draftRegistrationMode,
                        selectedSessionIDs: $draftSelectedSessionIDs
                    )
                }
            }
            .help(draftCourse?.format.requiresPerSessionEnrollment == true
                ? "私课仅支持选择具体课次"
                : "选择整期报名或具体课次")
            enrollmentCell(
                draftCourse.map { coursePriceLabel($0, mode: draftRegistrationMode) } ?? "—",
                width: EnrollmentColumns.price,
                mono: true
            )
            enrollmentCell(draftCourse.map(coursePricingStatusLabel) ?? "—", width: EnrollmentColumns.billing)
            enrollmentCell("待提交", width: EnrollmentColumns.status)
            enrollmentCell(Date().formatted(date: .abbreviated, time: .omitted), width: EnrollmentColumns.date, mono: true)
            Spacer(minLength: 0)

            Button(action: submitDraft) {
                Image(systemName: "checkmark")
            }
            .buttonStyle(MDIconButtonStyle())
            .disabled(!canSubmitDraft)
            .help("提交报名")
            .frame(width: EnrollmentColumns.action)
        }
        .frame(minHeight: 56)
        .background(theme.accent.opacity(colorScheme == .dark ? 0.075 : 0.045))
    }

    private func selectionLabel(
        title: String,
        subtitle: String,
        systemImage: String,
        width: CGFloat,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(width: 17)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 3)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 9)
        .frame(width: width - 8, height: 46, alignment: .leading)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
        .padding(.horizontal, 4)
    }

    private func pendingRow(_ submission: PendingEnrollmentSubmission, theme: MDTheme) -> some View {
        let course = model.course(id: submission.courseID)
        let student = model.student(id: submission.studentID)
        return HStack(spacing: 0) {
            enrollmentCell(student?.displayName ?? "学员", width: EnrollmentColumns.student, strong: true)
            enrollmentCell(course?.name ?? "课程", width: EnrollmentColumns.course)
            enrollmentCell(course.flatMap { model.term(id: $0.termID) }?.name ?? "—", width: EnrollmentColumns.term)
            enrollmentCell(course.map(scheduleLabel) ?? "—", width: EnrollmentColumns.schedule, mono: course != nil)
            enrollmentCell(course.map(staffAndRoom) ?? "—", width: EnrollmentColumns.staff)
            enrollmentCell(registrationLabel(submission.registrationMode, count: submission.selectedSessionIDs.count), width: EnrollmentColumns.mode)
            enrollmentCell(course.map { coursePriceLabel($0, mode: submission.registrationMode) } ?? "—", width: EnrollmentColumns.price, mono: true)
            enrollmentCell(course.map(coursePricingStatusLabel) ?? "—", width: EnrollmentColumns.billing)
            pendingStatus(submission.status, theme: theme)
            enrollmentCell("刚刚", width: EnrollmentColumns.date, mono: true)
            Spacer(minLength: 0)
            pendingActions(submission, theme: theme)
        }
        .frame(minHeight: 42)
        .background(theme.subtleSurface.opacity(0.55))
        .help(submission.status.errorMessage ?? "正在同步报名")
    }

    private func enrollmentRow(_ enrollment: Enrollment, theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            enrollmentCell(model.student(id: enrollment.studentID)?.displayName ?? "—", width: EnrollmentColumns.student, strong: true)
            enrollmentCell(model.course(id: enrollment.courseID)?.name ?? "—", width: EnrollmentColumns.course)
            enrollmentCell(model.term(id: enrollment.termID)?.name ?? "—", width: EnrollmentColumns.term)
            enrollmentCell(enrollmentScheduleLabel(enrollment), width: EnrollmentColumns.schedule, mono: true)
            enrollmentCell(courseForEnrollment(enrollment).map(staffAndRoom) ?? "—", width: EnrollmentColumns.staff)
            enrollmentCell(registrationLabel(enrollment.registrationMode, count: enrollment.selectedSessionIDs.count), width: EnrollmentColumns.mode)
            enrollmentCell(enrollmentPriceLabel(enrollment), width: EnrollmentColumns.price, mono: true)
            enrollmentCell(enrollmentPricingStatusLabel(enrollment.pricingStatus), width: EnrollmentColumns.billing)
            enrollmentCell(statusLabel(enrollment.status), width: EnrollmentColumns.status)
            enrollmentCell(enrollment.enrolledAt.formatted(date: .abbreviated, time: .omitted), width: EnrollmentColumns.date, mono: true)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Button {
                    editingEnrollment = enrollment
                } label: {
                    Image(systemName: "dollarsign.circle")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑这门课的计费")

                Button {
                    removeEnrollment(enrollment)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MDIconButtonStyle())
                .disabled(deletingID == enrollment.id)
                .help("移除报名")
            }
            .frame(width: EnrollmentColumns.action)
        }
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private func pendingStatus(_ status: PendingEnrollmentStatus, theme: MDTheme) -> some View {
        HStack(spacing: 6) {
            switch status {
            case .syncing:
                ProgressView().controlSize(.small)
                Text("同步中")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(theme.danger)
                Text("失败")
                    .foregroundStyle(theme.danger)
            }
        }
        .mdFont(.compact)
        .padding(.leading, 10)
        .frame(width: EnrollmentColumns.status, alignment: .leading)
    }

    @ViewBuilder
    private func pendingActions(_ submission: PendingEnrollmentSubmission, theme: MDTheme) -> some View {
        switch submission.status {
        case .syncing:
            Color.clear.frame(width: EnrollmentColumns.action, height: 32)
        case .failed:
            HStack(spacing: 2) {
                Button {
                    retry(submission)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("重试")
                Button {
                    pendingEnrollments.removeAll { $0.id == submission.id }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("取消这条报名")
            }
            .frame(width: EnrollmentColumns.action)
        }
    }

    private var filteredEnrollments: [Enrollment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = model.enrollments.filter { enrollment in
            guard selectedTermID == nil || enrollment.termID == selectedTermID else { return false }
            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                let student = model.student(id: enrollment.studentID)
                let course = model.course(id: enrollment.courseID)
                let guardianName = student.flatMap { model.guardian(id: $0.guardianID)?.displayName } ?? ""
                let searchableValues = [
                    student?.displayName ?? "",
                    guardianName,
                    course?.name ?? "",
                    course.flatMap { model.instructor(id: $0.defaultInstructorID)?.displayName } ?? "",
                    course.flatMap { model.room(id: $0.defaultRoomID)?.name } ?? ""
                ]
                matchesSearch = searchableValues.contains { $0.localizedCaseInsensitiveContains(query) }
            }
            return matchesSearch && matchesEnrollmentColumnFilters(enrollment)
        }
        guard let sortColumn else { return result }
        result.sort { enrollmentOrderedBefore($0, $1, by: sortColumn) }
        return result
    }

    private var filterSourceEnrollments: [Enrollment] {
        model.enrollments.filter { selectedTermID == nil || $0.termID == selectedTermID }
    }

    private var sortColumn: EnrollmentTableColumn? {
        get { EnrollmentTableColumn(rawValue: sortColumnStorage) }
        nonmutating set { sortColumnStorage = newValue?.rawValue ?? "" }
    }

    private var hasActiveColumnFilters: Bool {
        EnrollmentTableColumn.allCases.contains {
            !MDTableFilterCodec.selection(in: columnFiltersStorage, for: $0.rawValue).isEmpty
        }
    }

    private func toggleSort(_ column: EnrollmentTableColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }

    private func enrollmentFilterOptions(for column: EnrollmentTableColumn) -> [MDTableFilterOption] {
        mdTableFilterOptions(
            filterSourceEnrollments,
            key: { enrollmentColumnKey($0, column: column) },
            label: { enrollmentColumnLabel($0, column: column) }
        )
    }

    private func matchesEnrollmentColumnFilters(_ enrollment: Enrollment) -> Bool {
        EnrollmentTableColumn.allCases.allSatisfy { column in
            let selected = MDTableFilterCodec.selection(
                in: columnFiltersStorage,
                for: column.rawValue
            )
            return selected.isEmpty || selected.contains(enrollmentColumnKey(enrollment, column: column))
        }
    }

    private func enrollmentColumnKey(
        _ enrollment: Enrollment,
        column: EnrollmentTableColumn
    ) -> String {
        switch column {
        case .student: enrollment.studentID.description
        case .course: enrollment.courseID.description
        case .term: enrollment.termID.description
        case .schedule: enrollmentScheduleLabel(enrollment)
        case .staff: courseForEnrollment(enrollment).map(staffAndRoom) ?? "—"
        case .mode: enrollment.registrationMode.rawValue
        case .price: enrollmentPriceLabel(enrollment)
        case .billing: enrollment.pricingStatus.rawValue
        case .status: enrollment.status.rawValue
        case .date:
            enrollment.enrolledAt.formatted(.iso8601.year().month().day())
        }
    }

    private func enrollmentColumnLabel(
        _ enrollment: Enrollment,
        column: EnrollmentTableColumn
    ) -> String {
        switch column {
        case .student: model.student(id: enrollment.studentID)?.displayName ?? "—"
        case .course: model.course(id: enrollment.courseID)?.name ?? "—"
        case .term: model.term(id: enrollment.termID)?.name ?? "—"
        case .schedule: enrollmentScheduleLabel(enrollment)
        case .staff: courseForEnrollment(enrollment).map(staffAndRoom) ?? "—"
        case .mode: registrationLabel(enrollment.registrationMode, count: enrollment.selectedSessionIDs.count)
        case .price: enrollmentPriceLabel(enrollment)
        case .billing: enrollmentPricingStatusLabel(enrollment.pricingStatus)
        case .status: statusLabel(enrollment.status)
        case .date: enrollment.enrolledAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private func enrollmentOrderedBefore(
        _ lhs: Enrollment,
        _ rhs: Enrollment,
        by column: EnrollmentTableColumn
    ) -> Bool {
        switch column {
        case .price:
            let left = model.billingEstimate(for: lhs).totalCents ?? Int.max
            let right = model.billingEstimate(for: rhs).totalCents ?? Int.max
            if left != right { return sortAscending ? left < right : left > right }
        case .date:
            if lhs.enrolledAt != rhs.enrolledAt {
                return sortAscending ? lhs.enrolledAt < rhs.enrolledAt : lhs.enrolledAt > rhs.enrolledAt
            }
        case .schedule:
            let left = enrollmentScheduleSortDate(lhs)
            let right = enrollmentScheduleSortDate(rhs)
            if left != right { return sortAscending ? left < right : left > right }
        default:
            break
        }

        let comparison = enrollmentColumnLabel(lhs, column: column)
            .localizedStandardCompare(enrollmentColumnLabel(rhs, column: column))
        if comparison == .orderedSame { return lhs.id.description < rhs.id.description }
        return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private func enrollmentScheduleSortDate(_ enrollment: Enrollment) -> Date {
        if enrollment.registrationMode == .perSession {
            return model.sessions(for: enrollment).first?.startsAt ?? .distantFuture
        }
        return courseForEnrollment(enrollment)
            .flatMap { model.sessions(forCourse: $0.id).first?.startsAt } ?? .distantFuture
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

    private var enrollmentSummary: EnrollmentSummary {
        model.enrollmentSummary(termID: selectedTermID)
    }

    private var draftStudent: Student? {
        draftStudentID.flatMap { model.student(id: $0) }
    }

    private var draftCourse: Course? {
        draftCourseID.flatMap { model.course(id: $0) }
    }

    private var availableDraftCourses: [Course] {
        guard let draftStudentID else { return [] }
        let enrolledIDs = Set(model.enrollments(for: draftStudentID).map(\.courseID))
        let pendingIDs = Set(
            pendingEnrollments
                .filter { $0.studentID == draftStudentID }
                .map(\.courseID)
        )
        return model.courses.filter { course in
            course.isActive
                && (selectedTermID == nil || course.termID == selectedTermID)
                && !enrolledIDs.contains(course.id)
                && !pendingIDs.contains(course.id)
        }
    }

    private func selectStudent(_ studentID: StudentID) {
        draftStudentID = studentID
        draftCourseID = nil
        draftRegistrationMode = .fullTerm
        draftSelectedSessionIDs.removeAll()
        showingStudentPicker = false
    }

    private func selectCourse(_ courseID: CourseID) {
        draftCourseID = courseID
        draftRegistrationMode = model.course(id: courseID)?.format.requiresPerSessionEnrollment == true
            ? .perSession
            : .fullTerm
        draftSelectedSessionIDs.removeAll()
        showingCoursePicker = false
    }

    private func submitDraft() {
        guard let studentID = draftStudentID, let courseID = draftCourseID else { return }
        let submission = PendingEnrollmentSubmission(
            studentID: studentID,
            courseID: courseID,
            registrationMode: draftRegistrationMode,
            selectedSessionIDs: draftRegistrationMode == .perSession ? draftSelectedSessionIDs : []
        )
        pendingEnrollments.insert(submission, at: 0)
        draftStudentID = nil
        draftCourseID = nil
        draftRegistrationMode = .fullTerm
        draftSelectedSessionIDs.removeAll()
        start(submission)
    }

    private func retry(_ submission: PendingEnrollmentSubmission) {
        guard let index = pendingEnrollments.firstIndex(where: { $0.id == submission.id }) else { return }
        pendingEnrollments[index].status = .syncing
        start(pendingEnrollments[index])
    }

    private func start(_ submission: PendingEnrollmentSubmission) {
        model.performBackgroundOperation(
            label: "添加报名",
            successMessage: "报名已添加",
            completion: { result in
                switch result {
                case .success:
                    pendingEnrollments.removeAll { $0.id == submission.id }
                case let .failure(error):
                    guard let index = pendingEnrollments.firstIndex(where: { $0.id == submission.id }) else { return }
                    pendingEnrollments[index].status = .failed(error.localizedDescription)
                }
            }
        ) {
            try await model.enroll(
                studentID: submission.studentID,
                courseID: submission.courseID,
                registrationMode: submission.registrationMode,
                selectedSessionIDs: submission.selectedSessionIDs
            )
        }
    }

    private func removeEnrollment(_ enrollment: Enrollment) {
        deletingID = enrollment.id
        model.performBackgroundOperation(
            label: "移除报名",
            successMessage: "报名已移除",
            completion: { _ in deletingID = nil }
        ) {
            try await model.removeEnrollment(id: enrollment.id)
        }
    }

    private func courseForEnrollment(_ enrollment: Enrollment) -> Course? {
        model.course(id: enrollment.courseID)
    }

    private func studentSubtitle(_ student: Student) -> String {
        let guardian = model.guardian(id: student.guardianID)?.displayName ?? "未知家庭"
        return guardian + " · " + (student.kind == .adult ? "成人" : "少儿")
    }

    private func courseSelectorSubtitle(_ course: Course) -> String {
        let room = model.room(id: course.defaultRoomID)?.name ?? "未定教室"
        return scheduleLabel(course) + " · " + room
    }

    private func scheduleLabel(_ course: Course) -> String {
        guard let session = model.sessions(forCourse: course.id).first else { return "未排课" }
        return weekdayTitle(Calendar.masterDance.component(.weekday, from: session.startsAt)) + " "
            + session.startsAt.formatted(date: .omitted, time: .shortened) + "–"
            + session.endsAt.formatted(date: .omitted, time: .shortened)
    }

    private func staffAndRoom(_ course: Course) -> String {
        let instructor = model.instructor(id: course.defaultInstructorID)?.displayName ?? "—"
        let room = model.room(id: course.defaultRoomID)?.name ?? "—"
        return instructor + " · " + room
    }

    private func coursePriceLabel(
        _ course: Course,
        mode: EnrollmentRegistrationMode = .fullTerm
    ) -> String {
        let effectiveMode: EnrollmentRegistrationMode = course.format.requiresPerSessionEnrollment
            ? .perSession
            : mode
        let unitPrice = effectiveMode == .fullTerm ? course.unitPriceCents : course.dropInUnitPriceCents
        return switch course.pricingStatus {
        case .pending: "待定价"
        case .free: "$0.00"
        case .reviewRequired:
            unitPrice.map { "$\(MoneyTextParser.dollars(from: $0))/节" } ?? "待复核"
        case .priced:
            unitPrice.map { "$\(MoneyTextParser.dollars(from: $0))/节" } ?? "待定价"
        }
    }

    private var canSubmitDraft: Bool {
        guard draftStudentID != nil, let draftCourse else { return false }
        if draftCourse.format.requiresPerSessionEnrollment, draftRegistrationMode != .perSession {
            return false
        }
        return draftRegistrationMode == .fullTerm || !draftSelectedSessionIDs.isEmpty
    }

    private var draftRegistrationLabel: String {
        guard let draftCourse else {
            return registrationLabel(draftRegistrationMode, count: draftSelectedSessionIDs.count)
        }
        return draftCourse.format.requiresPerSessionEnrollment
            ? "私课按次 \(draftSelectedSessionIDs.count) 节"
            : registrationLabel(draftRegistrationMode, count: draftSelectedSessionIDs.count)
    }

    private func registrationLabel(_ mode: EnrollmentRegistrationMode, count: Int) -> String {
        mode == .fullTerm ? "整期" : "按次 \(count) 节"
    }

    private func enrollmentScheduleLabel(_ enrollment: Enrollment) -> String {
        guard enrollment.registrationMode == .perSession else {
            return courseForEnrollment(enrollment).map(scheduleLabel) ?? "未排课"
        }
        let selected = model.sessions(for: enrollment)
        guard let first = selected.first else { return "未选择课次" }
        let date = first.startsAt.formatted(.dateTime.month().day())
        return selected.count == 1 ? date : "\(date) 起 · \(selected.count) 节"
    }

    private func coursePricingStatusLabel(_ course: Course) -> String {
        switch course.pricingStatus {
        case .pending: "待定价"
        case .priced, .free: "待报名"
        case .reviewRequired: "需复核"
        }
    }

    private func enrollmentPriceLabel(_ enrollment: Enrollment) -> String {
        guard let total = model.billingEstimate(for: enrollment).totalCents else { return "待定价" }
        return "$" + MoneyTextParser.dollars(from: total)
    }

    private func enrollmentPricingStatusLabel(_ status: EnrollmentPricingStatus) -> String {
        switch status {
        case .pending: "待定价"
        case .ready: "已就绪"
        case .reviewRequired: "需复核"
        }
    }

    private func statusLabel(_ status: EnrollmentStatus) -> String {
        switch status {
        case .active: "在读"
        case .withdrawn: "已退课"
        case .completed: "已完成"
        }
    }
}

@MainActor
private struct StudentEnrollmentPicker: View {
    let model: AppModel
    let selectedID: StudentID?
    let select: (StudentID) -> Void

    @State private var searchText = ""
    @State private var filter = StudentPickerFilter.all
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "person.2")
                    .foregroundStyle(theme.accent)
                TextField("搜索学员或监护人", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                Text("\(filteredStudents.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(12)

            Picker("学员类型", selection: $filter) {
                ForEach(StudentPickerFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Divider()

            if groups.isEmpty {
                ContentUnavailableView("没有匹配的学员", systemImage: "person.slash")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            studentGroupHeader(group, theme: theme)
                            ForEach(group.students) { student in
                                studentRow(student, guardianName: group.title, theme: theme)
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 470, height: 500)
        .background(theme.background)
        .onAppear { searchFocused = true }
    }

    private var filteredStudents: [Student] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.students.filter { student in
            guard student.isActive else { return false }
            switch filter {
            case .children where student.kind != .child: return false
            case .adults where student.kind != .adult: return false
            default: break
            }
            guard !query.isEmpty else { return true }
            let guardian = model.guardian(id: student.guardianID)
            return student.displayName.localizedCaseInsensitiveContains(query)
                || student.legalName?.localizedCaseInsensitiveContains(query) == true
                || guardian?.displayName.localizedCaseInsensitiveContains(query) == true
                || guardian?.email?.localizedCaseInsensitiveContains(query) == true
                || guardian?.phone?.localizedCaseInsensitiveContains(query) == true
        }
    }

    private var groups: [StudentPickerGroup] {
        var remaining = filteredStudents
        var result: [StudentPickerGroup] = []
        for guardian in model.guardians {
            let students = remaining.filter { $0.guardianID == guardian.id }
            guard !students.isEmpty else { continue }
            result.append(
                StudentPickerGroup(
                    id: guardian.id.description,
                    title: guardian.displayName,
                    contact: [guardian.email, guardian.phone].compactMap { $0 }.joined(separator: " · "),
                    students: students.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                )
            )
            let studentIDs = Set(students.map(\.id))
            remaining.removeAll { studentIDs.contains($0.id) }
        }
        if !remaining.isEmpty {
            result.append(
                StudentPickerGroup(
                    id: "other",
                    title: "其他学员",
                    contact: "",
                    students: remaining.sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
                )
            )
        }
        return result
    }

    private func studentGroupHeader(_ group: StudentPickerGroup, theme: MDTheme) -> some View {
        HStack(spacing: 7) {
            Text(group.title)
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
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(theme.subtleSurface)
    }

    private func studentRow(_ student: Student, guardianName: String, theme: MDTheme) -> some View {
        Button {
            select(student.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: student.kind == .adult ? "person.crop.circle" : "figure.child.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(theme.accent)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.displayName)
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Text((student.kind == .adult ? "成人" : "少儿") + " · " + guardianName)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Text("\(model.enrollments(for: student.id).count) 门课")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                if selectedID == student.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct CourseEnrollmentPicker: View {
    let model: AppModel
    let courses: [Course]
    let selectedID: CourseID?
    let select: (CourseID) -> Void

    @State private var searchText = ""
    @State private var weekday: Int?
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(theme.accent)
                TextField("搜索课程、老师、教室或年龄段", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchFocused)
                Picker("星期", selection: $weekday) {
                    Text("全部星期").tag(Optional<Int>.none)
                    ForEach(weekdayOptions, id: \.0) { option in
                        Text(option.1).tag(Optional(option.0))
                    }
                }
                .labelsHidden()
                .frame(width: 105)
            }
            .padding(12)

            Divider()

            if groups.isEmpty {
                ContentUnavailableView(
                    "没有可报名课程",
                    systemImage: "calendar.badge.exclamationmark"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups) { group in
                            HStack {
                                Text(group.title).mdFont(.compactStrong)
                                Text("\(group.courses.count)")
                                    .mdFont(.mono)
                                    .foregroundStyle(theme.secondaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(theme.subtleSurface)

                            ForEach(group.courses) { course in
                                courseRow(course, theme: theme)
                                Divider().padding(.leading, 108)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 660, height: 520)
        .background(theme.background)
        .onAppear { searchFocused = true }
    }

    private var filteredCourses: [Course] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return courses.filter { course in
            let courseWeekday = firstSession(course).map {
                Calendar.masterDance.component(.weekday, from: $0.startsAt)
            }
            guard weekday == nil || weekday == courseWeekday else { return false }
            guard !query.isEmpty else { return true }
            let values = [
                course.name,
                model.ageGroup(id: course.ageGroupID)?.name ?? "",
                model.courseType(id: course.courseTypeID)?.name ?? "",
                model.instructor(id: course.defaultInstructorID)?.displayName ?? "",
                model.room(id: course.defaultRoomID)?.name ?? "",
                model.term(id: course.termID)?.name ?? ""
            ]
            return values.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var groups: [CourseDayGroup] {
        let orderedDays: [Int?] = [2, 3, 4, 5, 6, 7, 1, nil]
        return orderedDays.compactMap { day in
            let matching = filteredCourses.filter { course in
                guard let session = firstSession(course) else { return day == nil }
                return day == Calendar.masterDance.component(.weekday, from: session.startsAt)
            }
            .sorted { lhs, rhs in
                switch (firstSession(lhs), firstSession(rhs)) {
                case let (.some(left), .some(right)) where left.startsAt != right.startsAt:
                    return left.startsAt < right.startsAt
                default:
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
            }
            guard !matching.isEmpty else { return nil }
            return CourseDayGroup(
                id: day.map { String($0) } ?? "unscheduled",
                title: day.map { weekdayTitle($0) } ?? "未排课",
                courses: matching
            )
        }
    }

    private var weekdayOptions: [(Int, String)] {
        [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]
    }

    private func courseRow(_ course: Course, theme: MDTheme) -> some View {
        let session = firstSession(course)
        let typeIndex = model.courseTypes.firstIndex { $0.id == course.courseTypeID } ?? 0
        return Button {
            select(course.id)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.courseColor(index: typeIndex))
                    .frame(width: 4, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.map(timeRange) ?? "未排课")
                        .mdFont(.monoStrong)
                        .foregroundStyle(theme.primaryText)
                    Text(model.term(id: course.termID)?.name ?? "")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                .frame(width: 88, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(courseMeta(course))
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(model.instructor(id: course.defaultInstructorID)?.displayName ?? "未定老师")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.primaryText)
                    Text(model.room(id: course.defaultRoomID)?.name ?? "未定教室")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(width: 105, alignment: .trailing)

                Text(course.format == .privateLesson ? "私" : "组")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(theme.secondaryText, lineWidth: 1))

                Image(systemName: selectedID == course.id ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(selectedID == course.id ? theme.accent : theme.secondaryText)
                    .frame(width: 18)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func firstSession(_ course: Course) -> ClassSession? {
        model.sessions(forCourse: course.id).first
    }

    private func timeRange(_ session: ClassSession) -> String {
        session.startsAt.formatted(date: .omitted, time: .shortened) + "–"
            + session.endsAt.formatted(date: .omitted, time: .shortened)
    }

    private func courseMeta(_ course: Course) -> String {
        [
            model.ageGroup(id: course.ageGroupID)?.name,
            model.courseType(id: course.courseTypeID)?.name
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

@MainActor
private struct DraftEnrollmentRegistrationPicker: View {
    let model: AppModel
    let course: Course
    @Binding var mode: EnrollmentRegistrationMode
    @Binding var selectedSessionIDs: Set<ClassSessionID>

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                Text(course.name)
                    .mdFont(.bodyStrong)
                    .lineLimit(1)
                if course.format.requiresPerSessionEnrollment {
                    Label("私课仅支持按次报名", systemImage: "calendar.badge.clock")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.accent)
                } else {
                    Picker("报名方式", selection: $mode) {
                        Text("整期报名").tag(EnrollmentRegistrationMode.fullTerm)
                        Text("按次报名").tag(EnrollmentRegistrationMode.perSession)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(12)

            Divider()

            if mode == .fullTerm {
                ContentUnavailableView(
                    "整期报名",
                    systemImage: "calendar.badge.checkmark",
                    description: Text("包含这门课程所有未取消的课次。")
                )
            } else if sessions.isEmpty {
                ContentUnavailableView("没有可选课次", systemImage: "calendar.badge.exclamationmark")
            } else {
                HStack {
                    Text("选择具体日期")
                        .mdFont(.compactStrong)
                    Spacer()
                    Text("已选 \(selectedSessionIDs.count) 节")
                        .mdFont(.monoStrong)
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(theme.subtleSurface)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sessions) { session in
                            sessionRow(session, theme: theme)
                            Divider().padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .frame(width: 440, height: 480)
        .background(theme.background)
        .onAppear {
            if course.format.requiresPerSessionEnrollment {
                mode = .perSession
            }
        }
        .onChange(of: mode) { _, newMode in
            if course.format.requiresPerSessionEnrollment, newMode != .perSession {
                mode = .perSession
                return
            }
            if newMode == .fullTerm {
                selectedSessionIDs.removeAll()
            }
        }
    }

    private var sessions: [ClassSession] {
        model.sessions(forCourse: course.id).filter { $0.status != .cancelled }
    }

    private func sessionRow(_ session: ClassSession, theme: MDTheme) -> some View {
        let selected = selectedSessionIDs.contains(session.id)
        return Button {
            if selected {
                selectedSessionIDs.remove(session.id)
            } else {
                selectedSessionIDs.insert(session.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                    .frame(width: 22)
                Text(sessionDateLabel(session.startsAt))
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(session.startsAt.formatted(date: .omitted, time: .shortened))
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sessionDateLabel(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .weekday(.wide)
                .locale(Locale(identifier: "zh_Hans_CN"))
        )
    }
}

private enum StudentPickerFilter: String, CaseIterable, Identifiable {
    case all
    case children
    case adults

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .children: "少儿"
        case .adults: "成人"
        }
    }
}

private struct StudentPickerGroup: Identifiable {
    let id: String
    let title: String
    let contact: String
    let students: [Student]
}

private struct CourseDayGroup: Identifiable {
    let id: String
    let title: String
    let courses: [Course]
}

private struct PendingEnrollmentSubmission: Identifiable {
    let id = UUID()
    let studentID: StudentID
    let courseID: CourseID
    let registrationMode: EnrollmentRegistrationMode
    let selectedSessionIDs: Set<ClassSessionID>
    var status = PendingEnrollmentStatus.syncing
}

private enum PendingEnrollmentStatus {
    case syncing
    case failed(String)

    var errorMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }
}

private enum EnrollmentTableColumn: String, CaseIterable, Identifiable {
    case student
    case course
    case term
    case schedule
    case staff
    case mode
    case price
    case billing
    case status
    case date

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: "学员"
        case .course: "课程"
        case .term: "学期"
        case .schedule: "上课时间"
        case .staff: "老师 / 教室"
        case .mode: "报名方式"
        case .price: "预计课程费"
        case .billing: "计费"
        case .status: "状态"
        case .date: "报名日期"
        }
    }

    var width: CGFloat {
        switch self {
        case .student: EnrollmentColumns.student
        case .course: EnrollmentColumns.course
        case .term: EnrollmentColumns.term
        case .schedule: EnrollmentColumns.schedule
        case .staff: EnrollmentColumns.staff
        case .mode: EnrollmentColumns.mode
        case .price: EnrollmentColumns.price
        case .billing: EnrollmentColumns.billing
        case .status: EnrollmentColumns.status
        case .date: EnrollmentColumns.date
        }
    }
}

private enum EnrollmentColumns {
    static let student: CGFloat = 180
    static let course: CGFloat = 245
    static let term: CGFloat = 125
    static let schedule: CGFloat = 175
    static let staff: CGFloat = 120
    static let mode: CGFloat = 82
    static let price: CGFloat = 125
    static let billing: CGFloat = 76
    static let status: CGFloat = 88
    static let date: CGFloat = 110
    static let action: CGFloat = 76
}

private func weekdayTitle(_ weekday: Int) -> String {
    switch weekday {
    case 1: "周日"
    case 2: "周一"
    case 3: "周二"
    case 4: "周三"
    case 5: "周四"
    case 6: "周五"
    case 7: "周六"
    default: "—"
    }
}

@MainActor
private func enrollmentHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .mdFont(.compactStrong)
        .foregroundStyle(.secondary)
        .padding(.leading, 10)
        .frame(width: width, alignment: .leading)
}

@MainActor
private func enrollmentCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text)
        .mdFont(mono ? .mono : (strong ? .bodyStrong : .body))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.leading, 10)
        .frame(width: width, alignment: .leading)
}
#endif
