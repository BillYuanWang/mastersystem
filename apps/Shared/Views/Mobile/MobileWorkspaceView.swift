#if os(iOS)
import Foundation
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
            if role == .guardian && !isGuardianPreview {
                MobileGuardianAgreementGateView(
                    model: model,
                    actions: memberActions,
                    signerDisplayName: accountDisplayName ?? "监护人",
                    onSignOut: onSignOut
                ) {
                    memberTabs(actions: memberActions)
                }
            } else {
                memberTabs(actions: memberActions)
            }
        } else {
            ContentUnavailableView(
                "账号服务暂不可用",
                systemImage: "wifi.exclamationmark",
                description: Text("请退出后重新登录。")
            )
        }
    }

    private var isGuardianPreview: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--md-preview-guardian")
#else
        false
#endif
    }

    private func memberTabs(actions: MobileMemberActionService) -> some View {
        MobileMemberTabs(
            role: role,
            model: model,
            actions: actions,
            appearanceRawValue: $appearanceRawValue,
            accountDisplayName: accountDisplayName,
            onSignOut: onSignOut
        )
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
#if DEBUG
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--md-preview-inbox") ? 3 : 0
#else
    @State private var selectedTab = 0
#endif

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MobileMemberHomeView(
                    model: model,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("首页", systemImage: "house") }
            .tag(0)

            NavigationStack {
                MobileMemberCoursesView(
                    model: model,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("课程", systemImage: "calendar") }
            .tag(1)

            NavigationStack {
                MobileMemberLeaveView(
                    model: model,
                    actions: actions,
                    selectedStudentID: $selectedStudentID
                )
            }
            .tabItem { Label("请假", systemImage: "calendar.badge.minus") }
            .tag(2)

            NavigationStack {
                MobileMemberInboxView(
                    model: model,
                    actions: actions
                )
            }
            .tabItem { Label("文件", systemImage: "folder") }
            .tag(3)

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
            .tag(4)
        }
        .task(id: model.students.map(\.id)) {
            selectAvailableStudent()
        }
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
