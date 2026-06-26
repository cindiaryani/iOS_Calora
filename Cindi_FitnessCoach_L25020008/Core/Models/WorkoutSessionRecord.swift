import Foundation

#if canImport(SwiftData)
import SwiftData

@Model
final class WorkoutSessionRecord {
    var date: Date
    var title: String
    var estimatedCalories: Int
    var durationMinutes: Int
    var completed: Bool

    init(
        date: Date = .now,
        title: String,
        estimatedCalories: Int,
        durationMinutes: Int,
        completed: Bool
    ) {
        self.date = date
        self.title = title
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
        self.completed = completed
    }
}
#else
final class WorkoutSessionRecord: Codable, Identifiable {
    let id: UUID
    var date: Date
    var title: String
    var estimatedCalories: Int
    var durationMinutes: Int
    var completed: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        title: String,
        estimatedCalories: Int,
        durationMinutes: Int,
        completed: Bool
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
        self.completed = completed
    }
}
#endif
