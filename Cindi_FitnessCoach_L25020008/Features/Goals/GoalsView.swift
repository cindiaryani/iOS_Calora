import SwiftUI

struct GoalsView: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @State private var draftGoal: Double = 640
    @State private var profile: UserProfile?
    @AppStorage("weeklyActiveDaysGoal") private var weeklyActiveDaysGoal = 4
    @AppStorage(FitnessCoachViewModel.bodyWeightKgKey) private var bodyWeightKg = 72.0
    @AppStorage("heightCm") private var heightCm = 170.0
    private let accent = Color.appPrimary

    private struct GoalPreset {
        let label: String
        let value: Double
    }

    private let goalPresets: [GoalPreset] = [
        GoalPreset(label: "Light · 400", value: 400),
        GoalPreset(label: "Balanced · 650", value: 650),
        GoalPreset(label: "Active · 900", value: 900),
        GoalPreset(label: "Max · 1200", value: 1200)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goals")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)

                            Text("Tune your daily calorie target")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "target")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appOnPrimary)
                            .frame(width: 44, height: 44)
                            .background(accent, in: Circle())
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(draftGoal))")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(Color.appAccent)

                            Text("kcal")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)

                            Spacer()

                            Text(goalLabel)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.appOnPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(accent, in: Capsule())
                        }

                        Slider(value: $draftGoal, in: 250...1600, step: 10) {
                            Text("Daily calorie goal")
                        } minimumValueLabel: {
                            Text("250")
                        } maximumValueLabel: {
                            Text("1600")
                        }
                        .tint(accent)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(goalPresets, id: \.label) { preset in
                                    presetChip(preset)
                                }
                            }
                            .padding(.vertical, 1)
                        }

                        Button {
                            viewModel.updateCalorieGoal(draftGoal)
                        } label: {
                            Label(isSaved ? "Saved" : "Save Goal",
                                  systemImage: isSaved ? "checkmark.seal.fill" : "checkmark.circle.fill")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(isSaved ? Color.appTextSecondary : Color.appOnPrimary)
                        .background(
                            isSaved ? Color.appSurfaceMuted : accent,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.appBorder, lineWidth: isSaved ? 1 : 0)
                        }
                        .disabled(isSaved)
                        .animation(.easeInOut(duration: 0.25), value: isSaved)
                    }
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }

                    if let profile {
                        yourPlanCard(profile)
                    }

                    bmiCard

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Today's progress", systemImage: "flame.fill")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)

                            Spacer()

                            Text("\(viewModel.snapshot.progressPercent)%")
                                .font(.headline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(accent)
                        }

                        ProgressView(value: viewModel.snapshot.progress)
                            .tint(accent)

                        HStack {
                            progressStat("\(Int(viewModel.snapshot.activeEnergyBurned))", "burned")
                            Spacer()
                            progressStat("\(Int(viewModel.snapshot.remainingCalories))", "to go")
                            Spacer()
                            progressStat("\(Int(viewModel.snapshot.calorieGoal))", "goal")
                        }
                    }
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Weekly active days", systemImage: "calendar")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)

                            Spacer()

                            Text("\(weeklyActiveDaysGoal)/7")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(accent)
                        }

                        HStack(spacing: 8) {
                            ForEach(0..<7) { index in
                                Circle()
                                    .fill(index < weeklyActiveDaysGoal ? accent : Color.appSurfaceMuted)
                                    .frame(height: 26)
                                    .overlay {
                                        Circle().stroke(Color.appBorder, lineWidth: index < weeklyActiveDaysGoal ? 0 : 1)
                                    }
                            }
                        }

                        Stepper("Target days per week", value: $weeklyActiveDaysGoal, in: 1...7)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                            .tint(accent)
                    }
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Relevant features")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)

                        featureRow("Adaptive workout picks based on goal progress", systemImage: "wand.and.stars")
                        featureRow("Recovery guidance when your goal is complete", systemImage: "figure.mind.and.body")
                        featureRow("Local goal storage for fast daily use", systemImage: "lock.fill")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                draftGoal = viewModel.snapshot.calorieGoal
                profile = LocalProfileStore.shared.load()
            }
            .onChange(of: viewModel.snapshot.calorieGoal) { newValue in
                draftGoal = newValue
            }
        }
    }

    private func yourPlanCard(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Your plan", systemImage: "person.crop.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Image(systemName: profile.goal.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 32, height: 32)
                    .background(accent.opacity(0.16), in: Circle())
            }

            planRow("Goal", profile.goal.title)
            planRow("Focus", profile.focusAreas.isEmpty ? "—" : profile.focusAreas.map(\.title).joined(separator: ", "))
            planRow("Time", profile.workoutTime.title)

            HStack(spacing: 6) {
                ForEach(0..<7) { index in
                    let active = profile.workoutDays.contains(index)
                    Text(UserProfile.weekdayLabels[index].prefix(1))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(active ? Color.appOnPrimary : Color.appTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(active ? accent : Color.appSurfaceMuted, in: Circle())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private func planRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private var bmiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Body Mass Index", systemImage: "figure.arms.open")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                Spacer()

                Text(bmiCategory.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(bmiCategory.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(bmiCategory.color.opacity(0.16), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(bmiValue, specifier: "%.1f")")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(bmiCategory.color)

                Text("kg/m²")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.appSecondary, Color.appPrimary, Color.appIntensityModerate, Color.appIntensityHigh],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 8)

                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .overlay { Circle().stroke(bmiCategory.color, lineWidth: 3) }
                        .offset(x: bmiMarkerX(width: geo.size.width))
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 18)

            Text("Based on \(bodyWeightKg, specifier: "%.0f") kg · \(heightCm, specifier: "%.0f") cm — update these in Settings.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var bmiValue: Double {
        let meters = heightCm / 100
        guard meters > 0 else { return 0 }
        return bodyWeightKg / (meters * meters)
    }

    private var bmiCategory: (label: String, color: Color) {
        switch bmiValue {
        case ..<18.5: return ("Underweight", .appSecondary)
        case 18.5..<25: return ("Normal", .appPrimary)
        case 25..<30: return ("Overweight", .appIntensityModerate)
        default: return ("Obese", .appIntensityHigh)
        }
    }

    /// Positions the marker along a 15–40 BMI scale.
    private func bmiMarkerX(width: CGFloat) -> CGFloat {
        let clamped = min(max(bmiValue, 15), 40)
        let fraction = (clamped - 15) / (40 - 15)
        return fraction * max(width - 16, 0)
    }

    private func presetChip(_ preset: GoalPreset) -> some View {
        let selected = Int(draftGoal) == Int(preset.value)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                draftGoal = preset.value
            }
        } label: {
            Text(preset.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextSecondary)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(selected ? accent : Color.appSurfaceMuted, in: Capsule())
                .overlay {
                    Capsule().stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func progressStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.appTextPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func featureRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 30, height: 30)
                .background(accent.opacity(0.18), in: Circle())

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    /// True when the draft matches the stored goal, i.e. there is nothing new to save.
    private var isSaved: Bool {
        Int(draftGoal) == Int(viewModel.snapshot.calorieGoal)
    }

    private var goalLabel: String {
        switch draftGoal {
        case 250..<500:
            return "Light"
        case 500..<900:
            return "Balanced"
        default:
            return "Ambitious"
        }
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView(viewModel: FitnessCoachViewModel())
    }
}
