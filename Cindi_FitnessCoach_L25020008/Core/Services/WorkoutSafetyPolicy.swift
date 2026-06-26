import Foundation

struct WorkoutSafetyPolicy {
    func validatedPlan(_ plan: WorkoutPlan, input: RecommendationInput) -> WorkoutPlan? {
        guard !(plan.estimatedCalories > 800 && plan.durationMinutes < 30) else {
            return nil
        }

        var safePlan = plan
        if shouldFlagHighIntensity(plan: plan, recentSessions: input.recentSessions) {
            safePlan.safetyNotes.append("High intensity was adjusted because you logged an intense workout within the last 24 hours.")
            safePlan.intensity = .moderate
        }

        safePlan.safetyNotes.append("Stop if you feel pain, dizziness, chest discomfort, or unusual shortness of breath.")
        safePlan.safetyNotes.append("This is general fitness guidance, not a medical diagnosis.")
        safePlan.safetyNotes = Array(Set(safePlan.safetyNotes)).sorted()
        return safePlan
    }

    private func shouldFlagHighIntensity(plan: WorkoutPlan, recentSessions: [WorkoutSessionSummary]) -> Bool {
        guard plan.intensity == .high else { return false }
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        return recentSessions.contains { session in
            session.intensity == .high && session.date >= oneDayAgo
        }
    }
}
