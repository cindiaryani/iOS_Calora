import SwiftUI

struct WorkoutPlanDetailView: View {
    let plan: WorkoutPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                exerciseBlocks
                safetyNotes
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .navigationTitle("Plan Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            HStack(spacing: 10) {
                badge("clock", "\(plan.durationMinutes) min")
                badge("flame", "\(plan.estimatedCalories) kcal")
                badge("speedometer", plan.intensity.rawValue)
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var exerciseBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Blocks")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            ForEach(plan.exercises) { block in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(block.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Text("\(block.durationMinutes) min")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Text(block.muscleGroup)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)

                    Text(block.instructions)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)

                    Label(block.safetyNote, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding()
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.appBorder, lineWidth: 1)
                }
            }
        }
    }

    private var safetyNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Safety Notes")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            ForEach(plan.safetyNotes, id: \.self) { note in
                Label(note, systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func badge(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.appSurfaceMuted, in: Capsule())
    }
}
