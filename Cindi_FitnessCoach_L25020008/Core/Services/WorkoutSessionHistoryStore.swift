import Foundation
import Combine

#if canImport(SwiftData)
import SwiftData
#endif

final class WorkoutSessionHistoryStore: ObservableObject {
    @Published private(set) var records: [WorkoutSessionRecord] = []

    private let storageKey = "workoutSessionHistory"

    init() {
        loadFallbackRecords()
    }

    func saveCompleted(plan: WorkoutPlan) {
        let record = WorkoutSessionRecord(
            title: plan.title,
            estimatedCalories: plan.estimatedCalories,
            durationMinutes: plan.durationMinutes,
            completed: true
        )
        records.insert(record, at: 0)
        saveFallbackRecords()
    }

    #if canImport(SwiftData)
    func saveCompleted(plan: WorkoutPlan, modelContext: ModelContext) {
        let record = WorkoutSessionRecord(
            title: plan.title,
            estimatedCalories: plan.estimatedCalories,
            durationMinutes: plan.durationMinutes,
            completed: true
        )
        modelContext.insert(record)
        records.insert(record, at: 0)
    }
    #endif

    private func loadFallbackRecords() {
        #if canImport(SwiftData)
        records = []
        #else
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WorkoutSessionRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded
        #endif
    }

    private func saveFallbackRecords() {
        #if canImport(SwiftData)
        #else
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        #endif
    }
}
