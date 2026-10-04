import Foundation
import Testing
@testable import MasterDanceAdmin

@Suite("Schedule bottom detail layout")
struct ScheduleDetailLayoutTests {
    @Test("Expanded details leave usable timetable space", arguments: [550.0, 720.0, 1000.0])
    func keepsGridVisible(height: Double) {
        let layout = ScheduleDetailLayout(
            availableHeight: height,
            preferredHeight: ScheduleDetailLayout.defaultHeight,
            isCollapsed: false
        )

        #expect(layout.gridHeight >= 300)
        #expect(layout.detailHeight >= layout.minimumDetailHeight)
        #expect(layout.detailHeight <= layout.maximumDetailHeight)
        let totalHeight = Double(layout.gridHeight + layout.detailHeight + ScheduleDetailLayout.dividerHeight)
        #expect(abs(totalHeight - height) < 0.001)
    }

    @Test("Stored heights are clamped after resizing the window")
    func clampsStoredHeight() {
        let large = ScheduleDetailLayout(availableHeight: 550, preferredHeight: 900, isCollapsed: false)
        let small = ScheduleDetailLayout(availableHeight: 550, preferredHeight: 0, isCollapsed: false)

        #expect(large.detailHeight == large.maximumDetailHeight)
        #expect(small.detailHeight == small.minimumDetailHeight)
        #expect(large.gridHeight >= 300)
    }

    @Test("Collapsing preserves only the action header")
    func collapsesToHeader() {
        let expanded = ScheduleDetailLayout(availableHeight: 720, preferredHeight: 230, isCollapsed: false)
        let collapsed = ScheduleDetailLayout(availableHeight: 720, preferredHeight: 230, isCollapsed: true)

        #expect(collapsed.detailHeight == collapsed.headerHeight)
        #expect(collapsed.gridHeight > expanded.gridHeight)
    }

    @Test("Large interface text receives a taller header and minimum panel")
    func accommodatesInterfaceScale() {
        let normal = ScheduleDetailLayout(availableHeight: 720, preferredHeight: 0, isCollapsed: false)
        let large = ScheduleDetailLayout(availableHeight: 720, preferredHeight: 0, isCollapsed: false, interfaceScale: 1.4)

        #expect(large.headerHeight > normal.headerHeight)
        #expect(large.minimumDetailHeight > normal.minimumDetailHeight)
        #expect(large.gridHeight > 300)
    }

    @Test("Transient small geometry never produces negative frames", arguments: [0.0, 80.0, 200.0])
    func handlesSmallGeometry(height: Double) {
        let layout = ScheduleDetailLayout(availableHeight: height, preferredHeight: .nan, isCollapsed: false)

        #expect(layout.detailHeight >= 0)
        #expect(layout.gridHeight >= 0)
        #expect(layout.detailHeight.isFinite)
        #expect(layout.gridHeight.isFinite)
    }
}
