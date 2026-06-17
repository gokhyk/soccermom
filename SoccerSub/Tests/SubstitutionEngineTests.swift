import Testing
import Foundation
@testable import SoccerSub

struct SubstitutionEngineTests {

    // MARK: – Convenience builders

    private static let all: Set<Position> = [.goalkeeper, .defender, .midfielder, .attacker]

    private func field(_ seconds: Int, _ pos: Position, id: UUID = UUID()) -> OnFieldPlayer {
        OnFieldPlayer(id: id, secondsPlayed: seconds, position: pos)
    }

    private func bench(_ seconds: Int, _ positions: Set<Position>, id: UUID = UUID()) -> BenchPlayer {
        BenchPlayer(id: id, secondsPlayed: seconds, eligiblePositions: positions)
    }

    // MARK: – intervalSeconds

    @Test("Frequent interval is 240 s (4 min)")
    func frequentInterval() {
        #expect(SubstitutionEngine.intervalSeconds(for: .frequent) == 240)
    }

    @Test("Normal interval is 420 s (7 min)")
    func normalInterval() {
        #expect(SubstitutionEngine.intervalSeconds(for: .normal) == 420)
    }

    @Test("Infrequent interval is 720 s (12 min)")
    func infrequentInterval() {
        #expect(SubstitutionEngine.intervalSeconds(for: .infrequent) == 720)
    }

    @Test("All three frequency settings produce distinct intervals")
    func allFrequenciesDistinct() {
        let intervals = SubstitutionFrequency.allCases.map { SubstitutionEngine.intervalSeconds(for: $0) }
        #expect(Set(intervals).count == intervals.count)
    }

    // MARK: – nextCheckpoint

    @Test("First checkpoint from elapsed=0 with normal frequency is 420 s")
    func firstCheckpointFromZero() {
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 0,
            periodDurationSeconds: 1800,
            frequency: .normal
        )
        #expect(cp == 420)
    }

    @Test("Checkpoint advances past current elapsed time")
    func checkpointAdvances() {
        // elapsed=420 (just reached first checkpoint) → next should be 840
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 420,
            periodDurationSeconds: 1800,
            frequency: .normal
        )
        #expect(cp == 840)
    }

    @Test("Returns nil when next checkpoint would exceed period duration")
    func nilNearPeriodEnd() {
        // elapsed=1681 → next = ceil(1681/420)*420 = 5*420 = 2100 > 1800
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 1681,
            periodDurationSeconds: 1800,
            frequency: .normal
        )
        #expect(cp == nil)
    }

    @Test("Returns nil when elapsed equals period duration")
    func nilAtPeriodEnd() {
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 1800,
            periodDurationSeconds: 1800,
            frequency: .normal
        )
        #expect(cp == nil)
    }

    @Test("Frequent frequency produces 240 s checkpoints")
    func frequentCadence() {
        let cp1 = SubstitutionEngine.nextCheckpoint(elapsedPeriodSeconds: 0,   periodDurationSeconds: 1800, frequency: .frequent)
        let cp2 = SubstitutionEngine.nextCheckpoint(elapsedPeriodSeconds: 240, periodDurationSeconds: 1800, frequency: .frequent)
        #expect(cp1 == 240)
        #expect(cp2 == 480)
    }

    @Test("Infrequent frequency produces 720 s checkpoints")
    func infrequentCadence() {
        let cp1 = SubstitutionEngine.nextCheckpoint(elapsedPeriodSeconds: 0,   periodDurationSeconds: 1800, frequency: .infrequent)
        let cp2 = SubstitutionEngine.nextCheckpoint(elapsedPeriodSeconds: 720, periodDurationSeconds: 1800, frequency: .infrequent)
        #expect(cp1 == 720)
        #expect(cp2 == 1440)
    }

    @Test("Last valid checkpoint at exactly period_duration is still returned")
    func lastCheckpointExactlyAtPeriodEnd() {
        // period=1440, freq=.infrequent (720). elapsed=720 → next=1440 ≤ 1440 → Some(1440)
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 720,
            periodDurationSeconds: 1440,
            frequency: .infrequent
        )
        #expect(cp == 1440)
    }

    @Test("Short period with frequent sub shows first checkpoint within period")
    func shortPeriodFrequent() {
        // 5-min period, 4-min interval → one checkpoint at 240 s
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 0,
            periodDurationSeconds: 300,
            frequency: .frequent
        )
        #expect(cp == 240)
    }

    @Test("Very short period with no room for a checkpoint returns nil")
    func veryShortPeriodNoCheckpoint() {
        // 3-min period, 4-min interval → first checkpoint at 240 > 180 → nil
        let cp = SubstitutionEngine.nextCheckpoint(
            elapsedPeriodSeconds: 0,
            periodDurationSeconds: 180,
            frequency: .frequent
        )
        #expect(cp == nil)
    }

    // MARK: – shouldPromptSubstitution

    @Test("Prompts exactly at warningLeadSeconds before checkpoint")
    func promptsAtWarningLead() {
        // checkpoint=420, warning=60 → prompt at elapsed=360
        #expect(SubstitutionEngine.shouldPromptSubstitution(
            elapsedPeriodSeconds: 360,
            periodDurationSeconds: 1800,
            frequency: .normal
        ))
    }

    @Test("Does not prompt one second before warning window opens")
    func noPromptJustBeforeWindow() {
        // checkpoint=420, warning=60 → elapsed=359 → 420-359=61 > 60 → false
        #expect(!SubstitutionEngine.shouldPromptSubstitution(
            elapsedPeriodSeconds: 359,
            periodDurationSeconds: 1800,
            frequency: .normal
        ))
    }

    @Test("Stops prompting once elapsed equals the checkpoint (next checkpoint is now far away)")
    func noLongerPromptsAtCheckpointItself() {
        // At elapsed=420 the first checkpoint (420) is 'consumed'; nextCheckpoint returns 840.
        // 840 - 420 = 420 > warningLeadSeconds(60) → false.
        #expect(!SubstitutionEngine.shouldPromptSubstitution(
            elapsedPeriodSeconds: 420,
            periodDurationSeconds: 1800,
            frequency: .normal
        ))
    }

    @Test("Does not prompt after the last checkpoint in the period")
    func noPromptPastLastCheckpoint() {
        #expect(!SubstitutionEngine.shouldPromptSubstitution(
            elapsedPeriodSeconds: 1681,
            periodDurationSeconds: 1800,
            frequency: .normal
        ))
    }

    // MARK: – recommendedSubstitutions: basic behaviour

    @Test("Most-played on-field is paired with least-played eligible bench player")
    func basicPairing() {
        let aID = UUID(); let bID = UUID()
        let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .goalkeeper, id: aID), field(400, .defender, id: bID)],
            bench:   [bench(100, Self.all, id: xID), bench(200, Self.all, id: yID)]
        )

        #expect(pairs.count == 2)
        #expect(pairs[0].playerOut.id == aID && pairs[0].playerIn.id == xID)
        #expect(pairs[1].playerOut.id == bID && pairs[1].playerIn.id == yID)
    }

    @Test("Position is correctly propagated to each pair")
    func positionPropagated() {
        let a = field(600, .midfielder)
        let x = bench(100, [.midfielder, .attacker])

        let pairs = SubstitutionEngine.recommendedSubstitutions(onField: [a], bench: [x])
        #expect(pairs.first?.position == .midfielder)
    }

    // MARK: – recommendedSubstitutions: position eligibility

    @Test("Ineligible bench player is skipped; next eligible one is chosen")
    func positionEligibilityFiltering() {
        let aID = UUID(); let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .goalkeeper, id: aID)],
            bench:   [
                bench(100, [.defender, .midfielder], id: xID),  // can't play GK ← skip
                bench(200, [.goalkeeper, .defender], id: yID),  // can play GK  ← choose
            ]
        )

        #expect(pairs.count == 1)
        #expect(pairs[0].playerOut.id == aID)
        #expect(pairs[0].playerIn.id == yID)
    }

    @Test("No bench player can fill any open position → empty result")
    func noEligiblePlayerForPosition() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .goalkeeper)],
            bench:   [bench(100, [.defender]), bench(200, [.midfielder])]
        )
        #expect(pairs.isEmpty)
    }

    @Test("Position constraints on multiple on-field players are all respected")
    func multiplePositionConstraints() {
        let aID = UUID(); let bID = UUID(); let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(600, .goalkeeper, id: aID),
                field(500, .defender,   id: bID),
            ],
            bench: [
                bench(100, [.defender],              id: xID),  // GK ineligible
                bench(200, [.goalkeeper, .defender],  id: yID),  // both eligible
            ]
        )

        // A(GK) → Y (only GK-eligible remaining after X is skipped for A)
        // B(DEF) → X (DEF-eligible)
        #expect(pairs.count == 2)
        let outIDs = Set(pairs.map { $0.playerOut.id })
        let inIDs  = Set(pairs.map { $0.playerIn.id  })
        #expect(outIDs == [aID, bID])
        #expect(inIDs  == [xID, yID])
    }

    // MARK: – recommendedSubstitutions: gap / fairness checks

    @Test("Swap is skipped when bench player has more secondsPlayed than on-field player")
    func swapNotBeneficialSkipped() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(400, .goalkeeper)],
            bench:   [bench(500, Self.all)]   // bench played MORE
        )
        #expect(pairs.isEmpty)
    }

    @Test("Swap is skipped when bench player has equal secondsPlayed")
    func swapNotBeneficialEqualSeconds() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(400, .goalkeeper)],
            bench:   [bench(400, Self.all)]   // bench played SAME
        )
        #expect(pairs.isEmpty)
    }

    @Test("Position-constrained case: A's only GK sub played more, but B's DEF sub is valid")
    func positionConstrainedGapContinue() {
        // Using `continue` (not `break`) on gap failure is what makes this work.
        let aID = UUID(); let bID = UUID()
        let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(600, .goalkeeper, id: aID),  // only Y can play GK, Y.seconds=700 ≥ 600 → skip
                field(500, .defender,   id: bID),  // X can play DEF, X.seconds=300 < 500 → pair
            ],
            bench: [
                bench(300, [.defender],  id: xID),
                bench(700, [.goalkeeper], id: yID),
            ]
        )

        #expect(pairs.count == 1)
        #expect(pairs[0].playerOut.id == bID)
        #expect(pairs[0].playerIn.id  == xID)
    }

    @Test("Mixed: some pairs beneficial, some not — only beneficial pairs returned")
    func mixedBeneficialAndNot() {
        let aID = UUID(); let bID = UUID()
        let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(600, .goalkeeper, id: aID),  // X(100) < 600 → beneficial
                field(300, .defender,   id: bID),  // Y(400) ≥ 300 → not beneficial
            ],
            bench: [
                bench(100, Self.all, id: xID),
                bench(400, Self.all, id: yID),
            ]
        )

        #expect(pairs.count == 1)
        #expect(pairs[0].playerOut.id == aID)
        #expect(pairs[0].playerIn.id  == xID)
    }

    // MARK: – recommendedSubstitutions: limits and edge cases

    @Test("maxSubstitutions cap is respected")
    func maxSubstitutionsCap() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(600, .goalkeeper),
                field(500, .defender),
                field(400, .midfielder),
            ],
            bench: [
                bench(100, Self.all),
                bench(150, Self.all),
                bench(200, Self.all),
            ],
            maxSubstitutions: 2
        )
        #expect(pairs.count == 2)
    }

    @Test("Empty on-field list returns empty result")
    func emptyOnField() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [],
            bench:   [bench(100, Self.all)]
        )
        #expect(pairs.isEmpty)
    }

    @Test("Empty bench list returns empty result")
    func emptyBench() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .goalkeeper)],
            bench:   []
        )
        #expect(pairs.isEmpty)
    }

    @Test("Bench players are never double-booked across pairs")
    func noDoubleBooking() {
        let aID = UUID(); let bID = UUID()
        let xID = UUID(); let yID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(600, .goalkeeper, id: aID),
                field(500, .goalkeeper, id: bID),
            ],
            bench: [
                bench(100, [.goalkeeper], id: xID),
                bench(200, [.goalkeeper], id: yID),
            ]
        )

        #expect(pairs.count == 2)
        let inIDs = pairs.map { $0.playerIn.id }
        #expect(Set(inIDs).count == 2)   // both bench players used once
    }

    @Test("Large bench: only the least-played eligible player is suggested per slot")
    func largeBenchPicksLeastPlayed() {
        let leastID = UUID()

        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .midfielder)],
            bench: [
                bench(500, Self.all),
                bench(50,  Self.all, id: leastID),  // ← should be chosen
                bench(200, Self.all),
            ]
        )

        #expect(pairs.count == 1)
        #expect(pairs[0].playerIn.id == leastID)
    }

    @Test("On-field players with equal secondsPlayed all get valid pairings")
    func tiedOnFieldPlayersAllPaired() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [
                field(400, .goalkeeper),
                field(400, .defender),
            ],
            bench: [
                bench(100, Self.all),
                bench(150, Self.all),
            ]
        )
        #expect(pairs.count == 2)
    }

    @Test("More bench players than open slots: extras are unused")
    func moreBenchThanSlots() {
        let pairs = SubstitutionEngine.recommendedSubstitutions(
            onField: [field(600, .goalkeeper)],
            bench: [
                bench(50,  [.goalkeeper]),
                bench(100, [.goalkeeper]),
                bench(200, [.goalkeeper]),
            ]
        )
        // Only one on-field player → only one pair possible
        #expect(pairs.count == 1)
        #expect(pairs[0].playerIn.secondsPlayed == 50)  // least played chosen
    }

    // MARK: – immediateSubstitution

    @Test("Returns the least-played eligible bench player")
    func immediateSubPicksLeastPlayed() {
        let outID = UUID(); let zID = UUID()
        let outgoing = field(600, .goalkeeper, id: outID)

        let pair = SubstitutionEngine.immediateSubstitution(
            outgoing: outgoing,
            bench: [
                bench(400, [.defender]),                        // GK-ineligible
                bench(300, Self.all),                           // eligible, 300 s
                bench(100, [.goalkeeper], id: zID),             // eligible, 100 s ← expected
            ]
        )

        #expect(pair?.playerOut.id == outID)
        #expect(pair?.playerIn.id  == zID)
        #expect(pair?.position     == .goalkeeper)
    }

    @Test("Returns nil when no bench player can cover the open position")
    func immediateSubNilWhenNoEligible() {
        let pair = SubstitutionEngine.immediateSubstitution(
            outgoing: field(600, .goalkeeper),
            bench: [
                bench(100, [.defender]),
                bench(200, [.midfielder]),
            ]
        )
        #expect(pair == nil)
    }

    @Test("Immediate sub ignores the played-time gap check (injury forces a swap)")
    func immediateSubIgnoresGapCheck() {
        let xID = UUID()
        let pair = SubstitutionEngine.immediateSubstitution(
            outgoing: field(300, .defender),
            bench: [bench(700, [.defender], id: xID)]  // bench played MORE than outgoing
        )
        #expect(pair != nil)
        #expect(pair?.playerIn.id == xID)
    }

    @Test("Immediate sub correctly assigns the outgoing player's position to the pair")
    func immediateSubAssignsPosition() {
        let pair = SubstitutionEngine.immediateSubstitution(
            outgoing: field(500, .attacker),
            bench: [bench(100, Self.all)]
        )
        #expect(pair?.position == .attacker)
    }

    @Test("Immediate sub with single eligible player returns that player")
    func immediateSubSingleEligible() {
        let xID = UUID()
        let pair = SubstitutionEngine.immediateSubstitution(
            outgoing: field(400, .midfielder),
            bench: [bench(200, [.midfielder], id: xID)]
        )
        #expect(pair?.playerIn.id == xID)
    }
}
