#if os(macOS)
import Foundation

struct ScheduleFocusLayout {
    static let focusedDayShare: CGFloat = 0.25

    let dayWidths: [CGFloat]
    let roomCount: Int

    init(
        availableWidth: CGFloat,
        timeColumnWidth: CGFloat,
        dayCount: Int = ScheduleWeek.dayCount,
        roomCount: Int,
        focusedDayIndex: Int?
    ) {
        let safeDayCount = max(1, dayCount)
        self.roomCount = max(1, roomCount)
        let contentWidth = max(0, availableWidth - timeColumnWidth)
        let equalWidth = contentWidth / CGFloat(safeDayCount)

        guard
            safeDayCount > 1,
            let focusedDayIndex,
            (0..<safeDayCount).contains(focusedDayIndex)
        else {
            dayWidths = Array(repeating: equalWidth, count: safeDayCount)
            return
        }

        let focusedWidth = contentWidth * Self.focusedDayShare
        let overviewWidth = (contentWidth - focusedWidth) / CGFloat(safeDayCount - 1)
        dayWidths = (0..<safeDayCount).map { index in
            index == focusedDayIndex ? focusedWidth : overviewWidth
        }
    }

    func dayWidth(at dayIndex: Int) -> CGFloat {
        guard dayWidths.indices.contains(dayIndex) else { return 0 }
        return dayWidths[dayIndex]
    }

    func dayOffset(at dayIndex: Int) -> CGFloat {
        guard dayIndex > 0 else { return 0 }
        return dayWidths.prefix(min(dayIndex, dayWidths.count)).reduce(0, +)
    }

    func laneWidth(at dayIndex: Int) -> CGFloat {
        dayWidth(at: dayIndex) / CGFloat(roomCount)
    }

    func laneOffset(dayIndex: Int, roomIndex: Int) -> CGFloat {
        dayOffset(at: dayIndex) + laneWidth(at: dayIndex) * CGFloat(roomIndex)
    }
}
#endif
