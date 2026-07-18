#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct EnrollmentsWorkspaceView: View {
    let model: AppModel

    @State private var selectedTermID: TermID?
    @State private var searchText = ""
    @State private var showingEditor = false
    @State private var deletingID: EnrollmentID?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "总报名", english: "ENROLLMENT")
                Text("\(filteredEnrollments.count)")
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                Picker("学期", selection: $selectedTermID) {
                    Text("全部学期").tag(Optional<TermID>.none)
                    ForEach(model.terms) { term in
                        Text(term.name).tag(Optional(term.id))
                    }
                }
                .labelsHidden()
                .frame(width: 140)
                TextField("搜索学生或课程", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(MDType.compact)
                    .frame(width: 180)
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("添加报名")
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            enrollmentTable(theme: theme)
        }
        .background(theme.background)
        .sheet(isPresented: $showingEditor) {
            EnrollmentEditorView(model: model)
        }
        .task(id: model.terms.count) {
            if selectedTermID == nil {
                selectedTermID = model.terms.first?.id
            }
        }
    }

    private func enrollmentTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                enrollmentHeader("学生", width: 150)
                enrollmentHeader("课程", width: 210)
                enrollmentHeader("学期", width: 130)
                enrollmentHeader("上课时间", width: 190)
                enrollmentHeader("老师", width: 100)
                enrollmentHeader("状态", width: 90)
                enrollmentHeader("报名日期", width: 120)
                Spacer()
                Color.clear.frame(width: 40)
            }
            .frame(height: 34)
            .background(theme.subtleSurface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEnrollments) { enrollment in
                        HStack(spacing: 0) {
                            enrollmentCell(model.student(id: enrollment.studentID)?.displayName ?? "—", width: 150, strong: true)
                            enrollmentCell(model.course(id: enrollment.courseID)?.name ?? "—", width: 210)
                            enrollmentCell(model.term(id: enrollment.termID)?.name ?? "—", width: 130)
                            enrollmentCell(scheduleLabel(enrollment.courseID), width: 190)
                            enrollmentCell(instructorName(enrollment.courseID), width: 100)
                            enrollmentCell(statusLabel(enrollment.status), width: 90)
                            enrollmentCell(enrollment.enrolledAt.formatted(date: .abbreviated, time: .omitted), width: 120, mono: true)
                            Spacer()
                            Button {
                                deletingID = enrollment.id
                                Task {
                                    try? await model.removeEnrollment(id: enrollment.id)
                                    deletingID = nil
                                }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(MDIconButtonStyle())
                            .disabled(deletingID == enrollment.id)
                            .help("移除报名")
                            .frame(width: 40)
                        }
                        .frame(minHeight: 40)
                        Divider()
                    }
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private var filteredEnrollments: [Enrollment] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.enrollments.filter { enrollment in
            guard selectedTermID == nil || enrollment.termID == selectedTermID else { return false }
            guard !query.isEmpty else { return true }
            let studentName = model.student(id: enrollment.studentID)?.displayName ?? ""
            let courseName = model.course(id: enrollment.courseID)?.name ?? ""
            return studentName.localizedCaseInsensitiveContains(query)
                || courseName.localizedCaseInsensitiveContains(query)
        }
    }

    private func scheduleLabel(_ courseID: CourseID) -> String {
        guard let session = model.sessions(forCourse: courseID).first else { return "未排课" }
        return session.startsAt.formatted(.dateTime.weekday(.abbreviated)) + " "
            + session.startsAt.formatted(date: .omitted, time: .shortened) + "–"
            + session.endsAt.formatted(date: .omitted, time: .shortened)
    }

    private func instructorName(_ courseID: CourseID) -> String {
        guard let course = model.course(id: courseID) else { return "—" }
        return model.instructor(id: course.defaultInstructorID)?.displayName ?? "—"
    }

    private func statusLabel(_ status: EnrollmentStatus) -> String {
        switch status {
        case .active: "在读"
        case .withdrawn: "已退课"
        case .completed: "已完成"
        }
    }
}

private struct EnrollmentEditorView: View {
    let model: AppModel

    @State private var studentID: StudentID?
    @State private var courseID: CourseID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加报名", english: "NEW ENROLLMENT")
            Picker("学生", selection: $studentID) {
                Text("选择学生").tag(Optional<StudentID>.none)
                ForEach(model.students) { student in
                    Text(student.displayName).tag(Optional(student.id))
                }
            }
            Picker("课程", selection: $courseID) {
                Text("选择课程").tag(Optional<CourseID>.none)
                ForEach(availableCourses) { course in
                    Text(course.name).tag(Optional(course.id))
                }
            }
            Text("第一版只创建整学期报名，不提供按次报名或价格字段。")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(studentID == nil || courseID == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onChange(of: studentID) { _, _ in
            courseID = nil
        }
    }

    private var availableCourses: [Course] {
        guard let studentID else { return model.courses }
        let existingIDs = Set(model.enrollments(for: studentID).map(\.courseID))
        return model.courses.filter { !existingIDs.contains($0.id) }
    }

    private func save() {
        guard let studentID, let courseID else { return }
        model.performBackgroundOperation(
            label: "添加报名",
            successMessage: "报名已添加"
        ) {
            try await model.enroll(studentID: studentID, courseID: courseID)
        }
        dismiss()
    }
}

private func enrollmentHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .font(MDType.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

private func enrollmentCell(_ text: String, width: CGFloat, strong: Bool = false, mono: Bool = false) -> some View {
    Text(text)
        .font(mono ? MDType.mono : (strong ? MDType.bodyStrong : MDType.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
