#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct AdminDesktopShell: View {
    let model: AppModel
    @Binding var appearanceRawValue: String

    @State private var selection = AdminSection.schedule

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 0) {
            CompactRailView(
                selection: $selection,
                appearanceRawValue: $appearanceRawValue
            )
            .frame(width: MDMetrics.railWidth)

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1)

            workspace
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private var workspace: some View {
        switch selection {
        case .schedule:
            ScheduleWorkspaceView(model: model) { destination in
                selection = destination
            }
        case .setup:
            SetupWorkspaceView(model: model)
        case .students:
            StudentsWorkspaceView(model: model)
        case .enrollments:
            EnrollmentsWorkspaceView(model: model)
        case .attendance:
            AttendanceWorkspaceView(model: model)
        case .requests:
            RequestsWorkspaceView(model: model)
        }
    }
}

private struct CompactRailView: View {
    @Binding var selection: AdminSection
    @Binding var appearanceRawValue: String

    @Environment(\.colorScheme) private var colorScheme

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
                            .fill(selection == section ? theme.accent.opacity(0.13) : .clear)
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
                .help("\(section.title) / \(section.englishTitle)")
            }

            Spacer(minLength: 8)

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
                Image(systemName: appearanceImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 42, height: 38)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("外观 / APPEARANCE")
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
}
#endif
