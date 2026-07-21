#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberCoursesView: View {
    let model: AppModel
    @Binding var selectedStudentID: StudentID?

    var body: some View {
        List {
            if enrollments.isEmpty {
                ContentUnavailableView(
                    "暂无已报名课程",
                    systemImage: "calendar",
                    description: Text("报名由教务老师在 MD Desk 中管理。")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(enrollments) { enrollment in
                    if let course = model.course(id: enrollment.courseID) {
                        NavigationLink {
                            MobileMemberCourseDetailView(
                                model: model,
                                enrollment: enrollment,
                                course: course
                            )
                        } label: {
                            courseRow(course, enrollment: enrollment)
                        }
                    }
                }
            }

            MobileMemberLeaveHistorySection(
                model: model,
                studentID: selectedStudentID
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("我的课程")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MobileStudentPicker(students: model.students, selection: $selectedStudentID)
            }
        }
        .refreshable { await model.refreshFromCloud() }
    }

    private var enrollments: [Enrollment] {
        guard let selectedStudentID else { return [] }
        return model.activeEnrollments(forStudent: selectedStudentID)
    }

    private func courseRow(_ course: Course, enrollment: Enrollment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(course.name)
                .mdFont(.bodyStrong)
            if let next = model.nextSession(forCourse: course.id) {
                Text(next.startsAt.mdChineseFormatted(.dateTime.weekday(.wide).hour().minute()))
                    .mdFont(.monoStrong)
                    .foregroundStyle(.secondary)
                Text([
                    model.effectiveInstructor(for: next)?.displayName,
                    model.effectiveRoom(for: next)?.name,
                ].compactMap { $0 }.joined(separator: " · "))
                    .mdFont(.compact)
                    .foregroundStyle(.secondary)
            } else {
                Text("暂无后续课次")
                    .mdFont(.compact)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
private struct MobileMemberCourseDetailView: View {
    let model: AppModel
    let enrollment: Enrollment
    let course: Course
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        List {
            Section("课程信息") {
                detailRow("学期", model.term(id: course.termID)?.name ?? "")
                detailRow("课程种类", model.courseType(id: course.courseTypeID)?.name ?? "")
                detailRow("年龄段", model.ageGroup(id: course.ageGroupID)?.name ?? "")
                detailRow("授课老师", model.instructor(id: course.defaultInstructorID)?.displayName ?? "")
                detailRow("教室", model.room(id: course.defaultRoomID)?.name ?? "")
            }

            Section("接下来") {
                let sessions = Array(model.sessions(forCourse: course.id).filter { $0.startsAt >= Date() }.prefix(8))
                if sessions.isEmpty {
                    Text("暂无后续课次")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(sessions) { session in
                        MobileSessionRow(
                            session: session,
                            course: course,
                            room: model.effectiveRoom(for: session),
                            instructor: model.effectiveInstructor(for: session),
                            trailingText: session.startsAt.mdChineseFormatted(.dateTime.month().day())
                        )
                    }
                }
            }

            Section("出勤记录") {
                if attendanceHistory.isEmpty {
                    Text("暂无记录")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(attendanceHistory) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sessionDate(for: record))
                                    .mdFont(.bodyStrong)
                                Text(record.recordedAt.mdChineseFormatted(.dateTime.hour().minute()))
                                    .mdFont(.mono)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            Spacer()
                            MobileStatusPill(
                                title: record.status.mobileTitle,
                                systemImage: record.status.mobileSystemImage,
                                color: record.status.mobileColor(theme: theme)
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var attendanceHistory: [Attendance] {
        let sessionIDs = Set(model.sessions(forCourse: course.id).map(\.id))
        return model.attendance
            .filter {
                $0.studentID == enrollment.studentID && sessionIDs.contains($0.sessionID)
            }
            .sorted {
                (model.session(id: $0.sessionID)?.startsAt ?? .distantPast)
                    > (model.session(id: $1.sessionID)?.startsAt ?? .distantPast)
            }
    }

    private func sessionDate(for record: Attendance) -> String {
        model.session(id: record.sessionID)?.startsAt.mdChineseFormatted(
            .dateTime.year().month().day().weekday(.abbreviated)
        ) ?? "课次"
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value.isEmpty ? "待定" : value)
                .mdFont(.bodyStrong)
        }
    }
}
#endif
