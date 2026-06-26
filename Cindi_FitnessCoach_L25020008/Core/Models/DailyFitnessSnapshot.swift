import Foundation

struct DailyFitnessSnapshot: Equatable {
    var date: Date
    var calorieGoal: Double
    var activeEnergyBurned: Double
    var steps: Int
    var mindfulMinutes: Int

    var remainingCalories: Double {
        max(calorieGoal - activeEnergyBurned, 0)
    }

    var progress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(activeEnergyBurned / calorieGoal, 1)
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    static let sample = DailyFitnessSnapshot(
        date: .now,
        calorieGoal: 640,
        activeEnergyBurned: 385,
        steps: 7240,
        mindfulMinutes: 8
    )
}
