import Foundation

protocol CalorieEstimating {
    func calories(metValue: Double, bodyWeightPounds: Double, durationMinutes: Int) -> Int
}

struct METCalorieEstimator: CalorieEstimating {
    func calories(metValue: Double, bodyWeightPounds: Double, durationMinutes: Int) -> Int {
        let weightKilograms = max(bodyWeightPounds, 1) * 0.45359237
        let durationHours = Double(max(durationMinutes, 0)) / 60
        return Int((metValue * weightKilograms * durationHours).rounded())
    }
}
