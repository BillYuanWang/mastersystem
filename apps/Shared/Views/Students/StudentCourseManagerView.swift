#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct StudentCourseManagerView: View {
    let model: AppModel
    let student: Student

    @State private var selectedCourseID: CourseID?

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

            Button {
                addCourse()
            } label: {
                Label("加入课程", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .disabled(selectedCourseID == nil)
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
        guard let selectedCourseID else { return }
        let studentID = student.id
        model.performBackgroundOperation(
            label: "添加学员课程",
            successMessage: "学员课程已添加"
        ) {
            try await model.enroll(studentID: studentID, courseID: selectedCourseID)
        }
        self.selectedCourseID = nil
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
