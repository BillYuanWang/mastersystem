#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseEditorView: View {
    let model: AppModel
    let original: Course?

    @State private var draft = CourseCreationDraft()
    @State private var occurrenceCourseID: CourseID
    @State private var didConfigure = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, course: Course? = nil) {
        self.model = model
        original = course
        _occurrenceCourseID = State(initialValue: course?.id ?? CourseID())
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(
                    chinese: original == nil ? "添加课程" : "编辑课程",
                    english: original == nil ? "NEW COURSE" : "EDIT COURSE"
                )
                Spacer()
                Text("\(activeOccurrenceCount) 次课")
                    .mdFont(.monoStrong)
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
                                        .frame(minWidth: 280)
                                }
                                GridRow {
                                    fieldLabel("学期")
                                    Picker("", selection: $draft.termID) {
                                        ForEach(model.terms) { term in
                                            Text(term.name).tag(Optional(term.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }
                                GridRow {
                                    fieldLabel("年龄段")
                                    Picker("", selection: $draft.ageGroupID) {
                                        ForEach(model.ageGroups) { ageGroup in
                                            Text(ageGroup.name).tag(Optional(ageGroup.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }
                                GridRow {
                                    fieldLabel("教室")
                                    Picker("", selection: $draft.roomID) {
                                        ForEach(model.rooms) { room in
                                            Text(room.name).tag(Optional(room.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }
                                GridRow {
                                    fieldLabel("授课老师")
                                    Picker("", selection: $draft.instructorID) {
                                        ForEach(model.instructors) { instructor in
                                            Text(instructor.displayName).tag(Optional(instructor.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }
                                GridRow {
                                    fieldLabel("课程种类")
                                    Picker("", selection: $draft.courseTypeID) {
                                        ForEach(model.courseTypes) { courseType in
                                            Text(courseType.name).tag(Optional(courseType.id))
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }
                                GridRow {
                                    fieldLabel("课程状态")
                                    Toggle("启用课程", isOn: $draft.isActive)
                                        .toggleStyle(.switch)
                                }
                            }

                            if draft.termID != nil, !courseTermIsReady {
                                Label("请先在数据中心为这个学期添加假期", systemImage: "calendar.badge.exclamationmark")
                                    .mdFont(.compact)
                                    .foregroundStyle(theme.danger)
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
                                            .mdFont(.compact)
                                            .foregroundStyle(theme.secondaryText)
                                        DatePicker("", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                }
                            }
                        }

                        editorSection("课程定价", theme: theme) {
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                                GridRow {
                                    fieldLabel("定价状态")
                                    Picker("", selection: $draft.pricingStatus) {
                                        ForEach(CoursePricingStatus.allCases, id: \.self) { status in
                                            Text(pricingStatusTitle(status)).tag(status)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(minWidth: 280, alignment: .leading)
                                }

                                if draft.pricingStatus == .priced || draft.pricingStatus == .reviewRequired {
                                    GridRow {
                                        fieldLabel("每节单价")
                                        HStack(spacing: 7) {
                                            Text("$")
                                                .mdFont(.monoStrong)
                                                .foregroundStyle(theme.secondaryText)
                                            TextField("例如 25.00", text: $draft.unitPriceText)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 150)
                                        }
                                    }
                                }

                                GridRow {
                                    fieldLabel("学期估算")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(coursePriceSummary)
                                            .mdFont(.monoStrong)
                                            .foregroundStyle(priceIsValid ? theme.primaryText : theme.danger)
                                        Text("按当前实际课次计算；报名后会保存学员自己的价格快照。")
                                            .mdFont(.compact)
                                            .foregroundStyle(theme.secondaryText)
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
                .frame(width: 480)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("实际课次")
                                .mdFont(.bodyStrong)
                            Text("点击日期右上角的叉可移除休息周")
                                .mdFont(.compact)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        Text("\(activeOccurrenceCount)/\(occurrenceDates.count)")
                            .mdFont(.monoStrong)
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
                Spacer()
                Button("取消") { dismiss() }
                Button(original == nil ? "添加课程" : "保存修改") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(14)
        }
        .frame(width: 980, height: 700)
        .background(theme.background)
        .onAppear(perform: configureDraft)
        .onChange(of: draft.termID) { oldValue, newValue in
            guard didConfigure, oldValue != nil, oldValue != newValue else { return }
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
            && draft.ageGroupID != nil
            && draft.roomID != nil
            && draft.instructorID != nil
            && draft.courseTypeID != nil
            && courseTermIsReady
            && activeOccurrenceCount > 0
            && priceIsValid
    }

    private var courseTermIsReady: Bool {
        guard let termID = draft.termID else { return false }
        if let original, original.termID == termID { return true }
        return model.termHolidays.contains { $0.termID == termID }
    }

    private var weekdayOptions: [(Int, String)] {
        [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]
    }

    private var priceIsValid: Bool {
        switch draft.pricingStatus {
        case .pending, .free:
            true
        case .priced:
            (MoneyTextParser.cents(from: draft.unitPriceText) ?? 0) > 0
        case .reviewRequired:
            draft.unitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (MoneyTextParser.cents(from: draft.unitPriceText) ?? -1) >= 0
        }
    }

    private var coursePriceSummary: String {
        switch draft.pricingStatus {
        case .pending:
            return "待定价"
        case .free:
            return "\(activeOccurrenceCount) 次 · 免费"
        case .priced, .reviewRequired:
            guard let cents = MoneyTextParser.cents(from: draft.unitPriceText), cents >= 0 else {
                return "请输入正确单价"
            }
            let total = BillingCalculator.courseTotalCents(
                unitPriceCents: cents,
                scheduledSessionCount: activeOccurrenceCount
            ) ?? 0
            return "\(activeOccurrenceCount) 次 × $\(MoneyTextParser.dollars(from: cents)) = $\(MoneyTextParser.dollars(from: total))"
        }
    }

    private func pricingStatusTitle(_ status: CoursePricingStatus) -> String {
        switch status {
        case .pending: "待定价"
        case .priced: "已定价"
        case .free: "免费"
        case .reviewRequired: "需复核"
        }
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
                .mdFont(.bodyStrong)
            content()
        }
        .padding(.bottom, 4)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .mdFont(.compact)
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
                        .mdFont(.monoStrong)
                    Text(date.formatted(.dateTime.weekday(.wide)))
                        .mdFont(.compact)
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
        if let original {
            draft.name = original.name
            draft.termID = original.termID
            draft.ageGroupID = original.ageGroupID
            draft.roomID = original.defaultRoomID
            draft.instructorID = original.defaultInstructorID
            draft.courseTypeID = original.courseTypeID
            draft.pricingStatus = original.pricingStatus
            draft.unitPriceText = MoneyTextParser.dollars(from: original.unitPriceCents)
            draft.notes = original.notes ?? ""
            draft.isActive = original.isActive

            let existingSessions = model.sessions(forCourse: original.id)
            if let first = existingSessions.first, let last = existingSessions.last {
                let calendar = Calendar.masterDance
                draft.startsOn = calendar.startOfDay(for: first.startsAt)
                draft.endsOn = calendar.startOfDay(for: last.startsAt)
                draft.weekday = calendar.component(.weekday, from: first.startsAt)
                draft.startTime = SessionClockTime(
                    hour: calendar.component(.hour, from: first.startsAt),
                    minute: calendar.component(.minute, from: first.startsAt)
                )
                draft.endTime = SessionClockTime(
                    hour: calendar.component(.hour, from: first.endsAt),
                    minute: calendar.component(.minute, from: first.endsAt)
                )
                let existingDates = Set(existingSessions.map { calendar.startOfDay(for: $0.startsAt) })
                draft.excludedDates = Set(occurrenceDates.map(calendar.startOfDay(for:)).filter {
                    !existingDates.contains($0)
                })
            } else if let term = model.term(id: original.termID) {
                draft.startsOn = term.startsOn
                draft.endsOn = term.endsOn
            }
        } else {
            let initialTerm = model.terms.first { term in
                model.termHolidays.contains { $0.termID == term.id }
            } ?? model.terms.first
            draft.termID = initialTerm?.id
            draft.ageGroupID = model.ageGroups.first?.id
            draft.roomID = model.rooms.first?.id
            draft.instructorID = model.instructors.first?.id
            draft.courseTypeID = model.courseTypes.first?.id
            if let term = initialTerm {
                draft.startsOn = term.startsOn
                draft.endsOn = term.endsOn
            }
        }
    }

    private func save() {
        let draftSnapshot = draft
        let courseSnapshot = original
        let isCreating = courseSnapshot == nil
        model.performBackgroundOperation(
            label: isCreating ? "创建课程" : "更新课程",
            successMessage: isCreating ? "课程已创建" : "课程已更新"
        ) {
            if let courseSnapshot {
                try await model.updateCourse(courseSnapshot, from: draftSnapshot)
            } else {
                try await model.createCourse(from: draftSnapshot)
            }
        }
        dismiss()
    }
}
#endif
