import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct ModelRoundTripTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    // Helper: write with one context, read with a second context from the same container.
    private func roundTrip<T: PersistentModel>(
        container: ModelContainer,
        insert: (ModelContext) throws -> Void,
        fetch: (ModelContext) throws -> T?
    ) throws -> T? {
        let writeCtx = ModelContext(container)
        try insert(writeCtx)
        try writeCtx.save()

        let readCtx = ModelContext(container)
        return try fetch(readCtx)
    }

    // MARK: Team

    @Test("Team saves and fetches with all fields intact")
    func teamRoundTrip() throws {
        let container = try makeContainer()
        let teamId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(Team(
                id: teamId,
                name: "Storm",
                leagueName: "City League",
                ageGroup: "U12",
                defaultPlayersOnField: 9,
                defaultNumberOfPeriods: 2,
                defaultPeriodDurationSeconds: 1800,
                defaultBreakDurationSeconds: 300,
                colorThemeId: "green"
            ))
        } fetch: { ctx -> Team? in
            try ctx.fetch(FetchDescriptor<Team>()).first(where: { $0.id == teamId })
        }
        let team = try #require(result)
        #expect(team.name == "Storm")
        #expect(team.leagueName == "City League")
        #expect(team.ageGroup == "U12")
        #expect(team.defaultPlayersOnField == 9)
        #expect(team.defaultPeriodDurationSeconds == 1800)
        #expect(team.colorThemeId == "green")
    }

    // MARK: Player

    @Test("Player saves and fetches with all fields intact")
    func playerRoundTrip() throws {
        let container = try makeContainer()
        let playerId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(Player(
                id: playerId,
                name: "Grace",
                jerseyNumber: 11,
                canPlayGoalkeeper: false,
                seasonPlayedSeconds: 3600,
                seasonCreditedSeconds: 4200
            ))
        } fetch: { ctx -> Player? in
            try ctx.fetch(FetchDescriptor<Player>()).first(where: { $0.id == playerId })
        }
        let player = try #require(result)
        #expect(player.name == "Grace")
        #expect(player.jerseyNumber == 11)
        #expect(player.canPlayGoalkeeper == false)
        #expect(player.canPlayDefender == true)
        #expect(player.seasonPlayedSeconds == 3600)
        #expect(player.seasonCreditedSeconds == 4200)
    }

    // MARK: Game

    @Test("Game saves and fetches with all fields intact")
    func gameRoundTrip() throws {
        let container = try makeContainer()
        let gameId = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(Game(
                id: gameId,
                opponent: "Wolves",
                field: "Park Field 1",
                address: "123 Main St",
                dateTime: date,
                playersOnField: 9,
                numberOfPeriods: 2,
                periodDurationSeconds: 1800,
                substitutionFrequency: .frequent,
                status: .scheduled
            ))
        } fetch: { ctx -> Game? in
            try ctx.fetch(FetchDescriptor<Game>()).first(where: { $0.id == gameId })
        }
        let game = try #require(result)
        #expect(game.opponent == "Wolves")
        #expect(game.field == "Park Field 1")
        #expect(game.address == "123 Main St")
        #expect(game.periodDurationSeconds == 1800)
        #expect(game.substitutionFrequency == .frequent)
        #expect(game.status == .scheduled)
        #expect(game.dateTime == date)
    }

    // MARK: Availability

    @Test("Availability saves and fetches with status")
    func availabilityRoundTrip() throws {
        let container = try makeContainer()
        let availId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(Availability(id: availId, status: .absent))
        } fetch: { ctx -> Availability? in
            try ctx.fetch(FetchDescriptor<Availability>()).first(where: { $0.id == availId })
        }
        #expect(result?.status == .absent)
    }

    // MARK: PlayerGameAppearance

    @Test("PlayerGameAppearance saves and fetches with all fields intact")
    func pgaRoundTrip() throws {
        let container = try makeContainer()
        let pgaId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(PlayerGameAppearance(
                id: pgaId,
                secondsPlayed: 720,
                secondsCredited: 720,
                onFieldStatus: .onField,
                positionAssigned: .defender
            ))
        } fetch: { ctx -> PlayerGameAppearance? in
            try ctx.fetch(FetchDescriptor<PlayerGameAppearance>()).first(where: { $0.id == pgaId })
        }
        let pga = try #require(result)
        #expect(pga.secondsPlayed == 720)
        #expect(pga.secondsCredited == 720)
        #expect(pga.onFieldStatus == .onField)
        #expect(pga.positionAssigned == .defender)
    }

    // MARK: Enum encode/decode

    @Test("SubstitutionFrequency — all three values survive a save/fetch round-trip")
    func substitutionFrequencyAllValues() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        for freq in SubstitutionFrequency.allCases {
            ctx.insert(Game(opponent: freq.rawValue, substitutionFrequency: freq))
        }
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Game>())
        let freqs = Set(fetched.map(\.substitutionFrequency))
        #expect(freqs == Set(SubstitutionFrequency.allCases))
    }

    @Test("OnFieldStatus — all three values survive a save/fetch round-trip")
    func onFieldStatusAllValues() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        for status in [OnFieldStatus.onField, .bench, .absent] {
            ctx.insert(PlayerGameAppearance(onFieldStatus: status))
        }
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PlayerGameAppearance>())
        let statuses = Set(fetched.map(\.onFieldStatus))
        #expect(statuses.contains(.onField))
        #expect(statuses.contains(.bench))
        #expect(statuses.contains(.absent))
    }

    @Test("Position — all four values survive a save/fetch round-trip")
    func positionAllValues() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        for pos in Position.allCases {
            ctx.insert(PlayerGameAppearance(onFieldStatus: .bench, positionAssigned: pos))
        }
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<PlayerGameAppearance>())
        let positions = Set(fetched.compactMap(\.positionAssigned))
        #expect(positions == Set(Position.allCases))
    }

    @Test("AvailabilityStatus — both values survive a save/fetch round-trip")
    func availabilityStatusBothValues() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(Availability(status: .available))
        ctx.insert(Availability(status: .absent))
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Availability>())
        let statuses = Set(fetched.map(\.status))
        #expect(statuses.contains(.available))
        #expect(statuses.contains(.absent))
    }

    @Test("Optional Position nil saves and fetches as nil")
    func nilPositionRoundTrip() throws {
        let container = try makeContainer()
        let pgaId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(PlayerGameAppearance(id: pgaId, onFieldStatus: .bench, positionAssigned: nil))
        } fetch: { ctx -> PlayerGameAppearance? in
            try ctx.fetch(FetchDescriptor<PlayerGameAppearance>()).first(where: { $0.id == pgaId })
        }
        #expect(result?.positionAssigned == nil)
    }

    @Test("Game.address nil saves and fetches as nil")
    func nilAddressRoundTrip() throws {
        let container = try makeContainer()
        let gameId = UUID()
        let result = try roundTrip(container: container) { ctx in
            ctx.insert(Game(id: gameId, opponent: "Test", address: nil))
        } fetch: { ctx -> Game? in
            try ctx.fetch(FetchDescriptor<Game>()).first(where: { $0.id == gameId })
        }
        #expect(result?.address == nil)
    }
}
