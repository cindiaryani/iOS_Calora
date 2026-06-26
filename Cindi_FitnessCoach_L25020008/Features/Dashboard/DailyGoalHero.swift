import SwiftUI

struct DailyGoalHero: View {
    let snapshot: DailyFitnessSnapshot

    /// Light ink that reads cleanly on the periwinkle hero gradient.
    private let ink = Color.white

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Today's Activities")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ink)

                    Text("Active energy")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ink.opacity(0.66))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(snapshot.activeEnergyBurned))")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("kcal")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(ink.opacity(0.66))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }

                Spacer(minLength: 8)

                progressRing
            }

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: snapshot.progress)
                    .tint(ink)
                    .accessibilityLabel("Daily calorie progress")

                Text(snapshot.remainingCalories > 0 ? "\(Int(snapshot.remainingCalories)) kcal left to close today's goal." : "Goal complete. Keep it light and recover well.")
                    .font(.callout)
                    .foregroundStyle(ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.appSecondary, Color.appPrimaryDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(ink.opacity(0.18), lineWidth: 10)

            Circle()
                .trim(from: 0, to: snapshot.progress)
                .stroke(ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(snapshot.progressPercent)%")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)

                Text("goal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.62))
            }
        }
        .frame(width: 74, height: 74)
        .accessibilityLabel("Goal progress \(snapshot.progressPercent) percent")
    }
}

struct DailyGoalHero_Previews: PreviewProvider {
    static var previews: some View {
        DailyGoalHero(snapshot: .sample)
            .padding()
    }
}
