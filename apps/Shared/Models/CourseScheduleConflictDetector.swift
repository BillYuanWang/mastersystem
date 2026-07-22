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
        let scheduledSessions = sessions.compactMap { session -> ScheduledResource? in
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

        var aggregates: [CourseID: [CourseID: ConflictAggregate]] = [:]
        for leftIndex in scheduledSessions.indices {
            let left = scheduledSessions[leftIndex]
            for rightIndex in scheduledSessions.indices where rightIndex > leftIndex {
                let right = scheduledSessions[rightIndex]
                guard
                    left.courseID != right.courseID,
                    left.startsAt < right.endsAt,
                    right.startsAt < left.endsAt
                else { continue }

                var resources = Set<CourseScheduleConflict.Resource>()
                if left.roomID == right.roomID { resources.insert(.room) }
                if left.instructorID == right.instructorID { resources.insert(.instructor) }
                guard !resources.isEmpty else { continue }

                record(
                    conflictWith: right.courseID,
                    resources: resources,
                    for: left.courseID,
                    in: &aggregates
                )
                record(
                    conflictWith: left.courseID,
                    resources: resources,
                    for: right.courseID,
                    in: &aggregates
                )
            }
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
