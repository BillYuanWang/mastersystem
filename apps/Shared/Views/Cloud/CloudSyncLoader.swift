import SwiftUI

struct CloudSyncLoader: View {
    let label: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            VStack(spacing: 7) {
                CloudSyncGlyph(
                    elapsed: elapsed,
                    reduceMotion: reduceMotion,
                    cloudColor: colorScheme == .dark ? theme.accent : theme.primaryText,
                    arrowColor: colorScheme == .dark ? theme.warning : theme.accent,
                    trackColor: theme.secondaryText.opacity(colorScheme == .dark ? 0.42 : 0.28)
                )
                .frame(width: 76, height: 58)

                Text(label ?? "正在同步云端")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(width: 128)
            .frame(minHeight: 104)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.34 : 0.15),
                radius: 13,
                y: 5
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "正在同步云端")
    }
}

private struct CloudSyncGlyph: View {
    let elapsed: TimeInterval
    let reduceMotion: Bool
    let cloudColor: Color
    let arrowColor: Color
    let trackColor: Color

    var body: some View {
        let dashPhase = reduceMotion ? CGFloat.zero : CGFloat(-elapsed * 25)
        let rotation = reduceMotion ? Double.zero : elapsed * 150

        ZStack {
            CloudOutlineShape()
                .stroke(trackColor, lineWidth: 1.2)

            CloudOutlineShape()
                .trim(from: 0.03, to: 0.97)
                .stroke(
                    cloudColor,
                    style: StrokeStyle(
                        lineWidth: 2.2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [12, 7],
                        dashPhase: dashPhase
                    )
                )

            VStack(spacing: 4) {
                movingLine(index: 0, width: 27)
                movingLine(index: 1, width: 39)
                movingLine(index: 2, width: 23)
            }
            .offset(y: 8)

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(arrowColor)
                .rotationEffect(.degrees(rotation))
                .offset(y: -23)
        }
    }

    private func movingLine(index: Int, width: CGFloat) -> some View {
        let offset = reduceMotion
            ? CGFloat.zero
            : CGFloat(sin(elapsed * 2.8 + Double(index) * 1.9) * 6)
        return Capsule()
            .fill(cloudColor.opacity(index == 1 ? 0.92 : 0.64))
            .frame(width: width, height: 2)
            .offset(x: offset)
    }
}

private struct CloudOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        path.move(to: CGPoint(x: width * 0.23, y: height * 0.82))
        path.addCurve(
            to: CGPoint(x: width * 0.06, y: height * 0.64),
            control1: CGPoint(x: width * 0.12, y: height * 0.82),
            control2: CGPoint(x: width * 0.06, y: height * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.20, y: height * 0.43),
            control1: CGPoint(x: width * 0.06, y: height * 0.52),
            control2: CGPoint(x: width * 0.11, y: height * 0.44)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.38, y: height * 0.38),
            control1: CGPoint(x: width * 0.25, y: height * 0.38),
            control2: CGPoint(x: width * 0.31, y: height * 0.37)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.72, y: height * 0.40),
            control1: CGPoint(x: width * 0.47, y: height * 0.08),
            control2: CGPoint(x: width * 0.66, y: height * 0.17)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.93, y: height * 0.59),
            control1: CGPoint(x: width * 0.85, y: height * 0.38),
            control2: CGPoint(x: width * 0.93, y: height * 0.47)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.78, y: height * 0.82),
            control1: CGPoint(x: width * 0.93, y: height * 0.73),
            control2: CGPoint(x: width * 0.88, y: height * 0.82)
        )
        path.addLine(to: CGPoint(x: width * 0.23, y: height * 0.82))

        return path
    }
}
