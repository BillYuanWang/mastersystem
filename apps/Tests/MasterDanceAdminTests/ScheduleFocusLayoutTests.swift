import AppKit
import Foundation
import MasterDanceCore
import SwiftUI
import Testing
@testable import MasterDanceAdmin

@Suite("Schedule focused-day layout")
struct ScheduleFocusLayoutTests {
    @Test("The default week keeps seven equal day widths")
    func equalWeek() {
        let layout = ScheduleFocusLayout(
            availableWidth: 1_454,
            timeColumnWidth: 54,
            roomCount: 2,
            focusedDayIndex: nil
        )

        #expect(layout.dayWidths.count == 7)
        #expect(layout.dayWidths.allSatisfy { abs($0 - 200) < 0.001 })
        #expect(abs(layout.dayWidths.reduce(0, +) - 1_400) < 0.001)
    }

    @Test("The focused day receives one quarter while every overview day remains visible")
    func focusedWeek() {
        let layout = ScheduleFocusLayout(
            availableWidth: 1_454,
            timeColumnWidth: 54,
            roomCount: 2,
            focusedDayIndex: 5
        )

        #expect(abs(layout.dayWidth(at: 5) - 350) < 0.001)
        #expect(abs(layout.dayWidth(at: 0) - 175) < 0.001)
        #expect(layout.dayWidths.allSatisfy { $0 > 0 })
        #expect(abs(layout.dayWidths.reduce(0, +) - 1_400) < 0.001)
    }

    @Test("Room lanes follow each day's width and offset")
    func roomLanes() {
        let layout = ScheduleFocusLayout(
            availableWidth: 1_454,
            timeColumnWidth: 54,
            roomCount: 2,
            focusedDayIndex: 2
        )

        #expect(abs(layout.laneWidth(at: 2) - 175) < 0.001)
        #expect(abs(layout.laneWidth(at: 1) - 87.5) < 0.001)
        #expect(abs(layout.laneOffset(dayIndex: 2, roomIndex: 1) - 525) < 0.001)
    }

    @Test("An invalid focus falls back to equal widths")
    func invalidFocus() {
        let layout = ScheduleFocusLayout(
            availableWidth: 754,
            timeColumnWidth: 54,
            roomCount: 2,
            focusedDayIndex: 8
        )

        #expect(layout.dayWidths.allSatisfy { abs($0 - 100) < 0.001 })
    }

    @Test("The focused timetable renders at a desktop window size")
    @MainActor
    func rendersFocusedTimetable() throws {
        let calendar = Calendar.masterDance
        let weekStart = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 31,
            hour: 9,
            minute: 30
        )))
        let term = Term(name: "2026年秋季学期", startsOn: weekStart, endsOn: weekStart, status: .open)
        let rooms = [Room(name: "大教室"), Room(name: "小教室")]
        let instructor = Instructor(displayName: "蔡京")
        let courseType = CourseType(name: "大组课", isPrivate: false)
        let category = CourseCategory(name: "兼容分类")
        let ageGroups = [AgeGroup(name: "5-7 岁"), AgeGroup(name: "8-11 岁")]
        let names = ["中国舞基本功", "中国舞表演课", "比赛 Team 专属排舞课", "芭蕾基训"]
        var courses: [Course] = []
        var sessions: [ClassSession] = []

        for dayIndex in 0..<ScheduleWeek.dayCount {
            for roomIndex in rooms.indices {
                let course = Course(
                    termID: term.id,
                    name: names[(dayIndex + roomIndex) % names.count],
                    categoryID: category.id,
                    ageGroupID: ageGroups[(dayIndex + roomIndex) % ageGroups.count].id,
                    defaultRoomID: rooms[roomIndex].id,
                    defaultInstructorID: instructor.id,
                    courseTypeID: courseType.id,
                    format: .group,
                    pricingStatus: .priced,
                    unitPriceCents: 4_000,
                    dropInUnitPriceCents: 4_500
                )
                let day = try #require(calendar.date(byAdding: .day, value: dayIndex, to: weekStart))
                let start = try #require(calendar.date(
                    byAdding: .minute,
                    value: 360 + roomIndex * 75 + dayIndex % 3 * 20,
                    to: day
                ))
                courses.append(course)
                sessions.append(ClassSession(
                    courseID: course.id,
                    startsAt: start,
                    endsAt: start.addingTimeInterval(3_600)
                ))
            }
        }

        let model = AppModel(repository: PreviewMasterDanceStore())
        model.terms = [term]
        model.rooms = rooms
        model.instructors = [instructor]
        model.courseTypes = [courseType]
        model.ageGroups = ageGroups
        model.courses = courses
        model.sessions = sessions

        let size = NSSize(width: 1_228, height: 500)
        let hostingView = NSHostingView(
            rootView: ScheduleGridView(
                model: model,
                weekStart: weekStart,
                rooms: rooms,
                sessions: sessions,
                selectedSessionID: .constant(nil),
                zoom: 1,
                fontScale: 1,
                focusedDayIndex: 5,
                toggleFocusedDay: { _ in }
            )
            .frame(width: size.width, height: size.height)
        )
        hostingView.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        let bitmap = try #require(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))

        #expect(png.count > 30_000)
        if let path = ProcessInfo.processInfo.environment["MD_SCHEDULE_SNAPSHOT_PATH"] {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
