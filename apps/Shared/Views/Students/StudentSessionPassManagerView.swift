#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct StudentSessionPassManagerView: View {
    let model: AppModel
    let student: Student

    @State private var showingIssueSheet = false
    @State private var editingPass: StudentSessionPass?
    @State private var deletingPass: StudentSessionPass?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("学员次卡")
                    .mdFont(.bodyStrong)
                Spacer()
                Text("剩余 \(totalRemaining) 次")
                    .mdFont(.monoStrong)
                    .foregroundStyle(totalRemaining > 0 ? theme.accent : theme.secondaryText)
                Button {
                    showingIssueSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("发放次卡")
                .disabled(activePlans.isEmpty)
            }

            if activePlans.isEmpty {
                Text("请先到“数据中心 > 次卡方案”创建并启用方案。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }

            if passes.isEmpty {
                Text("这位成人学员尚未发放次卡")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                ForEach(passes) { pass in
                    passRow(pass, theme: theme)
                }
            }
        }
        .sheet(isPresented: $showingIssueSheet) {
            SessionPassIssueView(model: model, student: student)
        }
        .sheet(item: $editingPass) { pass in
            StudentSessionPassEditorView(model: model, pass: pass)
        }
        .alert(
            "删除这张次卡？",
            isPresented: Binding(
                get: { deletingPass != nil },
                set: { if !$0 { deletingPass = nil } }
            ),
            presenting: deletingPass
        ) { pass in
            Button("删除", role: .destructive) {
                deletingPass = nil
                model.performBackgroundOperation(
                    label: "删除学员次卡",
                    successMessage: "次卡已删除"
                ) {
                    try await model.deleteStudentSessionPass(id: pass.id)
                }
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("只有尚未使用的次卡可以删除；已有划卡记录时，请改为停用。")
        }
    }

    private var passes: [StudentSessionPass] {
        model.sessionPasses(for: student.id)
    }

    private var activePlans: [SessionPassPlan] {
        model.sessionPassPlans.filter(\.isActive)
    }

    private var totalRemaining: Int {
        passes.filter(\.isActive).reduce(0) { $0 + model.remainingSessionCount(for: $1) }
    }

    private func passRow(_ pass: StudentSessionPass, theme: MDTheme) -> some View {
        let uses = model.sessionPassUses(for: pass.id)
        let remaining = model.remainingSessionCount(for: pass)
        let planName = model.sessionPassPlan(id: pass.planID)?.name ?? "次卡"
        let exhausted = remaining == 0

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                if uses.isEmpty {
                    Text("尚无划卡记录")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(uses) { use in
                        useRow(use, theme: theme)
                    }
                }

                if let notes = pass.notes, !notes.isEmpty {
                    Text("备注：\(notes)")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(.top, 7)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(pass.isActive && !exhausted ? theme.accent.opacity(0.12) : theme.subtleSurface)
                    Image(systemName: "rectangle.stack.fill")
                        .foregroundStyle(pass.isActive && !exhausted ? theme.accent : theme.secondaryText)
                }
                .frame(width: 36, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(planName)
                            .mdFont(.bodyStrong)
                            .lineLimit(1)
                        Text(passStatus(pass, remaining: remaining))
                            .mdFont(.compactStrong)
                            .foregroundStyle(pass.isActive && !exhausted ? theme.accent : theme.secondaryText)
                    }
                    Text(
                        "\(pass.issuedAt.formatted(date: .abbreviated, time: .omitted)) 发卡 · $\(MoneyTextParser.dollars(from: pass.unitPriceCents))/次"
                    )
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(remaining) / \(pass.includedSessions)")
                    .mdFont(.monoStrong)
                    .foregroundStyle(remaining > 0 ? theme.primaryText : theme.secondaryText)

                Button {
                    editingPass = pass
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("编辑次卡")

                Button {
                    deletingPass = pass
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(MDIconButtonStyle())
                .help(uses.isEmpty ? "删除次卡" : "已有划卡记录，请停用")
                .disabled(!uses.isEmpty)
            }
        }
        .padding(9)
        .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
    }

    private func useRow(_ use: SessionPassUse, theme: MDTheme) -> some View {
        let session = model.session(id: use.sessionID)
        let courseName = session.flatMap { model.course(id: $0.courseID)?.name } ?? "课程"
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            Text(use.usedAt.formatted(
                .dateTime
                    .year()
                    .month()
                    .day()
                    .weekday(.abbreviated)
                    .locale(Locale(identifier: "zh_Hans_CN"))
            ))
            .mdFont(.mono)
            Text(courseName)
                .mdFont(.compact)
                .lineLimit(1)
            Spacer()
            Text("已划 1 次")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private func passStatus(_ pass: StudentSessionPass, remaining: Int) -> String {
        if !pass.isActive { return "已停用" }
        if remaining == 0 { return "已用完" }
        return "使用中"
    }
}

@MainActor
private struct SessionPassIssueView: View {
    let model: AppModel
    let student: Student

    @State private var selectedPlanID: SessionPassPlanID?
    @State private var issuedAt = Date()
    @State private var notes = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            MDSectionTitle(chinese: "发放学员次卡")
            LabeledContent("学员", value: student.displayName)
            Picker("次卡方案", selection: $selectedPlanID) {
                Text("选择方案").tag(Optional<SessionPassPlanID>.none)
                ForEach(plans) { plan in
                    Text("\(plan.name) · \(plan.includedSessions) 次 · $\(MoneyTextParser.dollars(from: plan.unitPriceCents))/次")
                        .tag(Optional(plan.id))
                }
            }
            DatePicker("发卡日期", selection: $issuedAt, displayedComponents: .date)
            TextField("备注", text: $notes, axis: .vertical)
                .lineLimit(2...4)

            if let selectedPlan {
                LabeledContent("卡内次数", value: "\(selectedPlan.includedSessions) 次")
                LabeledContent("每次单价", value: "$\(MoneyTextParser.dollars(from: selectedPlan.unitPriceCents))")
                Text("发卡时会固定这两个数字，日后修改方案不会改变这张卡。")
                    .mdFont(.compact)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("发卡") { issue() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedPlanID == nil)
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .padding(8)
        .task {
            if selectedPlanID == nil { selectedPlanID = plans.first?.id }
        }
    }

    private var plans: [SessionPassPlan] {
        model.sessionPassPlans.filter(\.isActive)
    }

    private var selectedPlan: SessionPassPlan? {
        selectedPlanID.flatMap { model.sessionPassPlan(id: $0) }
    }

    private func issue() {
        guard let selectedPlanID else { return }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        model.performBackgroundOperation(
            label: "发放学员次卡",
            successMessage: "次卡已发放"
        ) {
            try await model.issueSessionPass(
                studentID: student.id,
                planID: selectedPlanID,
                issuedAt: issuedAt,
                notes: trimmedNotes
            )
        }
        dismiss()
    }
}

@MainActor
private struct StudentSessionPassEditorView: View {
    let model: AppModel
    let pass: StudentSessionPass

    @State private var notes: String
    @State private var isActive: Bool

    @Environment(\.dismiss) private var dismiss

    init(model: AppModel, pass: StudentSessionPass) {
        self.model = model
        self.pass = pass
        _notes = State(initialValue: pass.notes ?? "")
        _isActive = State(initialValue: pass.isActive)
    }

    var body: some View {
        Form {
            MDSectionTitle(chinese: "编辑学员次卡")
            LabeledContent("卡内次数", value: "\(pass.includedSessions) 次")
            LabeledContent("每次单价", value: "$\(MoneyTextParser.dollars(from: pass.unitPriceCents))")
            LabeledContent("发卡日期", value: pass.issuedAt.formatted(date: .abbreviated, time: .omitted))
            TextField("备注", text: $notes, axis: .vertical)
                .lineLimit(2...4)
            Toggle("启用这张次卡", isOn: $isActive)
            Text("已有划卡记录后，学员、次数、单价与发卡日期都会锁定。")
                .mdFont(.compact)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
        .padding(8)
    }

    private func save() {
        var updated = pass
        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updated.isActive = isActive
        model.performBackgroundOperation(
            label: "更新学员次卡",
            successMessage: "次卡已更新"
        ) {
            try await model.saveStudentSessionPass(updated)
        }
        dismiss()
    }
}
#endif

#if os(macOS)
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
#endif
