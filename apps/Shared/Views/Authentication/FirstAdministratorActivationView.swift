#if os(macOS)
import SwiftUI

@MainActor
struct FirstAdministratorActivationView: View {
    let session: AdminSessionModel

    @State private var displayName = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Label("首次启用", systemImage: "building.2.crop.circle")
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 8) {
                    Text("首位教务姓名")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                    TextField("姓名", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(activate)
                }

                if let errorMessage = session.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("退出登录") {
                        Task { await session.signOut() }
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button(action: activate) {
                        Label("启用学校", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(session.isWorking)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 360)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func activate() {
        Task { await session.completeFirstAdministratorActivation(displayName: displayName) }
    }
}
#endif
