import MasterDanceCore
import Testing
@testable import MasterDanceAdmin

@Suite("Schedule age group colors")
struct ScheduleAgeGroupPaletteTests {
    @Test("The first twelve age groups use distinct palette positions")
    func distinguishesAgeGroups() {
        let groups = (1...12).map { AgeGroup(name: "Age group \($0)") }
        let palette = ScheduleAgeGroupPalette(ageGroups: groups)

        #expect(Set(groups.map { palette.index(for: $0.id) }) == Set(0..<12))
    }

    @Test("Renaming, reordering, and deactivating age groups keep the same colors")
    func ignoresPresentationChanges() {
        let groups = (1...8).map { AgeGroup(name: "Age group \($0)") }
        let original = ScheduleAgeGroupPalette(ageGroups: groups)
        let edited = groups.reversed().map { group in
            var value = group
            value.name = "Renamed \(group.name)"
            value.isActive = false
            return value
        }
        let updated = ScheduleAgeGroupPalette(ageGroups: edited)

        for group in groups {
            #expect(original.index(for: group.id) == updated.index(for: group.id))
        }
    }

    @Test("Missing age data uses the neutral fallback")
    func handlesMissingAgeGroups() {
        let palette = ScheduleAgeGroupPalette(ageGroups: [AgeGroup(name: "Configured age")])

        #expect(palette.index(for: nil) == ScheduleAgeGroupPalette.unassignedIndex)
        #expect(palette.index(for: AgeGroupID()) == ScheduleAgeGroupPalette.unassignedIndex)
    }

    @Test("Repeated age identities do not duplicate or shift palette entries")
    func handlesRepeatedIdentity() {
        let group = AgeGroup(name: "Shared age")
        let palette = ScheduleAgeGroupPalette(ageGroups: [group, group])

        #expect(palette.index(for: group.id) == 0)
    }
}
