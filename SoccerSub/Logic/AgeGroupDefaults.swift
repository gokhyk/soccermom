// No SwiftData or SwiftUI imports — pure Swift.

struct GameDefaults: Equatable {
    let playersOnField: Int
    let numberOfPeriods: Int
    let periodDurationSeconds: Int
    let breakDurationSeconds: Int
}

enum AgeGroupDefaults {
    static let allAgeGroups: [String] = ["U6", "U8", "U10", "U12", "U14", "U16/U19"]

    // Returned when the age group string is unrecognized.
    static let fallback = GameDefaults(
        playersOnField: 7,
        numberOfPeriods: 2,
        periodDurationSeconds: 1500,
        breakDurationSeconds: 300
    )

    static func defaults(for ageGroup: String) -> GameDefaults {
        switch ageGroup {
        case "U6":
            return GameDefaults(playersOnField: 4,  numberOfPeriods: 4,
                                periodDurationSeconds: 480,  breakDurationSeconds: 120)
        case "U8":
            return GameDefaults(playersOnField: 6,  numberOfPeriods: 4,
                                periodDurationSeconds: 600,  breakDurationSeconds: 120)
        case "U10":
            return GameDefaults(playersOnField: 7,  numberOfPeriods: 2,
                                periodDurationSeconds: 1500, breakDurationSeconds: 300)
        case "U12":
            return GameDefaults(playersOnField: 9,  numberOfPeriods: 2,
                                periodDurationSeconds: 1800, breakDurationSeconds: 300)
        case "U14":
            return GameDefaults(playersOnField: 11, numberOfPeriods: 2,
                                periodDurationSeconds: 2100, breakDurationSeconds: 600)
        case "U16/U19":
            return GameDefaults(playersOnField: 11, numberOfPeriods: 2,
                                periodDurationSeconds: 2400, breakDurationSeconds: 600)
        default:
            return fallback
        }
    }
}
