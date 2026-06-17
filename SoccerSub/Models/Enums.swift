// All persisted enums — each must be Codable so SwiftData can serialize them.

enum Position: String, Codable, CaseIterable {
    case goalkeeper
    case defender
    case midfielder
    case attacker
}

enum SubstitutionFrequency: String, Codable, CaseIterable {
    case frequent    // ~4 min of period time
    case normal      // ~7 min
    case infrequent  // ~12 min

    var displayName: String {
        switch self {
        case .frequent:   return "Frequent (~4 min)"
        case .normal:     return "Normal (~7 min)"
        case .infrequent: return "Infrequent (~12 min)"
        }
    }
}

enum GameStatus: String, Codable {
    case scheduled
    case inProgress
    case completed
}

enum AvailabilityStatus: String, Codable {
    case available
    case absent
}

enum OnFieldStatus: String, Codable {
    case onField
    case bench
    case absent
}

enum SubstitutionReason: String, Codable {
    case scheduled
    case injury
    case earlyLeave
    case lateArrival
}
