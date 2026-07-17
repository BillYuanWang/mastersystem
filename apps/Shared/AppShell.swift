import MasterDanceCore
import SwiftUI

@MainActor
struct AppShell: View {
    let role: AppRole

    @AppStorage("appearancePreference") private var appearanceRawValue = AppearancePreference.dark.rawValue
    @State private var model: AppModel

    init(role: AppRole, repository: any MasterDanceRepository) {
        self.role = role
        _model = State(initialValue: AppModel(repository: repository))
    }

    var body: some View {
        Group {
#if os(macOS)
            if role == .administrator {
                AdminDesktopShell(
                    model: model,
                    appearanceRawValue: $appearanceRawValue
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
                appearanceRawValue: $appearanceRawValue
            )
#endif
        }
        .preferredColorScheme(preferredColorScheme)
        .task {
            guard !model.hasLoaded else { return }
            await model.reload()
        }
        .overlay(alignment: .top) {
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(MDType.compact)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.9), in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
            }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearanceRawValue) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
