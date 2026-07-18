#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct StudentCourseManagerView: View {
    let model: AppModel
    let student: Student

    @State private var selectedCourseID: CourseID?
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("已选课程")
                    .font(MDType.bodyStrong)
                Spacer()
                Text("\(activeEnrollments.count)")
                    .font(MDType.monoStrong)
                    .foregroundStyle(theme.secondaryText)
            }

            if activeEnrollments.isEmpty {
                Text("尚未报名课程")
                    .font(MDType.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                ForEach(activeEnrollments) { enrollment in
                    enrollmentRow(enrollment, theme: theme)
                }
            }

            Divider()

            Text("添加现有课程")
                .font(MDType.bodyStrong)

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
            .disabled(selectedCourseID == nil || isWorking)

            if let errorMessage {
                Text(errorMessage)
                    .font(MDType.compact)
                    .foregroundStyle(theme.danger)
            }
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
        let firstSession = course.flatMap { model.sessions(forCourse: $0.id).first }

        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.courseColor(index: course.flatMap { course in
                    model.courseTypes.firstIndex(where: { $0.id == course.courseTypeID })
                } ?? 0))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(course?.name ?? "课程")
                    .font(MDType.bodyStrong)
                    .lineLimit(1)
                if let firstSession {
                    Text(
                        firstSession.startsAt.formatted(.dateTime.weekday(.abbreviated))
                            + " · "
                            + firstSession.startsAt.formatted(date: .omitted, time: .shortened)
                    )
                    .font(MDType.compact)
                    .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
            Button {
                remove(enrollment)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(MDIconButtonStyle())
            .disabled(isWorking)
            .help("移除课程")
        }
        .padding(9)
        .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
    }

    private func addCourse() {
        guard let selectedCourseID else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.enroll(studentID: student.id, courseID: selectedCourseID)
                self.selectedCourseID = nil
                isWorking = false
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }

    private func remove(_ enrollment: Enrollment) {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await model.removeEnrollment(id: enrollment.id)
                isWorking = false
            } catch {
                errorMessage = error.localizedDescription
                isWorking = false
            }
        }
    }
}
#endif
