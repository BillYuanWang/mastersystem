#if os(macOS)
import MasterDanceCore

struct ScheduleAgeGroupPalette {
    static let unassignedIndex = 11

    private let indices: [AgeGroupID: Int]

    init(ageGroups: [AgeGroup]) {
        // Use identities, not editable names or the administrator's row order.
        let ids = Set(ageGroups.map(\.id)).sorted { $0.description < $1.description }
        indices = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
    }

    func index(for ageGroupID: AgeGroupID?) -> Int {
        ageGroupID.flatMap { indices[$0] } ?? Self.unassignedIndex
    }
}
#endif
