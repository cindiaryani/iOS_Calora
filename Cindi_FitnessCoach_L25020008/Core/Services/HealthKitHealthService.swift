import Foundation
import HealthKit

final class HealthKitHealthService: HealthDataProviding {
    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else { return }
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        // MVP reads only activeEnergyBurned. Workouts, height, weight, and heart rate
        // should be requested later only when a personalized feature needs them.
        try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: [activeEnergyType])
    }

    func todayActiveEnergyBurned() async throws -> Double {
        guard isHealthDataAvailable else { return 0 }
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: .now,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let calories = statistics?
                    .sumQuantity()?
                    .doubleValue(for: .kilocalorie()) ?? 0

                continuation.resume(returning: calories)
            }

            healthStore.execute(query)
        }
    }
}
