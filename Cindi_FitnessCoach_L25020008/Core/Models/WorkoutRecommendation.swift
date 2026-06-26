import Foundation

struct WorkoutRecommendation: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var subtitle: String
    var durationMinutes: Int
    var estimatedCalories: Int
    var systemImage: String
    var intensity: WorkoutIntensity

    init(
        title: String,
        subtitle: String,
        durationMinutes: Int,
        estimatedCalories: Int,
        systemImage: String,
        intensity: WorkoutIntensity
    ) {
        self.title = title
        self.subtitle = subtitle
        self.durationMinutes = durationMinutes
        self.estimatedCalories = estimatedCalories
        self.systemImage = systemImage
        self.intensity = intensity
    }

    init(plan: WorkoutPlan) {
        title = plan.title
        subtitle = plan.safetyNotes.first ?? plan.intensity.guidance
        durationMinutes = plan.durationMinutes
        estimatedCalories = plan.estimatedCalories
        systemImage = plan.intensity == .low ? "figure.cooldown" : "figure.run"
        intensity = plan.intensity
    }
}
