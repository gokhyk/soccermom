import Testing
import Foundation
@testable import SoccerSub

struct LiveGameLogicTests {

    // MARK: – elapsedSeconds

    @Test("elapsedSeconds returns correct integer seconds")
    func elapsedSecondsBasic() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now   = start.addingTimeInterval(137)
        #expect(LiveGameLogic.elapsedSeconds(since: start, now: now) == 137)
    }

    @Test("elapsedSeconds truncates fractional seconds (floor)")
    func elapsedSecondsFloor() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now   = start.addingTimeInterval(59.9)
        #expect(LiveGameLogic.elapsedSeconds(since: start, now: now) == 59)
    }

    @Test("elapsedSeconds returns 0 when now equals startDate")
    func elapsedSecondsZero() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(LiveGameLogic.elapsedSeconds(since: start, now: start) == 0)
    }

    @Test("elapsedSeconds is never negative even when now is before startDate")
    func elapsedSecondsNeverNegative() {
        let start = Date(timeIntervalSince1970: 1_000_100)
        let now   = Date(timeIntervalSince1970: 1_000_000)  // before start
        #expect(LiveGameLogic.elapsedSeconds(since: start, now: now) == 0)
    }

    @Test("elapsedSeconds handles large gaps (simulating background)")
    func elapsedSecondsLargeGap() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let now   = start.addingTimeInterval(1800)  // full 30-min period
        #expect(LiveGameLogic.elapsedSeconds(since: start, now: now) == 1800)
    }

    // MARK: – applyTick: on-field players

    @Test("applyTick increments secondsPlayed for an on-field player")
    func tickIncrementsOnFieldSecondsPlayed() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .onField, secondsPlayed: 100, secondsCredited: 100
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 5)
        #expect(result[0].secondsPlayed == 105)
    }

    @Test("applyTick sets secondsCredited equal to secondsPlayed for an on-field player")
    func tickSetsCreditedEqualPlayedForOnField() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .onField, secondsPlayed: 200, secondsCredited: 200
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 10)
        #expect(result[0].secondsCredited == result[0].secondsPlayed)
        #expect(result[0].secondsCredited == 210)
    }

    // MARK: – applyTick: bench and absent players unchanged

    @Test("applyTick does not change a bench player's secondsPlayed")
    func tickLeavesBenchUnchanged() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .bench, secondsPlayed: 300, secondsCredited: 300
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 10)
        #expect(result[0].secondsPlayed   == 300)
        #expect(result[0].secondsCredited == 300)
    }

    @Test("applyTick does not change an absent player's secondsPlayed or secondsCredited")
    func tickLeavesAbsentUnchanged() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .absent, secondsPlayed: 0, secondsCredited: 500
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 10)
        #expect(result[0].secondsPlayed   == 0)
        #expect(result[0].secondsCredited == 500)
    }

    // MARK: – applyTick: delta edge cases

    @Test("applyTick with delta=0 is a no-op")
    func tickDeltaZeroIsNoOp() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .onField, secondsPlayed: 50, secondsCredited: 50
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 0)
        #expect(result[0].secondsPlayed == 50)
    }

    @Test("applyTick with negative delta is a no-op")
    func tickNegativeDeltaIsNoOp() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .onField, secondsPlayed: 50, secondsCredited: 50
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: -5)
        #expect(result[0].secondsPlayed == 50)
    }

    @Test("applyTick with a large delta correctly accumulates (simulates backgrounding)")
    func tickLargeDeltaAccumulates() {
        let player = LiveGameLogic.PlayerState(
            id: UUID(), status: .onField, secondsPlayed: 100, secondsCredited: 100
        )
        let result = LiveGameLogic.applyTick(to: [player], delta: 30)  // 30-second background gap
        #expect(result[0].secondsPlayed   == 130)
        #expect(result[0].secondsCredited == 130)
    }

    // MARK: – applyTick: mixed roster

    @Test("applyTick only updates on-field players in a mixed roster")
    func tickMixedRoster() {
        let onField = LiveGameLogic.PlayerState(id: UUID(), status: .onField,  secondsPlayed: 200, secondsCredited: 200)
        let bench   = LiveGameLogic.PlayerState(id: UUID(), status: .bench,    secondsPlayed: 100, secondsCredited: 100)
        let absent  = LiveGameLogic.PlayerState(id: UUID(), status: .absent,   secondsPlayed: 0,   secondsCredited: 300)

        let result = LiveGameLogic.applyTick(to: [onField, bench, absent], delta: 7)

        #expect(result[0].secondsPlayed == 207)  // on-field: incremented
        #expect(result[1].secondsPlayed == 100)  // bench: unchanged
        #expect(result[2].secondsPlayed == 0)    // absent: unchanged
        #expect(result[2].secondsCredited == 300) // absent credited stays fixed
    }
}
