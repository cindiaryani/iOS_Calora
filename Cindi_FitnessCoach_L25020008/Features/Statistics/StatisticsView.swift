import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct StatisticsView: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @State private var range: StatRange = .weekly

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    StatRangePicker(selection: $range)

                    rangeStepper

                    PhysicalActivityCard(summary: summary)

                    caloriesChartCard

                    stepsChartCard

                    averagesRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.appPrimary.opacity(0.18))
                Image(systemName: "chart.bar.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appPrimary)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text("Statistics")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                Text("Your activity at a glance")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
            }

            Spacer()
        }
    }

    private var rangeStepper: some View {
        HStack {
            Image(systemName: "chevron.left")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 34, height: 34)
                .background(Color.appSurface, in: Circle())

            Spacer()

            Text(rangeLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 34, height: 34)
                .background(Color.appSurface, in: Circle())
        }
    }

    // MARK: - Charts

    private var caloriesChartCard: some View {
        ChartCard(title: "Calories burned", subtitle: "kcal per \(range.unitLabel)", accent: Color.appPrimary) {
            #if canImport(Charts)
            Chart(data) { point in
                BarMark(
                    x: .value("Label", point.label),
                    y: .value("Calories", point.calories)
                )
                .foregroundStyle(Color.appPrimary.gradient)
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.appBorder)
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(height: 170)
            #else
            FallbackBars(values: data.map(\.calories), accent: Color.appPrimary)
            #endif
        }
    }

    private var stepsChartCard: some View {
        ChartCard(title: "Steps", subtitle: "steps per \(range.unitLabel)", accent: Color.appSecondary) {
            #if canImport(Charts)
            Chart(data) { point in
                AreaMark(
                    x: .value("Label", point.label),
                    y: .value("Steps", point.steps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.appSecondary.opacity(0.45), Color.appSecondary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Label", point.label),
                    y: .value("Steps", point.steps)
                )
                .foregroundStyle(Color.appSecondary)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.appBorder)
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(height: 170)
            #else
            FallbackBars(values: data.map { Double($0.steps) }, accent: Color.appSecondary)
            #endif
        }
    }

    private var averagesRow: some View {
        HStack(spacing: 12) {
            AverageTile(
                title: "Steps",
                value: "\(summary.averageSteps)",
                delta: summary.stepsDelta,
                systemImage: "shoeprints.fill",
                tint: Color.appSecondary
            )
            AverageTile(
                title: "Calories",
                value: "\(summary.averageCalories)",
                delta: summary.caloriesDelta,
                systemImage: "flame.fill",
                tint: Color.appPrimary
            )
        }
    }

    // MARK: - Data

    private var rangeLabel: String {
        switch range {
        case .daily: return "Today"
        case .weekly: return "This week"
        case .monthly: return "This month"
        }
    }

    /// Deterministic sample series, lightly seeded by today's real snapshot so
    /// the screen feels connected to the user's data even without long history.
    private var data: [StatPoint] {
        let todayCalories = max(Int(viewModel.snapshot.activeEnergyBurned.rounded()), 0)
        let todaySteps = max(viewModel.snapshot.steps, 0)

        switch range {
        case .daily:
            let labels = ["6a", "9a", "12p", "3p", "6p", "9p"]
            return labels.enumerated().map { index, label in
                let weight = [0.10, 0.28, 0.22, 0.18, 0.14, 0.08][index]
                return StatPoint(
                    id: index,
                    label: label,
                    calories: Double(max(Int(Double(max(todayCalories, 420)) * weight), 12)),
                    steps: Int(Double(max(todaySteps, 6200)) * weight)
                )
            }
        case .weekly:
            let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let calBase = [0.78, 0.92, 0.64, 1.0, 0.86, 0.58, 0.7]
            let stepBase = [0.82, 0.95, 0.6, 1.0, 0.88, 0.66, 0.74]
            let dayIndex = (Calendar.current.component(.weekday, from: .now) + 5) % 7
            return labels.enumerated().map { index, label in
                let isToday = index == dayIndex
                return StatPoint(
                    id: index,
                    label: label,
                    calories: isToday ? Double(max(todayCalories, 300)) : (calBase[index] * 540).rounded(),
                    steps: isToday ? max(todaySteps, 5200) : Int(stepBase[index] * 9200)
                )
            }
        case .monthly:
            let labels = ["W1", "W2", "W3", "W4"]
            let calBase = [0.72, 0.88, 0.66, 0.94]
            let stepBase = [0.76, 0.9, 0.62, 0.98]
            return labels.enumerated().map { index, label in
                StatPoint(
                    id: index,
                    label: label,
                    calories: (calBase[index] * 3400).rounded(),
                    steps: Int(stepBase[index] * 58000)
                )
            }
        }
    }

    private var summary: StatSummary {
        let points = data
        let totalCalories = Int(points.reduce(0) { $0 + $1.calories })
        let totalSteps = points.reduce(0) { $0 + $1.steps }
        let count = max(points.count, 1)
        let trainingMinutes = Int((Double(totalCalories) / 9.5).rounded())

        return StatSummary(
            totalSteps: totalSteps,
            totalCalories: totalCalories,
            trainingMinutes: trainingMinutes,
            averageSteps: totalSteps / count,
            averageCalories: totalCalories / count,
            stepsDelta: range == .weekly ? 4 : (range == .daily ? 2 : 6),
            caloriesDelta: range == .weekly ? -2 : (range == .daily ? 1 : 3)
        )
    }
}

// MARK: - Range

enum StatRange: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var unitLabel: String {
        switch self {
        case .daily: return "block"
        case .weekly: return "day"
        case .monthly: return "week"
        }
    }
}

private struct StatPoint: Identifiable {
    let id: Int
    let label: String
    let calories: Double
    let steps: Int
}

private struct StatSummary {
    let totalSteps: Int
    let totalCalories: Int
    let trainingMinutes: Int
    let averageSteps: Int
    let averageCalories: Int
    let stepsDelta: Int
    let caloriesDelta: Int
}

// MARK: - Components

private struct StatRangePicker: View {
    @Binding var selection: StatRange

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StatRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = range
                    }
                } label: {
                    Text(range.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(selection == range ? Color.appOnPrimary : Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if selection == range {
                                Capsule().fill(Color.appPrimary)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Color.appSurface, in: Capsule())
        .overlay { Capsule().stroke(Color.appBorder, lineWidth: 1) }
    }
}

private struct PhysicalActivityCard: View {
    let summary: StatSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Physical Activity")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Total for the period")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 0) {
                stat("Steps", value: summary.totalSteps.formatted())
                divider
                stat("Calories", value: summary.totalCalories.formatted())
                divider
                stat("Training", value: trainingLabel)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.appSecondary, Color.appPrimaryDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private var trainingLabel: String {
        let hours = summary.trainingMinutes / 60
        let minutes = summary.trainingMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 34)
    }
}

private struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
            }

            content
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }
}

private struct AverageTile: View {
    let title: String
    let value: String
    let delta: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.18), in: Circle())

                Spacer()

                Text(delta >= 0 ? "+\(delta)%" : "\(delta)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(delta >= 0 ? Color.appPrimary : Color.appIntensityHigh)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((delta >= 0 ? Color.appPrimary : Color.appIntensityHigh).opacity(0.16), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }
}

#if !canImport(Charts)
/// Lightweight fallback if Swift Charts is unavailable on the toolchain.
private struct FallbackBars: View {
    let values: [Double]
    let accent: Color

    var body: some View {
        let maxValue = max(values.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                RoundedRectangle(cornerRadius: 6)
                    .fill(accent.gradient)
                    .frame(height: max(CGFloat(value / maxValue) * 150, 6))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 170, alignment: .bottom)
    }
}
#endif

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView(viewModel: FitnessCoachViewModel())
    }
}
