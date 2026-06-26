import Foundation

enum ExerciseCategory: String, Codable {
    case cardio
    case strength
    case mobility
}

struct CatalogExercise: Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: ExerciseCategory
    var intensity: WorkoutIntensity
    var metValue: Double
    var muscleGroup: String
    var equipment: String?
    var instructions: String
    var safetyNote: String

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        intensity: WorkoutIntensity,
        metValue: Double,
        muscleGroup: String,
        equipment: String? = nil,
        instructions: String,
        safetyNote: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.intensity = intensity
        self.metValue = metValue
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.instructions = instructions
        self.safetyNote = safetyNote
    }
}

protocol ExerciseCatalogProviding {
    var exercises: [CatalogExercise] { get }
    var warmUp: CatalogExercise { get }
    var cooldown: CatalogExercise { get }
}
