#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct CourseEditorView: View {
    let model: AppModel
    let original: Course?
    let duplicateSource: Course?
    let initialTermID: TermID?

    @State private var draft = CourseCreationDraft()
    @State private var occurrenceCourseID: CourseID
    @State private var didConfigure = false
    @State private var confirmingScheduleChange = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    init(
        model: AppModel,
        course: Course? = nil,
        duplicateOf duplicateSource: Course? = nil,
        initialTermID: TermID? = nil
    ) {
        self.model = model
        original = course
        self.duplicateSource = duplicateSource
        self.initialTermID = initialTermID
        _occurrenceCourseID = State(initialValue: course?.id ?? CourseID())
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(
                    chinese: editorTitle,
                    english: editorEnglishTitle
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

                        editorSection(original == nil ? "每周排课" : "批量调整课次", theme: theme) {
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
                            if original != nil {
                                Button("应用到所选日期区间") {
                                    draft.existingSessions = CourseSessionEditing.moving(
                                        draft.existingSessions ?? [], from: draft.startsOn, through: draft.endsOn,
                                        weekday: draft.weekday, startTime: draft.startTime, endTime: draft.endTime,
                                        calendar: .masterDance
                                    )
                                }
                                .disabled(draft.startsOn > draft.endsOn)
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
                                    if draftIsPrivateLesson {
                                        GridRow {
                                            fieldLabel("私课按次价")
                                            HStack(spacing: 7) {
                                                Text("$")
                                                    .mdFont(.monoStrong)
                                                    .foregroundStyle(theme.secondaryText)
                                                TextField("例如 80.00", text: $draft.dropInUnitPriceText)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(width: 150)
                                                Text("私课仅按所选课次报名")
                                                    .mdFont(.compact)
                                                    .foregroundStyle(theme.secondaryText)
                                            }
                                        }
                                    } else {
                                        GridRow {
                                            fieldLabel("整期每节价")
                                            HStack(spacing: 7) {
                                                Text("$")
                                                    .mdFont(.monoStrong)
                                                    .foregroundStyle(theme.secondaryText)
                                                TextField("例如 25.00", text: $draft.unitPriceText)
                                                    .textFieldStyle(.roundedBorder)
                                                    .frame(width: 150)
                                            }
                                        }

                                        GridRow {
                                            fieldLabel("按次每节价")
                                            HStack(spacing: 7) {
                                                Text("$")
                                                    .mdFont(.monoStrong)
                                                    .foregroundStyle(theme.secondaryText)
                                                Text(derivedGroupDropInPriceText ?? "—")
                                                    .mdFont(.monoStrong)
                                                    .frame(width: 150, alignment: .leading)
                                                Text(derivedGroupDropInPriceText == nil
                                                    ? "整期单价确定后自动生成"
                                                    : "固定为整期单价 + $5/节")
                                                    .mdFont(.compact)
                                                    .foregroundStyle(theme.secondaryText)
                                            }
                                        }
                                    }
                                }

                                GridRow {
                                    fieldLabel("学期估算")
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(coursePriceSummary)
                                            .mdFont(.monoStrong)
                                            .foregroundStyle(priceIsValid ? theme.primaryText : theme.danger)
                                        Text(draftIsPrivateLesson
                                            ? "私课只按报名时选择的具体课次计算，并保存当时的单价快照。"
                                            : "整期价按实际课次计算；按次价按所选日期计算。报名后均保存价格快照。")
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
                            Text(original == nil ? "点击日期右上角的叉可移除休息周" : "已排定的每一次课；修改资料不会重新生成课次")
                                .mdFont(.compact)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        Text("\(activeOccurrenceCount)/\(draft.existingSessions?.count ?? occurrenceDates.count)")
                            .mdFont(.monoStrong)
                    }

                    if original != nil {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(Array((draft.existingSessions ?? []).indices), id: \.self) { index in
                                    existingSessionRow(index, theme: theme)
                                    Divider()
                                }
                            }
                        }
                        if let scheduleError {
                            Text(scheduleError).mdFont(.compact).foregroundStyle(theme.danger)
                        }
                    } else {
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
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button(saveButtonTitle) {
                    if hasSessionChanges { confirmingScheduleChange = true } else { save() }
                }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(14)
        }
        .frame(width: 980, height: 700)
        .background(theme.background)
        .confirmationDialog("确认修改实际课次？", isPresented: $confirmingScheduleChange) {
            Button("保存排课修改") { save() }
        } message: {
            Text("报名和签到将继续关联原课次；已签发账单与收据保留原安排，不会被改写。")
        }
        .onAppear(perform: configureDraft)
        .onChange(of: draft.termID) { oldValue, newValue in
            guard didConfigure, oldValue != nil, oldValue != newValue else { return }
            guard let newValue, let term = model.term(id: newValue) else { return }
            draft.startsOn = term.startsOn
            draft.endsOn = term.endsOn
            draft.excludedDates.removeAll()
        }
        .onChange(of: draft.courseTypeID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            alignPricingFieldsForCourseType()
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
        if let sessions = draft.existingSessions {
            return sessions.filter { $0.status != .cancelled }.count
        }
        return occurrenceDates.filter {
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
            && scheduleError == nil
    }

    private var courseTermIsReady: Bool {
        guard let termID = draft.termID else { return false }
        if let original, original.termID == termID { return true }
        return model.termHolidays.contains { $0.termID == termID }
    }

    private var draftIsPrivateLesson: Bool {
        guard let courseTypeID = draft.courseTypeID else { return false }
        return model.courseType(id: courseTypeID)?.isPrivate == true
    }

    private var weekdayOptions: [(Int, String)] {
        [(2, "周一"), (3, "周二"), (4, "周三"), (5, "周四"), (6, "周五"), (7, "周六"), (1, "周日")]
    }

    private var priceIsValid: Bool {
        let dropInText = draft.dropInUnitPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if draftIsPrivateLesson {
            return switch draft.pricingStatus {
            case .pending, .free:
                true
            case .priced:
                (MoneyTextParser.cents(from: dropInText) ?? 0) > 0
            case .reviewRequired:
                dropInText.isEmpty || (MoneyTextParser.cents(from: dropInText) ?? -1) >= 0
            }
        }
        return switch draft.pricingStatus {
        case .pending, .free:
            true
        case .priced:
            (MoneyTextParser.cents(from: draft.unitPriceText) ?? 0) > 0
        case .reviewRequired:
            (draft.unitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (MoneyTextParser.cents(from: draft.unitPriceText) ?? -1) >= 0)
        }
    }

    private var coursePriceSummary: String {
        if draftIsPrivateLesson {
            return privateLessonPriceSummary
        }
        switch draft.pricingStatus {
        case .pending:
            return "整期与按次价格待定"
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
            let termSummary = "整期 \(activeOccurrenceCount) 次 × $\(MoneyTextParser.dollars(from: cents)) = $\(MoneyTextParser.dollars(from: total))"
            guard let perSessionPrice = CoursePricingPolicy.perSessionUnitPriceCents(
                fullTermUnitPriceCents: cents
            ) else {
                return termSummary + " · 按次待定"
            }
            return termSummary + " · 按次 $\(MoneyTextParser.dollars(from: perSessionPrice))/节"
        }
    }

    private var derivedGroupDropInPriceText: String? {
        guard let fullTermPrice = MoneyTextParser.cents(from: draft.unitPriceText),
              let perSessionPrice = CoursePricingPolicy.perSessionUnitPriceCents(
                  fullTermUnitPriceCents: fullTermPrice
              ) else {
            return nil
        }
        return MoneyTextParser.dollars(from: perSessionPrice)
    }

    private var privateLessonPriceSummary: String {
        switch draft.pricingStatus {
        case .pending:
            return "私课 · 按次待定价"
        case .free:
            return "私课 · 按次免费"
        case .priced, .reviewRequired:
            let text = draft.dropInUnitPriceText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let cents = MoneyTextParser.cents(from: text), cents >= 0 else {
                return draft.pricingStatus == .reviewRequired ? "私课 · 按次价格待复核" : "请输入正确按次单价"
            }
            return "私课 · 按次 $\(MoneyTextParser.dollars(from: cents))/节"
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
                    Text(
                        date.formatted(
                            .dateTime
                                .month(.abbreviated)
                                .day()
                                .locale(Locale(identifier: "zh_Hans_CN"))
                        )
                    )
                        .mdFont(.monoStrong)
                    Text(
                        date.formatted(
                            .dateTime
                                .weekday(.wide)
                                .locale(Locale(identifier: "zh_Hans_CN"))
                        )
                    )
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
        if let source = original ?? duplicateSource {
            draft.name = duplicateSource == nil ? source.name : source.name + " 副本"
            draft.termID = source.termID
            draft.ageGroupID = source.ageGroupID
            draft.roomID = source.defaultRoomID
            draft.instructorID = source.defaultInstructorID
            draft.courseTypeID = source.courseTypeID
            draft.pricingStatus = source.pricingStatus
            draft.unitPriceText = source.format.requiresPerSessionEnrollment
                ? ""
                : MoneyTextParser.dollars(from: source.unitPriceCents)
            draft.dropInUnitPriceText = MoneyTextParser.dollars(
                from: source.dropInUnitPriceCents
                    ?? (source.format.requiresPerSessionEnrollment ? source.unitPriceCents : nil)
            )
            draft.notes = source.notes ?? ""
            draft.isActive = source.isActive

            let existingSessions = model.sessions(forCourse: source.id)
            if original != nil {
                draft.existingSessions = existingSessions
                draft.sourceSessions = existingSessions
            }
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
            } else if let term = model.term(id: source.termID) {
                draft.startsOn = term.startsOn
                draft.endsOn = term.endsOn
            }
        } else {
            let initialTerm = initialTermID.flatMap(model.term(id:))
                ?? model.currentEnrollmentTerm
                ?? model.terms.first { term in
                    model.termHolidays.contains { $0.termID == term.id }
                }
                ?? model.terms.first
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
        alignPricingFieldsForCourseType()
    }

    private var editorTitle: String {
        if original != nil { return "编辑课程" }
        if duplicateSource != nil { return "复制课程" }
        return "添加课程"
    }

    private var hasSessionChanges: Bool {
        guard let original, let sessions = draft.existingSessions else { return false }
        return sessions != model.sessions(forCourse: original.id)
    }

    private var scheduleError: String? {
        guard let sessions = draft.existingSessions else { return nil }
        guard let termID = draft.termID, let term = model.term(id: termID) else { return "请选择学期" }
        let calendar = Calendar.masterDance
        var times = Set<Date>()
        for session in sessions where session.status != .cancelled {
            let day = calendar.startOfDay(for: session.startsAt)
            if session.endsAt <= session.startsAt { return "下课时间必须晚于上课时间" }
            if day < calendar.startOfDay(for: term.startsOn) || day > calendar.startOfDay(for: term.endsOn) {
                return "实际课次必须在所选学期内"
            }
            if automaticHolidayDates.contains(day) { return "实际课次落在假期，请调整日期或取消该课次" }
            if !times.insert(session.startsAt).inserted { return "同一门课程不能在同一时间安排两次" }
        }
        return nil
    }

    private func existingSessionRow(_ index: Int, theme: MDTheme) -> some View {
        let session = draft.existingSessions![index]
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                DatePicker("上课", selection: Binding(
                    get: { draft.existingSessions![index].startsAt },
                    set: { date in
                        let duration = session.endsAt.timeIntervalSince(session.startsAt)
                        draft.existingSessions![index].startsAt = date
                        draft.existingSessions![index].endsAt = date.addingTimeInterval(duration)
                    }
                ), displayedComponents: [.date, .hourAndMinute])
                Button {
                    let previous = draft.sourceSessions?.first { $0.id == session.id }?.status
                    draft.existingSessions![index].status = session.status == .cancelled
                        ? (previous == .cancelled ? .scheduled : previous ?? .scheduled) : .cancelled
                } label: {
                    Image(systemName: session.status == .cancelled ? "arrow.uturn.backward" : "xmark.circle")
                }.buttonStyle(.plain).help(session.status == .cancelled ? "恢复课次" : "取消课次（保留记录）")
            }
            DatePicker("下课", selection: Binding(
                get: { draft.existingSessions![index].endsAt },
                set: { draft.existingSessions![index].endsAt = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
            HStack {
                Picker("教室", selection: Binding(
                    get: { draft.existingSessions![index].roomOverrideID },
                    set: { draft.existingSessions![index].roomOverrideID = $0 }
                )) {
                    Text("课程默认").tag(Optional<RoomID>.none)
                    ForEach(model.rooms) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("老师", selection: Binding(
                    get: { draft.existingSessions![index].instructorOverrideID },
                    set: { draft.existingSessions![index].instructorOverrideID = $0 }
                )) {
                    Text("课程默认").tag(Optional<InstructorID>.none)
                    ForEach(model.instructors) { Text($0.displayName).tag(Optional($0.id)) }
                }
            }
            Text(session.status == .cancelled ? "已取消" : session.startsAt.formatted(.dateTime.weekday(.wide)))
                .mdFont(.compact).foregroundStyle(session.status == .cancelled ? theme.danger : theme.secondaryText)
        }
        .mdFont(.compact)
        .padding(.vertical, 4)
    }

    private var editorEnglishTitle: String {
        if original != nil { return "EDIT COURSE" }
        if duplicateSource != nil { return "DUPLICATE COURSE" }
        return "NEW COURSE"
    }

    private var saveButtonTitle: String {
        if original != nil { return "保存修改" }
        if duplicateSource != nil { return "创建副本" }
        return "添加课程"
    }

    private func alignPricingFieldsForCourseType() {
        if draftIsPrivateLesson {
            if draft.dropInUnitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.dropInUnitPriceText = draft.unitPriceText
            }
            draft.unitPriceText = ""
        } else if draft.unitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !draft.dropInUnitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.unitPriceText = draft.dropInUnitPriceText
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
