public enum AppRole: String, Codable, CaseIterable, Hashable, Sendable {
    case administrator
    case guardian
    case adultStudent
}

public enum AppearancePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case light
    case dark
}

public struct RoleCapabilities: Codable, Equatable, Sendable {
    public let canManageTermsAndCourses: Bool
    public let canManageEnrollments: Bool
    public let canRecordAttendance: Bool
    public let canSubmitLeave: Bool
    public let canConsentToContract: Bool

    public init(role: AppRole) {
        switch role {
        case .administrator:
            canManageTermsAndCourses = true
            canManageEnrollments = true
            canRecordAttendance = true
            canSubmitLeave = true
            canConsentToContract = false
        case .guardian, .adultStudent:
            canManageTermsAndCourses = false
            canManageEnrollments = false
            canRecordAttendance = false
            canSubmitLeave = true
            canConsentToContract = true
        }
    }
}
