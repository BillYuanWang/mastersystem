#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct AdminDesktopShell: View {
    let model: AppModel
    @Binding var appearanceRawValue: String
    let accountDisplayName: String?
    let onManageAccount: (() -> Void)?
    let onSignOut: (() -> Void)?

    @State private var selection = AdminSection.schedule
    @State private var showingGuardianLinkCode = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 0) {
            CompactRailView(
                selection: $selection,
                appearanceRawValue: $appearanceRawValue,
                accountDisplayName: accountDisplayName,
                onManageAccount: onManageAccount,
                onSignOut: onSignOut
            )
            .frame(width: MDMetrics.railWidth)
            .zIndex(20)

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1)

            workspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
        .overlay(alignment: .bottomTrailing) {
            if model.backgroundSync.isVisible || !model.availableGuardianLinkCodes.isEmpty {
                BackgroundSyncIndicator(
                    presentation: model.backgroundSync,
                    guardianLinkCodeCount: model.availableGuardianLinkCodes.count,
                    showGuardianLinkCode: { showingGuardianLinkCode = true },
                    dismissNotice: model.dismissBackgroundSyncNotice
                )
                .padding(14)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .animation(.easeOut(duration: 0.18), value: model.backgroundSync)
        .animation(.easeOut(duration: 0.18), value: model.availableGuardianLinkCodes.count)
        .sheet(isPresented: $showingGuardianLinkCode, onDismiss: model.clearGuardianLinkCode) {
            if let code = model.availableGuardianLinkCodes.first {
                GuardianLinkCodeSheet(code: code)
            }
        }
    }

    @ViewBuilder
    private var workspace: some View {
        switch selection {
        case .schedule:
            ScheduleWorkspaceView(model: model) { destination in
                selection = destination
            }
        case .courses:
            SetupWorkspaceView(model: model)
        case .families:
            StudentsWorkspaceView(model: model)
        case .enrollments:
            EnrollmentsWorkspaceView(model: model)
        case .attendance:
            AttendanceWorkspaceView(model: model)
        case .requests:
            RequestsWorkspaceView(model: model)
        case .contracts:
            ContractsWorkspaceView(model: model)
        case .dataCenter:
            DataCenterWorkspaceView(model: model)
        }
    }
}

private struct BackgroundSyncIndicator: View {
    let presentation: BackgroundSyncPresentation
    let guardianLinkCodeCount: Int
    let showGuardianLinkCode: () -> Void
    let dismissNotice: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 9) {
            statusMark(theme: theme)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.primaryText)
                Text(detail)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            if hasGuardianLinkCode {
                Button(guardianLinkCodeCount > 1 ? "查看 \(guardianLinkCodeCount)" : "查看", action: showGuardianLinkCode)
                    .buttonStyle(.borderless)
                    .mdFont(.compactStrong)
            }

            if presentation.notice != nil {
                Button(action: dismissNotice) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryText)
                .help("关闭提示")
            }
        }
        .padding(.horizontal, 11)
        .frame(minWidth: 210, maxWidth: 390, minHeight: 44)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(borderColor(theme: theme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.13), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func statusMark(theme: MDTheme) -> some View {
        if case .failure = presentation.notice {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.danger)
                .frame(width: 18, height: 18)
        } else if presentation.activeCount > 0 {
            ProgressView()
                .controlSize(.small)
                .tint(statusColor(theme: theme))
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: statusImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusColor(theme: theme))
                .frame(width: 18, height: 18)
        }
    }

    private var title: String {
        if case .failure = presentation.notice { return "同步失败" }
        if presentation.activeCount > 0 { return "正在同步" }
        if hasGuardianLinkCode { return "监护人码已生成" }
        return "已完成"
    }

    private var hasGuardianLinkCode: Bool {
        guardianLinkCodeCount > 0
    }

    private var detail: String {
        if case let .failure(message) = presentation.notice {
            let pending = presentation.activeCount > 0 ? " · 另有 \(presentation.activeCount) 项同步中" : ""
            return message + pending
        }
        if presentation.activeCount > 0 {
            let count = presentation.activeCount > 1 ? " · \(presentation.activeCount) 项" : ""
            return (presentation.activeLabel ?? "保存资料") + count
        }
        if hasGuardianLinkCode { return "可继续工作，需要时再查看。" }
        if case let .success(message) = presentation.notice { return message }
        return "资料已同步。"
    }

    private var statusImage: String {
        if case .failure = presentation.notice { return "exclamationmark.triangle.fill" }
        if hasGuardianLinkCode { return "key.fill" }
        return "checkmark.circle.fill"
    }

    private func statusColor(theme: MDTheme) -> Color {
        if case .failure = presentation.notice { return theme.danger }
        if presentation.activeCount > 0 { return theme.accent }
        return theme.success
    }

    private func borderColor(theme: MDTheme) -> Color {
        if case .failure = presentation.notice { return theme.danger.opacity(0.55) }
        return theme.separator
    }
}

private struct CompactRailView: View {
    @Binding var selection: AdminSection
    @Binding var appearanceRawValue: String
    let accountDisplayName: String?
    let onManageAccount: (() -> Void)?
    let onSignOut: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItem: String?

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 9) {
            MasterDanceLogoView()
                .frame(width: 38, height: 38)
                .clipShape(Circle())
                .padding(.top, 12)
                .padding(.bottom, 8)
                .help("Master Dance")

            ForEach(AdminSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .fill(
                                selection == section
                                    ? theme.accent.opacity(0.13)
                                    : (hoveredItem == section.id ? theme.subtleSurface : .clear)
                            )
                            .frame(width: 42, height: 38)

                        if selection == section {
                            Capsule()
                                .fill(theme.accent)
                                .frame(width: 3, height: 24)
                                .offset(x: -6)
                        }

                        Image(systemName: section.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(selection == section ? theme.accent : theme.secondaryText)
                            .frame(width: 42, height: 38)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .onHover { isHovering in
                    updateHover(section.id, isHovering: isHovering)
                }
                .overlay(alignment: .leading) {
                    hoverLabel(id: section.id, title: section.title)
                }
                .zIndex(hoveredItem == section.id ? 10 : 0)
                .help(section.title)
            }

            Spacer(minLength: 8)

            if let onManageAccount, let onSignOut {
                Menu {
                    if let accountDisplayName {
                        Text(accountDisplayName)
                    }
                    Button(action: onManageAccount) {
                        Label("教务账号", systemImage: "person.2")
                    }
                    Divider()
                    Button(role: .destructive, action: onSignOut) {
                        Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .fill(hoveredItem == "account" ? theme.subtleSurface : .clear)
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .frame(width: 42, height: 38)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel("教务账号")
                .onHover { isHovering in
                    updateHover("account", isHovering: isHovering)
                }
                .overlay(alignment: .leading) {
                    hoverLabel(id: "account", title: "教务账号")
                }
                .zIndex(hoveredItem == "account" ? 10 : 0)
                .help("教务账号")
            }

            Menu {
                Picker("外观", selection: $appearanceRawValue) {
                    Label("跟随系统", systemImage: "circle.lefthalf.filled")
                        .tag(AppearancePreference.system.rawValue)
                    Label("浅色", systemImage: "sun.max")
                        .tag(AppearancePreference.light.rawValue)
                    Label("深色", systemImage: "moon")
                        .tag(AppearancePreference.dark.rawValue)
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .fill(hoveredItem == "appearance" ? theme.subtleSurface : .clear)
                    Image(systemName: appearanceImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(width: 42, height: 38)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("外观")
            .onHover { isHovering in
                updateHover("appearance", isHovering: isHovering)
            }
            .overlay(alignment: .leading) {
                hoverLabel(id: "appearance", title: "外观")
            }
            .zIndex(hoveredItem == "appearance" ? 10 : 0)
            .help("外观")
            .padding(.bottom, 12)
        }
        .frame(maxHeight: .infinity)
        .background(theme.surface)
    }

    private var appearanceImage: String {
        switch AppearancePreference(rawValue: appearanceRawValue) ?? .system {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    @ViewBuilder
    private func hoverLabel(id: String, title: String) -> some View {
        if hoveredItem == id {
            RailHoverLabel(title: title)
                .offset(x: 50)
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .allowsHitTesting(false)
        }
    }

    private func updateHover(_ id: String, isHovering: Bool) {
        withAnimation(.easeOut(duration: 0.1)) {
            if isHovering {
                hoveredItem = id
            } else if hoveredItem == id {
                hoveredItem = nil
            }
        }
    }
}

private struct RailHoverLabel: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        Text(title)
            .mdFont(.bodyStrong)
            .foregroundStyle(theme.primaryText)
        .fixedSize()
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.34 : 0.14), radius: 7, y: 3)
        .accessibilityHidden(true)
    }
}
#endif
