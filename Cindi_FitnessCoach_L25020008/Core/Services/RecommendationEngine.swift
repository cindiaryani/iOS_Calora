import Foundation

struct RecommendationEngine {
    private let workoutEngine: WorkoutRecommendationEngine

    init(workoutEngine: WorkoutRecommendationEngine = WorkoutRecommendationEngine()) {
        self.workoutEngine = workoutEngine
    }

    func recommendations(for snapshot: DailyFitnessSnapshot) -> [WorkoutRecommendation] {
        let primaryInput = RecommendationInput(
            targetCalories: snapshot.calorieGoal,
            activeEnergyBurned: snapshot.activeEnergyBurned,
            availableMinutes: snapshot.progress > 0.85 ? 12 : 25,
            preferredIntensity: snapshot.progress > 0.85 ? .low : .moderate,
            bodyWeightPounds: 160,
            recentSessions: []
        )
        let alternateInput = RecommendationInput(
            targetCalories: snapshot.calorieGoal,
            activeEnergyBurned: snapshot.activeEnergyBurned,
            availableMinutes: snapshot.progress > 0.5 ? 15 : 30,
            preferredIntensity: snapshot.progress > 0.85 ? .low : .high,
            bodyWeightPounds: 160,
            recentSessions: []
        )

        return [
            WorkoutRecommendation(plan: workoutEngine.recommendPlan(for: primaryInput)),
            WorkoutRecommendation(plan: workoutEngine.recommendPlan(for: alternateInput))
        ]
    }

    func plan(for input: RecommendationInput) -> WorkoutPlan {
        workoutEngine.recommendPlan(for: input)
    }
}
