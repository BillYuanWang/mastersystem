#if os(macOS)
import Foundation
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseSheetView: View {
    let model: AppModel
    let searchText: String
    let edit: (Course) -> Void
    let delete: (Course) -> Void

    @State private var sortColumn: CourseTableColumn?
    @State private var sortAscending = true
    @State private var activeFilterColumn: CourseTableColumn?
    @State private var courseNameFilter = ""
    @State private var selectedFilterValues: [CourseTableColumn: Set<String>] = [:]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let allEntries = entries
        let visibleEntries = displayedEntries(from: allEntries)
        VStack(spacing: 0) {
            courseHeader(
                theme: theme,
                entries: allEntries,
                displayedCount: visibleEntries.count
            )
            ScrollView {
                if visibleEntries.isEmpty {
                    ContentUnavailableView(
                        allEntries.isEmpty ? "暂无课程" : "没有符合条件的课程",
                        systemImage: allEntries.isEmpty ? "books.vertical" : "line.3.horizontal.decrease.circle"
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleEntries) { entry in
                            courseRow(entry, theme: theme)
                            Rectangle()
                                .fill(theme.faintSeparator)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private func courseHeader(
        theme: MDTheme,
        entries: [CourseTableEntry],
        displayedCount: Int
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(CourseTableColumn.allCases) { column in
                sortableHeaderCell(column, entries: entries, theme: theme)
            }
            operationHeader(
                theme: theme,
                displayedCount: displayedCount,
                totalCount: entries.count
            )
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func sortableHeaderCell(
        _ column: CourseTableColumn,
        entries: [CourseTableEntry],
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 3) {
            Button {
                toggleSort(column)
            } label: {
                HStack(spacing: 3) {
                    Text(column.title)
                        .mdFont(.compactStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Image(systemName: sortSymbol(for: column))
                        .mdFont(size: 8, weight: .semibold)
                        .foregroundStyle(sortColumn == column ? theme.accent : theme.secondaryText.opacity(0.55))
                        .frame(width: 9)
                }
            }
            .buttonStyle(.plain)
            .help(sortHelp(for: column))

            Spacer(minLength: 0)

            Button {
                activeFilterColumn = column
            } label: {
                Image(systemName: isFilterActive(column)
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle")
                    .mdFont(size: 11, weight: .medium)
                    .foregroundStyle(isFilterActive(column) ? theme.accent : theme.secondaryText)
                    .frame(width: 16, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("筛选\(column.title)")
            .popover(isPresented: filterPopoverBinding(for: column), arrowEdge: .bottom) {
                filterPopover(for: column, entries: entries, theme: theme)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: column.width)
    }

    private func operationHeader(
        theme: MDTheme,
        displayedCount: Int,
        totalCount: Int
    ) -> some View {
        HStack(spacing: 5) {
            if activeFilterCount > 0 {
                Button {
                    clearAllFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .mdFont(size: 11, weight: .medium)
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help("清除全部列筛选")
            }

            Spacer(minLength: 0)

            Text(isNarrowed ? "\(displayedCount)/\(totalCount)" : "操作")
                .mdFont(isNarrowed ? .mono : .compactStrong)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(width: 70)
    }

    @ViewBuilder
    private func filterPopover(
        for column: CourseTableColumn,
        entries: [CourseTableEntry],
        theme: MDTheme
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("筛选 · \(column.title)")
                    .mdFont(.bodyStrong)
                Spacer()
                if isFilterActive(column) {
                    Button {
                        clearFilter(for: column)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(MDIconButtonStyle())
                    .help("清除此列筛选")
                }
            }

            Rectangle()
                .fill(theme.separator)
                .frame(height: 1)

            if column == .name {
                HStack(spacing: 6) {
                    TextField("输入课程名称", text: $courseNameFilter)
                        .textFieldStyle(.roundedBorder)
                        .mdFont(.compact)
                    if !trimmedCourseNameFilter.isEmpty {
                        Button {
                            courseNameFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(theme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .help("清空")
                    }
                }
            } else {
                let options = filterOptions(for: column, entries: entries)
                if options.isEmpty {
                    Text("暂无可选项")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(options) { option in
                                filterOptionRow(option, column: column, theme: theme)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
        }
        .padding(14)
        .frame(width: 270)
        .background(theme.raisedSurface)
    }

    private func filterOptionRow(
        _ option: CourseFilterOption,
        column: CourseTableColumn,
        theme: MDTheme
    ) -> some View {
        let selected = selectedFilterValues[column, default: []].contains(option.id)
        return Button {
            toggleFilterOption(option.id, for: column)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                    .frame(width: 16)
                Text(option.label)
                    .mdFont(.compact)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(option.count)")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 29, alignment: .leading)
            .background(
                selected ? theme.accent.opacity(colorScheme == .dark ? 0.15 : 0.09) : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func courseRow(_ entry: CourseTableEntry, theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            dataCell(entry.course.name, width: CourseTableColumn.name.width, strong: true)
            dataCell(entry.ageGroupName, width: CourseTableColumn.ageGroup.width)
            dataCell(entry.roomName, width: CourseTableColumn.room.width)
            dataCell(entry.instructorName, width: CourseTableColumn.instructor.width)
            dataCell(entry.scheduleLabel, width: CourseTableColumn.schedule.width)
            dataCell("\(entry.sessionCount)", width: CourseTableColumn.sessions.width, monospaced: true)
            dataCell(entry.pricingLabel, width: CourseTableColumn.pricing.width, monospaced: true)
            courseTypeCell(entry, theme: theme)
            dataCell(entry.statusLabel, width: CourseTableColumn.status.width)
            HStack(spacing: 3) {
                Button {
                    edit(entry.course)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑")
                Button {
                    delete(entry.course)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("删除")
            }
            .frame(width: 70)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 38)
        .contentShape(Rectangle())
        .help(entry.course.notes ?? "")
    }

    private func courseTypeCell(_ entry: CourseTableEntry, theme: MDTheme) -> some View {
        HStack(spacing: 6) {
            Text(entry.course.format == .privateLesson ? "私" : "组")
                .mdFont(.compactStrong)
                .frame(width: 21, height: 21)
                .overlay(Circle().stroke(theme.secondaryText, lineWidth: 1))
            Text(entry.courseTypeName)
                .mdFont(.compact)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .frame(width: CourseTableColumn.courseType.width, alignment: .leading)
    }

    private func dataCell(
        _ text: String,
        width: CGFloat,
        strong: Bool = false,
        monospaced: Bool = false
    ) -> some View {
        Text(text)
            .mdFont(monospaced ? .mono : (strong ? .bodyStrong : .body))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .frame(width: width, alignment: .leading)
    }

    private var entries: [CourseTableEntry] {
        let sessionsByCourse = Dictionary(grouping: model.sessions, by: \.courseID)
        return model.courses.map { course in
            let courseSessions = (sessionsByCourse[course.id] ?? []).sorted { $0.startsAt < $1.startsAt }
            let schedule = courseSessions.first.map(scheduleDetails)
            let typeName = model.courseType(id: course.courseTypeID)?.name ?? "—"
            let formatToken = course.format == .privateLesson ? "私" : "组"
            return CourseTableEntry(
                course: course,
                termName: model.term(id: course.termID)?.name ?? "—",
                ageGroupName: model.ageGroup(id: course.ageGroupID)?.name ?? "—",
                ageGroupKey: course.ageGroupID.description,
                roomName: model.room(id: course.defaultRoomID)?.name ?? "—",
                roomKey: course.defaultRoomID.description,
                instructorName: model.instructor(id: course.defaultInstructorID)?.displayName ?? "—",
                instructorKey: course.defaultInstructorID.description,
                scheduleLabel: schedule?.label ?? "未排课",
                scheduleKey: schedule?.key ?? "none",
                scheduleSortKey: schedule?.sortKey,
                sessionCount: courseSessions.count,
                pricingLabel: pricingLabel(course, sessionCount: courseSessions.count),
                pricingKey: course.pricingStatus.rawValue,
                pricingSortValue: String(format: "%012d", course.unitPriceCents ?? -1),
                courseTypeName: typeName,
                courseTypeKey: "\(course.courseTypeID.description)|\(course.format.rawValue)",
                courseTypeFilterLabel: "\(formatToken) · \(typeName)",
                statusLabel: course.isActive ? "启用" : "停用",
                statusKey: course.isActive ? "active" : "inactive"
            )
        }
    }

    private func pricingLabel(_ course: Course, sessionCount: Int) -> String {
        let dropIn = course.dropInUnitPriceCents.map {
            "按次 $\(MoneyTextParser.dollars(from: $0))"
        } ?? "按次待定"
        switch course.pricingStatus {
        case .pending:
            return "整期待定 · \(dropIn)"
        case .free:
            return "免费"
        case .reviewRequired:
            return course.unitPriceCents.map {
                "需复核 · 整期 $\(MoneyTextParser.dollars(from: $0)) · \(dropIn)"
            } ?? "需复核 · \(dropIn)"
        case .priced:
            guard let unit = course.unitPriceCents else { return "待定价" }
            let total = BillingCalculator.courseTotalCents(
                unitPriceCents: unit,
                scheduledSessionCount: sessionCount
            ) ?? 0
            return "整期 $\(MoneyTextParser.dollars(from: unit))/节 · \(dropIn) · 合计 $\(MoneyTextParser.dollars(from: total))"
        }
    }

    private func displayedEntries(from entries: [CourseTableEntry]) -> [CourseTableEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = entries.filter { entry in
            let matchesSearch = query.isEmpty || entry.searchValues.contains {
                $0.localizedCaseInsensitiveContains(query)
            }
            let matchesName = trimmedCourseNameFilter.isEmpty
                || entry.course.name.localizedCaseInsensitiveContains(trimmedCourseNameFilter)
            return matchesSearch && matchesName && matchesSelectedFilters(entry)
        }

        guard let sortColumn else { return result }
        result.sort { orderedBefore($0, $1, by: sortColumn) }
        return result
    }

    private var trimmedCourseNameFilter: String {
        courseNameFilter.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeFilterCount: Int {
        let selectedCount = selectedFilterValues.values.filter { !$0.isEmpty }.count
        return selectedCount + (trimmedCourseNameFilter.isEmpty ? 0 : 1)
    }

    private var isNarrowed: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || activeFilterCount > 0
    }

    private func matchesSelectedFilters(_ entry: CourseTableEntry) -> Bool {
        selectedFilterValues.allSatisfy { column, selectedValues in
            selectedValues.isEmpty || selectedValues.contains(entry.filterKey(for: column))
        }
    }

    private func filterOptions(
        for column: CourseTableColumn,
        entries: [CourseTableEntry]
    ) -> [CourseFilterOption] {
        var grouped: [String: CourseFilterOption] = [:]
        for entry in entries {
            let key = entry.filterKey(for: column)
            let label = entry.filterLabel(for: column)
            if let existing = grouped[key] {
                grouped[key] = CourseFilterOption(id: key, label: existing.label, count: existing.count + 1)
            } else {
                grouped[key] = CourseFilterOption(id: key, label: label, count: 1)
            }
        }
        return grouped.values.sorted {
            if column == .sessions {
                return (Int($0.id) ?? 0) < (Int($1.id) ?? 0)
            }
            if column == .schedule {
                return scheduleOptionSortKey($0.id) < scheduleOptionSortKey($1.id)
            }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    private func toggleSort(_ column: CourseTableColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
    }

    private func sortSymbol(for column: CourseTableColumn) -> String {
        guard sortColumn == column else { return "arrow.up.arrow.down" }
        return sortAscending ? "chevron.up" : "chevron.down"
    }

    private func sortHelp(for column: CourseTableColumn) -> String {
        guard sortColumn == column else { return "按\(column.title)升序排列" }
        return sortAscending ? "按\(column.title)降序排列" : "按\(column.title)升序排列"
    }

    private func orderedBefore(
        _ lhs: CourseTableEntry,
        _ rhs: CourseTableEntry,
        by column: CourseTableColumn
    ) -> Bool {
        if column == .schedule {
            switch (lhs.scheduleSortKey, rhs.scheduleSortKey) {
            case (nil, nil): break
            case (nil, _): return false
            case (_, nil): return true
            case let (left?, right?) where left != right:
                return sortAscending ? left < right : left > right
            default: break
            }
        }

        if column == .sessions, lhs.sessionCount != rhs.sessionCount {
            return sortAscending
                ? lhs.sessionCount < rhs.sessionCount
                : lhs.sessionCount > rhs.sessionCount
        }

        let comparison = lhs.sortValue(for: column).localizedStandardCompare(rhs.sortValue(for: column))
        if comparison != .orderedSame {
            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        let nameComparison = lhs.course.name.localizedStandardCompare(rhs.course.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.id.description < rhs.id.description
    }

    private func isFilterActive(_ column: CourseTableColumn) -> Bool {
        if column == .name {
            return !trimmedCourseNameFilter.isEmpty
        }
        return !(selectedFilterValues[column] ?? []).isEmpty
    }

    private func toggleFilterOption(_ value: String, for column: CourseTableColumn) {
        var selected = selectedFilterValues[column] ?? []
        if selected.contains(value) {
            selected.remove(value)
        } else {
            selected.insert(value)
        }
        if selected.isEmpty {
            selectedFilterValues.removeValue(forKey: column)
        } else {
            selectedFilterValues[column] = selected
        }
    }

    private func clearFilter(for column: CourseTableColumn) {
        if column == .name {
            courseNameFilter = ""
        } else {
            selectedFilterValues.removeValue(forKey: column)
        }
    }

    private func clearAllFilters() {
        courseNameFilter = ""
        selectedFilterValues.removeAll()
    }

    private func filterPopoverBinding(for column: CourseTableColumn) -> Binding<Bool> {
        Binding(
            get: { activeFilterColumn == column },
            set: { isPresented in
                if isPresented {
                    activeFilterColumn = column
                } else if activeFilterColumn == column {
                    activeFilterColumn = nil
                }
            }
        )
    }

    private func scheduleDetails(_ session: ClassSession) -> (label: String, key: String, sortKey: Int) {
        let calendar = Calendar.masterDance
        let weekday = calendar.component(.weekday, from: session.startsAt)
        let startHour = calendar.component(.hour, from: session.startsAt)
        let startMinute = calendar.component(.minute, from: session.startsAt)
        let endHour = calendar.component(.hour, from: session.endsAt)
        let endMinute = calendar.component(.minute, from: session.endsAt)
        let weekdayIndex = (weekday + 5) % 7
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute
        let day = session.startsAt.formatted(.dateTime.weekday(.abbreviated))
        let start = session.startsAt.formatted(date: .omitted, time: .shortened)
        let end = session.endsAt.formatted(date: .omitted, time: .shortened)
        return (
            label: "\(day) \(start)–\(end)",
            key: "\(weekday)-\(startMinutes)-\(endMinutes)",
            sortKey: weekdayIndex * 1_440 + startMinutes
        )
    }

    private func scheduleOptionSortKey(_ key: String) -> Int {
        guard key != "none" else { return Int.max }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count >= 2 else { return Int.max - 1 }
        let weekdayIndex = (parts[0] + 5) % 7
        return weekdayIndex * 1_440 + parts[1]
    }
}

private enum CourseTableColumn: String, CaseIterable, Identifiable {
    case name
    case ageGroup
    case room
    case instructor
    case schedule
    case sessions
    case pricing
    case courseType
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "课程名称"
        case .ageGroup: "年龄段"
        case .room: "教室"
        case .instructor: "老师"
        case .schedule: "每周时间"
        case .sessions: "课次"
        case .pricing: "课程费用"
        case .courseType: "课程种类"
        case .status: "状态"
        }
    }

    var width: CGFloat {
        switch self {
        case .name: 205
        case .ageGroup: 115
        case .room: 100
        case .instructor: 110
        case .schedule: 180
        case .sessions: 70
        case .pricing: 175
        case .courseType: 120
        case .status: 70
        }
    }
}

private struct CourseTableEntry: Identifiable {
    let course: Course
    let termName: String
    let ageGroupName: String
    let ageGroupKey: String
    let roomName: String
    let roomKey: String
    let instructorName: String
    let instructorKey: String
    let scheduleLabel: String
    let scheduleKey: String
    let scheduleSortKey: Int?
    let sessionCount: Int
    let pricingLabel: String
    let pricingKey: String
    let pricingSortValue: String
    let courseTypeName: String
    let courseTypeKey: String
    let courseTypeFilterLabel: String
    let statusLabel: String
    let statusKey: String

    var id: CourseID { course.id }

    var searchValues: [String] {
        [
            course.name,
            termName,
            ageGroupName,
            roomName,
            instructorName,
            scheduleLabel,
            pricingLabel,
            courseTypeFilterLabel,
            statusLabel
        ]
    }

    func filterKey(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .ageGroup: ageGroupKey
        case .room: roomKey
        case .instructor: instructorKey
        case .schedule: scheduleKey
        case .sessions: String(sessionCount)
        case .pricing: pricingKey
        case .courseType: courseTypeKey
        case .status: statusKey
        }
    }

    func filterLabel(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .ageGroup: ageGroupName
        case .room: roomName
        case .instructor: instructorName
        case .schedule: scheduleLabel
        case .sessions: "\(sessionCount) 节"
        case .pricing: pricingLabel
        case .courseType: courseTypeFilterLabel
        case .status: statusLabel
        }
    }

    func sortValue(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .ageGroup: ageGroupName
        case .room: roomName
        case .instructor: instructorName
        case .schedule: scheduleLabel
        case .sessions: String(sessionCount)
        case .pricing: pricingSortValue
        case .courseType: courseTypeFilterLabel
        case .status: statusLabel
        }
    }
}

private struct CourseFilterOption: Identifiable {
    let id: String
    let label: String
    let count: Int
}
#endif
