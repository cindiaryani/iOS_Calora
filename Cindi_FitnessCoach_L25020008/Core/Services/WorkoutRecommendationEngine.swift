import Foundation

struct WorkoutRecommendationEngine {
    private let catalog: ExerciseCatalogProviding
    private let calorieEstimator: CalorieEstimating
    private let safetyPolicy: WorkoutSafetyPolicy

    init(
        catalog: ExerciseCatalogProviding = MockExerciseCatalog(),
        calorieEstimator: CalorieEstimating = METCalorieEstimator(),
        safetyPolicy: WorkoutSafetyPolicy = WorkoutSafetyPolicy()
    ) {
        self.catalog = catalog
        self.calorieEstimator = calorieEstimator
        self.safetyPolicy = safetyPolicy
    }

    func recommendPlan(for input: RecommendationInput) -> WorkoutPlan {
        let remainingCalories = input.targetCalories - input.activeEnergyBurned

        if remainingCalories <= 0 {
            return safetyPolicy.validatedPlan(mobilityPlan(for: input), input: input) ?? mobilityPlan(for: input)
        }

        let minutes = max(input.availableMinutes, 5)
        let mainMinutes = minutes >= 15 ? max(minutes - 8, 5) : minutes
        let candidates = catalog.exercises
            .filter { isSafeCandidate($0, input: input) }
            .map { candidate in
                scoredCandidate(candidate, input: input, mainMinutes: mainMinutes, remainingCalories: remainingCalories)
            }
            .sorted { $0.score > $1.score }

        let selected = candidates.first?.exercise ?? catalog.exercises.first ?? catalog.cooldown
        let plan = buildPlan(from: selected, input: input, mainMinutes: mainMinutes)

        if let safePlan = safetyPolicy.validatedPlan(plan, input: input) {
            return safePlan
        }

        return safetyPolicy.validatedPlan(mobilityPlan(for: input), input: input) ?? mobilityPlan(for: input)
    }

    private func scoredCandidate(
        _ exercise: CatalogExercise,
        input: RecommendationInput,
        mainMinutes: Int,
        remainingCalories: Double
    ) -> (exercise: CatalogExercise, score: Double) {
        let calories = calorieEstimator.calories(
            metValue: exercise.metValue,
            bodyWeightPounds: input.bodyWeightPounds,
            durationMinutes: mainMinutes
        )
        let calorieFit = fitScore(value: Double(calories), target: max(remainingCalories, 1))
        let durationFit = fitScore(value: Double(mainMinutes), target: Double(max(input.availableMinutes, 1)))
        let intensityFit = exercise.intensity == input.preferredIntensity ? 1.0 : adjacentIntensityScore(exercise.intensity, input.preferredIntensity)
        let noveltyFit = noveltyScore(for: exercise, recentSessions: input.recentSessions)
        let equipmentFit = exercise.equipment == nil ? 1.0 : 0.55
        let safetyPenalty = safetyPenalty(for: exercise, input: input)

        let score = calorieFit * 0.45
            + durationFit * 0.20
            + intensityFit * 0.20
            + noveltyFit * 0.10
            + equipmentFit * 0.05
            - safetyPenalty

        return (exercise, score)
    }

    private func buildPlan(from exercise: CatalogExercise, input: RecommendationInput, mainMinutes: Int) -> WorkoutPlan {
        var blocks: [ExerciseBlock] = []

        if input.availableMinutes >= 15 {
            blocks.append(block(from: catalog.warmUp, minutes: 4, weight: input.bodyWeightPounds))
        }

        blocks.append(block(from: exercise, minutes: mainMinutes, weight: input.bodyWeightPounds))

        if input.availableMinutes >= 15 {
            blocks.append(block(from: catalog.cooldown, minutes: 4, weight: input.bodyWeightPounds))
        }

        return WorkoutPlan(
            title: title(for: exercise, input: input),
            estimatedCalories: blocks.map(\.estimatedCalories).reduce(0, +),
            durationMinutes: blocks.map(\.durationMinutes).reduce(0, +),
            intensity: exercise.intensity,
            exercises: blocks,
            safetyNotes: blocks.map(\.safetyNote)
        )
    }

    private func mobilityPlan(for input: RecommendationInput) -> WorkoutPlan {
        let minutes = max(min(input.availableMinutes, 20), 8)
        let blocks: [ExerciseBlock]

        if minutes >= 15 {
            blocks = [
                block(from: catalog.warmUp, minutes: 4, weight: input.bodyWeightPounds),
                block(from: catalog.cooldown, minutes: minutes - 8, weight: input.bodyWeightPounds),
                block(from: catalog.cooldown, minutes: 4, weight: input.bodyWeightPounds)
            ]
        } else {
            blocks = [block(from: catalog.cooldown, minutes: minutes, weight: input.bodyWeightPounds)]
        }

        return WorkoutPlan(
            title: "Mobility Reset",
            estimatedCalories: blocks.map(\.estimatedCalories).reduce(0, +),
            durationMinutes: blocks.map(\.durationMinutes).reduce(0, +),
            intensity: .low,
            exercises: blocks,
            safetyNotes: blocks.map(\.safetyNote) + ["You already reached today's active energy target, so this plan keeps effort easy."]
        )
    }

    private func block(from exercise: CatalogExercise, minutes: Int, weight: Double) -> ExerciseBlock {
        ExerciseBlock(
            name: exercise.name,
            durationMinutes: minutes,
            estimatedCalories: calorieEstimator.calories(
                metValue: exercise.metValue,
                bodyWeightPounds: weight,
                durationMinutes: minutes
            ),
            muscleGroup: exercise.muscleGroup,
            instructions: exercise.instructions,
            safetyNote: exercise.safetyNote
        )
    }

    private func isSafeCandidate(_ exercise: CatalogExercise, input: RecommendationInput) -> Bool {
        if input.availableMinutes < 10 && exercise.intensity == .high {
            return false
        }

        if safetyPenalty(for: exercise, input: input) >= 0.5 {
            return false
        }

        return true
    }

    private func fitScore(value: Double, target: Double) -> Double {
        guard target > 0 else { return 1 }
        let distance = abs(value - target) / target
        return max(0, 1 - distance)
    }

    private func adjacentIntensityScore(_ first: WorkoutIntensity, _ second: WorkoutIntensity) -> Double {
        abs(intensityRank(first) - intensityRank(second)) == 1 ? 0.65 : 0.25
    }

    private func intensityRank(_ intensity: WorkoutIntensity) -> Int {
        switch intensity {
        case .low:
            return 0
        case .moderate:
            return 1
        case .high:
            return 2
        }
    }

    private func noveltyScore(for exercise: CatalogExercise, recentSessions: [WorkoutSessionSummary]) -> Double {
        let recentTitles = recentSessions.map { $0.title.lowercased() }
        return recentTitles.contains { $0.contains(exercise.name.lowercased()) } ? 0.2 : 1.0
    }

    private func safetyPenalty(for exercise: CatalogExercise, input: RecommendationInput) -> Double {
        guard exercise.intensity == .high else { return 0 }
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        let recentHigh = input.recentSessions.contains { $0.intensity == .high && $0.date >= oneDayAgo }
        return recentHigh ? 0.6 : 0
    }

    private func title(for exercise: CatalogExercise, input: RecommendationInput) -> String {
        switch exercise.category {
        case .cardio:
            return "\(exercise.name) Calorie Builder"
        case .strength:
            return "\(exercise.name) Strength Block"
        case .mobility:
            return "Mobility Reset"
        }
    }
}
