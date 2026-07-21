#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct ScheduleGridView: View {
    let model: AppModel
    let weekStart: Date
    let rooms: [Room]
    let sessions: [ClassSession]
    @Binding var selectedSessionID: ClassSessionID?
    let zoom: Double
    let fontScale: Double

    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.masterDance
    private let timelineStart = 9 * 60 + 30
    private let timelineEnd = 20 * 60 + 30
    private let timeColumnWidth: CGFloat = 54
    private let headerHeight: CGFloat = 58

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        GeometryReader { geometry in
            let contentHeight = max(420, (geometry.size.height - headerHeight) * zoom)

            VStack(spacing: 0) {
                dayHeader(width: geometry.size.width, theme: theme)
                    .frame(height: headerHeight)

                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)

                ScrollView(.vertical) {
                    timelineBody(
                        width: geometry.size.width,
                        height: contentHeight,
                        theme: theme
                    )
                    .frame(width: geometry.size.width, height: contentHeight)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func dayHeader(width: CGFloat, theme: MDTheme) -> some View {
        let laneWidth = max(
            1,
            (width - timeColumnWidth) / CGFloat(ScheduleWeek.dayCount * max(1, rooms.count))
        )
        return HStack(spacing: 0) {
            Text("时间")
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
                .frame(width: timeColumnWidth, height: headerHeight)

            ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        Text(day.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                        if calendar.isDateInToday(day) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 5, height: 5)
                                .accessibilityLabel("今天")
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .mdFont(.monoStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(calendar.isDateInToday(day) ? theme.accent : theme.secondaryText)
                    .padding(.horizontal, 4)
                    .frame(height: 30)

                    HStack(spacing: 0) {
                        ForEach(rooms) { room in
                            Text(room.name)
                                .mdFont(.compact)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .frame(width: laneWidth, height: 28)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(theme.faintSeparator)
                                        .frame(width: 1)
                                }
                        }
                    }
                }
                .frame(width: laneWidth * CGFloat(rooms.count), height: headerHeight)
                .background(
                    dayIndex.isMultiple(of: 2)
                        ? theme.scheduleAlternatingDayHeaderBackground
                        : theme.surface
                )
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(theme.separator)
                        .frame(width: 1)
                }
            }
        }
        .background(theme.surface)
    }

    private func timelineBody(width: CGFloat, height: CGFloat, theme: MDTheme) -> some View {
        let roomCount = max(1, rooms.count)
        let laneCount = days.count * roomCount
        let laneWidth = max(1, (width - timeColumnWidth) / CGFloat(laneCount))
        let dayWidth = laneWidth * CGFloat(roomCount)
        let blockInset: CGFloat = laneWidth < 84 ? 1.5 : 2.5
        return ZStack(alignment: .topLeading) {
            theme.background

            ForEach(days.indices, id: \.self) { dayIndex in
                if dayIndex.isMultiple(of: 2) {
                    Rectangle()
                        .fill(theme.scheduleAlternatingDayBackground)
                        .frame(width: dayWidth, height: height)
                        .offset(x: timeColumnWidth + CGFloat(dayIndex) * dayWidth)
                        .accessibilityHidden(true)
                }
            }

            ForEach(0...22, id: \.self) { index in
                let minute = timelineStart + index * 30
                let y = CGFloat(minute - timelineStart) / CGFloat(timelineEnd - timelineStart) * height
                let isWholeHour = minute.isMultiple(of: 60)

                Rectangle()
                    .fill(isWholeHour ? theme.separator : theme.faintSeparator.opacity(0.72))
                    .frame(width: width, height: isWholeHour ? 1 : 0.45)
                    .offset(y: y)

                if isWholeHour || index == 0 || index == 22 {
                    Text(timeLabel(minute))
                        .mdFont(.mono)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: timeColumnWidth - 5, alignment: .trailing)
                        .offset(y: min(max(0, y - 7), height - 14))
                }
            }

            ForEach(0...laneCount, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: roomCount) ? theme.separator : theme.faintSeparator)
                    .frame(width: index.isMultiple(of: roomCount) ? 0.8 : 0.45, height: height)
                    .offset(x: timeColumnWidth + CGFloat(index) * laneWidth)
            }

            ForEach(sessions) { session in
                if let placement = placement(for: session, laneWidth: laneWidth, height: height) {
                    CourseBlockView(
                        model: model,
                        session: session,
                        width: max(1, laneWidth - blockInset * 2),
                        height: placement.height,
                        fontScale: fontScale,
                        isSelected: selectedSessionID == session.id,
                        hasConflict: hasConflict(session),
                        select: { selectedSessionID = session.id }
                    )
                    .offset(x: placement.x + blockInset, y: placement.y + 1.5)
                }
            }
        }
        .clipped()
    }

    private var days: [Date] {
        ScheduleWeek.days(startingAt: weekStart, calendar: calendar)
    }

    private func placement(for session: ClassSession, laneWidth: CGFloat, height: CGFloat) -> SessionPlacement? {
        guard
            let dayIndex = days.firstIndex(where: { calendar.isDate($0, inSameDayAs: session.startsAt) }),
            let effectiveRoom = model.effectiveRoom(for: session),
            let roomIndex = rooms.firstIndex(where: { $0.id == effectiveRoom.id })
        else {
            return nil
        }

        let startMinute = calendar.component(.hour, from: session.startsAt) * 60
            + calendar.component(.minute, from: session.startsAt)
        let endMinute = calendar.component(.hour, from: session.endsAt) * 60
            + calendar.component(.minute, from: session.endsAt)
        guard startMinute < timelineEnd, endMinute > timelineStart else { return nil }

        let clippedStart = max(startMinute, timelineStart)
        let clippedEnd = min(endMinute, timelineEnd)
        let laneIndex = dayIndex * rooms.count + roomIndex
        let x = timeColumnWidth + CGFloat(laneIndex) * laneWidth
        let y = CGFloat(clippedStart - timelineStart) / CGFloat(timelineEnd - timelineStart) * height
        let blockHeight = CGFloat(clippedEnd - clippedStart) / CGFloat(timelineEnd - timelineStart) * height
        return SessionPlacement(x: x, y: y, height: max(28, blockHeight - 3))
    }

    private func hasConflict(_ session: ClassSession) -> Bool {
        guard let roomID = model.effectiveRoom(for: session)?.id else { return false }
        return sessions.contains { candidate in
            guard
                candidate.id != session.id,
                model.effectiveRoom(for: candidate)?.id == roomID,
                calendar.isDate(candidate.startsAt, inSameDayAs: session.startsAt)
            else {
                return false
            }
            return candidate.startsAt < session.endsAt && candidate.endsAt > session.startsAt
        }
    }

    private func timeLabel(_ minute: Int) -> String {
        let hour = minute / 60
        let minutePart = minute % 60
        let suffix = hour >= 12 ? "PM" : "AM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minutePart, suffix)
    }
}

private struct SessionPlacement {
    let x: CGFloat
    let y: CGFloat
    let height: CGFloat
}
#endif
