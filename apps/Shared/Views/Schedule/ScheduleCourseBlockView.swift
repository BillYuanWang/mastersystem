#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseBlockView: View {
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
        let ageGroup = course.flatMap { model.ageGroup(id: $0.ageGroupID) }
        let instructor = model.effectiveInstructor(for: session)
        let instructorIndex = instructor.flatMap { selectedInstructor in
            model.instructors.firstIndex(where: { $0.id == selectedInstructor.id })
        } ?? 11
        let backgroundColor = theme.scheduleBlockBackground(index: instructorIndex)
        let borderColor = theme.scheduleBlockBorder(index: instructorIndex)
        let textColor = theme.scheduleBlockText
        let preview = CourseAttendancePreview(model: model, session: session)

        Button(action: select) {
            ZStack(alignment: .bottomTrailing) {
                if usesVerticalLayout {
                    verticalContent(
                        courseName: course?.name ?? "课程",
                        courseTypeName: courseType?.name ?? "课程种类",
                        ageGroupName: ageGroup?.name ?? "年龄未设置",
                        instructorName: instructor?.displayName ?? "老师",
                        isPrivateLesson: course?.format == .privateLesson,
                        textColor: textColor
                    )
                } else {
                    wideContent(
                        courseName: course?.name ?? "课程",
                        courseTypeName: courseType?.name ?? "课程种类",
                        ageGroupName: ageGroup?.name ?? "年龄未设置",
                        instructorName: instructor?.displayName ?? "老师",
                        isPrivateLesson: course?.format == .privateLesson,
                        textColor: textColor
                    )
                }

                if hasConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: usesVerticalLayout ? 8 : 10))
                        .foregroundStyle(theme.warning)
                        .padding(usesVerticalLayout ? 3 : 5)
                }
            }
            .frame(width: width, height: height)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 5))
            .clipShape(RoundedRectangle(cornerRadius: 5))
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

    private func verticalContent(
        courseName: String,
        courseTypeName: String,
        ageGroupName: String,
        instructorName: String,
        isPrivateLesson: Bool,
        textColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: height < 62 ? 0 : 1) {
            HStack(spacing: 2) {
                Text(verticalMetadata(courseTypeName: courseTypeName, ageGroupName: ageGroupName))
                    .mdFont(size: labelFontSize, weight: .semibold, design: .monospaced)
                    .foregroundStyle(textColor.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .layoutPriority(1)

                Spacer(minLength: 1)

                formatBadge(
                    isPrivateLesson: isPrivateLesson,
                    size: 14,
                    fontSize: 7,
                    textColor: textColor
                )
            }
            .frame(height: 14)

            Text(courseName)
                .mdFont(size: titleFontSize, weight: .bold)
                .foregroundStyle(textColor)
                .lineLimit(verticalTitleLineLimit)
                .minimumScaleFactor(0.84)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)

            if height >= 62 {
                ageBadge(ageGroupName, textColor: textColor)
                    .layoutPriority(1)
            }

            Spacer(minLength: 0)

            if height >= 70 {
                Text(instructorName)
                    .mdFont(size: detailFontSize, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(compactSessionTime)
                    .mdFont(size: detailFontSize, weight: .semibold, design: .monospaced)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } else {
                Text("\(instructorName) · \(compactSessionTime)")
                    .mdFont(size: detailFontSize, weight: .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(textColor.opacity(0.92))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 4)
        .padding(.vertical, height < 54 ? 2 : 4)
    }

    private func wideContent(
        courseName: String,
        courseTypeName: String,
        ageGroupName: String,
        instructorName: String,
        isPrivateLesson: Bool,
        textColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: height < 58 ? 0 : 1) {
            HStack(alignment: .top, spacing: 4) {
                Text(courseName)
                    .mdFont(size: titleFontSize, weight: .bold)
                    .lineLimit(height >= 68 ? 2 : 1)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(2)

                formatBadge(
                    isPrivateLesson: isPrivateLesson,
                    size: 16,
                    fontSize: 8,
                    textColor: textColor
                )
            }

            HStack(spacing: 4) {
                Text(courseTypeName.uppercased())
                    .mdFont(size: labelFontSize, weight: .semibold, design: .monospaced)
                    .foregroundStyle(textColor.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .layoutPriority(1)

                ageBadge(ageGroupName, textColor: textColor)
                    .layoutPriority(2)

                Spacer(minLength: 0)
            }

            Spacer(minLength: height < 58 ? 0 : 2)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(instructorName)
                    .mdFont(size: detailFontSize, weight: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 2)

                Text(compactSessionTime)
                    .mdFont(size: detailFontSize, weight: .semibold, design: .monospaced)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(textColor.opacity(0.92))
        }
        .foregroundStyle(textColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
    }

    private func formatBadge(
        isPrivateLesson: Bool,
        size: CGFloat,
        fontSize: CGFloat,
        textColor: Color
    ) -> some View {
        Text(isPrivateLesson ? "私" : "组")
            .mdFont(size: fontSize, weight: .semibold)
            .foregroundStyle(textColor)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(textColor.opacity(0.78), lineWidth: 1))
            .accessibilityLabel(isPrivateLesson ? "私课" : "组课")
    }

    private func ageBadge(_ ageGroupName: String, textColor: Color) -> some View {
        Text(ageGroupName)
            .mdFont(size: labelFontSize, weight: .semibold)
            .foregroundStyle(textColor.opacity(0.9))
            .lineLimit(1)
            .minimumScaleFactor(0.62)
            .padding(.horizontal, 3)
            .frame(height: 13)
            .background(
                textColor.opacity(colorScheme == .dark ? 0.14 : 0.1),
                in: RoundedRectangle(cornerRadius: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(textColor.opacity(0.18), lineWidth: 0.5)
            )
            .accessibilityLabel("年龄段，\(ageGroupName)")
    }

    private func verticalMetadata(courseTypeName: String, ageGroupName: String) -> String {
        height >= 62
            ? courseTypeName.uppercased()
            : "\(courseTypeName.uppercased()) · \(ageGroupName)"
    }

    private var usesVerticalLayout: Bool {
        width < 84
    }

    private var verticalTitleLineLimit: Int {
        if height >= 84 { return 3 }
        if height >= 52 { return 2 }
        return 1
    }

    private var titleFontSize: CGFloat {
        let base: CGFloat = usesVerticalLayout ? 11.5 : 11
        return max(9.5, min(15, base + CGFloat(fontScale - 1) * 5))
    }

    private var detailFontSize: CGFloat {
        let base: CGFloat = usesVerticalLayout ? 8.5 : 9
        return max(7.5, min(12, base + CGFloat(fontScale - 1) * 3))
    }

    private var labelFontSize: CGFloat {
        let base: CGFloat = usesVerticalLayout ? 8 : 8.5
        return max(7, min(11, base + CGFloat(fontScale - 1) * 2.5))
    }

    private var compactSessionTime: String {
        "\(clockTime(session.startsAt))–\(clockTime(session.endsAt))"
    }

    private var fullSessionTime: String {
        "\(session.startsAt.formatted(date: .omitted, time: .shortened))–\(session.endsAt.formatted(date: .omitted, time: .shortened))"
    }

    private func clockTime(_ date: Date) -> String {
        let calendar = Calendar.masterDance
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", displayHour, minute)
    }

    private var hoverText: String {
        let course = model.course(id: session.courseID)
        let courseType = course.flatMap { model.courseType(id: $0.courseTypeID) }?.name ?? ""
        let age = course.flatMap { model.ageGroup(id: $0.ageGroupID) }?.name ?? ""
        let room = model.effectiveRoom(for: session)?.name ?? ""
        let roster = model.enrollments(forSession: session.id).compactMap {
            model.student(id: $0.studentID)?.displayName
        }
        return [course?.name ?? "课程", courseType, age, room, fullSessionTime, roster.joined(separator: "、")]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
#endif
