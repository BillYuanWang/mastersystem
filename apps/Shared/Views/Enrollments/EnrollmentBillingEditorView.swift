#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct EnrollmentBillingEditorView: View {
    let model: AppModel
    let original: Enrollment

    @State private var draft: Enrollment
    @State private var unitPriceText: String
    @State private var trialFeeText: String
    @State private var discountEnabled: Bool
    @State private var discountKind: BillingDiscountKind
    @State private var discountName: String
    @State private var discountValueText: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    init(model: AppModel, enrollment: Enrollment) {
        self.model = model
        original = enrollment
        _draft = State(initialValue: enrollment)
        _unitPriceText = State(initialValue: MoneyTextParser.dollars(from: enrollment.unitPriceCents))
        _trialFeeText = State(initialValue: MoneyTextParser.dollars(from: enrollment.trialFeeCents))
        _discountEnabled = State(initialValue: enrollment.discountKind != nil)
        _discountKind = State(initialValue: enrollment.discountKind ?? .percentage)
        _discountName = State(initialValue: enrollment.discountName ?? "")
        if enrollment.discountKind == .percentage, let value = enrollment.discountValue {
            _discountValueText = State(initialValue: MoneyTextParser.dollars(from: value))
        } else {
            _discountValueText = State(initialValue: MoneyTextParser.dollars(from: enrollment.discountValue))
        }
    }

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: "报名计费", english: "ENROLLMENT BILLING")
                Spacer()
                statusBadge(theme: theme)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    identitySection(theme: theme)
                    pricingSection(theme: theme)
                    discountSection(theme: theme)
                    estimateSection(theme: theme)
                    notesSection(theme: theme)
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("保存计费") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
            }
            .padding(14)
        }
        .frame(width: 700, height: 690)
        .background(theme.background)
    }

    private func identitySection(theme: MDTheme) -> some View {
        section("报名对象", theme: theme) {
            LabeledContent("学员", value: model.student(id: original.studentID)?.displayName ?? "—")
            LabeledContent("课程", value: model.course(id: original.courseID)?.name ?? "—")
            LabeledContent("学期", value: model.term(id: original.termID)?.name ?? "—")
        }
    }

    private func pricingSection(theme: MDTheme) -> some View {
        section("实际计费", theme: theme) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    fieldLabel("计费状态")
                    Picker("", selection: $draft.pricingStatus) {
                        ForEach(EnrollmentPricingStatus.allCases, id: \.self) { status in
                            Text(statusTitle(status)).tag(status)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                GridRow {
                    fieldLabel("计费起始")
                    HStack(spacing: 8) {
                        DatePicker(
                            "",
                            selection: billingStartBinding,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        Button("采用建议日期") {
                            draft.billingStartsOn = model.suggestedBillingStart(
                                courseID: original.courseID,
                                studentID: original.studentID
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }

                GridRow {
                    fieldLabel("每节单价")
                    HStack(spacing: 7) {
                        Text("$").mdFont(.monoStrong).foregroundStyle(theme.secondaryText)
                        TextField("例如 25.00", text: $unitPriceText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        if let coursePrice = model.course(id: original.courseID)?.unitPriceCents {
                            Button("使用课程价 $\(MoneyTextParser.dollars(from: coursePrice))") {
                                unitPriceText = MoneyTextParser.dollars(from: coursePrice)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                GridRow {
                    fieldLabel("试课费用")
                    HStack(spacing: 7) {
                        Text("$").mdFont(.monoStrong).foregroundStyle(theme.secondaryText)
                        TextField("0.00", text: $trialFeeText)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                        Text("按这名学员填写，不参与课程折扣")
                            .mdFont(.compact)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func discountSection(theme: MDTheme) -> some View {
        section("单门课折扣", theme: theme) {
            Toggle("这门课使用折扣", isOn: $discountEnabled)
                .toggleStyle(.switch)

            if discountEnabled {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        fieldLabel("折扣名称")
                        TextField("例如：兄弟姐妹折扣", text: $discountName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 300)
                    }
                    GridRow {
                        fieldLabel("折扣方式")
                        HStack(spacing: 8) {
                            Picker("", selection: $discountKind) {
                                Text("百分比").tag(BillingDiscountKind.percentage)
                                Text("固定金额").tag(BillingDiscountKind.fixedAmount)
                            }
                            .labelsHidden()
                            .frame(width: 135)
                            Text(discountKind == .percentage ? "%" : "$")
                                .mdFont(.monoStrong)
                                .foregroundStyle(theme.secondaryText)
                            TextField(discountKind == .percentage ? "例如 10" : "例如 50.00", text: $discountValueText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 150)
                        }
                    }
                }
            }
        }
    }

    private func estimateSection(theme: MDTheme) -> some View {
        let estimate = currentEstimate
        return section("费用估算", theme: theme) {
            HStack(spacing: 22) {
                estimateMetric("正常课次", value: "\(estimate.normalSessionCount) 次", theme: theme)
                estimateMetric("正常学费", value: money(estimate.tuitionBeforeDiscountCents), theme: theme)
                estimateMetric("课程折扣", value: estimate.discountCents > 0 ? "−\(money(estimate.discountCents))" : "$0.00", theme: theme)
                estimateMetric("试课费", value: money(estimate.trialFeeCents), theme: theme)
                Spacer()
                estimateMetric("预计合计", value: money(estimate.totalCents), theme: theme, emphasized: true)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(theme.subtleSurface)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.separator).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.separator).frame(height: 1)
            }
        }
    }

    private func notesSection(theme: MDTheme) -> some View {
        section("内部备注", theme: theme) {
            TextEditor(text: billingNotesBinding)
                .mdFont(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 72)
                .padding(6)
                .background(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
        }
    }

    private var parsedUnitPrice: Int? {
        MoneyTextParser.cents(from: unitPriceText)
    }

    private var parsedTrialFee: Int? {
        MoneyTextParser.cents(from: trialFeeText)
    }

    private var parsedDiscountValue: Int? {
        guard discountEnabled else { return nil }
        return MoneyTextParser.cents(from: discountValueText)
    }

    private var draftForEstimate: Enrollment {
        var value = draft
        value.unitPriceCents = parsedUnitPrice
        value.trialFeeCents = max(0, parsedTrialFee ?? 0)
        value.discountName = discountEnabled ? discountName : nil
        value.discountKind = discountEnabled ? discountKind : nil
        value.discountValue = parsedDiscountValue
        return value
    }

    private var currentEstimate: EnrollmentChargeEstimate {
        model.billingEstimate(for: draftForEstimate)
    }

    private var isValid: Bool {
        guard let trial = parsedTrialFee, trial >= 0 else { return false }
        if draft.pricingStatus == .ready {
            guard draft.billingStartsOn != nil,
                  let price = parsedUnitPrice,
                  price >= 0 else { return false }
        } else if !unitPriceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let price = parsedUnitPrice, price >= 0 else { return false }
        }
        guard discountEnabled else { return true }
        guard !discountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let value = parsedDiscountValue,
              value > 0 else { return false }
        return discountKind != .percentage || value <= 10_000
    }

    private var billingStartBinding: Binding<Date> {
        Binding(
            get: {
                draft.billingStartsOn
                    ?? model.suggestedBillingStart(
                        courseID: original.courseID,
                        studentID: original.studentID
                    )
                    ?? Date()
            },
            set: { draft.billingStartsOn = Calendar.masterDance.startOfDay(for: $0) }
        )
    }

    private var billingNotesBinding: Binding<String> {
        Binding(
            get: { draft.billingNotes ?? "" },
            set: { draft.billingNotes = $0 }
        )
    }

    private func save() {
        guard isValid else { return }
        var saved = draft
        saved.unitPriceCents = parsedUnitPrice
        saved.trialFeeCents = parsedTrialFee ?? 0
        saved.discountName = discountEnabled
            ? discountName.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil
        saved.discountKind = discountEnabled ? discountKind : nil
        saved.discountValue = parsedDiscountValue
        saved.billingNotes = saved.billingNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank
        model.performBackgroundOperation(
            label: "保存报名计费",
            successMessage: "报名计费已保存"
        ) {
            try await model.saveEnrollmentBilling(saved)
        }
        dismiss()
    }

    private func statusBadge(theme: MDTheme) -> some View {
        Text(statusTitle(draft.pricingStatus))
            .mdFont(.compactStrong)
            .foregroundStyle(statusColor(theme: theme))
            .padding(.horizontal, 9)
            .frame(height: 25)
            .overlay(Capsule().stroke(statusColor(theme: theme), lineWidth: 1))
    }

    private func statusTitle(_ status: EnrollmentPricingStatus) -> String {
        switch status {
        case .pending: "待定价"
        case .ready: "已就绪"
        case .reviewRequired: "需复核"
        }
    }

    private func statusColor(theme: MDTheme) -> Color {
        switch draft.pricingStatus {
        case .pending: theme.secondaryText
        case .ready: theme.success
        case .reviewRequired: theme.warning
        }
    }

    private func money(_ cents: Int?) -> String {
        guard let cents else { return "待定价" }
        return "$" + MoneyTextParser.dollars(from: cents)
    }

    private func section<Content: View>(
        _ title: String,
        theme: MDTheme,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .mdFont(.bodyStrong)
            content()
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .mdFont(.compact)
            .foregroundStyle(.secondary)
            .frame(width: 76, alignment: .leading)
    }

    private func estimateMetric(
        _ title: String,
        value: String,
        theme: MDTheme,
        emphasized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).mdFont(.compact).foregroundStyle(theme.secondaryText)
            Text(value)
                .mdFont(emphasized ? .monoStrong : .mono)
                .foregroundStyle(emphasized ? theme.accent : theme.primaryText)
        }
    }
}

private extension String {
    var nilIfBlank: String? { isEmpty ? nil : self }
}
#endif
