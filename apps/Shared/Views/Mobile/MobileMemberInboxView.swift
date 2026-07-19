#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberInboxView: View {
    let model: AppModel
    let actions: MobileMemberActionService
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
                                document: document
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
    let document: ContractDocument
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.title)
                        .mdFont(size: 20, weight: .bold)
                        .foregroundStyle(theme.primaryText)
                    HStack(spacing: 8) {
                        Text("版本 \(document.version)")
                            .mdFont(.mono)
                        Label(
                            hasConsent ? "已签署" : "未签署",
                            systemImage: hasConsent ? "checkmark.seal.fill" : "exclamationmark.circle"
                        )
                        .mdFont(.compactStrong)
                        .foregroundStyle(hasConsent ? theme.success : theme.danger)
                    }
                    .foregroundStyle(theme.secondaryText)
                }

                Divider()

                MobileAgreementTextView(bodyText: document.bodyText)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle("合同")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasConsent: Bool {
        model.contractConsents.contains {
            $0.contractDocumentID == document.id && $0.enrollmentID == nil
        }
    }
}
#endif
