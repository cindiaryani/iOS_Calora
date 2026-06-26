import XCTest
@testable import Cindi_FitnessCoach_L25020008

final class Cindi_FitnessCoach_L25020008Tests: XCTestCase {
    func testDailySnapshotProgressIsClampedToGoal() {
        let snapshot = DailyFitnessSnapshot(
            date: .now,
            calorieGoal: 500,
            activeEnergyBurned: 640,
            steps: 0,
            mindfulMinutes: 0
        )

        XCTAssertEqual(snapshot.progress, 1)
        XCTAssertEqual(snapshot.remainingCalories, 0)
        XCTAssertEqual(snapshot.progressPercent, 100)
    }

    func testRecommendationEngineSuggestsRecoveryWhenGoalIsComplete() {
        let snapshot = DailyFitnessSnapshot(
            date: .now,
            calorieGoal: 500,
            activeEnergyBurned: 510,
            steps: 0,
            mindfulMinutes: 0
        )

        let recommendations = RecommendationEngine().recommendations(for: snapshot)

        XCTAssertEqual(recommendations.first?.intensity, .recovery)
        XCTAssertEqual(recommendations.first?.title, "Mobility Reset")
    }

    func testRecommendationEngineSuggestsChallengeBeforeGoalIsReached() {
        let snapshot = DailyFitnessSnapshot(
            date: .now,
            calorieGoal: 600,
            activeEnergyBurned: 360,
            steps: 0,
            mindfulMinutes: 0
        )

        let recommendations = RecommendationEngine().recommendations(for: snapshot)

        XCTAssertTrue(recommendations.contains { $0.intensity == .challenge })
    }

    @MainActor
    func testViewModelShowsEmptyStateWhenHealthHasNoActiveEnergyToday() async {
        let viewModel = FitnessCoachViewModel(
            healthService: MockHealthService(activeEnergy: 0),
            recommendationEngine: RecommendationEngine()
        )

        await viewModel.requestHealthAccess()

        XCTAssertEqual(viewModel.healthState, .emptyToday)
        XCTAssertEqual(viewModel.snapshot.activeEnergyBurned, 0)
        XCTAssertTrue(viewModel.healthStatus.contains("no active energy"))
    }

    @MainActor
    func testViewModelLoadsTodayActiveEnergyFromHealthService() async {
        let viewModel = FitnessCoachViewModel(
            healthService: MockHealthService(activeEnergy: 420),
            recommendationEngine: RecommendationEngine()
        )

        await viewModel.requestHealthAccess()

        XCTAssertEqual(viewModel.healthState, .hasData)
        XCTAssertEqual(viewModel.snapshot.activeEnergyBurned, 420)
        XCTAssertEqual(viewModel.snapshot.steps, 7560)
    }
}

private struct MockHealthService: HealthDataProviding {
    let isHealthDataAvailable: Bool
    let activeEnergy: Double

    init(isHealthDataAvailable: Bool = true, activeEnergy: Double) {
        self.isHealthDataAvailable = isHealthDataAvailable
        self.activeEnergy = activeEnergy
    }

    func requestAuthorization() async throws {}

    func todayActiveEnergyBurned() async throws -> Double {
        activeEnergy
    }
}
