#if os(macOS)
import AppKit
import Foundation
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseSheetView: View {
    let model: AppModel
    let selectedTermID: TermID?
    let searchText: String
    let edit: (Course) -> Void
    let duplicate: (Course) -> Void
    let delete: (Course) -> Void

    @SceneStorage("md-desk.courses.sort-column") private var sortColumnStorage = ""
    @SceneStorage("md-desk.courses.sort-ascending") private var sortAscending = true
    @SceneStorage("md-desk.courses.name-filter") private var courseNameFilter = ""
    @SceneStorage("md-desk.courses.column-filters") private var selectedFilterValuesStorage = ""
    @State private var activeFilterColumn: CourseTableColumn?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mdInterfaceFontScale) private var interfaceFontScale

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let allEntries = entries
        let visibleEntries = displayedEntries(from: allEntries)
        GeometryReader { proxy in
            let layout = columnLayout(for: allEntries, availableWidth: proxy.size.width)
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    courseHeader(
                        theme: theme,
                        entries: allEntries,
                        displayedCount: visibleEntries.count,
                        layout: layout
                    )
                    ScrollView(.vertical) {
                        if visibleEntries.isEmpty {
                            ContentUnavailableView(
                                allEntries.isEmpty ? "暂无课程" : "没有符合条件的课程",
                                systemImage: allEntries.isEmpty ? "books.vertical" : "line.3.horizontal.decrease.circle"
                            )
                            .frame(maxWidth: .infinity, minHeight: 260)
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(visibleEntries) { entry in
                                    courseRow(entry, theme: theme, layout: layout)
                                    Rectangle()
                                        .fill(theme.faintSeparator)
                                        .frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .frame(width: layout.totalWidth, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .foregroundStyle(theme.primaryText)
    }

    private func courseHeader(
        theme: MDTheme,
        entries: [CourseTableEntry],
        displayedCount: Int,
        layout: CourseTableLayout
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(CourseTableColumn.allCases) { column in
                sortableHeaderCell(
                    column,
                    width: layout[column],
                    entries: entries,
                    theme: theme
                )
            }
            operationHeader(
                theme: theme,
                displayedCount: displayedCount,
                totalCount: entries.count,
                width: layout.operationWidth
            )
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.separator).frame(height: 1)
        }
    }

    private func sortableHeaderCell(
        _ column: CourseTableColumn,
        width: CGFloat,
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
        .frame(width: width)
    }

    private func operationHeader(
        theme: MDTheme,
        displayedCount: Int,
        totalCount: Int,
        width: CGFloat
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
        .frame(width: width)
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

    private func courseRow(
        _ entry: CourseTableEntry,
        theme: MDTheme,
        layout: CourseTableLayout
    ) -> some View {
        HStack(spacing: 0) {
            dataCell(entry.course.name, width: layout[.name], strong: true)
            dataCell(entry.termName, width: layout[.term])
            dataCell(entry.ageGroupName, width: layout[.ageGroup])
            dataCell(entry.roomName, width: layout[.room])
            dataCell(entry.instructorName, width: layout[.instructor])
            dataCell(entry.scheduleLabel, width: layout[.schedule])
            dataCell("\(entry.sessionCount)", width: layout[.sessions], monospaced: true)
            dataCell(entry.pricingLabel, width: layout[.pricing], monospaced: true)
            courseTypeCell(entry, width: layout[.courseType], theme: theme)
            conflictCell(entry, width: layout[.conflict], theme: theme)
            dataCell(entry.statusLabel, width: layout[.status])
            HStack(spacing: 3) {
                Button {
                    edit(entry.course)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑")
                Button {
                    duplicate(entry.course)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("复制并编辑")
                Button {
                    delete(entry.course)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("删除")
            }
            .frame(width: layout.operationWidth)
        }
        .frame(minHeight: 38)
        .background(
            entry.hasConflict
                ? theme.danger.opacity(colorScheme == .dark ? 0.10 : 0.055)
                : Color.clear
        )
        .contentShape(Rectangle())
        .help(entry.course.notes ?? "")
        .contextMenu {
            Button("编辑课程") { edit(entry.course) }
            Button("复制并编辑") { duplicate(entry.course) }
            Divider()
            Button("删除课程", role: .destructive) { delete(entry.course) }
        }
    }

    private func conflictCell(
        _ entry: CourseTableEntry,
        width: CGFloat,
        theme: MDTheme
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: entry.hasConflict ? "exclamationmark.triangle.fill" : "checkmark.circle")
            Text(entry.conflictLabel)
                .lineLimit(1)
        }
        .mdFont(.compactStrong)
        .foregroundStyle(entry.hasConflict ? theme.danger : theme.secondaryText)
        .padding(.horizontal, 10)
        .frame(width: width, alignment: .leading)
        .help(conflictHelp(for: entry))
    }

    private func conflictHelp(for entry: CourseTableEntry) -> String {
        guard entry.hasConflict else { return "没有发现教室或老师的时间冲突" }
        let details = entry.conflicts.map { conflict in
            let courseName = model.course(id: conflict.conflictingCourseID)?.name ?? "其他课程"
            var reasons: [String] = []
            if conflict.resources.contains(.room) { reasons.append("教室") }
            if conflict.resources.contains(.instructor) { reasons.append("老师") }
            return "与“\(courseName)”重叠 \(conflict.overlappingSessionCount) 次（\(reasons.joined(separator: "、"))）"
        }
        return (["课程时间冲突"] + details).joined(separator: "\n")
    }

    private func courseTypeCell(
        _ entry: CourseTableEntry,
        width: CGFloat,
        theme: MDTheme
    ) -> some View {
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
        .frame(width: width, alignment: .leading)
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

    private func columnLayout(
        for entries: [CourseTableEntry],
        availableWidth: CGFloat
    ) -> CourseTableLayout {
        var widths = Dictionary(
            uniqueKeysWithValues: CourseTableColumn.allCases.map { column in
                (column, max(column.minimumWidth, headerWidth(for: column)))
            }
        )

        for entry in entries {
            for column in CourseTableColumn.allCases {
                widths[column] = max(widths[column, default: column.minimumWidth], contentWidth(entry, for: column))
            }
        }

        let operationWidth = max(102, ceil(102 * interfaceFontScale))
        let measuredWidth = widths.values.reduce(0, +) + operationWidth
        let extraWidth = max(0, availableWidth - measuredWidth)
        let stretchWeight = CourseTableColumn.allCases.reduce(0) { $0 + $1.stretchWeight }
        if extraWidth > 0, stretchWeight > 0 {
            for column in CourseTableColumn.allCases where column.stretchWeight > 0 {
                widths[column, default: column.minimumWidth] += extraWidth * column.stretchWeight / stretchWeight
            }
        }

        return CourseTableLayout(widths: widths, operationWidth: operationWidth)
    }

    private func headerWidth(for column: CourseTableColumn) -> CGFloat {
        measuredTextWidth(column.title, size: 11, weight: .semibold) + 50
    }

    private func contentWidth(_ entry: CourseTableEntry, for column: CourseTableColumn) -> CGFloat {
        switch column {
        case .name:
            measuredTextWidth(entry.course.name, size: 13, weight: .semibold) + 17
        case .term:
            measuredTextWidth(entry.termName, size: 13) + 17
        case .ageGroup:
            measuredTextWidth(entry.ageGroupName, size: 13) + 17
        case .room:
            measuredTextWidth(entry.roomName, size: 13) + 17
        case .instructor:
            measuredTextWidth(entry.instructorName, size: 13) + 17
        case .schedule:
            measuredTextWidth(entry.scheduleLabel, size: 13) + 17
        case .sessions:
            measuredTextWidth("\(entry.sessionCount)", size: 11, monospaced: true) + 17
        case .pricing:
            measuredTextWidth(entry.pricingLabel, size: 11, monospaced: true) + 17
        case .courseType:
            measuredTextWidth(entry.courseTypeName, size: 11) + 44
        case .conflict:
            measuredTextWidth(entry.conflictLabel, size: 11, weight: .semibold) + 34
        case .status:
            measuredTextWidth(entry.statusLabel, size: 13) + 17
        }
    }

    private func measuredTextWidth(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        monospaced: Bool = false
    ) -> CGFloat {
        let scaledSize = size * interfaceFontScale
        let font = monospaced
            ? NSFont.monospacedSystemFont(ofSize: scaledSize, weight: weight)
            : NSFont.systemFont(ofSize: scaledSize, weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private var entries: [CourseTableEntry] {
        let sessionsByCourse = Dictionary(grouping: model.sessions, by: \.courseID)
        let conflictsByCourse = CourseScheduleConflictDetector.conflicts(
            courses: model.courses,
            sessions: model.sessions
        )
        return model.courses
            .filter { selectedTermID == nil || $0.termID == selectedTermID }
            .map { course in
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
                conflicts: conflictsByCourse[course.id] ?? [],
                statusLabel: course.isActive ? "启用" : "停用",
                statusKey: course.isActive ? "active" : "inactive"
            )
        }
    }

    private func pricingLabel(_ course: Course, sessionCount: Int) -> String {
        if course.format.requiresPerSessionEnrollment {
            return switch course.pricingStatus {
            case .pending:
                "私课 · 按次待定"
            case .free:
                "私课 · 按次免费"
            case .reviewRequired:
                course.dropInUnitPriceCents.map {
                    "私课 · 按次 $\(MoneyTextParser.dollars(from: $0))/节 · 需复核"
                } ?? "私课 · 按次待复核"
            case .priced:
                course.dropInUnitPriceCents.map {
                    "私课 · 按次 $\(MoneyTextParser.dollars(from: $0))/节"
                } ?? "私课 · 按次待定"
            }
        }
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

    private var sortColumn: CourseTableColumn? {
        get { CourseTableColumn(rawValue: sortColumnStorage) }
        nonmutating set { sortColumnStorage = newValue?.rawValue ?? "" }
    }

    private var selectedFilterValues: [CourseTableColumn: Set<String>] {
        Dictionary(
            uniqueKeysWithValues: CourseTableColumn.allCases.compactMap { column in
                let values = MDTableFilterCodec.selection(
                    in: selectedFilterValuesStorage,
                    for: column.rawValue
                )
                return values.isEmpty ? nil : (column, values)
            }
        )
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
        var selected = MDTableFilterCodec.selection(
            in: selectedFilterValuesStorage,
            for: column.rawValue
        )
        if selected.contains(value) {
            selected.remove(value)
        } else {
            selected.insert(value)
        }
        selectedFilterValuesStorage = MDTableFilterCodec.updating(
            selected,
            in: selectedFilterValuesStorage,
            for: column.rawValue
        )
    }

    private func clearFilter(for column: CourseTableColumn) {
        if column == .name {
            courseNameFilter = ""
        } else {
            selectedFilterValuesStorage = MDTableFilterCodec.clearing(
                column.rawValue,
                in: selectedFilterValuesStorage
            )
        }
    }

    private func clearAllFilters() {
        courseNameFilter = ""
        selectedFilterValuesStorage = MDTableFilterCodec.removeAll(from: selectedFilterValuesStorage)
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
    case term
    case ageGroup
    case room
    case instructor
    case schedule
    case sessions
    case pricing
    case courseType
    case conflict
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "课程名称"
        case .term: "学期"
        case .ageGroup: "年龄段"
        case .room: "教室"
        case .instructor: "老师"
        case .schedule: "每周时间"
        case .sessions: "课次"
        case .pricing: "课程费用"
        case .courseType: "课程种类"
        case .conflict: "排课检查"
        case .status: "状态"
        }
    }

    var minimumWidth: CGFloat {
        switch self {
        case .name: 140
        case .term: 120
        case .ageGroup: 90
        case .room: 75
        case .instructor: 85
        case .schedule: 145
        case .sessions: 68
        case .pricing: 120
        case .courseType: 100
        case .conflict: 105
        case .status: 68
        }
    }

    var stretchWeight: CGFloat {
        switch self {
        case .name: 1.4
        case .term: 0.7
        case .schedule: 1
        case .pricing: 1.5
        case .courseType: 0.8
        case .ageGroup, .room, .instructor, .sessions, .conflict, .status: 0
        }
    }
}

private struct CourseTableLayout {
    let widths: [CourseTableColumn: CGFloat]
    let operationWidth: CGFloat

    subscript(column: CourseTableColumn) -> CGFloat {
        widths[column, default: column.minimumWidth]
    }

    var totalWidth: CGFloat {
        widths.values.reduce(0, +) + operationWidth
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
    let conflicts: [CourseScheduleConflict]
    let statusLabel: String
    let statusKey: String

    var id: CourseID { course.id }

    var hasConflict: Bool { !conflicts.isEmpty }

    var conflictOccurrenceCount: Int {
        conflicts.reduce(0) { $0 + $1.overlappingSessionCount }
    }

    var conflictLabel: String {
        hasConflict ? "冲突 \(conflictOccurrenceCount) 次" : "正常"
    }

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
            conflictLabel,
            statusLabel
        ]
    }

    func filterKey(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .term: course.termID.description
        case .ageGroup: ageGroupKey
        case .room: roomKey
        case .instructor: instructorKey
        case .schedule: scheduleKey
        case .sessions: String(sessionCount)
        case .pricing: pricingKey
        case .courseType: courseTypeKey
        case .conflict: hasConflict ? "conflict" : "clear"
        case .status: statusKey
        }
    }

    func filterLabel(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .term: termName
        case .ageGroup: ageGroupName
        case .room: roomName
        case .instructor: instructorName
        case .schedule: scheduleLabel
        case .sessions: "\(sessionCount) 节"
        case .pricing: pricingLabel
        case .courseType: courseTypeFilterLabel
        case .conflict: hasConflict ? "有冲突" : "正常"
        case .status: statusLabel
        }
    }

    func sortValue(for column: CourseTableColumn) -> String {
        switch column {
        case .name: course.name
        case .term: termName
        case .ageGroup: ageGroupName
        case .room: roomName
        case .instructor: instructorName
        case .schedule: scheduleLabel
        case .sessions: String(sessionCount)
        case .pricing: pricingSortValue
        case .courseType: courseTypeFilterLabel
        case .conflict: String(format: "%08d", conflictOccurrenceCount)
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
