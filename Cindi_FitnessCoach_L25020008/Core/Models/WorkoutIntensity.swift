import Foundation

enum WorkoutIntensity: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"

    var id: String { rawValue }

    var guidance: String {
        switch self {
        case .low:
            return "Easy pace"
        case .moderate:
            return "Comfortably hard"
        case .high:
            return "Push intervals"
        }
    }

    var metRange: ClosedRange<Double> {
        switch self {
        case .low:
            return 1.8...3.4
        case .moderate:
            return 3.5...6.5
        case .high:
            return 6.6...12.0
        }
    }
}
