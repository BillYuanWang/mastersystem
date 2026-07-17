#if os(macOS)
import AppKit
import MasterDanceCore
import SwiftUI

@MainActor
struct ScheduleWorkspaceView: View {
    let model: AppModel
    let navigate: (AdminSection) -> Void

    @State private var selectedTermID: TermID?
    @State private var weekStart = Date().startOfWeek()
    @State private var roomScope = RoomScope.both
    @State private var selectedSessionID: ClassSessionID?
    @State private var selectedCategoryIDs: Set<CourseCategoryID> = []
    @State private var searchText = ""
    @State private var zoom = 1.0
    @State private var showingPrintPreview = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar

                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 1)

                if visibleRooms.isEmpty {
                    ContentUnavailableView(
                        "请先添加教室",
                        systemImage: "door.left.hand.open",
                        description: Text("课程资料中的教室完全由你维护。")
                    )
                } else {
                    ScheduleGridView(
                        model: model,
                        weekStart: weekStart,
                        rooms: visibleRooms,
                        sessions: filteredSessions,
                        selectedSessionID: $selectedSessionID,
                        zoom: zoom
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1)

            ScheduleInspectorView(
                model: model,
                sessionID: selectedSessionID,
                openCourse: { navigate(.setup) },
                startAttendance: { sessionID in
                    model.focusedSessionID = sessionID
                    navigate(.attendance)
                }
            )
            .frame(width: MDMetrics.inspectorWidth)
        }
        .background(theme.background)
        .task(id: model.terms.count) {
            if selectedTermID == nil {
                selectedTermID = model.terms.first?.id
            }
            if selectedSessionID == nil {
                selectedSessionID = filteredSessions.first(where: {
                    Calendar.masterDance.isDateInToday($0.startsAt)
                })?.id ?? filteredSessions.first?.id
            }
        }
        .sheet(isPresented: $showingPrintPreview) {
            SchedulePrintPreview(
                model: model,
                weekStart: weekStart,
                rooms: visibleRooms,
                sessions: filteredSessions
            )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            MDSectionTitle(chinese: "课表", english: "SCHEDULE")

            Spacer(minLength: 6)

            Picker("学期", selection: $selectedTermID) {
                ForEach(model.terms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            .labelsHidden()
            .frame(width: 128)

            Button {
                shiftWeek(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("上一周")

            Text(weekLabel)
                .font(MDType.monoStrong)
                .frame(minWidth: 88)

            Button {
                shiftWeek(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("下一周")

            Picker("教室", selection: $roomScope) {
                ForEach(RoomScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 238)

            Menu {
                ForEach(model.categories) { category in
                    Button {
                        toggleCategory(category.id)
                    } label: {
                        Label(
                            category.name,
                            systemImage: selectedCategoryIDs.contains(category.id) ? "checkmark" : "circle"
                        )
                    }
                }
                Divider()
                Button("清除分类筛选") {
                    selectedCategoryIDs.removeAll()
                }
                .disabled(selectedCategoryIDs.isEmpty)
            } label: {
                Image(systemName: selectedCategoryIDs.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: MDMetrics.controlHeight, height: MDMetrics.controlHeight)
            .help("课程分类筛选")

            TextField("搜索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(MDType.compact)
                .frame(width: 118)

            Button {
                showingPrintPreview = true
            } label: {
                Image(systemName: "printer")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("打印课程表")

            Image(systemName: "minus")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
            Slider(value: $zoom, in: 0.82...1.38)
                .frame(width: 76)
                .help("调整时间轴比例")
            Image(systemName: "plus")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var visibleRooms: [Room] {
        let activeRooms = model.rooms.filter(\.isActive)
        guard !activeRooms.isEmpty else { return [] }
        switch roomScope {
        case .both:
            return Array(activeRooms.prefix(2))
        case .large:
            return [activeRooms.first(where: { $0.name.contains("大") }) ?? activeRooms[0]]
        case .small:
            return [activeRooms.first(where: { $0.name.contains("小") }) ?? activeRooms[min(1, activeRooms.count - 1)]]
        }
    }

    private var filteredSessions: [ClassSession] {
        let calendar = Calendar.masterDance
        guard let weekEnd = calendar.date(byAdding: .day, value: 5, to: weekStart) else { return [] }
        let visibleRoomIDs = Set(visibleRooms.map(\.id))
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return model.sessions.filter { session in
            guard
                session.startsAt >= weekStart,
                session.startsAt < weekEnd,
                let course = model.course(id: session.courseID),
                selectedTermID == nil || course.termID == selectedTermID,
                let room = model.effectiveRoom(for: session),
                visibleRoomIDs.contains(room.id)
            else {
                return false
            }

            if !selectedCategoryIDs.isEmpty, !selectedCategoryIDs.contains(course.categoryID) {
                return false
            }
            if !query.isEmpty {
                let category = model.category(id: course.categoryID)?.name ?? ""
                let instructor = model.effectiveInstructor(for: session)?.displayName ?? ""
                return [course.name, category, instructor].contains {
                    $0.localizedCaseInsensitiveContains(query)
                }
            }
            return true
        }
    }

    private var weekLabel: String {
        let end = Calendar.masterDance.date(byAdding: .day, value: 4, to: weekStart) ?? weekStart
        return "\(weekStart.formatted(.dateTime.month(.abbreviated).day()))–\(end.formatted(.dateTime.day()))"
            .uppercased()
    }

    private func shiftWeek(_ amount: Int) {
        weekStart = Calendar.masterDance.date(byAdding: .day, value: amount * 7, to: weekStart) ?? weekStart
        selectedSessionID = nil
    }

    private func toggleCategory(_ categoryID: CourseCategoryID) {
        if selectedCategoryIDs.contains(categoryID) {
            selectedCategoryIDs.remove(categoryID)
        } else {
            selectedCategoryIDs.insert(categoryID)
        }
    }
}

private struct SchedulePrintPreview: View {
    let model: AppModel
    let weekStart: Date
    let rooms: [Room]
    let sessions: [ClassSession]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MDSectionTitle(chinese: "打印预览", english: "PRINT PREVIEW")
                Spacer()
                Button("取消") { dismiss() }
                Button("打印") {
                    SchedulePrinter.run(
                        SchedulePrintDocument(
                            model: model,
                            weekStart: weekStart,
                            rooms: rooms,
                            sessions: sessions
                        )
                    )
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)

            Divider()

            SchedulePrintDocument(
                model: model,
                weekStart: weekStart,
                rooms: rooms,
                sessions: sessions
            )
            .padding(20)
        }
        .frame(width: 1080, height: 760)
    }
}

private struct SchedulePrintDocument: View {
    let model: AppModel
    let weekStart: Date
    let rooms: [Room]
    let sessions: [ClassSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MASTER DANCE")
                    .font(MDType.monoStrong)
                Spacer()
                Text(weekStart.formatted(date: .long, time: .omitted))
                    .font(MDType.mono)
            }
            ScheduleGridView(
                model: model,
                weekStart: weekStart,
                rooms: rooms,
                sessions: sessions,
                selectedSessionID: .constant(nil),
                zoom: 1
            )
        }
        .padding(18)
        .frame(width: 1000, height: 680)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

private enum SchedulePrinter {
    @MainActor
    static func run<Content: View>(_ content: Content) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1000, height: 680)
        let printInfo = NSPrintInfo.shared
        printInfo.orientation = .landscape
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        NSPrintOperation(view: hostingView, printInfo: printInfo).run()
    }
}
#endif
