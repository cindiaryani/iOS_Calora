import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case loseFat
    case buildMuscle
    case getFitter
    case maintain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseFat: return "Lose fat"
        case .buildMuscle: return "Build muscle"
        case .getFitter: return "Get fitter"
        case .maintain: return "Stay consistent"
        }
    }

    var subtitle: String {
        switch self {
        case .loseFat: return "Burn more, lean down"
        case .buildMuscle: return "Strength & size"
        case .getFitter: return "Energy & endurance"
        case .maintain: return "Keep the habit going"
        }
    }

    var systemImage: String {
        switch self {
        case .loseFat: return "flame.fill"
        case .buildMuscle: return "dumbbell.fill"
        case .getFitter: return "figure.run"
        case .maintain: return "checkmark.seal.fill"
        }
    }
}

enum FocusArea: String, Codable, CaseIterable, Identifiable {
    case cardio
    case strength
    case core
    case mobility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cardio: return "Cardio"
        case .strength: return "Strength"
        case .core: return "Core"
        case .mobility: return "Mobility"
        }
    }

    var systemImage: String {
        switch self {
        case .cardio: return "heart.fill"
        case .strength: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .mobility: return "figure.cooldown"
        }
    }
}

enum WorkoutTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case flexible

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .flexible: return "Flexible"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        case .flexible: return "clock.fill"
        }
    }
}

/// The user's setup captured during onboarding. Stored via `ProfileStoring` — locally now,
/// Firestore later — so the rest of the app never depends on where it lives.
struct UserProfile: Codable, Equatable {
    var name: String
    var heightCm: Double
    var weightKg: Double
    var goal: FitnessGoal
    var targetCalories: Double
    var focusAreas: [FocusArea]
    var workoutDays: [Int]          // 0 = Monday … 6 = Sunday
    var workoutTime: WorkoutTime
    var createdAt: Date

    static let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static let placeholder = UserProfile(
        name: "",
        heightCm: 170,
        weightKg: 72,
        goal: .getFitter,
        targetCalories: 640,
        focusAreas: [.cardio, .strength],
        workoutDays: [0, 2, 4],
        workoutTime: .flexible,
        createdAt: .now
    )
}
