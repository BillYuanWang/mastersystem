import MasterDanceCore
import SwiftUI

struct AppShell: View {
    let role: AppRole
    let repository: any MasterDanceRepository

    @AppStorage("appearancePreference") private var appearanceRawValue = AppearancePreference.system.rawValue
    @State private var selectedSection: AppSection?
    @State private var summary = AppSummary()
    @State private var loadError: String?

    var body: some View {
        NavigationSplitView {
            List(availableSections, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Master Dance")
        } detail: {
            detail
        }
        .task(id: role) {
            selectedSection = selectedSection ?? availableSections.first
            await loadSummary()
        }
        .preferredColorScheme(preferredColorScheme)
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedSection ?? availableSections.first {
        case .home:
            DashboardView(role: role, summary: summary, loadError: loadError)
        case .terms:
            EntityListView(title: "Terms", systemImage: "calendar", count: summary.termCount)
        case .courses:
            EntityListView(title: "Courses", systemImage: "figure.dance", count: summary.courseCount)
        case .enrollments:
            EntityListView(title: "Enrollments", systemImage: "person.2.badge.plus", count: summary.enrollmentCount)
        case .attendance:
            EntityListView(title: "Attendance", systemImage: "checkmark.circle", count: summary.attendanceCount)
        case .leave:
            EntityListView(title: "Leave", systemImage: "calendar.badge.minus", count: summary.leaveCount)
        case .contracts:
            EntityListView(title: "Contracts", systemImage: "signature", count: summary.consentCount)
        case .notifications:
            EntityListView(title: "Notifications", systemImage: "bell", count: summary.notificationCount)
        case .appearance:
            AppearanceView(selection: $appearanceRawValue)
        case nil:
            ContentUnavailableView("No Selection", systemImage: "sidebar.left")
        }
    }

    private var availableSections: [AppSection] {
        switch role {
        case .administrator:
            return [.home, .terms, .courses, .enrollments, .attendance, .leave, .contracts, .notifications, .appearance]
        case .guardian, .adultStudent:
            return [.home, .courses, .leave, .contracts, .notifications, .appearance]
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch AppearancePreference(rawValue: appearanceRawValue) ?? .system {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func loadSummary() async {
        do {
            async let terms = repository.listTerms()
            async let courses = repository.listCourses(termID: nil)
            async let enrollments = repository.listEnrollments(termID: nil, courseID: nil, studentID: nil)
            async let attendance = repository.listAttendance(sessionID: nil, studentID: nil)
            async let leave = repository.listLeaveRequests(sessionID: nil, studentID: nil)
            async let notifications = repository.listNotifications(recipientReference: nil)

            let loadedTerms = try await terms
            let consents: [ContractConsent]
            if let currentTerm = loadedTerms.first {
                consents = try await repository.listContractConsents(termID: currentTerm.id, enrollmentID: nil)
            } else {
                consents = []
            }

            summary = try await AppSummary(
                termCount: loadedTerms.count,
                courseCount: courses.count,
                enrollmentCount: enrollments.count,
                attendanceCount: attendance.count,
                leaveCount: leave.count,
                consentCount: consents.count,
                notificationCount: notifications.count
            )
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private enum AppSection: String, Identifiable, CaseIterable {
    case home
    case terms
    case courses
    case enrollments
    case attendance
    case leave
    case contracts
    case notifications
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .terms: "Terms"
        case .courses: "Courses"
        case .enrollments: "Enrollments"
        case .attendance: "Attendance"
        case .leave: "Leave"
        case .contracts: "Contracts"
        case .notifications: "Notifications"
        case .appearance: "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .terms: "calendar"
        case .courses: "figure.dance"
        case .enrollments: "person.2.badge.plus"
        case .attendance: "checkmark.circle"
        case .leave: "calendar.badge.minus"
        case .contracts: "signature"
        case .notifications: "bell"
        case .appearance: "circle.lefthalf.filled"
        }
    }
}

private struct AppSummary: Sendable {
    var termCount = 0
    var courseCount = 0
    var enrollmentCount = 0
    var attendanceCount = 0
    var leaveCount = 0
    var consentCount = 0
    var notificationCount = 0
}

private struct DashboardView: View {
    let role: AppRole
    let summary: AppSummary
    let loadError: String?

    private var metrics: [(String, String, Int)] {
        if role == .administrator {
            return [
                ("Terms", "calendar", summary.termCount),
                ("Courses", "figure.dance", summary.courseCount),
                ("Enrollments", "person.2", summary.enrollmentCount),
                ("Leave", "calendar.badge.minus", summary.leaveCount)
            ]
        }
        return [
            ("Courses", "figure.dance", summary.courseCount),
            ("Leave", "calendar.badge.minus", summary.leaveCount),
            ("Contracts", "signature", summary.consentCount),
            ("Notifications", "bell", summary.notificationCount)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(role == .administrator ? "Administration" : "My Dance")
                    .font(.largeTitle.bold())

                if let loadError {
                    Label(loadError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(metrics, id: \.0) { metric in
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: metric.1)
                                .foregroundStyle(.tint)
                            Text(metric.2, format: .number)
                                .font(.title.bold())
                            Text(metric.0)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                        .padding(16)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct EntityListView: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text("\(count) records")
        }
        .navigationTitle(title)
    }
}

private struct AppearanceView: View {
    @Binding var selection: String

    var body: some View {
        Form {
            Picker("Appearance", selection: $selection) {
                Text("System").tag(AppearancePreference.system.rawValue)
                Text("Light").tag(AppearancePreference.light.rawValue)
                Text("Dark").tag(AppearancePreference.dark.rawValue)
            }
            .pickerStyle(.segmented)
        }
        .formStyle(.grouped)
        .padding()
        .navigationTitle("Appearance")
    }
}
