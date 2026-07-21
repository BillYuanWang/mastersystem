import SwiftUI

@MainActor
struct MDTheme {
    let scheme: ColorScheme

    var background: Color { scheme == .dark ? hex(0x0A0E14) : hex(0xF7F7F8) }
    var surface: Color { scheme == .dark ? hex(0x0F1419) : .white }
    var raisedSurface: Color { scheme == .dark ? hex(0x151B22) : hex(0xFFFFFF) }
    var subtleSurface: Color { scheme == .dark ? hex(0x131920) : hex(0xF1F1F3) }
    var scheduleAlternatingDayBackground: Color { scheme == .dark ? hex(0x10161D) : hex(0xF0F0F2) }
    var scheduleAlternatingDayHeaderBackground: Color { scheme == .dark ? hex(0x131920) : hex(0xF4F4F6) }
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

    func scheduleBlockBackground(index: Int) -> Color {
        let darkColors = [
            0x185E78, 0x80501E, 0x41651F, 0x5D477C,
            0x7A3F49, 0x26665B, 0x75466D, 0x405982,
            0x6E5D1D, 0x25616D, 0x6D4B31, 0x4D5F70,
        ]
        let lightColors = [
            0xD7EFF8, 0xF9E5C2, 0xDEEDCF, 0xE7DDF6,
            0xF4D9DD, 0xD5EEE8, 0xEFDCEA, 0xDCE4F4,
            0xF2E8C5, 0xD7EBEF, 0xEEDFD2, 0xDEE5EA,
        ]
        let colors = scheme == .dark ? darkColors : lightColors
        return hex(colors[index.modulo(colors.count)])
    }

    func scheduleBlockBorder(index: Int) -> Color {
        let darkColors = [
            0x39BAE6, 0xFFB454, 0xAAD94C, 0xD2A6FF,
            0xF07178, 0x95E6CB, 0xFF8FD8, 0x8FA8FF,
            0xE6C95C, 0x61D6E8, 0xE6A66A, 0xA9B7C6,
        ]
        let lightColors = [
            0x238CB5, 0xC77A1F, 0x5D913A, 0x8067BE,
            0xC9505C, 0x378F80, 0xA9518D, 0x5D75B8,
            0x9A801D, 0x3B8997, 0xA36B42, 0x687D8C,
        ]
        let colors = scheme == .dark ? darkColors : lightColors
        return hex(colors[index.modulo(colors.count)])
    }

    var scheduleBlockText: Color {
        scheme == .dark ? hex(0xFFF9EA) : hex(0x202124)
    }

    private func hex(_ value: Int) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum MDInterfaceFontScale {
    static let storageKey = "md.interfaceFontScale"
    static let defaultValue = 1.0
    static let minimum = 0.8
    static let maximum = 1.3
    static let step = 0.1

    static func normalized(_ value: Double) -> Double {
        let clamped = min(maximum, max(minimum, value))
        return (clamped / step).rounded() * step
    }

    static func larger(than value: Double) -> Double {
        normalized(value + step)
    }

    static func smaller(than value: Double) -> Double {
        normalized(value - step)
    }
}

enum MDTextStyle {
    case body
    case bodyStrong
    case compact
    case compactStrong
    case mono
    case monoStrong

    fileprivate var size: CGFloat {
        switch self {
        case .body, .bodyStrong:
#if os(iOS)
            16
#else
            13
#endif
        case .compact, .compactStrong, .mono, .monoStrong:
#if os(iOS)
            13
#else
            11
#endif
        }
    }

    fileprivate var weight: Font.Weight {
        switch self {
        case .bodyStrong, .compactStrong, .monoStrong: .semibold
        case .body, .compact, .mono: .regular
        }
    }

    fileprivate var design: Font.Design {
        switch self {
        case .mono, .monoStrong: .monospaced
        case .body, .bodyStrong, .compact, .compactStrong: .default
        }
    }
}

private struct MDInterfaceFontScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var mdInterfaceFontScale: CGFloat {
        get { self[MDInterfaceFontScaleKey.self] }
        set { self[MDInterfaceFontScaleKey.self] = newValue }
    }
}

private struct MDScaledFontModifier: ViewModifier {
    @Environment(\.mdInterfaceFontScale) private var interfaceScale

    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(
            .system(
                size: max(1, size * interfaceScale),
                weight: weight,
                design: design
            )
        )
    }
}

private struct MDInterfaceFontScaleModifier: ViewModifier {
    let value: Double

    func body(content: Content) -> some View {
        let scale = CGFloat(MDInterfaceFontScale.normalized(value))
#if os(iOS)
        let baseSize: CGFloat = 16
#else
        let baseSize: CGFloat = 13
#endif
        content
            .environment(\.mdInterfaceFontScale, scale)
            .font(.system(size: baseSize * scale))
            .minimumScaleFactor(0.72)
    }
}

extension View {
    func mdFont(_ style: MDTextStyle) -> some View {
        modifier(
            MDScaledFontModifier(
                size: style.size,
                weight: style.weight,
                design: style.design
            )
        )
    }

    func mdFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(MDScaledFontModifier(size: size, weight: weight, design: design))
    }

    func mdInterfaceFontScale(_ value: Double) -> some View {
        modifier(MDInterfaceFontScaleModifier(value: value))
    }
}

enum MDMetrics {
    static let railWidth: CGFloat = 58
    static let inspectorWidth: CGFloat = 294
    static let statusBarHeight: CGFloat = 34
    static let radius: CGFloat = 7
    static let controlHeight: CGFloat = 30
    static let compactSpacing: CGFloat = 8
}

struct MDIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mdInterfaceFontScale) private var interfaceScale

    func makeBody(configuration: Configuration) -> some View {
        let theme = MDTheme(scheme: colorScheme)
        let dimension = MDMetrics.controlHeight + max(0, interfaceScale - 1) * 8
        configuration.label
            .mdFont(size: 13, weight: .medium)
            .foregroundStyle(theme.primaryText)
            .frame(width: dimension, height: dimension)
            .background(
                theme.subtleSurface.opacity(configuration.isPressed ? 1 : 0),
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .contentShape(Rectangle())
    }
}

struct MDHeaderActionButtonStyle: ButtonStyle {
    let isActive: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let theme = MDTheme(scheme: colorScheme)
        configuration.label
            .mdFont(.compactStrong)
            .foregroundStyle(isActive ? theme.accent : theme.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                isActive
                    ? theme.accent.opacity(colorScheme == .dark ? 0.2 : 0.1)
                    : theme.raisedSurface,
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(isActive ? theme.accent.opacity(0.58) : theme.separator, lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .contentShape(Rectangle())
    }
}

struct MDSectionTitle: View {
    let chinese: String

    init(chinese: String, english: String? = nil) {
        self.chinese = chinese
    }

    var body: some View {
        Text(chinese)
            .mdFont(.bodyStrong)
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
