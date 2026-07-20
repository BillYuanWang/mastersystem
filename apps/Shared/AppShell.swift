import MasterDanceCore
import SwiftUI

@MainActor
struct AppShell: View {
    let role: AppRole
    let accountDisplayName: String?
    let onManageAccount: (() -> Void)?
    let onSignOut: (() -> Void)?
    let memberActions: MobileMemberActionService?

    @Binding private var appearanceRawValue: String
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
#if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
#endif

    init(
        role: AppRole,
        repository: any MasterDanceRepository,
        appearanceRawValue: Binding<String>,
        accountDisplayName: String? = nil,
        onManageAccount: (() -> Void)? = nil,
        onSignOut: (() -> Void)? = nil,
        memberActions: MobileMemberActionService? = nil
    ) {
        self.role = role
        self.accountDisplayName = accountDisplayName
        self.onManageAccount = onManageAccount
        self.onSignOut = onSignOut
        self.memberActions = memberActions
        _appearanceRawValue = appearanceRawValue
        _model = State(initialValue: AppModel(repository: repository))
    }

    var body: some View {
        Group {
#if os(macOS)
            if role == .administrator {
                AdminDesktopShell(
                    model: model,
                    appearanceRawValue: $appearanceRawValue,
                    accountDisplayName: accountDisplayName,
                    onManageAccount: onManageAccount,
                    onSignOut: onSignOut
                )
            } else {
                ContentUnavailableView(
                    "请在 iPhone 使用学员端",
                    systemImage: "iphone",
                    description: Text("MD Desk 的 macOS 版本仅提供教务功能。")
                )
            }
#else
            MobileWorkspaceView(
                role: role,
                model: model,
                appearanceRawValue: $appearanceRawValue,
                accountDisplayName: accountDisplayName,
                onSignOut: onSignOut,
                memberActions: memberActions
            )
#endif
        }
        .task {
            guard !model.hasLoaded else { return }
            await model.reload()
            await synchronizeMemberActions()
            await model.prepareLocalFirstSession()
        }
        .task(id: synchronizationActivityID) {
            guard shouldPollForSynchronization else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }
                guard shouldPollForSynchronization else { return }
                await synchronizeMemberActions()
                await model.synchronizeRemoteChanges()
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .mdFont(.compact)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
        }
        .overlay {
            CloudSyncOverlay(
                isActive: model.cloudActivity.isActive,
                label: model.cloudActivity.activeLabel
            )
            .zIndex(100)
        }
#if os(iOS)
        .overlay(alignment: .bottom) {
            if model.backgroundSync.isVisible {
                MobileBackgroundSyncNotice(
                    presentation: model.backgroundSync,
                    dismiss: model.dismissBackgroundSyncNotice
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 58)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(90)
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.backgroundSync)
#endif
    }

    private var synchronizationActivityID: String {
#if os(macOS)
        "\(scenePhase)-\(controlActiveState)"
#else
        "\(scenePhase)"
#endif
    }

    private var shouldPollForSynchronization: Bool {
        guard scenePhase == .active else { return false }
#if os(macOS)
        return controlActiveState == .key
#else
        return true
#endif
    }

    private func synchronizeMemberActions() async {
        guard let memberActions else { return }
        do {
            _ = try await memberActions.synchronizePendingChanges()
        } catch {
            model.reportBackgroundSyncFailure(error)
        }
    }

}
