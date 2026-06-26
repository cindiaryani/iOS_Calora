import Foundation

struct WorkoutPlan: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var estimatedCalories: Int
    var durationMinutes: Int
    var intensity: WorkoutIntensity
    var exercises: [ExerciseBlock]
    var safetyNotes: [String]

    init(
        id: UUID = UUID(),
        title: String,
        estimatedCalories: Int,
        durationMinutes: Int,
        intensity: WorkoutIntensity,
        exercises: [ExerciseBlock],
        safetyNotes: [String]
    ) {
        self.id = id
        self.title = title
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.exercises = exercises
        self.safetyNotes = safetyNotes
    }
}
