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
                MDSectionTitle(chinese: "请假与通知")
                Picker("申请", selection: $section) {
                    ForEach(RequestSection.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 54)

            Rectangle().fill(theme.separator).frame(height: 1)

            switch section {
            case .leave:
                leaveList(theme: theme)
            case .notifications:
                notificationList(theme: theme)
            }
        }
        .background(theme.background)
        .foregroundStyle(theme.primaryText)
    }

    private func leaveList(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            requestHeader([("学生", 140), ("课程", 190), ("课次", 180), ("来源", 90), ("状态", 90), ("备注", 180), ("处理", 126)], theme: theme)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.leaveRequests) { request in
                        let session = model.session(id: request.sessionID)
                        let course = session.flatMap { model.course(id: $0.courseID) }
                        HStack(spacing: 0) {
                            requestCell(model.student(id: request.studentID)?.displayName ?? "—", width: 140, strong: true)
                            requestCell(course?.name ?? "—", width: 190)
                            requestCell(session?.startsAt.formatted(date: .abbreviated, time: .shortened) ?? "—", width: 180, mono: true)
                            requestCell(request.source == .app ? "手机端" : "教务代办", width: 90)
                            requestCell(leaveStatus(request.status), width: 90)
                            requestCell(request.note ?? "—", width: 180)
                            leaveActions(request)
                                .frame(width: 126, alignment: .leading)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .frame(minHeight: 42)
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func leaveActions(_ request: LeaveRequest) -> some View {
        if request.status == .pending || request.status == .late {
            HStack(spacing: 5) {
                Button {
                    resolve(request, as: .approved)
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderless)
                .help("同意")

                Button {
                    resolve(request, as: .denied)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("拒绝")
            }
        } else {
            Text("—")
                .mdFont(.body)
        }
    }

    private func resolve(_ request: LeaveRequest, as status: LeaveRequestStatus) {
        Task {
            do {
                try await model.resolveLeaveRequest(id: request.id, status: status)
            } catch {
                model.errorMessage = error.localizedDescription
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
                            requestCell(notification.channel == .applePush ? "苹果推送" : "应用内", width: 120)
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
    case notifications

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leave: "请假"
        case .notifications: "通知"
        }
    }
}

@MainActor
private func requestCell(
    _ text: String,
    width: CGFloat,
    strong: Bool = false,
    mono: Bool = false
) -> some View {
    Text(text)
        .mdFont(mono ? .mono : (strong ? .bodyStrong : .body))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: width, alignment: .leading)
        .padding(.leading, 10)
}
#endif
