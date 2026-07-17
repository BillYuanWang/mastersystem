import Foundation

public enum MigrationEntityKind: String, Codable, CaseIterable, Sendable {
    case term
    case courseCategory
    case ageGroup
    case room
    case instructor
    case course
    case session
    case student
    case guardian
    case enrollment
}

public enum MigrationIssueSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case error
}

public struct MigrationIssue: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var severity: MigrationIssueSeverity
    public var entity: MigrationEntityKind
    public var sourceRow: Int
    public var field: String?
    public var message: String

    public init(
        id: UUID = UUID(),
        severity: MigrationIssueSeverity,
        entity: MigrationEntityKind,
        sourceRow: Int,
        field: String? = nil,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.entity = entity
        self.sourceRow = sourceRow
        self.field = field
        self.message = message
    }
}

public struct MigrationEntitySummary: Codable, Equatable, Sendable {
    public var entity: MigrationEntityKind
    public var sourceRows: Int
    public var validRows: Int
    public var skippedRows: Int
    public var proposedInserts: Int
    public var proposedUpdates: Int

    public init(
        entity: MigrationEntityKind,
        sourceRows: Int,
        validRows: Int,
        skippedRows: Int,
        proposedInserts: Int,
        proposedUpdates: Int
    ) {
        self.entity = entity
        self.sourceRows = sourceRows
        self.validRows = validRows
        self.skippedRows = skippedRows
        self.proposedInserts = proposedInserts
        self.proposedUpdates = proposedUpdates
    }
}

public struct MigrationDryRunReport: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var sourceFingerprint: String
    public var summaries: [MigrationEntitySummary]
    public var issues: [MigrationIssue]

    public init(
        generatedAt: Date,
        sourceFingerprint: String,
        summaries: [MigrationEntitySummary],
        issues: [MigrationIssue]
    ) {
        self.generatedAt = generatedAt
        self.sourceFingerprint = sourceFingerprint
        self.summaries = summaries
        self.issues = issues
    }

    public var isReadyToApply: Bool {
        !issues.contains { $0.severity == .error }
    }

    public var proposedWriteCount: Int {
        summaries.reduce(0) { partial, summary in
            partial + summary.proposedInserts + summary.proposedUpdates
        }
    }
}
