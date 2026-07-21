#if os(iOS)
import MasterDanceCore
import SwiftUI
import UIKit

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
        .refreshable {
            _ = try? await actions.synchronizePendingChanges()
            await model.refreshFromCloud()
        }
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
                Label("已签署", systemImage: "checkmark.seal.fill")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.success)
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
            VStack(alignment: .leading, spacing: 22) {
                contractHeader(theme: theme)
                Divider()
                MobileAgreementTextView(bodyText: document.bodyText)
                MobileAgreementLegalFooter()
                Divider()

                if let consent {
                    MobileContractSignatureRecord(consent: consent)
                } else {
                    Label("尚未找到这份合同的签署记录", systemImage: "signature")
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .center)
                }

                Text("合同正文、版本、签署时间与手写签名共同构成此电子签署记录。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
        .navigationTitle("合同")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.refreshFromCloud() }
    }

    private func contractHeader(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                consent == nil ? "待签署合同" : "已签署合同 / SIGNED AGREEMENT",
                systemImage: consent == nil ? "doc.text" : "checkmark.seal.fill"
            )
            .mdFont(.compactStrong)
            .foregroundStyle(consent == nil ? theme.danger : theme.success)

            Text(document.title)
                .mdFont(size: 23, weight: .bold)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("Starton EDU Irvine, Inc. · Master Dance")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)

            HStack(spacing: 8) {
                Text("版本 \(document.version)")
                    .mdFont(.mono)
                Text("·")
                Text(model.term(id: document.termID)?.name ?? "学期")
                    .mdFont(.compact)
            }
            .foregroundStyle(theme.secondaryText)
        }
    }

    private var consent: ContractConsent? {
        model.contractConsents
            .filter {
                $0.contractDocumentID == document.id && $0.enrollmentID == nil
            }
            .max { $0.consentedAt < $1.consentedAt }
    }
}

@MainActor
private struct MobileContractSignatureRecord: View {
    let consent: ContractConsent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("电子签署记录", systemImage: "signature")
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Label("已记录", systemImage: "checkmark.shield.fill")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.success)
            }

            Divider()

            LabeledContent("签署人") {
                Text(consent.signerDisplayName)
                    .mdFont(.bodyStrong)
            }
            LabeledContent("身份") {
                Text(consent.signerKind == .guardian ? "监护人" : "成人学员")
                    .mdFont(.compactStrong)
            }
            LabeledContent("签署时间") {
                Text(consent.consentedAt.mdChineseFormatted(.dateTime.year().month().day().hour().minute()))
                    .mdFont(.mono)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("合同版本") {
                Text(consent.contractVersion)
                    .mdFont(.mono)
            }
            LabeledContent("记录编号") {
                Text(String(consent.id.description.prefix(8)).uppercased())
                    .mdFont(.mono)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("监护人手写签名")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)

                if let image = consent.signaturePNG.flatMap(UIImage.init(data:)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 112, maxHeight: 168)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                        .overlay {
                            RoundedRectangle(cornerRadius: MDMetrics.radius)
                                .stroke(theme.separator, lineWidth: 1)
                        }
                        .accessibilityLabel("\(consent.signerDisplayName)的手写签名")
                } else {
                    Label("签名影像暂未同步，请下拉刷新", systemImage: "icloud.and.arrow.down")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .center)
                        .background(theme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                }
            }
        }
        .foregroundStyle(theme.primaryText)
    }
}
#endif
