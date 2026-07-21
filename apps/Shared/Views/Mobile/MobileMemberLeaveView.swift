#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberLeaveHistorySection: View {
    let model: AppModel
    let studentID: StudentID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        Section {
            if requests.isEmpty {
                Text("暂无请假记录")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ForEach(requests) { request in
                    leaveRequestRow(request, theme: theme)
                }
            }
        } header: {
            HStack {
                Text("请假记录")
                Spacer()
                if !requests.isEmpty {
                    Text("\(requests.count) 条")
                }
            }
        }
    }

    private var requests: [LeaveRequest] {
        guard let studentID else { return [] }
        return model.leaveRequests
            .filter { $0.studentID == studentID }
            .sorted { $0.submittedAt > $1.submittedAt }
    }

    private func leaveRequestRow(_ request: LeaveRequest, theme: MDTheme) -> some View {
        let session = model.session(id: request.sessionID)
        let course = session.flatMap { model.course(id: $0.courseID) }
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(course?.name ?? "课程")
                    .mdFont(.bodyStrong)
                Text(session?.startsAt.mdChineseFormatted(
                    .dateTime.year().month().day().hour().minute()
                ) ?? "课次")
                    .mdFont(.mono)
                    .foregroundStyle(theme.secondaryText)
                if let note = request.note, !note.isEmpty {
                    Text(note)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            MobileStatusPill(
                title: "已请假",
                systemImage: "checkmark.circle.fill",
                color: theme.success
            )
        }
        .padding(.vertical, 3)
    }
}
#endif
