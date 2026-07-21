#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileMemberHomeView: View {
    let model: AppModel
    @Binding var selectedStudentID: StudentID?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            if let student = selectedStudent {
                LazyVStack(alignment: .leading, spacing: 22) {
                    greeting(student: student, theme: theme)

                    nextClassSection(student: student, theme: theme)

                    summaryStrip(theme: theme)

                    newsSection(theme: theme)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            } else if model.isLoading {
                ProgressView("正在读取家庭资料")
                    .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                ContentUnavailableView(
                    "尚未连接学员",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("请联系教务老师确认监护人码和家庭档案。")
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            }
        }
        .background(theme.background)
        .navigationTitle("Master Dance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MobileStudentPicker(students: model.students, selection: $selectedStudentID)
            }
        }
        .refreshable { await model.refreshFromCloud() }
    }

    private var selectedStudent: Student? {
        selectedStudentID.flatMap(model.student(id:))
    }

    private func greeting(student: Student, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(student.kind == .adult ? "你好，\(student.displayName)" : "\(student.displayName)的课程")
                .mdFont(size: 20, weight: .bold)
                .foregroundStyle(theme.primaryText)
            Text(Date().mdChineseFormatted(.dateTime.year().month().day().weekday(.wide)))
                .mdFont(.mono)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func nextClassSection(student: Student, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MobileSectionHeading("下一节课")
            if let session = model.upcomingSessions(forStudent: student.id).first {
                let course = model.course(id: session.courseID)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course?.name ?? "课程")
                                .mdFont(size: 17, weight: .bold)
                                .foregroundStyle(theme.primaryText)
                            Text(session.startsAt.mdChineseFormatted(.dateTime.weekday(.wide).month().day()))
                                .mdFont(.bodyStrong)
                                .foregroundStyle(theme.accent)
                        }
                        Spacer()
                        Text(session.startsAt.mdChineseFormatted(.dateTime.hour().minute()))
                            .mdFont(size: 16, weight: .bold, design: .monospaced)
                            .foregroundStyle(theme.primaryText)
                    }

                    Divider()

                    HStack(spacing: 16) {
                        Label(
                            model.effectiveInstructor(for: session)?.displayName ?? "待定老师",
                            systemImage: "person.fill"
                        )
                        Label(
                            model.effectiveRoom(for: session)?.name ?? "待定教室",
                            systemImage: "door.left.hand.open"
                        )
                    }
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.secondaryText)
                }
                .padding(14)
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
            } else {
                Text("暂无排定课程")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            }
        }
    }

    private func summaryStrip(theme: MDTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(theme.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("已报课程")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                Text("\(activeCourseCount) 门")
                    .mdFont(size: 17, weight: .bold, design: .monospaced)
                    .foregroundStyle(theme.primaryText)
            }
            Spacer()
            Text("本学期")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
        .overlay {
            RoundedRectangle(cornerRadius: MDMetrics.radius)
                .stroke(theme.separator, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func newsSection(theme: MDTheme) -> some View {
        let articles = Array(publishedNews.prefix(6))
        VStack(alignment: .leading, spacing: 8) {
            MobileSectionHeading("新闻", detail: articles.isEmpty ? nil : "最近更新")
            if articles.isEmpty {
                Text("暂无新闻")
                    .mdFont(.body)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(theme.subtleSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                        NavigationLink {
                            MobileNewsDetailView(model: model, article: article)
                        } label: {
                            MobileNewsRow(model: model, article: article)
                        }
                        .buttonStyle(.plain)

                        if index < articles.count - 1 {
                            Divider().padding(.leading, 118)
                        }
                    }
                }
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
            }
        }
    }

    private var activeCourseCount: Int {
        guard let selectedStudentID else { return 0 }
        return model.activeEnrollments(forStudent: selectedStudentID).count
    }

    private var publishedNews: [NewsArticle] {
        model.newsArticles
            .filter { $0.status == .published }
            .sorted { ($0.publishedAt ?? $0.updatedAt) > ($1.publishedAt ?? $1.updatedAt) }
    }
}
#endif
