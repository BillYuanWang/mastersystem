#if os(iOS)
import SwiftUI

struct MobileBackgroundSyncNotice: View {
    let presentation: BackgroundSyncPresentation
    let dismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 9) {
            statusIcon(theme: theme)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .mdFont(.compactStrong)
                Text(detail)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if presentation.notice != nil {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(borderColor(theme: theme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 9, y: 3)
    }

    @ViewBuilder
    private func statusIcon(theme: MDTheme) -> some View {
        if case .failure = presentation.notice {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.danger)
        } else if presentation.activeCount > 0 {
            ProgressView()
                .controlSize(.small)
                .tint(theme.accent)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
        }
    }

    private var title: String {
        if case .failure = presentation.notice { return "同步失败" }
        if presentation.activeCount > 0 { return "正在同步" }
        return "已完成"
    }

    private var detail: String {
        if case let .failure(message) = presentation.notice { return message }
        if presentation.activeCount > 0 { return presentation.activeLabel ?? "保存资料" }
        if case let .success(message) = presentation.notice { return message }
        return "资料已同步"
    }

    private func borderColor(theme: MDTheme) -> Color {
        if case .failure = presentation.notice { return theme.danger.opacity(0.55) }
        return theme.separator
    }
}
#endif
