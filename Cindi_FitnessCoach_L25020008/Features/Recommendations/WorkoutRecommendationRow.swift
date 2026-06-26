import SwiftUI

struct WorkoutRecommendationRow: View {
    let recommendation: WorkoutRecommendation
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: recommendation.systemImage)
                    .font(.title2)
                    .foregroundStyle(intensityColor)
                    .frame(width: 52, height: 52)
                    .background(intensityColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(recommendation.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text(recommendation.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            HStack(spacing: 10) {
                metadataBadge(systemImage: "clock", text: "\(recommendation.durationMinutes) min")
                metadataBadge(systemImage: "flame", text: "\(recommendation.estimatedCalories) kcal")
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func metadataBadge(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))

            Text(text)
                .font(.caption.weight(.medium))
                .monospacedDigit()
        }
        .foregroundStyle(Color.appTextSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.appSurfaceMuted, in: Capsule())
    }

    private var intensityColor: Color {
        switch recommendation.intensity {
        case .low:
            return .appIntensityLow
        case .moderate:
            return .appIntensityModerate
        case .high:
            return .appIntensityHigh
        }
    }
}

struct WorkoutRecommendationRow_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutRecommendationRow(recommendation: RecommendationEngine().recommendations(for: .sample)[0])
            .padding()
    }
}
