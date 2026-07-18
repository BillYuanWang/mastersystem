import Foundation

public struct EntityID<Tag>: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init() {
        self.init(rawValue: UUID())
    }

    public init(uuidString: String) throws {
        guard let value = UUID(uuidString: uuidString) else {
            throw InvalidEntityID(value: uuidString)
        }
        self.init(rawValue: value)
    }

    public var description: String { rawValue.uuidString }
}

public struct InvalidEntityID: Error, Equatable, Sendable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

public enum TermIDTag: Sendable {}
public enum TermHolidayIDTag: Sendable {}
public enum CourseCategoryIDTag: Sendable {}
public enum CourseTypeIDTag: Sendable {}
public enum AgeGroupIDTag: Sendable {}
public enum RoomIDTag: Sendable {}
public enum InstructorIDTag: Sendable {}
public enum CourseIDTag: Sendable {}
public enum ClassSessionIDTag: Sendable {}
public enum StudentIDTag: Sendable {}
public enum GuardianIDTag: Sendable {}
public enum EnrollmentIDTag: Sendable {}
public enum AttendanceIDTag: Sendable {}
public enum LeaveRequestIDTag: Sendable {}
public enum ContractConsentIDTag: Sendable {}
public enum ContractDocumentIDTag: Sendable {}
public enum NotificationRecordIDTag: Sendable {}

public typealias TermID = EntityID<TermIDTag>
public typealias TermHolidayID = EntityID<TermHolidayIDTag>
public typealias CourseCategoryID = EntityID<CourseCategoryIDTag>
public typealias CourseTypeID = EntityID<CourseTypeIDTag>
public typealias AgeGroupID = EntityID<AgeGroupIDTag>
public typealias RoomID = EntityID<RoomIDTag>
public typealias InstructorID = EntityID<InstructorIDTag>
public typealias CourseID = EntityID<CourseIDTag>
public typealias ClassSessionID = EntityID<ClassSessionIDTag>
public typealias StudentID = EntityID<StudentIDTag>
public typealias GuardianID = EntityID<GuardianIDTag>
public typealias EnrollmentID = EntityID<EnrollmentIDTag>
public typealias AttendanceID = EntityID<AttendanceIDTag>
public typealias LeaveRequestID = EntityID<LeaveRequestIDTag>
public typealias ContractConsentID = EntityID<ContractConsentIDTag>
public typealias ContractDocumentID = EntityID<ContractDocumentIDTag>
public typealias NotificationRecordID = EntityID<NotificationRecordIDTag>
