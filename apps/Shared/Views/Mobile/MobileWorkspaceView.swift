#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileWorkspaceView: View {
    let role: AppRole
    let model: AppModel
    @Binding var appearanceRawValue: String
    let accountDisplayName: String?
    let onSignOut: (() -> Void)?
    let memberActions: MobileMemberActionService?

    var body: some View {
        if role == .administrator {
            MobileAdministratorTabs(
                model: model,
                appearanceRawValue: $appearanceRawValue,
                accountDisplayName: accountDisplayName,
                onSignOut: onSignOut
            )
        } else if let memberActions {
            MobileMemberTabs(
                role: role,
                model: model,
                actions: memberActions,
                appearanceRawValue: $appearanceRawValue,
                accountDisplayName: accountDisplayName,
                onSignOut: onSignOut
            )
        } else {
            ContentUnavailableView(
                "账号服务暂不可用",
                systemImage: "wifi.exclamationmark",
                description: Text("请退出后重新登录。")
            )
        }
    }
}

private struct MobileAdministratorTabs: View {
    let model: AppModel
    @Binding var appearanceRawValue: String
    let accountDisplayName: String?
    let onSignOut: (() -> Void)?

    var body: some View {
        TabView {
            NavigationStack {
                MobileAttendanceHomeView(model: model)
            }
            .tabItem { Label("签到", systemImage: "checkmark.circle") }

            NavigationStack {
                MobileAccountSettingsView(
                    role: .administrator,
                    model: model,
                    accountDisplayName: accountDisplayName,
                    appearanceRawValue: $appearanceRawValue,
                    actions: nil,
                    onSignOut: onSignOut
                )
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
    }
}

private struct MobileMemberTabs: View {
    let role: AppRole
    let model: AppModel
    let actions: MobileMemberActionService
    @Binding var appearanceRawValue: String
    let accountDisplayName: String?
    let onSignOut: (() -> Void)?

    @State private var selectedStudentID: StudentID?

    var body: some View {
        TabView {
            NavigationStack {
                MobileMemberHomeView(
                    model: model,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("首页", systemImage: "house") }

            NavigationStack {
                MobileMemberCoursesView(
                    model: model,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("课程", systemImage: "calendar") }

            NavigationStack {
                MobileMemberLeaveView(
                    model: model,
                    actions: actions,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("请假", systemImage: "calendar.badge.minus") }

            NavigationStack {
                MobileMemberInboxView(
                    model: model,
                    actions: actions,
                    signerKind: role == .adultStudent ? .adultStudent : .guardian,
                    signerDisplayName: accountDisplayName ?? "监护人"
                )
            }
            .tabItem { Label("消息", systemImage: "bell") }
            .badge(unreadNotificationCount)

            NavigationStack {
                MobileAccountSettingsView(
                    role: role,
                    model: model,
                    accountDisplayName: accountDisplayName,
                    appearanceRawValue: $appearanceRawValue,
                    actions: actions,
                    onSignOut: onSignOut
                )
            }
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .task(id: model.students.map(\.id)) {
            selectAvailableStudent()
        }
    }

    private var unreadNotificationCount: Int {
        model.notifications.filter { $0.status != .read }.count
    }

    private func selectAvailableStudent() {
        guard !model.students.isEmpty else {
            selectedStudentID = nil
            return
        }
        if let selectedStudentID, model.student(id: selectedStudentID) != nil {
            return
        }
        selectedStudentID = model.students.first?.id
    }
}
#endif
