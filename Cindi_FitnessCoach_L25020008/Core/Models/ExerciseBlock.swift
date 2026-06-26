import Foundation

struct ExerciseBlock: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var durationMinutes: Int
    var estimatedCalories: Int
    var muscleGroup: String
    var instructions: String
    var safetyNote: String

    init(
        id: UUID = UUID(),
        name: String,
        durationMinutes: Int,
        estimatedCalories: Int,
        muscleGroup: String,
        instructions: String,
        safetyNote: String
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.estimatedCalories = estimatedCalories
        self.muscleGroup = muscleGroup
        self.instructions = instructions
        self.safetyNote = safetyNote
    }
}
