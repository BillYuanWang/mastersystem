#if os(macOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct RequestsWorkspaceView: View {
    let model: AppModel

    @State private var section = RequestSection.leave

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MDSectionTitle(chinese: "申请", english: "REQUESTS")
                Picker("申请", selection: $section) {
                    ForEach(RequestSection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 300)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            switch section {
            case .leave:
                leaveList(theme: theme)
            case .contracts:
                contractList(theme: theme)
            case .notifications:
                notificationList(theme: theme)
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func leaveList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            requestHeader([("学生", 150), ("课程", 210), ("课次", 190), ("来源", 100), ("状态", 100), ("备注", 240)], theme: theme)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.leaveRequests) { request in
                        let session = model.session(id: request.sessionID)
                        let course = session.flatMap { model.course(id: $0.courseID) }
                        HStack(spacing: 0) {
                            requestCell(model.student(id: request.studentID)?.displayName ?? "—", width: 150, strong: true)
                            requestCell(course?.name ?? "—", width: 210)
                            requestCell(session?.startsAt.formatted(date: .abbreviated, time: .shortened) ?? "—", width: 190, mono: true)
                            requestCell(request.source == .app ? "App" : "教务代办", width: 100)
                            requestCell(leaveStatus(request.status), width: 100)
                            requestCell(request.note ?? "—", width: 240)
                            Spacer()
                        }
                        .frame(minHeight: 42)
                        Divider()
                    }
                }
            }
        }
    }

    private func contractList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            requestHeader([("签署人", 180), ("版本", 150), ("范围", 160), ("同意时间", 200)], theme: theme)
            if model.contractConsents.isEmpty {
                ContentUnavailableView(
                    "暂无合同同意记录",
                    systemImage: "signature",
                    description: Text("合同范围规则尚待产品确认，因此这里不做默认推断。")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.contractConsents) { consent in
                            HStack(spacing: 0) {
                                requestCell(consent.signerDisplayName, width: 180, strong: true)
                                requestCell(consent.contractVersion, width: 150, mono: true)
                                requestCell(consent.enrollmentID == nil ? "学期" : "报名", width: 160)
                                requestCell(consent.consentedAt.formatted(date: .abbreviated, time: .shortened), width: 200, mono: true)
                                Spacer()
                            }
                            .frame(minHeight: 42)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func notificationList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            requestHeader([("标题", 220), ("内容", 360), ("渠道", 120), ("状态", 120), ("计划时间", 180)], theme: theme)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.notifications) { notification in
                        HStack(spacing: 0) {
                            requestCell(notification.title, width: 220, strong: true)
                            requestCell(notification.body, width: 360)
                            requestCell(notification.channel == .applePush ? "Apple Push" : "App", width: 120)
                            requestCell(notificationStatus(notification.status), width: 120)
                            requestCell(notification.scheduledAt?.formatted(date: .abbreviated, time: .shortened) ?? "—", width: 180, mono: true)
                            Spacer()
                        }
                        .frame(minHeight: 42)
                        Divider()
                    }
                }
            }
        }
    }

    private func requestHeader(_ columns: [(String, CGFloat)], theme: MDTheme) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                requestCell(column.0, width: column.1, strong: true)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
        }
        .frame(height: 34)
        .background(theme.subtleSurface)
    }

    private func leaveStatus(_ status: LeaveRequestStatus) -> String {
        switch status {
        case .pending: "待处理"
        case .approved: "已同意"
        case .denied: "已拒绝"
        case .late: "逾期"
        }
    }

    private func notificationStatus(_ status: NotificationDeliveryStatus) -> String {
        switch status {
        case .pending: "待发送"
        case .sent: "已发送"
        case .failed: "失败"
        case .read: "已读"
        }
    }
}

private enum RequestSection: String, CaseIterable, Identifiable {
    case leave
    case contracts
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leave: "请假"
        case .contracts: "合同"
        case .notifications: "通知"
        }
    }
}

private func requestCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text)
        .font(mono ? MDType.mono : (strong ? MDType.bodyStrong : MDType.body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
