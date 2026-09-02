#if os(macOS)
import Foundation

struct ScheduleDetailLayout {
    static let defaultHeight: CGFloat = 190
    static let dividerHeight: CGFloat = 6

    let headerHeight: CGFloat
    let minimumDetailHeight: CGFloat
    let maximumDetailHeight: CGFloat
    let detailHeight: CGFloat
    let gridHeight: CGFloat

    init(
        availableHeight: CGFloat,
        preferredHeight: CGFloat,
        isCollapsed: Bool,
        interfaceScale: CGFloat = 1
    ) {
        let height = max(0, availableHeight)
        let scale = max(1, interfaceScale)
        headerHeight = 40 + (scale - 1) * 16
        let usableHeight = max(0, height - Self.dividerHeight)
        maximumDetailHeight = min(
            usableHeight,
            max(headerHeight, min(360 * scale, height * 0.45, usableHeight - 300))
        )
        minimumDetailHeight = min(160 + (scale - 1) * 60, maximumDetailHeight)
        let preferred = preferredHeight.isFinite ? preferredHeight : Self.defaultHeight
        detailHeight = isCollapsed
            ? min(headerHeight, usableHeight)
            : min(maximumDetailHeight, max(minimumDetailHeight, preferred))
        gridHeight = max(0, usableHeight - detailHeight)
    }
}
#endif
