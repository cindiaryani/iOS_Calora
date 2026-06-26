import Foundation

enum HealthConnectionState: Equatable {
    case unavailable
    case permissionNeeded
    case requestingPermission
    case loadingData
    case permissionDenied
    case emptyToday
    case hasData
    case usingA2AMock
}

@MainActor
final class FitnessCoachViewModel: ObservableObject {
    @Published private(set) var snapshot: DailyFitnessSnapshot
    @Published private(set) var recommendations: [WorkoutRecommendation]
    @Published private(set) var healthStatus: String
    @Published private(set) var healthState: HealthConnectionState
    @Published private(set) var lastHealthUpdate: Date?
    @Published private(set) var isLoading: Bool
    @Published var availableWorkoutMinutes: Int
    @Published var preferredWorkoutIntensity: WorkoutIntensity {
        didSet {
            recalculateWorkoutPlan()
        }
    }
    @Published private(set) var recommendedPlan: WorkoutPlan

    private let healthService: HealthDataProviding
    private let recommendationEngine: RecommendationEngine
    private let calorieGoalKey = "dailyCalorieGoal"
    static let bodyWeightKgKey = "bodyWeightKg"

    /// Body weight drives the calorie estimate. Sourced from Settings (kg) and
    /// converted to pounds; falls back to ~160 lb when unset. Static so it can be
    /// read during `init` before all stored properties are set.
    private static var bodyWeightPounds: Double {
        let kg = UserDefaults.standard.double(forKey: bodyWeightKgKey)
        return kg > 0 ? kg * 2.2046226218 : 160
    }

    /// Maps the onboarding goal to a starting workout intensity (the user can still change it).
    private static func defaultIntensity(for goal: FitnessGoal?) -> WorkoutIntensity {
        switch goal {
        case .buildMuscle: return .high
        case .maintain: return .low
        case .loseFat, .getFitter, .none: return .moderate
        }
    }

    init(
        healthService: HealthDataProviding = HealthKitHealthService(),
        recommendationEngine: RecommendationEngine = RecommendationEngine()
    ) {
        self.healthService = healthService
        self.recommendationEngine = recommendationEngine

        let savedGoal = UserDefaults.standard.double(forKey: calorieGoalKey)
        let goal = savedGoal > 0 ? savedGoal : 640
        let initialSnapshot = DailyFitnessSnapshot(
            date: .now,
            calorieGoal: goal,
            activeEnergyBurned: 0,
            steps: 0,
            mindfulMinutes: 0
        )

        snapshot = initialSnapshot
        recommendations = recommendationEngine.recommendations(for: initialSnapshot)
        availableWorkoutMinutes = 25

        // Personalize the default workout intensity from the onboarding goal, so different
        // users start with a different recommended plan.
        let goalIntensity = Self.defaultIntensity(for: LocalProfileStore.shared.load()?.goal)
        preferredWorkoutIntensity = goalIntensity
        recommendedPlan = recommendationEngine.plan(
            for: RecommendationInput(
                targetCalories: initialSnapshot.calorieGoal,
                activeEnergyBurned: initialSnapshot.activeEnergyBurned,
                availableMinutes: 25,
                preferredIntensity: goalIntensity,
                bodyWeightPounds: Self.bodyWeightPounds,
                recentSessions: []
            )
        )
        healthState = healthService.isHealthDataAvailable ? .permissionNeeded : .unavailable
        healthStatus = healthService.isHealthDataAvailable
            ? "Connect Apple Health to read today's active energy."
            : "Apple Health is not available on this device."
        lastHealthUpdate = nil
        isLoading = false
    }

    func prepare() async {
        guard healthService.isHealthDataAvailable else {
            healthState = .unavailable
            healthStatus = "Apple Health is not available on this device."
            return
        }

        healthState = .permissionNeeded
        healthStatus = "Connect Apple Health to read today's active energy."
    }

    func requestHealthAccess() async {
        guard healthService.isHealthDataAvailable else {
            healthState = .unavailable
            healthStatus = "Apple Health is not available on this device."
            return
        }

        healthState = .requestingPermission
        healthStatus = "Requesting Apple Health permission..."
        isLoading = true
        defer { isLoading = false }

        do {
            try await healthService.requestAuthorization()
            await refreshActiveEnergyAfterPermission()
        } catch {
            healthState = .permissionDenied
            healthStatus = "Health access was not granted. Enable Active Energy in Settings."
        }
    }

    func refreshActiveEnergy() async {
        if healthState == .usingA2AMock {
            refreshAppleHealthA2AMock()
            return
        }

        guard healthService.isHealthDataAvailable else {
            healthState = .unavailable
            healthStatus = "Apple Health is not available on this device."
            return
        }

        isLoading = true
        healthState = .loadingData
        healthStatus = "Reading today's active energy from Apple Health..."
        defer { isLoading = false }

        do {
            let activeEnergy = try await healthService.todayActiveEnergyBurned()
            applyHealthEnergy(activeEnergy)
        } catch {
            healthState = .permissionDenied
            healthStatus = "Could not read Active Energy. Check Health permission in Settings."
        }
    }

    func loadAppleHealthA2AMock() {
        applyAppleHealthA2AMock(statusPrefix: "Parsed")
    }

    func refreshAppleHealthA2AMock() {
        applyAppleHealthA2AMock(statusPrefix: "Synced")
    }

    func switchBackToAppleHealth() {
        lastHealthUpdate = nil

        guard healthService.isHealthDataAvailable else {
            healthState = .unavailable
            healthStatus = "Apple Health is not available on this device."
            updateSnapshot(activeEnergyBurned: 0)
            return
        }

        healthState = .permissionNeeded
        healthStatus = "A2A demo ended. Connect Apple Health to read today's active energy."
        updateSnapshot(activeEnergyBurned: 0)
    }

    func refreshCurrentHealthSource() async {
        if healthState == .usingA2AMock {
            refreshAppleHealthA2AMock()
        } else {
            await refreshActiveEnergy()
        }
    }

    private func applyAppleHealthA2AMock(statusPrefix: String) {
        do {
            let response = try AppleHealthA2AResponse.decodeMock()
            snapshot = response.makeSnapshot()
            recommendations = recommendationEngine.recommendations(for: snapshot)
            recalculateWorkoutPlan()
            healthState = .usingA2AMock
            lastHealthUpdate = .now
            healthStatus = "\(statusPrefix) A2A calorie data from \(response.sender.role). Health permission is not required for this demo."
        } catch {
            healthState = .permissionDenied
            healthStatus = "A2A mock JSON could not be parsed"
        }
    }

    func updateCalorieGoal(_ goal: Double) {
        let clampedGoal = min(max(goal, 250), 1600)
        UserDefaults.standard.set(clampedGoal, forKey: calorieGoalKey)
        snapshot.calorieGoal = clampedGoal
        recommendations = recommendationEngine.recommendations(for: snapshot)
        recalculateWorkoutPlan()
    }

    func updateAvailableWorkoutMinutes(_ minutes: Int) {
        availableWorkoutMinutes = min(max(minutes, 5), 90)
        recalculateWorkoutPlan()
    }

    /// Call after the user changes profile values (e.g. body weight) in Settings.
    func applyProfileChanges() {
        recalculateWorkoutPlan()
    }

    private func updateSnapshot(activeEnergyBurned: Double) {
        snapshot.activeEnergyBurned = activeEnergyBurned
        snapshot.date = .now
        snapshot.steps = estimatedSteps(from: activeEnergyBurned)
        snapshot.mindfulMinutes = estimatedMindfulMinutes(from: snapshot.progress)
        recommendations = recommendationEngine.recommendations(for: snapshot)
        recalculateWorkoutPlan()
    }

    private func refreshActiveEnergyAfterPermission() async {
        healthState = .loadingData
        healthStatus = "Permission granted. Reading today's active energy..."

        do {
            let activeEnergy = try await healthService.todayActiveEnergyBurned()
            applyHealthEnergy(activeEnergy)
        } catch {
            healthState = .permissionDenied
            healthStatus = "Permission was requested, but Active Energy could not be read."
        }
    }

    private func applyHealthEnergy(_ activeEnergy: Double) {
        updateSnapshot(activeEnergyBurned: activeEnergy)
        lastHealthUpdate = .now

        if activeEnergy > 0 {
            healthState = .hasData
            healthStatus = "Updated from Apple Health active energy."
        } else {
            healthState = .emptyToday
            healthStatus = "Apple Health is connected, but no active energy is recorded today."
        }
    }

    private func estimatedSteps(from activeEnergy: Double) -> Int {
        max(Int(activeEnergy * 18), 0)
    }

    private func estimatedMindfulMinutes(from progress: Double) -> Int {
        progress > 0.85 ? 10 : 5
    }

    private func recalculateWorkoutPlan() {
        recommendedPlan = recommendationEngine.plan(
            for: RecommendationInput(
                targetCalories: snapshot.calorieGoal,
                activeEnergyBurned: snapshot.activeEnergyBurned,
                availableMinutes: availableWorkoutMinutes,
                preferredIntensity: preferredWorkoutIntensity,
                bodyWeightPounds: Self.bodyWeightPounds,
                recentSessions: []
            )
        )
    }
}
