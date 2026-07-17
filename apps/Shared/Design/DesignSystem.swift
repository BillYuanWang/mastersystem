import SwiftUI

@MainActor
struct MDTheme {
    let scheme: ColorScheme

    var background: Color { scheme == .dark ? hex(0x0A0E14) : hex(0xF7F7F8) }
    var surface: Color { scheme == .dark ? hex(0x0F1419) : .white }
    var raisedSurface: Color { scheme == .dark ? hex(0x151B22) : hex(0xFFFFFF) }
    var subtleSurface: Color { scheme == .dark ? hex(0x131920) : hex(0xF1F1F3) }
    var separator: Color { scheme == .dark ? hex(0x2A3139) : hex(0xD9D9DE) }
    var faintSeparator: Color { separator.opacity(scheme == .dark ? 0.48 : 0.58) }
    var primaryText: Color { scheme == .dark ? hex(0xE6E1CF) : hex(0x202124) }
    var secondaryText: Color { scheme == .dark ? hex(0x8A9199) : hex(0x68686F) }
    var accent: Color { scheme == .dark ? hex(0x39BAE6) : hex(0xFF4D4F) }
    var warning: Color { hex(0xFFB454) }
    var success: Color { scheme == .dark ? hex(0xAAD94C) : hex(0x27A35A) }
    var danger: Color { hex(0xF07178) }

    func courseColor(index: Int) -> Color {
        let darkColors = [0x39BAE6, 0xFFB454, 0xAAD94C, 0xD2A6FF, 0xF07178, 0x95E6CB]
        let lightColors = [0x36A3D9, 0xE6A23C, 0x67A84A, 0x8B78D7, 0xE26068, 0x45A997]
        let colors = scheme == .dark ? darkColors : lightColors
        return hex(colors[index.modulo(colors.count)])
    }

    private func hex(_ value: Int) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum MDType {
    static let body = Font.system(size: 13)
    static let bodyStrong = Font.system(size: 13, weight: .semibold)
    static let compact = Font.system(size: 11)
    static let compactStrong = Font.system(size: 11, weight: .semibold)
    static let mono = Font.system(size: 11, design: .monospaced)
    static let monoStrong = Font.system(size: 11, weight: .semibold, design: .monospaced)
}

enum MDMetrics {
    static let railWidth: CGFloat = 58
    static let inspectorWidth: CGFloat = 294
    static let radius: CGFloat = 7
    static let controlHeight: CGFloat = 30
    static let compactSpacing: CGFloat = 8
}

struct MDIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let theme = MDTheme(scheme: colorScheme)
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.primaryText)
            .frame(width: MDMetrics.controlHeight, height: MDMetrics.controlHeight)
            .background(
                theme.subtleSurface.opacity(configuration.isPressed ? 1 : 0),
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .contentShape(Rectangle())
    }
}

struct MDSectionTitle: View {
    let chinese: String
    let english: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 7) {
            Text(chinese)
                .font(MDType.bodyStrong)
            Text("/")
                .font(MDType.mono)
                .foregroundStyle(theme.secondaryText)
            Text(english)
                .font(MDType.monoStrong)
                .foregroundStyle(theme.accent)
        }
        .foregroundStyle(theme.primaryText)
    }
}

struct MDStatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
