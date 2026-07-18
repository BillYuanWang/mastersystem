#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseEditorView: View {
    let model: AppModel

    @State private var draft = CourseCreationDraft()
    @State private var occurrenceCourseID = CourseID()
    @State private var didConfigure = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: "添加课程", english: "NEW COURSE")
                Spacer()
                Text("\(activeOccurrenceCount) 次课")
                    .font(MDType.monoStrong)
                    .foregroundStyle(theme.accent)
            }
            .padding(16)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        editorSection("课程资料", theme: theme) {
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                                GridRow {
                                    fieldLabel("课程名称")
                                    TextField("由你填写", text: $draft.name)
                                }
                                GridRow {
                                    fieldLabel("学期")
                                    Picker("", selection: $draft.termID) {
                                        ForEach(model.terms) { term in
                                            Text(term.name).tag(Optional(term.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("课程分类")
                                    Picker("", selection: $draft.categoryID) {
                                        ForEach(model.categories) { category in
                                            Text(category.name).tag(Optional(category.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("年龄段")
                                    Picker("", selection: $draft.ageGroupID) {
                                        ForEach(model.ageGroups) { ageGroup in
                                            Text(ageGroup.name).tag(Optional(ageGroup.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("教室")
                                    Picker("", selection: $draft.roomID) {
                                        ForEach(model.rooms) { room in
                                            Text(room.name).tag(Optional(room.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("授课老师")
                                    Picker("", selection: $draft.instructorID) {
                                        ForEach(model.instructors) { instructor in
                                            Text(instructor.displayName).tag(Optional(instructor.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("课程种类")
                                    Picker("", selection: $draft.courseTypeID) {
                                        ForEach(model.courseTypes) { courseType in
                                            Text(courseType.name).tag(Optional(courseType.id))
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                        }

                        editorSection("每周排课", theme: theme) {
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                                GridRow {
                                    fieldLabel("开始周")
                                    DatePicker("", selection: $draft.startsOn, displayedComponents: .date)
                                        .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("结束周")
                                    DatePicker("", selection: $draft.endsOn, displayedComponents: .date)
                                        .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("星期")
                                    Picker("", selection: $draft.weekday) {
                                        ForEach(weekdayOptions, id: \.0) { option in
                                            Text(option.1).tag(option.0)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                GridRow {
                                    fieldLabel("时间")
                                    HStack(spacing: 8) {
                                        DatePicker("", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                        Text("至")
                                            .font(MDType.compact)
                                            .foregroundStyle(theme.secondaryText)
                                        DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                }
                            }
                        }

                        editorSection("备注", theme: theme) {
                            TextField("选填", text: $draft.notes, axis: .vertical)
                                .lineLimit(3...5)
                        }
                    }
                    .padding(16)
                }
                .frame(width: 430)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("实际课次")
                                .font(MDType.bodyStrong)
                            Text("点击日期右上角的叉可移除休息周")
                                .font(MDType.compact)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        Text("\(activeOccurrenceCount)/\(occurrenceDates.count)")
                            .font(MDType.monoStrong)
                    }

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], spacing: 8) {
                            ForEach(occurrenceDates, id: \.self) { date in
                                occurrenceChip(date, theme: theme)
                            }
                        }
                    }

                    if occurrenceDates.isEmpty {
                        ContentUnavailableView(
                            "没有可生成的课次",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("请检查日期、星期和上课时间。")
                        )
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(MDType.compact)
                        .foregroundStyle(theme.danger)
                }
                Spacer()
                Button("取消") { dismiss() }
                Button("添加课程") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave || isSaving)
            }
            .padding(14)
        }
        .frame(width: 860, height: 680)
        .background(theme.background)
        .onAppear(perform: configureDraft)
        .onChange(of: draft.termID) { _, newValue in
            guard let newValue, let term = model.term(id: newValue) else { return }
            draft.startsOn = term.startsOn
            draft.endsOn = term.endsOn
            draft.excludedDates.removeAll()
        }
    }

    private var occurrenceDates: [Date] {
        let plan = WeeklySessionPlan(
            courseID: occurrenceCourseID,
            startsOn: draft.startsOn,
            endsOn: draft.endsOn,
            weekday: draft.weekday,
            startTime: draft.startTime,
            endTime: draft.endTime
        )
        return (try? RecurringSessionBuilder.occurrenceDates(for: plan, calendar: .masterDance)) ?? []
    }

    private var activeOccurrenceCount: Int {
        occurrenceDates.filter {
            let date = Calendar.masterDance.startOfDay(for: $0)
            return !draft.excludedDates.contains(date) && !automaticHolidayDates.contains(date)
        }.count
    }

    private var automaticHolidayDates: Set<Date> {
        guard let termID = draft.termID else { return [] }
        let calendar = Calendar.masterDance
        return model.termHolidays
            .filter { $0.termID == termID }
            .reduce(into: Set<Date>()) { dates, holiday in
                var date = calendar.startOfDay(for: holiday.startsOn)
                let end = calendar.startOfDay(for: holiday.endsOn)
                while date <= end {
                    dates.insert(date)
                    guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                    date = next
                }
            }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.termID != nil
            && draft.categoryID != nil
            && draft.ageGroupID != nil
            && draft.roomID != nil
            && draft.instructorID != nil
            && draft.courseTypeID != nil
            && activeOccurrenceCount > 0
    }

    private var weekdayOptions: [(Int, String)] {
        [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]
    }

    private var startTimeBinding: Binding<Date> {
        timeBinding(\.startTime)
    }

    private var endTimeBinding: Binding<Date> {
        timeBinding(\.endTime)
    }

    private func timeBinding(_ keyPath: WritableKeyPath<CourseCreationDraft, SessionClockTime>) -> Binding<Date> {
        Binding(
            get: {
                let clock = draft[keyPath: keyPath]
                return Calendar.masterDance.date(
                    bySettingHour: clock.hour,
                    minute: clock.minute,
                    second: 0,
                    of: draft.startsOn
                ) ?? draft.startsOn
            },
            set: { date in
                draft[keyPath: keyPath] = SessionClockTime(
                    hour: Calendar.masterDance.component(.hour, from: date),
                    minute: Calendar.masterDance.component(.minute, from: date)
                )
            }
        )
    }

    @ViewBuilder
    private func editorSection<Content: View>(
        _ title: String,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(MDType.bodyStrong)
            content()
        }
        .padding(.bottom, 4)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(MDType.compact)
            .foregroundStyle(.secondary)
            .frame(width: 72, alignment: .leading)
    }

    private func occurrenceChip(_ date: Date, theme: MDTheme) -> some View {
        let normalized = Calendar.masterDance.startOfDay(for: date)
        let isHoliday = automaticHolidayDates.contains(normalized)
        let isExcluded = draft.excludedDates.contains(normalized) || isHoliday
        return Button {
            guard !isHoliday else { return }
            if isExcluded {
                draft.excludedDates.remove(normalized)
            } else {
                draft.excludedDates.insert(normalized)
            }
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(MDType.monoStrong)
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .font(MDType.compact)
                }
                Spacer(minLength: 2)
                Image(systemName: isHoliday ? "calendar.badge.exclamationmark" : (isExcluded ? "arrow.uturn.backward" : "xmark"))
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isExcluded ? theme.secondaryText : theme.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 44)
            .background(
                isExcluded ? theme.subtleSurface.opacity(0.55) : theme.raisedSurface,
                in: RoundedRectangle(cornerRadius: MDMetrics.radius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(isExcluded ? theme.faintSeparator : theme.separator, lineWidth: 1)
            )
            .opacity(isExcluded ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isHoliday)
        .help(isHoliday ? "学期假期，自动停课" : (isExcluded ? "恢复这一周" : "移除这一周"))
    }

    private func configureDraft() {
        guard !didConfigure else { return }
        didConfigure = true
        draft.termID = model.terms.first?.id
        draft.categoryID = model.categories.first?.id
        draft.ageGroupID = model.ageGroups.first?.id
        draft.roomID = model.rooms.first?.id
        draft.instructorID = model.instructors.first?.id
        draft.courseTypeID = model.courseTypes.first?.id
        if let term = model.terms.first {
            draft.startsOn = term.startsOn
            draft.endsOn = term.endsOn
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await model.createCourse(from: draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
#endif
