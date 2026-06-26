import Foundation

struct RecommendationInput: Equatable {
    var targetCalories: Double
    var activeEnergyBurned: Double
    var availableMinutes: Int
    var preferredIntensity: WorkoutIntensity
    var bodyWeightPounds: Double
    var recentSessions: [WorkoutSessionSummary]
}
