import SwiftUI

/// First-launch setup. Collects name, body, goal, target, focus, and schedule, writes them to
/// the existing app settings + the `ProfileStoring` profile, then calls `onComplete`. Shown by
/// `RootView` only until onboarding is finished; everything stays editable later in Settings/Goals.
struct OnboardingView: View {
    let onComplete: () -> Void

    // Existing app settings these steps feed into.
    @AppStorage(FitnessCoachViewModel.bodyWeightKgKey) private var storedWeight = 72.0
    @AppStorage("heightCm") private var storedHeight = 170.0
    @AppStorage("dailyCalorieGoal") private var storedGoal = 640.0
    @AppStorage("userName") private var storedName = ""

    @State private var step = 0
    @State private var name = ""
    @State private var height = 170.0
    @State private var weight = 72.0
    @State private var goal: FitnessGoal = .getFitter
    @State private var targetCalories = 640.0
    @State private var focus: Set<FocusArea> = [.cardio, .strength]
    @State private var days: Set<Int> = [0, 2, 4]
    @State private var time: WorkoutTime = .flexible

    private let store: ProfileStoring = LocalProfileStore.shared
    private let totalSteps = 8
    private let accent = Color.appPrimary

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    stepContent
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                footer
            }
        }
        .onAppear {
            // Prefill from any existing settings.
            name = storedName
            height = storedHeight
            weight = storedWeight
            targetCalories = storedGoal
        }
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.appSurfaceMuted, in: Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }

                Spacer()

                Text("Step \(step + 1) of \(totalSteps)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Color.clear.frame(width: 40, height: 40)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.appSurfaceMuted).frame(height: 6)
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 6)
                        .animation(.easeInOut(duration: 0.25), value: step)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        Button {
            if step < totalSteps - 1 {
                withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
            } else {
                finish()
            }
        } label: {
            Text(footerTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var footerTitle: String {
        switch step {
        case 0: return "Get started"
        case totalSteps - 1: return "Start training"
        default: return "Continue"
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: nameStep
        case 2: bodyStep
        case 3: goalStep
        case 4: targetStep
        case 5: focusStep
        case 6: scheduleStep
        default: summaryStep
        }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                Circle().fill(accent.opacity(0.16)).frame(width: 96, height: 96)
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(accent)
            }
            .padding(.top, 24)

            title("Welcome to Calora", "Let's set up your plan in under a minute. You can change everything later.")
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("What's your name?", "We'll use it to greet you on your dashboard.")
            TextField("Your name", text: $name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1) }
                .textInputAutocapitalization(.words)
        }
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Your body", "Used for calorie estimates and BMI.")
            stepperRow(label: "Height", value: "\(Int(height)) cm") {
                Stepper("", value: $height, in: 120...220, step: 1).labelsHidden().tint(accent)
            }
            stepperRow(label: "Weight", value: "\(String(format: "%.1f", weight)) kg") {
                Stepper("", value: $weight, in: 35...200, step: 0.5).labelsHidden().tint(accent)
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("What's your goal?", "We'll tailor your plan around it.")
            ForEach(FitnessGoal.allCases) { option in
                selectableCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    systemImage: option.systemImage,
                    isSelected: goal == option
                ) {
                    goal = option
                }
            }
        }
    }

    private var targetStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Daily calorie target", "How many active calories do you want to burn each day?")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(targetCalories))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                Text("kcal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }

            Slider(value: $targetCalories, in: 250...1600, step: 10).tint(accent)

            HStack {
                Text("Light").font(.caption).foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text("Ambitious").font(.caption).foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("What do you want to focus on?", "Pick one or more.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(FocusArea.allCases) { area in
                    let selected = focus.contains(area)
                    Button {
                        if selected { focus.remove(area) } else { focus.insert(area) }
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: area.systemImage)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(selected ? Color.appOnPrimary : accent)
                            Text(area.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextPrimary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .background(selected ? accent : Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("When do you train?", "Pick your usual days and time.")

            VStack(alignment: .leading, spacing: 10) {
                Text("Days").font(.subheadline.weight(.bold)).foregroundStyle(Color.appTextPrimary)
                HStack(spacing: 6) {
                    ForEach(0..<7) { index in
                        let selected = days.contains(index)
                        Button {
                            if selected { days.remove(index) } else { days.insert(index) }
                        } label: {
                            Text(UserProfile.weekdayLabels[index].prefix(1))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected ? accent : Color.appSurface, in: Circle())
                                .overlay { Circle().stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Time").font(.subheadline.weight(.bold)).foregroundStyle(Color.appTextPrimary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(WorkoutTime.allCases) { option in
                        let selected = time == option
                        Button {
                            time = option
                        } label: {
                            Label(option.title, systemImage: option.systemImage)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextSecondary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(selected ? accent : Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            title(name.isEmpty ? "You're all set" : "All set, \(name)!", "Here's your plan. Tap start to begin.")

            summaryRow("person.fill", "Name", name.isEmpty ? "—" : name)
            summaryRow(goal.systemImage, "Goal", goal.title)
            summaryRow("flame.fill", "Daily target", "\(Int(targetCalories)) kcal")
            summaryRow("bolt.fill", "Focus", focus.isEmpty ? "—" : focus.map(\.title).joined(separator: ", "))
            summaryRow("calendar", "Days", days.isEmpty ? "—" : days.sorted().map { UserProfile.weekdayLabels[$0] }.joined(separator: " "))
            summaryRow("clock.fill", "Time", time.title)
        }
    }

    // MARK: - Reusable bits

    private func stepperRow<Control: View>(label: String, value: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.weight(.bold)).foregroundStyle(Color.appTextPrimary)
                Text(value).font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(accent)
            }
            Spacer()
            control()
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1) }
    }

    private func selectableCard(title: String, subtitle: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? Color.appOnPrimary : accent)
                    .frame(width: 46, height: 46)
                    .background(isSelected ? Color.white.opacity(0.18) : accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isSelected ? Color.appOnPrimary : Color.appTextPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.appOnPrimary.opacity(0.8) : Color.appTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appOnPrimary)
                }
            }
            .padding()
            .background(isSelected ? accent : Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.clear : Color.appBorder, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(_ systemImage: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.16), in: Circle())
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
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1) }
    }

    // MARK: - Finish

    private func finish() {
        // Feed the existing app settings so the dashboard, BMI, and calorie goal reflect this.
        storedName = name.trimmingCharacters(in: .whitespaces)
        storedHeight = height
        storedWeight = weight
        storedGoal = targetCalories

        // Persist the full profile (Firebase-ready via the ProfileStoring protocol).
        store.save(
            UserProfile(
                name: storedName,
                heightCm: height,
                weightKg: weight,
                goal: goal,
                targetCalories: targetCalories,
                focusAreas: Array(focus),
                workoutDays: days.sorted(),
                workoutTime: time,
                createdAt: .now
            )
        )

        onComplete()
    }
}
