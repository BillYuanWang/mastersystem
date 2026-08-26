import Foundation
import MasterDanceCore

struct CourseScheduleConflict: Equatable, Sendable {
    enum Resource: Hashable, Sendable {
        case room
        case instructor
    }

    let conflictingCourseID: CourseID
    let resources: Set<Resource>
    let overlappingSessionCount: Int
}

enum CourseScheduleConflictDetector {
    static func conflicts(
        courses: [Course],
        sessions: [ClassSession]
    ) -> [CourseID: [CourseScheduleConflict]] {
        let activeCourses = Dictionary(
            uniqueKeysWithValues: courses.filter(\.isActive).map { ($0.id, $0) }
        )
        let scheduledSessions = sessions
            .compactMap { session -> ScheduledResource? in
                guard
                    session.status != .cancelled,
                    let course = activeCourses[session.courseID]
                else { return nil }

                return ScheduledResource(
                    courseID: course.id,
                    startsAt: session.startsAt,
                    endsAt: session.endsAt,
                    roomID: session.roomOverrideID ?? course.defaultRoomID,
                    instructorID: session.instructorOverrideID ?? course.defaultInstructorID
                )
            }
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                if lhs.endsAt != rhs.endsAt { return lhs.endsAt < rhs.endsAt }
                return lhs.courseID.description < rhs.courseID.description
            }

        var aggregates: [CourseID: [CourseID: ConflictAggregate]] = [:]
        var activeSessions: [ScheduledResource] = []
        for current in scheduledSessions {
            activeSessions.removeAll { $0.endsAt <= current.startsAt }

            for other in activeSessions {
                guard
                    current.courseID != other.courseID,
                    current.startsAt < other.endsAt,
                    other.startsAt < current.endsAt
                else { continue }

                var resources = Set<CourseScheduleConflict.Resource>()
                if current.roomID == other.roomID { resources.insert(.room) }
                if current.instructorID == other.instructorID { resources.insert(.instructor) }
                guard !resources.isEmpty else { continue }

                record(
                    conflictWith: other.courseID,
                    resources: resources,
                    for: current.courseID,
                    in: &aggregates
                )
                record(
                    conflictWith: current.courseID,
                    resources: resources,
                    for: other.courseID,
                    in: &aggregates
                )
            }

            activeSessions.append(current)
        }

        return aggregates.mapValues { conflictsByCourse in
            conflictsByCourse.map { otherCourseID, aggregate in
                CourseScheduleConflict(
                    conflictingCourseID: otherCourseID,
                    resources: aggregate.resources,
                    overlappingSessionCount: aggregate.overlappingSessionCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.overlappingSessionCount != rhs.overlappingSessionCount {
                    return lhs.overlappingSessionCount > rhs.overlappingSessionCount
                }
                return lhs.conflictingCourseID.description < rhs.conflictingCourseID.description
            }
        }
    }

    private static func record(
        conflictWith conflictingCourseID: CourseID,
        resources: Set<CourseScheduleConflict.Resource>,
        for courseID: CourseID,
        in aggregates: inout [CourseID: [CourseID: ConflictAggregate]]
    ) {
        var aggregate = aggregates[courseID]?[conflictingCourseID] ?? ConflictAggregate()
        aggregate.resources.formUnion(resources)
        aggregate.overlappingSessionCount += 1
        aggregates[courseID, default: [:]][conflictingCourseID] = aggregate
    }
}

private struct ScheduledResource {
    let courseID: CourseID
    let startsAt: Date
    let endsAt: Date
    let roomID: RoomID
    let instructorID: InstructorID
}

private struct ConflictAggregate {
    var resources = Set<CourseScheduleConflict.Resource>()
    var overlappingSessionCount = 0
}
