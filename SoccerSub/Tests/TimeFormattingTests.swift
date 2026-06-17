import Testing
@testable import SoccerSub

struct TimeFormattingTests {

    @Test("0 seconds formats as '0 min'")
    func zero() {
        #expect(TimeFormatting.format(0) == "0 min")
    }

    @Test("Negative seconds are clamped to 0 and format as '0 min'")
    func negative() {
        #expect(TimeFormatting.format(-60) == "0 min")
    }

    @Test("1–59 seconds shows seconds-only label")
    func subMinuteSeconds() {
        #expect(TimeFormatting.format(1)  == "1 sec")
        #expect(TimeFormatting.format(45) == "45 sec")
        #expect(TimeFormatting.format(59) == "59 sec")
    }

    @Test("Exact minute multiples show minutes-only label")
    func exactMinutes() {
        #expect(TimeFormatting.format(60)   == "1 min")
        #expect(TimeFormatting.format(300)  == "5 min")
        #expect(TimeFormatting.format(1500) == "25 min")
        #expect(TimeFormatting.format(3600) == "60 min")
    }

    @Test("Mixed minutes and seconds shows compact mixed label")
    func mixed() {
        #expect(TimeFormatting.format(61)   == "1m 1s")
        #expect(TimeFormatting.format(1530) == "25m 30s")
        #expect(TimeFormatting.format(90)   == "1m 30s")
        #expect(TimeFormatting.format(3661) == "61m 1s")
    }
}
