import Testing
@testable import SoccerSub

struct AgeGroupDefaultsTests {

    // MARK: Known age groups

    @Test("U6 defaults: 4 players, 4 periods, 8 min, 2 min break")
    func u6Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U6")
        #expect(d.playersOnField == 4)
        #expect(d.numberOfPeriods == 4)
        #expect(d.periodDurationSeconds == 480)
        #expect(d.breakDurationSeconds == 120)
    }

    @Test("U8 defaults: 6 players, 4 periods, 10 min, 2 min break")
    func u8Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U8")
        #expect(d.playersOnField == 6)
        #expect(d.numberOfPeriods == 4)
        #expect(d.periodDurationSeconds == 600)
        #expect(d.breakDurationSeconds == 120)
    }

    @Test("U10 defaults: 7 players, 2 periods, 25 min, 5 min break")
    func u10Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U10")
        #expect(d.playersOnField == 7)
        #expect(d.numberOfPeriods == 2)
        #expect(d.periodDurationSeconds == 1500)
        #expect(d.breakDurationSeconds == 300)
    }

    @Test("U12 defaults: 9 players, 2 periods, 30 min, 5 min break")
    func u12Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U12")
        #expect(d.playersOnField == 9)
        #expect(d.numberOfPeriods == 2)
        #expect(d.periodDurationSeconds == 1800)
        #expect(d.breakDurationSeconds == 300)
    }

    @Test("U14 defaults: 11 players, 2 periods, 35 min, 10 min break")
    func u14Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U14")
        #expect(d.playersOnField == 11)
        #expect(d.numberOfPeriods == 2)
        #expect(d.periodDurationSeconds == 2100)
        #expect(d.breakDurationSeconds == 600)
    }

    @Test("U16/U19 defaults: 11 players, 2 periods, 40 min, 10 min break")
    func u16u19Defaults() {
        let d = AgeGroupDefaults.defaults(for: "U16/U19")
        #expect(d.playersOnField == 11)
        #expect(d.numberOfPeriods == 2)
        #expect(d.periodDurationSeconds == 2400)
        #expect(d.breakDurationSeconds == 600)
    }

    // MARK: Fallback — must not crash

    @Test("Unrecognized age group returns fallback, not a crash")
    func unknownAgeGroupReturnsFallback() {
        let d = AgeGroupDefaults.defaults(for: "U99")
        #expect(d == AgeGroupDefaults.fallback)
    }

    @Test("Empty string returns fallback")
    func emptyStringReturnsFallback() {
        let d = AgeGroupDefaults.defaults(for: "")
        #expect(d == AgeGroupDefaults.fallback)
    }

    @Test("Arbitrary garbage string returns fallback")
    func garbageStringReturnsFallback() {
        let d = AgeGroupDefaults.defaults(for: "not-a-group")
        #expect(d == AgeGroupDefaults.fallback)
    }

    // MARK: allAgeGroups covers the spec table

    @Test("allAgeGroups contains all six spec entries")
    func allAgeGroupsHasSixEntries() {
        let expected = ["U6", "U8", "U10", "U12", "U14", "U16/U19"]
        #expect(AgeGroupDefaults.allAgeGroups == expected)
    }

    @Test("Every entry in allAgeGroups maps to a non-fallback default")
    func everyListedGroupHasOwnDefault() {
        for group in AgeGroupDefaults.allAgeGroups {
            let d = AgeGroupDefaults.defaults(for: group)
            #expect(d != AgeGroupDefaults.fallback || group == "U10",
                    "group \(group) unexpectedly returned the fallback value")
        }
    }
}
