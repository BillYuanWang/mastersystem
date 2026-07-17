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
        let laneWidth = max(1, (width - timeColumnWidth) / CGFloat(5 * max(1, rooms.count)))
        return HStack(spacing: 0) {
            Text("TIME")
                .font(MDType.mono)
                .foregroundStyle(theme.secondaryText)
                .frame(width: timeColumnWidth, height: headerHeight)

            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        Text(day.formatted(.dateTime.month(.abbreviated).day()).uppercased())
                        if calendar.isDateInToday(day) {
                            Text("TODAY")
                                .foregroundStyle(theme.accent)
                        }
                    }
                    .font(MDType.monoStrong)
                    .foregroundStyle(calendar.isDateInToday(day) ? theme.accent : theme.secondaryText)
                    .frame(height: 30)

                    HStack(spacing: 0) {
                        ForEach(rooms) { room in
                            Text(room.name)
                                .font(MDType.compact)
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
        let laneCount = 5 * max(1, rooms.count)
        let laneWidth = max(1, (width - timeColumnWidth) / CGFloat(laneCount))
        return ZStack(alignment: .topLeading) {
            theme.background

            ForEach(0...22, id: \.self) { index in
                let minute = timelineStart + index * 30
                let y = CGFloat(minute - timelineStart) / CGFloat(timelineEnd - timelineStart) * height

                Rectangle()
                    .fill(index.isMultiple(of: 2) ? theme.separator : theme.faintSeparator)
                    .frame(width: width, height: index.isMultiple(of: 2) ? 0.7 : 0.45)
                    .offset(y: y)

                if index.isMultiple(of: 2) || index == 22 {
                    Text(timeLabel(minute))
                        .font(MDType.mono)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(theme.secondaryText)
                        .frame(width: timeColumnWidth - 5, alignment: .trailing)
                        .offset(y: min(max(0, y - 7), height - 14))
                }
            }

            ForEach(0...laneCount, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: max(1, rooms.count)) ? theme.separator : theme.faintSeparator)
                    .frame(width: index.isMultiple(of: max(1, rooms.count)) ? 0.8 : 0.45, height: height)
                    .offset(x: timeColumnWidth + CGFloat(index) * laneWidth)
            }

            ForEach(sessions) { session in
                if let placement = placement(for: session, laneWidth: laneWidth, height: height) {
                    CourseBlockView(
                        model: model,
                        session: session,
                        width: laneWidth - 5,
                        height: placement.height,
                        isSelected: selectedSessionID == session.id,
                        hasConflict: hasConflict(session),
                        select: { selectedSessionID = session.id }
                    )
                    .offset(x: placement.x + 2.5, y: placement.y + 1.5)
                }
            }
        }
        .clipped()
    }

    private var days: [Date] {
        (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
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

private struct CourseBlockView: View {
    let model: AppModel
    let session: ClassSession
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let hasConflict: Bool
    let select: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let course = model.course(id: session.courseID)
        let category = course.flatMap { model.category(id: $0.categoryID) }
        let categoryIndex = category.flatMap { selectedCategory in
            model.categories.firstIndex(where: { $0.id == selectedCategory.id })
        } ?? 0
        let color = theme.courseColor(index: categoryIndex)
        let fontSize = blockFontSize

        Button(action: select) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(course?.name ?? "课程")
                        .font(.system(size: fontSize, weight: .semibold))
                        .padding(.trailing, 19)
                    Text((category?.name ?? "分类").uppercased())
                        .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                    Text(model.effectiveInstructor(for: session)?.displayName ?? "老师")
                        .font(.system(size: fontSize - 1))
                    Text(sessionTime)
                        .font(.system(size: fontSize - 1, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)

                Text(course?.format == .privateLesson ? "私" : "组")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(theme.primaryText.opacity(0.72), lineWidth: 1))
                    .padding(4)

                if hasConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.warning)
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
            .frame(width: width, height: height)
            .background(
                color.opacity(colorScheme == .dark ? 0.58 : 0.18),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? theme.accent : color.opacity(0.9), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(hoverText)
    }

    private var blockFontSize: CGFloat {
        if width < 72 || height < 54 { return 8 }
        if width < 92 || height < 70 { return 9 }
        return 10
    }

    private var sessionTime: String {
        "\(session.startsAt.formatted(date: .omitted, time: .shortened))–\(session.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private var hoverText: String {
        let course = model.course(id: session.courseID)
        let category = course.flatMap { model.category(id: $0.categoryID) }?.name ?? ""
        let age = course.flatMap { model.ageGroup(id: $0.ageGroupID) }?.name ?? ""
        let room = model.effectiveRoom(for: session)?.name ?? ""
        let roster = model.enrollments(forCourse: session.courseID).compactMap { model.student(id: $0.studentID)?.displayName }
        return [course?.name ?? "课程", category, age, room, sessionTime, roster.joined(separator: "、")]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
#endif
