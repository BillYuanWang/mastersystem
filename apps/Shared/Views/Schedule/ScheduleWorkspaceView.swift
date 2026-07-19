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
    @State private var selectedRoomIDs: Set<RoomID> = []
    @State private var selectedSessionID: ClassSessionID?
    @State private var searchText = ""
    @State private var zoom = 1.0
    @State private var fontScale = 1.0
    @State private var showingWeekPicker = false
    @State private var showingRoomPicker = false
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
                        zoom: zoom,
                        fontScale: fontScale
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
                openCourse: { navigate(.courses) },
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
        .task(id: activeRoomSignature) {
            reconcileRoomSelection()
        }
        .sheet(isPresented: $showingPrintPreview) {
            SchedulePrintPreview(
                model: model,
                weekStart: weekStart,
                rooms: visibleRooms,
                sessions: filteredSessions,
                fontScale: fontScale
            )
        }
    }

    private var toolbar: some View {
        let theme = MDTheme(scheme: colorScheme)
        return HStack(spacing: 7) {
            MDSectionTitle(chinese: "课表", english: "SCHEDULE")

            Spacer(minLength: 6)

            Picker("学期", selection: $selectedTermID) {
                ForEach(model.terms) { term in
                    Text(term.name).tag(Optional(term.id))
                }
            }
            .labelsHidden()
            .frame(width: 190)

            Button {
                shiftWeek(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("上一周")

            Button {
                showingWeekPicker.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                    Text(weekLabel)
                        .font(MDType.monoStrong)
                        .lineLimit(1)
                }
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 9)
                .frame(width: 126, height: 28)
                .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.separator, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingWeekPicker, arrowEdge: .bottom) {
                weekPicker(theme: theme)
            }
            .help("选择日期")

            Button {
                shiftWeek(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(MDIconButtonStyle())
            .help("下一周")

            roomSelector(theme: theme)

            TextField("搜索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .font(MDType.compact)
                .frame(width: 100)

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
                .frame(width: 64)
                .help("调整时间轴比例")
            Image(systemName: "plus")
                .font(MDType.compact)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(theme.separator)
                .frame(width: 1, height: 18)

            Image(systemName: "textformat.size.smaller")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
            Slider(value: $fontScale, in: 0.72...1.35)
                .frame(width: 64)
                .help("调整课程块字体大小")
                .accessibilityLabel("课程块字体大小")
            Image(systemName: "textformat.size.larger")
                .font(MDType.compact)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private func weekPicker(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("选择周")
                    .font(MDType.bodyStrong)
                Spacer()
                Text(weekLabel)
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
                Button {
                    selectWeek(containing: Date())
                } label: {
                    Image(systemName: "calendar.badge.clock")
                }
                .buttonStyle(MDIconButtonStyle())
                .help("回到本周")
            }
            .padding(.horizontal, 12)
            .frame(height: 42)

            Divider()

            DatePicker(
                "选择日期",
                selection: weekDateSelection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(10)
        }
        .frame(width: 292)
        .background(theme.background)
    }

    private func roomSelector(theme: MDTheme) -> some View {
        Button {
            showingRoomPicker.toggle()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accent)
                Text(roomSelectionLabel)
                    .font(MDType.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 4)
                Text(roomSelectionCount)
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 9)
            .frame(width: 210, height: 28)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(activeRooms.isEmpty)
        .popover(isPresented: $showingRoomPicker, arrowEdge: .bottom) {
            roomPicker(theme: theme)
        }
        .help("选择要显示的教室")
    }

    private func roomPicker(theme: MDTheme) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("显示教室")
                    .font(MDType.bodyStrong)
                Spacer()
                Text(roomSelectionCount)
                    .font(MDType.mono)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(activeRooms) { room in
                        roomOption(room, theme: theme)
                        if room.id != activeRooms.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(width: 260)
        .background(theme.background)
    }

    private func roomOption(_ room: Room, theme: MDTheme) -> some View {
        let isSelected = currentRoomSelection.contains(room.id)
        let isDisabled = isSelected
            ? currentRoomSelection.count == 1
            : currentRoomSelection.count >= 2

        return Button {
            toggleRoom(room.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? theme.accent : theme.secondaryText)
                    .frame(width: 18)
                Text(room.name)
                    .font(MDType.body)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.48 : 1)
        .help(roomOptionHelp(isSelected: isSelected, isDisabled: isDisabled))
    }

    private var activeRooms: [Room] {
        model.rooms.filter(\.isActive)
    }

    private var visibleRooms: [Room] {
        Array(activeRooms.filter { currentRoomSelection.contains($0.id) }.prefix(2))
    }

    private var currentRoomSelection: Set<RoomID> {
        let activeIDs = Set(activeRooms.map(\.id))
        let validSelection = selectedRoomIDs.intersection(activeIDs)
        if !validSelection.isEmpty {
            return Set(validSelection.prefix(2))
        }
        return Set(activeRooms.prefix(2).map(\.id))
    }

    private var activeRoomSignature: String {
        activeRooms.map(\.id.description).joined(separator: "|")
    }

    private var roomSelectionLabel: String {
        let names = visibleRooms.map(\.name)
        return names.isEmpty ? "选择教室" : names.joined(separator: " + ")
    }

    private var roomSelectionCount: String {
        guard !activeRooms.isEmpty else { return "0" }
        return "\(visibleRooms.count)/\(min(2, activeRooms.count))"
    }

    private var weekDateSelection: Binding<Date> {
        Binding(
            get: { weekStart },
            set: { selectWeek(containing: $0) }
        )
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

            if !query.isEmpty {
                let courseType = model.courseType(id: course.courseTypeID)?.name ?? ""
                let instructor = model.effectiveInstructor(for: session)?.displayName ?? ""
                return [course.name, courseType, instructor].contains {
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

    private func selectWeek(containing date: Date) {
        weekStart = date.startOfWeek()
        selectedSessionID = nil
        showingWeekPicker = false
    }

    private func reconcileRoomSelection() {
        let selection = currentRoomSelection
        if selection != selectedRoomIDs {
            selectedRoomIDs = selection
        }
    }

    private func toggleRoom(_ roomID: RoomID) {
        var selection = currentRoomSelection
        if selection.contains(roomID) {
            guard selection.count > 1 else { return }
            selection.remove(roomID)
        } else {
            guard selection.count < 2 else { return }
            selection.insert(roomID)
        }
        selectedRoomIDs = selection
        selectedSessionID = nil
    }

    private func roomOptionHelp(isSelected: Bool, isDisabled: Bool) -> String {
        if isSelected && isDisabled {
            return "课表至少显示一间教室"
        }
        if !isSelected && isDisabled {
            return "最多同时显示两间教室"
        }
        return isSelected ? "隐藏这间教室" : "显示这间教室"
    }

}

private struct SchedulePrintPreview: View {
    let model: AppModel
    let weekStart: Date
    let rooms: [Room]
    let sessions: [ClassSession]
    let fontScale: Double

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
                            sessions: sessions,
                            fontScale: fontScale
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
                sessions: sessions,
                fontScale: fontScale
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
    let fontScale: Double

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
                zoom: 1,
                fontScale: fontScale
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
