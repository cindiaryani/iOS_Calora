import Foundation

struct WorkoutSessionSummary: Identifiable, Equatable, Codable {
    let id: UUID
    var date: Date
    var title: String
    var intensity: WorkoutIntensity

    init(id: UUID = UUID(), date: Date, title: String, intensity: WorkoutIntensity) {
        self.id = id
        self.date = date
        self.title = title
        self.intensity = intensity
    }
}
