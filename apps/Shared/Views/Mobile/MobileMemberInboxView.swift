#if os(iOS)
import MasterDanceCore
import PDFKit
import SwiftUI

@MainActor
struct MobileMemberInboxView: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let signerKind: ConsentSignerKind
    let signerDisplayName: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        List {
            Section("通知") {
                if notifications.isEmpty {
                    Text("暂无通知")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(notifications) { notification in
                        NavigationLink {
                            MobileNotificationDetailView(
                                model: model,
                                actions: actions,
                                notification: notification
                            )
                        } label: {
                            notificationRow(notification, theme: theme)
                        }
                    }
                }
            }

            Section("合同") {
                if publishedContracts.isEmpty {
                    Text("暂无需要查看的合同")
                        .foregroundStyle(theme.secondaryText)
                } else {
                    ForEach(publishedContracts) { document in
                        NavigationLink {
                            MobileContractDetailView(
                                model: model,
                                actions: actions,
                                document: document,
                                signerKind: signerKind,
                                signerDisplayName: signerDisplayName
                            )
                        } label: {
                            contractRow(document, theme: theme)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("消息与合同")
        .refreshable { await model.reload() }
    }

    private var notifications: [NotificationRecord] {
        model.notifications.sorted { lhs, rhs in
            if lhs.status == .read, rhs.status != .read { return false }
            if lhs.status != .read, rhs.status == .read { return true }
            return (lhs.sentAt ?? lhs.scheduledAt ?? .distantPast)
                > (rhs.sentAt ?? rhs.scheduledAt ?? .distantPast)
        }
    }

    private var publishedContracts: [ContractDocument] {
        model.contractDocuments
            .filter { $0.status == .published }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    private func notificationRow(
        _ notification: NotificationRecord,
        theme: MDTheme
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(notification.status == .read ? Color.clear : theme.accent)
                .frame(width: 7, height: 7)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .mdFont(.bodyStrong)
                    .lineLimit(2)
                Text(notification.body)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }

    private func contractRow(_ document: ContractDocument, theme: MDTheme) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(document.title)
                    .mdFont(.bodyStrong)
                Text("版本 \(document.version) · \(model.term(id: document.termID)?.name ?? "学期")")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            if model.contractConsents.contains(where: { $0.contractDocumentID == document.id }) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(theme.success)
                    .accessibilityLabel("已确认")
            }
        }
        .padding(.vertical, 3)
    }
}

@MainActor
private struct MobileNotificationDetailView: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let notification: NotificationRecord
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(notification.title)
                    .mdFont(size: 20, weight: .bold)
                    .foregroundStyle(theme.primaryText)
                if let date = notification.sentAt ?? notification.scheduledAt {
                    Text(date.mdChineseFormatted(.dateTime.year().month().day().hour().minute()))
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }
                Divider()
                Text(notification.body)
                    .mdFont(.body)
                    .foregroundStyle(theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: notification.id) {
            guard notification.status != .read else { return }
            do {
                try await actions.markNotificationRead(id: notification.id)
                model.applyLocalNotificationRead(id: notification.id)
            } catch {
                model.reportBackgroundSyncFailure(error)
            }
        }
    }
}

@MainActor
private struct MobileContractDetailView: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let document: ContractDocument
    let signerKind: ConsentSignerKind
    let signerDisplayName: String

    @State private var pdfData: Data?
    @State private var errorMessage: String?
    @State private var showingConsentOptions = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            if let pdfData {
                MobilePDFView(data: pdfData)
            } else if let errorMessage {
                ContentUnavailableView(
                    "无法打开合同",
                    systemImage: "doc.badge.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("正在读取合同")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .mdFont(.bodyStrong)
                        .lineLimit(1)
                    Text(consentSummary)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    showingConsentOptions = true
                } label: {
                    Label("确认合同", systemImage: "signature")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            }
            .padding(12)
            .background(theme.raisedSurface)
        }
        .navigationTitle("合同")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: document.id) { await loadPDF() }
        .confirmationDialog(
            "选择确认范围",
            isPresented: $showingConsentOptions,
            titleVisibility: .visible
        ) {
            if !hasTermConsent {
                Button("确认整个学期") {
                    consent(enrollmentID: nil)
                }
            }
            ForEach(eligibleEnrollments) { enrollment in
                if !hasConsent(enrollmentID: enrollment.id) {
                    Button("仅确认：\(model.course(id: enrollment.courseID)?.name ?? "课程")") {
                        consent(enrollmentID: enrollment.id)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("合同可以覆盖整个学期，也可以只关联某一门已报名课程。")
        }
    }

    private var eligibleEnrollments: [Enrollment] {
        model.enrollments
            .filter { $0.termID == document.termID && $0.status == .active }
            .sorted {
                (model.course(id: $0.courseID)?.name ?? "")
                    .localizedCompare(model.course(id: $1.courseID)?.name ?? "") == .orderedAscending
            }
    }

    private var hasTermConsent: Bool {
        model.contractConsents.contains {
            $0.contractDocumentID == document.id && $0.enrollmentID == nil
        }
    }

    private func hasConsent(enrollmentID: EnrollmentID) -> Bool {
        model.contractConsents.contains {
            $0.contractDocumentID == document.id && $0.enrollmentID == enrollmentID
        }
    }

    private var consentSummary: String {
        let count = model.contractConsents.filter { $0.contractDocumentID == document.id }.count
        return count == 0 ? "尚未确认 · 版本 \(document.version)" : "已确认 \(count) 项范围 · 版本 \(document.version)"
    }

    private func loadPDF() async {
        guard pdfData == nil else { return }
        do {
            pdfData = try await model.performCloudAction(label: "读取合同") {
                try await actions.downloadContract(path: document.storagePath)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func consent(enrollmentID: EnrollmentID?) {
        Task {
            do {
                try await actions.recordContractConsent(
                    documentID: document.id,
                    enrollmentID: enrollmentID,
                    signerDisplayName: signerDisplayName
                )
                model.applyLocalContractConsent(
                    documentID: document.id,
                    enrollmentID: enrollmentID,
                    signerKind: signerKind,
                    signerDisplayName: signerDisplayName
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MobilePDFView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
    }
}
#endif
