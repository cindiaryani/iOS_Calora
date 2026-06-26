import SwiftUI

#if canImport(SwiftData)
import SwiftData
#endif

struct WorkoutPlanRecommendationCard: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @StateObject private var historyStore = WorkoutSessionHistoryStore()
    @State private var isSessionPresented = false
    @State private var justCompleted = false
    #if canImport(SwiftData)
    @Environment(\.modelContext) private var modelContext
    #endif

    private var availableMinutesBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.availableWorkoutMinutes) },
            set: { viewModel.updateAvailableWorkoutMinutes(Int($0.rounded())) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controls

            NavigationLink {
                WorkoutPlanDetailView(plan: viewModel.recommendedPlan)
            } label: {
                planSummary
            }
            .buttonStyle(.plain)

            if justCompleted {
                Label("Workout completed today", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appPrimary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                isSessionPresented = true
            } label: {
                Label("Start workout", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(Color.appPrimary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .onChange(of: viewModel.recommendedPlan.id) { _ in
            justCompleted = false
        }
        .fullScreenCover(isPresented: $isSessionPresented) {
            WorkoutSessionView(plan: viewModel.recommendedPlan) {
                completeCurrentPlan()
            }
        }
    }

    private func completeCurrentPlan() {
        #if canImport(SwiftData)
        historyStore.saveCompleted(plan: viewModel.recommendedPlan, modelContext: modelContext)
        #else
        historyStore.saveCompleted(plan: viewModel.recommendedPlan)
        #endif
        withAnimation(.easeInOut(duration: 0.2)) {
            justCompleted = true
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Workout Recommendation")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Adjust time and intensity")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appPrimary)
                .frame(width: 36, height: 36)
                .background(Color.appPrimary.opacity(0.16), in: Circle())
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Intensity", selection: $viewModel.preferredWorkoutIntensity) {
                ForEach(WorkoutIntensity.allCases) { intensity in
                    Text(intensity.rawValue).tag(intensity)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Available time", systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(viewModel.availableWorkoutMinutes) min")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }

                Slider(value: availableMinutesBinding, in: 5...90, step: 5)
            }
            .foregroundStyle(Color.appTextPrimary)
        }
    }

    private var planSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.recommendedPlan.intensity == .low ? "figure.cooldown" : "figure.run")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(intensityColor)
                    .frame(width: 44, height: 44)
                    .background(intensityColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.recommendedPlan.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text(viewModel.recommendedPlan.safetyNotes.first ?? viewModel.recommendedPlan.intensity.guidance)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            HStack(spacing: 10) {
                metadata("clock", "\(viewModel.recommendedPlan.durationMinutes) min")
                metadata("flame", "\(viewModel.recommendedPlan.estimatedCalories) kcal")
                metadata("list.bullet", "\(viewModel.recommendedPlan.exercises.count) blocks")
            }
        }
        .padding(12)
        .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metadata(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextSecondary)
    }

    private var intensityColor: Color {
        switch viewModel.recommendedPlan.intensity {
        case .low:
            return .appIntensityLow
        case .moderate:
            return .appIntensityModerate
        case .high:
            return .appIntensityHigh
        }
    }
}
