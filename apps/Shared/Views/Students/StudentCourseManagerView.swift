#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct StudentCourseManagerView: View {
    let model: AppModel
    let student: Student

    @State private var selectedCourseID: CourseID?
    @State private var selectedSessionIDs: Set<ClassSessionID> = []

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已选课程")
                    .mdFont(.bodyStrong)
                Spacer()
                Text("\(activeEnrollments.count)")
                    .mdFont(.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }

            if activeEnrollments.isEmpty {
                Text("尚未报名课程")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                ForEach(activeEnrollments) { enrollment in
                    enrollmentRow(enrollment, theme: theme)
                }
            }

            Divider()

            Text("添加现有课程")
                .mdFont(.bodyStrong)

            Picker("课程", selection: $selectedCourseID) {
                Text("选择课程").tag(Optional<CourseID>.none)
                ForEach(availableCourses) { course in
                    Text(course.name).tag(Optional(course.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: selectedCourseID) { _, _ in
                selectedSessionIDs.removeAll()
            }

            if selectedCourse?.format.requiresPerSessionEnrollment == true {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Label("私课仅按次报名", systemImage: "calendar.badge.clock")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text("已选 \(selectedSessionIDs.count) 节")
                            .mdFont(.mono)
                            .foregroundStyle(theme.secondaryText)
                    }

                    if selectableSessions.isEmpty {
                        Text("这门私课没有可报名课次")
                            .mdFont(.compact)
                            .foregroundStyle(theme.danger)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(selectableSessions) { session in
                                    sessionButton(session, theme: theme)
                                }
                            }
                        }
                        .frame(maxHeight: 170)
                    }
                }
                .padding(9)
                .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            }

            Button {
                addCourse()
            } label: {
                Label("加入课程", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canAddCourse)
        }
    }

    private var activeEnrollments: [Enrollment] {
        model.enrollments(for: student.id)
            .sorted { first, second in
                let firstName = model.course(id: first.courseID)?.name ?? ""
                let secondName = model.course(id: second.courseID)?.name ?? ""
                return firstName.localizedCompare(secondName) == .orderedAscending
            }
    }

    private var availableCourses: [Course] {
        let enrolledIDs = Set(activeEnrollments.map(\.courseID))
        return model.courses
            .filter { !enrolledIDs.contains($0.id) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var selectedCourse: Course? {
        selectedCourseID.flatMap { model.course(id: $0) }
    }

    private var selectableSessions: [ClassSession] {
        guard let selectedCourseID else { return [] }
        return model.sessions(forCourse: selectedCourseID).filter { $0.status != .cancelled }
    }

    private var canAddCourse: Bool {
        guard let selectedCourse else { return false }
        return !selectedCourse.format.requiresPerSessionEnrollment || !selectedSessionIDs.isEmpty
    }

    private func enrollmentRow(_ enrollment: Enrollment, theme: MDTheme) -> some View {
        let course = model.course(id: enrollment.courseID)
        let firstSession = model.sessions(for: enrollment).first

        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.courseColor(index: course.flatMap { course in
                    model.courseTypes.firstIndex(where: { $0.id == course.courseTypeID })
                } ?? 0))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(course?.name ?? "课程")
                    .mdFont(.bodyStrong)
                    .lineLimit(1)
                if let firstSession {
                    Text(
                        firstSession.startsAt.formatted(.dateTime.weekday(.abbreviated))
                            + " · "
                            + firstSession.startsAt.formatted(date: .omitted, time: .shortened)
                    )
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                }
                Text(enrollment.registrationMode == .fullTerm ? "整期报名" : "按次报名 · \(enrollment.selectedSessionIDs.count) 节")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Button {
                remove(enrollment)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(MDIconButtonStyle())
            .help("移除课程")
        }
        .padding(9)
        .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
    }

    private func addCourse() {
        guard let selectedCourse else { return }
        let studentID = student.id
        let mode: EnrollmentRegistrationMode = selectedCourse.format.requiresPerSessionEnrollment
            ? .perSession
            : .fullTerm
        let selectedSessionIDs = self.selectedSessionIDs
        model.performBackgroundOperation(
            label: "添加学员课程",
            successMessage: "学员课程已添加"
        ) {
            try await model.enroll(
                studentID: studentID,
                courseID: selectedCourse.id,
                registrationMode: mode,
                selectedSessionIDs: selectedSessionIDs
            )
        }
        self.selectedCourseID = nil
        self.selectedSessionIDs.removeAll()
    }

    private func sessionButton(_ session: ClassSession, theme: MDTheme) -> some View {
        let selected = selectedSessionIDs.contains(session.id)
        return Button {
            if selected {
                selectedSessionIDs.remove(session.id)
            } else {
                selectedSessionIDs.insert(session.id)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                Text(session.startsAt.formatted(
                    .dateTime
                        .month()
                        .day()
                        .weekday(.abbreviated)
                        .locale(Locale(identifier: "zh_Hans_CN"))
                ))
                .mdFont(.compactStrong)
                Spacer()
                Text(session.startsAt.formatted(date: .omitted, time: .shortened))
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 7)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func remove(_ enrollment: Enrollment) {
        model.performBackgroundOperation(
            label: "移除学员课程",
            successMessage: "学员课程已移除"
        ) {
            try await model.removeEnrollment(id: enrollment.id)
        }
    }
}
#endif
