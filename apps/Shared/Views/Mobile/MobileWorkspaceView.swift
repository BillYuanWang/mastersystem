#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileWorkspaceView: View {
    let role: AppRole
    let model: AppModel
    @Binding var appearanceRawValue: String

    var body: some View {
        if role == .administrator {
            administratorTabs
        } else {
            memberTabs
        }
    }

    private var administratorTabs: some View {
        TabView {
            NavigationStack {
                MobileUpcomingSessionsView(model: model)
                    .navigationTitle("课表")
            }
            .tabItem { Label("课表", systemImage: "calendar") }

            NavigationStack {
                MobileStudentListView(model: model)
                    .navigationTitle("学生")
            }
            .tabItem { Label("学生", systemImage: "person.2") }

            NavigationStack {
                MobileEnrollmentListView(model: model)
                    .navigationTitle("报名")
            }
            .tabItem { Label("报名", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                MobileSettingsView(appearanceRawValue: $appearanceRawValue)
                    .navigationTitle("设置")
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }

    private var memberTabs: some View {
        TabView {
            NavigationStack {
                MemberOverviewView(role: role, model: model)
                    .navigationTitle("Master Dance")
            }
            .tabItem { Label("首页", systemImage: "house") }

            NavigationStack {
                MobileUpcomingSessionsView(model: model)
                    .navigationTitle("我的课程")
            }
            .tabItem { Label("课程", systemImage: "calendar") }

            NavigationStack {
                ContentUnavailableView("请假将在第 5 阶段接入", systemImage: "calendar.badge.minus")
                    .navigationTitle("请假")
            }
            .tabItem { Label("请假", systemImage: "calendar.badge.minus") }

            NavigationStack {
                MobileSettingsView(appearanceRawValue: $appearanceRawValue)
                    .navigationTitle("设置")
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

private struct MobileUpcomingSessionsView: View {
    let model: AppModel

    var body: some View {
        List(model.sessions.prefix(30)) { session in
            let course = model.course(id: session.courseID)
            VStack(alignment: .leading, spacing: 4) {
                Text(course?.name ?? "课程")
                    .font(.headline)
                Text(session.startsAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(model.effectiveRoom(for: session)?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MobileStudentListView: View {
    let model: AppModel

    var body: some View {
        List(model.students) { student in
            HStack {
                Text(student.displayName)
                Spacer()
                Text("\(model.enrollments(for: student.id).count) 门课")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MobileEnrollmentListView: View {
    let model: AppModel

    var body: some View {
        List(model.enrollments) { enrollment in
            VStack(alignment: .leading, spacing: 4) {
                Text(model.student(id: enrollment.studentID)?.displayName ?? "学生")
                Text(model.course(id: enrollment.courseID)?.name ?? "课程")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MemberOverviewView: View {
    let role: AppRole
    let model: AppModel

    var body: some View {
        List {
            Section("下一节课") {
                if let session = model.sessions.first(where: { $0.startsAt >= Date() }) {
                    Text(model.course(id: session.courseID)?.name ?? "课程")
                    Text(session.startsAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                } else {
                    Text("暂无排定课程")
                        .foregroundStyle(.secondary)
                }
            }
            Section("身份") {
                Text(role == .guardian ? "家长" : "成人学员")
            }
        }
    }
}

private struct MobileSettingsView: View {
    @Binding var appearanceRawValue: String

    var body: some View {
        Form {
            Picker("外观", selection: $appearanceRawValue) {
                Text("跟随系统").tag(AppearancePreference.system.rawValue)
                Text("浅色").tag(AppearancePreference.light.rawValue)
                Text("深色").tag(AppearancePreference.dark.rawValue)
            }
        }
    }
}
#endif
