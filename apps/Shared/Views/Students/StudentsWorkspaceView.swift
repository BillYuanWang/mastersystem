#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct StudentsWorkspaceView: View {
    let model: AppModel

    @State private var searchText = ""
    @State private var selectedStudentID: StudentID?
    @State private var showingStudentEditor = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "学生", english: "STUDENTS")
                Text("\(filteredStudents.count)")
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
                Spacer()
                TextField("搜索学生或课程", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(MDType.compact)
                    .frame(width: 190)
                Button {
                    showingStudentEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("添加学生")
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 0) {
                studentTable(theme: theme)

                Rectangle().fill(theme.separator).frame(width: 1)

                if let selectedStudentID, let student = model.student(id: selectedStudentID) {
                    StudentCourseInspector(model: model, student: student)
                        .id(student.id)
                        .frame(width: 330)
                } else {
                    ContentUnavailableView(
                        "选择一名学生",
                        systemImage: "person.crop.circle",
                        description: Text("这里仅管理该学生已选的课程，不直接修改个人资料。")
                    )
                    .frame(width: 330)
                }
            }
        }
        .background(theme.background)
        .task(id: model.students.count) {
            if selectedStudentID == nil {
                selectedStudentID = filteredStudents.first?.id
            }
        }
        .sheet(isPresented: $showingStudentEditor) {
            StudentEditorView(model: model)
        }
    }

    private func studentTable(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                studentHeader("学生", width: 150)
                studentHeader("类型", width: 70)
                studentHeader("监护人", width: 150)
                studentHeader("已选课程", width: 360)
                studentHeader("数量", width: 60)
                Spacer()
            }
            .frame(height: 34)
            .background(theme.subtleSurface)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredStudents) { student in
                        Button {
                            selectedStudentID = student.id
                        } label: {
                            HStack(spacing: 0) {
                                studentCell(student.displayName, width: 150, strong: true)
                                studentCell(student.kind == .adult ? "成人" : "少儿", width: 70)
                                studentCell(guardianName(for: student), width: 150)
                                studentCell(courseSummary(for: student), width: 360)
                                studentCell("\(model.enrollments(for: student.id).count)", width: 60, mono: true)
                                Spacer()
                            }
                            .frame(minHeight: 40)
                            .contentShape(Rectangle())
                            .background(
                                selectedStudentID == student.id ? theme.accent.opacity(0.11) : .clear
                            )
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(theme.primaryText)
    }

    private var filteredStudents: [Student] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.students }
        return model.students.filter { student in
            student.displayName.localizedCaseInsensitiveContains(query)
                || courseSummary(for: student).localizedCaseInsensitiveContains(query)
        }
    }

    private func guardianName(for student: Student) -> String {
        model.guardians.first(where: { $0.studentIDs.contains(student.id) })?.displayName
            ?? (student.kind == .adult ? "本人" : "—")
    }

    private func courseSummary(for student: Student) -> String {
        model.enrollments(for: student.id)
            .compactMap { model.course(id: $0.courseID)?.name }
            .joined(separator: "，")
    }
}

private struct StudentCourseInspector: View {
    let model: AppModel
    let student: Student

    @State private var selectedCourseID: CourseID?
    @State private var isWorking = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(student.displayName)
                            .font(MDType.bodyStrong)
                        Text(student.kind == .adult ? "成人学员" : "少儿学员")
                            .font(MDType.mono)
                            .foregroundStyle(theme.secondaryText)
                        if let guardian = model.guardians.first(where: { $0.studentIDs.contains(student.id) }) {
                            Label(guardian.displayName, systemImage: "person.2")
                                .font(MDType.compact)
                                .padding(.top, 3)
                        }
                    }
                    .padding(16)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
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
                        }

                        ForEach(activeEnrollments) { enrollment in
                            enrollmentRow(enrollment, theme: theme)
                        }
                    }
                    .padding(16)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
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
                    .padding(16)
                }
            }

            Divider()

            Text("表格内容为只读；这里仅同步增删课程报名。")
                .font(MDType.compact)
                .foregroundStyle(theme.secondaryText)
                .padding(14)
        }
        .foregroundStyle(theme.primaryText)
        .background(theme.surface)
    }

    private var activeEnrollments: [Enrollment] {
        model.enrollments(for: student.id)
    }

    private var availableCourses: [Course] {
        let enrolledIDs = Set(activeEnrollments.map(\.courseID))
        return model.courses.filter { !enrolledIDs.contains($0.id) }
    }

    private func enrollmentRow(_ enrollment: Enrollment, theme: MDTheme) -> some View {
        let course = model.course(id: enrollment.courseID)
        let firstSession = course.flatMap { model.sessions(forCourse: $0.id).first }
        return HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.courseColor(index: course.flatMap { course in
                    model.categories.firstIndex(where: { $0.id == course.categoryID })
                } ?? 0))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(course?.name ?? "课程")
                    .font(MDType.bodyStrong)
                if let firstSession {
                    Text(firstSession.startsAt.formatted(.dateTime.weekday(.abbreviated)) + " · " + firstSession.startsAt.formatted(date: .omitted, time: .shortened))
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

private struct StudentEditorView: View {
    let model: AppModel

    @State private var displayName = ""
    @State private var kind = StudentKind.child
    @State private var guardianName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MDSectionTitle(chinese: "添加学生", english: "NEW STUDENT")
            TextField("学生姓名", text: $displayName)
            Picker("类型", selection: $kind) {
                Text("少儿").tag(StudentKind.child)
                Text("成人").tag(StudentKind.adult)
            }
            .pickerStyle(.segmented)
            if kind == .child {
                TextField("监护人姓名（选填）", text: $guardianName)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(MDType.compact)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await model.createStudent(
                    displayName: displayName,
                    kind: kind,
                    guardianName: guardianName
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private func studentHeader(_ text: String, width: CGFloat) -> some View {
    Text(text)
        .font(MDType.compactStrong)
        .foregroundStyle(.secondary)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}

private func studentCell(_ text: String, width: CGFloat, strong: Bool = false, mono: Bool = false) -> some View {
    Text(text)
        .font(mono ? MDType.mono : (strong ? MDType.bodyStrong : MDType.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
