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

            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
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
        let laneCount = days.count * max(1, rooms.count)
        let laneWidth = max(1, (width - timeColumnWidth) / CGFloat(laneCount))
        return ZStack(alignment: .topLeading) {
            theme.background

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
                        fontScale: fontScale,
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

private struct CourseBlockView: View {
    let model: AppModel
    let session: ClassSession
    let width: CGFloat
    let height: CGFloat
    let fontScale: Double
    let isSelected: Bool
    let hasConflict: Bool
    let select: () -> Void

    @State private var isShowingAttendancePreview = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let course = model.course(id: session.courseID)
        let courseType = course.flatMap { model.courseType(id: $0.courseTypeID) }
        let instructor = model.effectiveInstructor(for: session)
        let instructorIndex = instructor.flatMap { selectedInstructor in
            model.instructors.firstIndex(where: { $0.id == selectedInstructor.id })
        } ?? 11
        let backgroundColor = theme.scheduleBlockBackground(index: instructorIndex)
        let borderColor = theme.scheduleBlockBorder(index: instructorIndex)
        let textColor = theme.scheduleBlockText
        let fontSize = max(6, min(14, blockFontSize * CGFloat(fontScale)))
        let titleFontSize = min(15, fontSize + 1)
        let detailFontSize = max(6, fontSize - 1)
        let preview = CourseAttendancePreview(model: model, session: session)

        Button(action: select) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: height < 58 ? 0 : 1) {
                    Text(course?.name ?? "课程")
                        .mdFont(size: titleFontSize, weight: .semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .padding(.trailing, 19)

                    Text((courseType?.name ?? "课程种类").uppercased())
                        .mdFont(size: detailFontSize, weight: .semibold, design: .monospaced)
                        .foregroundStyle(textColor.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Spacer(minLength: height < 58 ? 0 : 2)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(instructor?.displayName ?? "老师")
                                .mdFont(size: detailFontSize, weight: .medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.58)
                                .layoutPriority(1)
                            Spacer(minLength: 2)
                            Text(sessionTime)
                                .mdFont(size: detailFontSize, weight: .semibold, design: .monospaced)
                                .lineLimit(1)
                                .minimumScaleFactor(0.58)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            Text(instructor?.displayName ?? "老师")
                                .mdFont(size: detailFontSize, weight: .medium)
                            Text(sessionTime)
                                .mdFont(size: detailFontSize, weight: .semibold, design: .monospaced)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    }
                    .foregroundStyle(textColor.opacity(0.9))
                }
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 5)

                Text(course?.format == .privateLesson ? "私" : "组")
                    .mdFont(size: 8, weight: .semibold)
                    .foregroundStyle(textColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(textColor.opacity(0.78), lineWidth: 1))
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
                backgroundColor,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? theme.accent : borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(
                color: isShowingAttendancePreview ? borderColor.opacity(colorScheme == .dark ? 0.42 : 0.24) : .clear,
                radius: 5,
                y: 2
            )
            .scaleEffect(isShowingAttendancePreview ? 1.012 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isShowingAttendancePreview)
        .onHover { isShowingAttendancePreview = $0 }
        .popover(
            isPresented: $isShowingAttendancePreview,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            CourseAttendanceHoverCard(preview: preview)
        }
        .accessibilityHint(hoverText)
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
        let courseType = course.flatMap { model.courseType(id: $0.courseTypeID) }?.name ?? ""
        let age = course.flatMap { model.ageGroup(id: $0.ageGroupID) }?.name ?? ""
        let room = model.effectiveRoom(for: session)?.name ?? ""
        let roster = model.enrollments(forCourse: session.courseID).compactMap { model.student(id: $0.studentID)?.displayName }
        return [course?.name ?? "课程", courseType, age, room, sessionTime, roster.joined(separator: "、")]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
#endif
