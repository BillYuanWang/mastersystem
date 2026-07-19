import SwiftUI

struct CloudSyncOverlay: View {
    let isActive: Bool
    let label: String?

    @State private var isVisible = false
    @State private var visibleSince: Date?

    var body: some View {
        ZStack {
            if isVisible {
                CloudSyncLoader(label: label)
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .task(id: isActive) {
            if isActive {
                await showAfterDelay()
            } else {
                await hideAfterMinimumDuration()
            }
        }
    }

    private func showAfterDelay() async {
        do {
            try await Task.sleep(nanoseconds: 120_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        visibleSince = Date()
        withAnimation(.smooth(duration: 0.18)) {
            isVisible = true
        }
    }

    private func hideAfterMinimumDuration() async {
        if let visibleSince {
            let elapsed = Date().timeIntervalSince(visibleSince)
            let remaining = max(0, 0.32 - elapsed)
            if remaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
        guard !Task.isCancelled else { return }
        withAnimation(.smooth(duration: 0.16)) {
            isVisible = false
        }
        visibleSince = nil
    }
}

private struct CloudSyncLoader: View {
    let label: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 10) {
            SmoothActivityIndicator(tint: theme.primaryText)
                .frame(width: 18, height: 18)

            Text(label ?? "正在同步")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 14)
        .frame(minWidth: 132, minHeight: 46)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.26 : 0.10),
            radius: 7,
            y: 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "正在同步")
    }
}

private struct SmoothActivityIndicator: View {
    let tint: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 0.78) / 0.78

            ZStack {
                Circle()
                    .stroke(tint.opacity(0.16), lineWidth: 2.2)

                Circle()
                    .trim(from: 0.06, to: 0.72)
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(cycle * 360))
            }
        }
    }
}
