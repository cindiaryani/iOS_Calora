import Foundation
import Combine

/// A workout the user started but hasn't finished yet, so the dashboard can offer to
/// resume it from the "Continue training" section.
struct InProgressWorkout: Identifiable, Codable, Equatable {
    let id: UUID            // matches the originating WorkoutPlan id
    let plan: WorkoutPlan
    let blockIndex: Int
    let elapsedSeconds: Int
    let totalSeconds: Int
    let updatedAt: Date

    var progress: Double {
        totalSeconds > 0 ? min(Double(elapsedSeconds) / Double(totalSeconds), 1) : 0
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }
}

/// Persists in-progress workouts in UserDefaults. A single shared instance keeps the
/// live session player and the dashboard "Continue training" cards in sync.
final class WorkoutProgressStore: ObservableObject {
    static let shared = WorkoutProgressStore()

    @Published private(set) var items: [InProgressWorkout] = []

    private let storageKey = "inProgressWorkouts"
    private let maxItems = 4

    init() {
        load()
    }

    /// Inserts or refreshes the progress for a plan. Dedupes by title so the same
    /// workout type shows a single card, newest first.
    func saveProgress(plan: WorkoutPlan, blockIndex: Int, elapsedSeconds: Int, totalSeconds: Int) {
        let entry = InProgressWorkout(
            id: plan.id,
            plan: plan,
            blockIndex: blockIndex,
            elapsedSeconds: elapsedSeconds,
            totalSeconds: totalSeconds,
            updatedAt: .now
        )
        var next = items.filter { $0.plan.title != plan.title }
        next.insert(entry, at: 0)
        items = Array(next.prefix(maxItems))
        persist()
    }

    /// Removes a workout from the continue list (e.g. once it is finished or discarded).
    func remove(title: String) {
        items.removeAll { $0.plan.title == title }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([InProgressWorkout].self, from: data) else {
            items = []
            return
        }
        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
