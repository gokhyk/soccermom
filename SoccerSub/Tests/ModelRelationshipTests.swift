import Testing
import Foundation
import SwiftData
@testable import SoccerSub

@MainActor
struct ModelRelationshipTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Team.self, Player.self, Game.self, Availability.self, PlayerGameAppearance.self,
            configurations: config
        )
    }

    // MARK: Team ↔ Player

    @Test("Team.players is populated and Player.team back-link is set")
    func teamPlayerBidirectional() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let team = Team(name: "Tigers")
        let p1 = Player(name: "Alice", jerseyNumber: 7)
        let p2 = Player(name: "Bob", jerseyNumber: 10)
        ctx.insert(team); ctx.insert(p1); ctx.insert(p2)

        team.players.append(contentsOf: [p1, p2])
        try ctx.save()

        #expect(team.players.count == 2)
        #expect(team.players.contains(where: { $0.name == "Alice" }))
        #expect(team.players.contains(where: { $0.name == "Bob" }))
        #expect(p1.team?.name == "Tigers")
        #expect(p2.team?.name == "Tigers")
    }

    // MARK: Team ↔ Game

    @Test("Team.games is populated and Game.team back-link is set")
    func teamGameBidirectional() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let team = Team(name: "Lions")
        let game = Game(opponent: "Panthers")
        ctx.insert(team); ctx.insert(game)

        team.games.append(game)
        try ctx.save()

        #expect(team.games.count == 1)
        #expect(team.games.first?.opponent == "Panthers")
        #expect(game.team?.name == "Lions")
    }

    // MARK: Game ↔ Availability

    @Test("Game.availabilities is populated and Availability.game back-link is set")
    func gameAvailabilityBidirectional() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let game = Game(opponent: "Bears")
        let player = Player(name: "Carol", jerseyNumber: 5)
        let avail = Availability(status: .available)
        ctx.insert(game); ctx.insert(player); ctx.insert(avail)

        avail.player = player
        game.availabilities.append(avail)
        try ctx.save()

        #expect(game.availabilities.count == 1)
        #expect(game.availabilities.first?.status == .available)
        #expect(game.availabilities.first?.player?.name == "Carol")
        #expect(avail.game?.opponent == "Bears")
    }

    // MARK: Game ↔ PlayerGameAppearance and Player ↔ PlayerGameAppearance

    @Test("Game.appearances and Player.appearances are both populated; PGA back-links resolve")
    func appearanceBidirectional() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let game = Game(opponent: "Eagles")
        let player = Player(name: "Dave", jerseyNumber: 3)
        let pga = PlayerGameAppearance(secondsPlayed: 300, onFieldStatus: .onField, positionAssigned: .midfielder)
        ctx.insert(game); ctx.insert(player); ctx.insert(pga)

        pga.player = player
        pga.game = game
        game.appearances.append(pga)
        player.appearances.append(pga)
        try ctx.save()

        #expect(game.appearances.count == 1)
        #expect(player.appearances.count == 1)
        #expect(game.appearances.first?.secondsPlayed == 300)
        #expect(game.appearances.first?.positionAssigned == .midfielder)
        #expect(pga.game?.opponent == "Eagles")
        #expect(pga.player?.name == "Dave")
    }

    // MARK: Full object graph

    @Test("Full graph: team, two players, one game, availabilities, and appearances all resolve")
    func fullObjectGraph() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let team = Team(name: "Rockets", leagueName: "Youth League", ageGroup: "U10")
        let p1 = Player(name: "Eve", jerseyNumber: 1)
        let p2 = Player(name: "Frank", jerseyNumber: 2)
        let game = Game(opponent: "Comets", playersOnField: 7)
        let av1 = Availability(status: .available)
        let av2 = Availability(status: .absent)
        let pga1 = PlayerGameAppearance(onFieldStatus: .onField, positionAssigned: .goalkeeper)
        let pga2 = PlayerGameAppearance(onFieldStatus: .bench)

        for obj in [team, p1, p2] as [any PersistentModel] { ctx.insert(obj) }
        ctx.insert(game); ctx.insert(av1); ctx.insert(av2)
        ctx.insert(pga1); ctx.insert(pga2)

        team.players.append(contentsOf: [p1, p2])
        team.games.append(game)

        av1.player = p1; av2.player = p2
        game.availabilities.append(contentsOf: [av1, av2])

        pga1.player = p1; pga1.game = game
        pga2.player = p2; pga2.game = game
        game.appearances.append(contentsOf: [pga1, pga2])
        p1.appearances.append(pga1)
        p2.appearances.append(pga2)

        try ctx.save()

        #expect(team.players.count == 2)
        #expect(team.games.count == 1)
        #expect(game.availabilities.count == 2)
        #expect(game.appearances.count == 2)
        #expect(p1.team?.name == "Rockets")
        #expect(p2.team?.name == "Rockets")
        #expect(game.team?.name == "Rockets")
        #expect(pga1.game?.opponent == "Comets")
        #expect(pga1.player?.name == "Eve")
        #expect(pga2.player?.name == "Frank")
    }
}
