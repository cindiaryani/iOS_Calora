import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @State private var selectedDate = Date.now
    @State private var selectedCategory: PlanCategory = .all
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showSettings = false
    @State private var resumeWorkout: InProgressWorkout?
    @State private var didApplyFocus = false
    @AppStorage("userName") private var userName = ""

    @ObservedObject private var progressStore = WorkoutProgressStore.shared
    @StateObject private var historyStore = WorkoutSessionHistoryStore()

    private let accent = Color.appPrimary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dashboardHeader

                    if isSearching {
                        searchField
                    }

                    WeeklyActivityStrip(selectedDate: $selectedDate)

                    DailyGoalHero(snapshot: viewModel.snapshot)

                    if !progressStore.items.isEmpty {
                        ContinueTrainingSection(items: progressStore.items) { workout in
                            resumeWorkout = workout
                        }
                    }

                    categoryPills

                    DailyPlanTimeline(
                        selectedDate: selectedDate,
                        selectedCategory: selectedCategory,
                        searchText: searchText,
                        recommendations: viewModel.recommendations
                    )

                    WorkoutPlanRecommendationCard(viewModel: viewModel)

                    Group {
                        CalorieGoalCard(currentGoal: viewModel.snapshot.calorieGoal) { goal in
                            viewModel.updateCalorieGoal(goal)
                        }

                        HealthStatusCard(
                            status: viewModel.healthStatus,
                            state: viewModel.healthState,
                            lastUpdated: viewModel.lastHealthUpdate,
                            isLoading: viewModel.isLoading,
                            requestPermission: {
                                Task {
                                    await viewModel.requestHealthAccess()
                                }
                            },
                            refresh: {
                                Task {
                                    await viewModel.refreshCurrentHealthSource()
                                }
                            },
                            loadMockA2A: {
                                viewModel.loadAppleHealthA2AMock()
                            },
                            switchBackToHealth: {
                                viewModel.switchBackToAppleHealth()
                            }
                        )

                        MetricGrid(snapshot: viewModel.snapshot)
                        CoachInsightCard(snapshot: viewModel.snapshot)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                // Default the plan filter to the user's primary focus, once.
                guard !didApplyFocus else { return }
                didApplyFocus = true
                if let focus = LocalProfileStore.shared.load()?.focusAreas.first {
                    selectedCategory = planCategory(for: focus)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel)
            }
            .fullScreenCover(item: $resumeWorkout) { workout in
                WorkoutSessionView(
                    plan: workout.plan,
                    resumeBlockIndex: workout.blockIndex,
                    resumeElapsedSeconds: workout.elapsedSeconds
                ) {
                    historyStore.saveCompleted(plan: workout.plan)
                }
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(userName.isEmpty ? "Today" : "Hi, \(userName)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                Text(Date.now.formatted(date: .complete, time: .omitted))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearching.toggle()
                    if !isSearching {
                        searchText = ""
                    }
                }
            } label: {
                headerIcon(isSearching ? "xmark" : "magnifyingglass")
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await viewModel.refreshCurrentHealthSource()
                }
            } label: {
                headerIcon("arrow.clockwise")
            }
            .disabled(
                viewModel.healthState == .unavailable ||
                viewModel.healthState == .permissionNeeded ||
                viewModel.healthState == .requestingPermission ||
                viewModel.healthState == .permissionDenied
            )
            .buttonStyle(.plain)

            Button {
                showSettings = true
            } label: {
                headerIcon("gearshape.fill")
            }
            .buttonStyle(.plain)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)

            TextField("Search today's plan", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var categoryPills: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline.weight(.bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PlanCategory.allCases) { category in
                        categoryPill(category)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func planCategory(for focus: FocusArea) -> PlanCategory {
        switch focus {
        case .cardio: return .cardio
        case .strength, .core: return .muscle
        case .mobility: return .recovery
        }
    }

    private func headerIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.appTextPrimary)
            .frame(width: 38, height: 38)
            .background(Color.appSurfaceMuted, in: Circle())
    }

    private func categoryPill(_ category: PlanCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            Label(category.title, systemImage: category.systemImage)
                .font(.subheadline.weight(.bold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(selectedCategory == category ? Color.appOnPrimary : Color.appTextSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(selectedCategory == category ? accent : Color.appSurface, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(selectedCategory == category ? Color.clear : Color.appBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(viewModel: FitnessCoachViewModel())
    }
}

private enum PlanCategory: String, CaseIterable, Identifiable {
    case all
    case cardio
    case muscle
    case form
    case recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .cardio:
            return "Cardio"
        case .muscle:
            return "Muscle"
        case .form:
            return "Form"
        case .recovery:
            return "Recovery"
        }
    }

    var systemImage: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .cardio:
            return "heart.fill"
        case .muscle:
            return "dumbbell"
        case .form:
            return "camera.viewfinder"
        case .recovery:
            return "figure.cooldown"
        }
    }
}

private struct ContinueTrainingSection: View {
    let items: [InProgressWorkout]
    let onResume: (InProgressWorkout) -> Void

    private let accent = Color.appPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue training")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            ForEach(items) { workout in
                card(workout)
            }
        }
    }

    private func card(_ workout: InProgressWorkout) -> some View {
        Button {
            onResume(workout)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: ExerciseDemo.forBlock(workout.plan.exercises.first?.name ?? "").symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 54, height: 54)
                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.plan.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)

                    Text("\(workout.plan.intensity.rawValue) · block \(min(workout.blockIndex + 1, workout.plan.exercises.count))/\(workout.plan.exercises.count)")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)

                    ProgressView(value: workout.progress)
                        .tint(accent)
                }

                VStack(spacing: 6) {
                    Text("\(workout.progressPercent)%")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accent)

                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(accent)
                }
            }
            .padding(14)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct WeeklyActivityStrip: View {
    @Binding var selectedDate: Date

    private let accent = Color.appPrimary
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { date in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = date
                    }
                } label: {
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)

                    VStack(spacing: 7) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextSecondary)

                        Text(date.formatted(.dateTime.day()))
                            .font(.subheadline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(selected ? Color.appOnPrimary : Color.appTextPrimary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(selected ? accent : Color.appSurface, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(selected ? Color.clear : Color.appBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var days: [Date] {
        (-3...3).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: .now)
        }
    }
}

private struct DailyPlanTimeline: View {
    let selectedDate: Date
    let selectedCategory: PlanCategory
    let searchText: String
    let recommendations: [WorkoutRecommendation]

    @State private var expandedItemID: String?

    private let accent = Color.appPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Plan")
                        .font(.headline.weight(.bold))

                    Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                Label("\(filteredItems.count)", systemImage: "calendar")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent, in: Capsule())
            }

            if filteredItems.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        timelineRow(item)
                    }
                }
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var filteredItems: [PlanItem] {
        planItems.filter { item in
            let matchesCategory = selectedCategory == .all || item.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty ||
                item.title.localizedCaseInsensitiveContains(query) ||
                item.category.title.localizedCaseInsensitiveContains(query)

            return matchesCategory && matchesSearch
        }
    }

    private var planItems: [PlanItem] {
        var items = recommendations.enumerated().map { index, recommendation in
            PlanItem(
                id: "\(index)-\(recommendation.title)",
                startTime: index == 0 ? "09:30" : "17:20",
                endTime: index == 0
                    ? endTime(from: "09:30", adding: recommendation.durationMinutes)
                    : endTime(from: "17:20", adding: recommendation.durationMinutes),
                title: recommendation.title,
                subtitle: recommendation.intensity.guidance,
                category: category(for: recommendation),
                durationMinutes: recommendation.durationMinutes,
                calories: recommendation.estimatedCalories,
                systemImage: recommendation.systemImage
            )
        }

        items.append(
            PlanItem(
                id: "form-check",
                startTime: "12:45",
                endTime: "12:55",
                title: "Form Check",
                subtitle: "Camera posture scan",
                category: .form,
                durationMinutes: 10,
                calories: 0,
                systemImage: "camera.viewfinder"
            )
        )

        items.append(
            PlanItem(
                id: "recovery-reset",
                startTime: "20:30",
                endTime: "20:42",
                title: "Recovery Reset",
                subtitle: "Mobility and breathing",
                category: .recovery,
                durationMinutes: 12,
                calories: 35,
                systemImage: "figure.cooldown"
            )
        )

        return items.sorted { $0.startTime < $1.startTime }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)

            Text("No plan items match this filter.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
    }

    private func timelineRow(_ item: PlanItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedItemID = expandedItemID == item.id ? nil : item.id
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.startTime)
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()

                    Text(item.endTime)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextSecondary)
                }
                .frame(width: 48, alignment: .trailing)

                VStack(spacing: 0) {
                    Circle()
                        .fill(accent)
                        .frame(width: 8, height: 8)

                    Rectangle()
                        .fill(Color.appBorder)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 10)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: item.systemImage)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)
                            .frame(width: 32, height: 32)
                            .background(accent.opacity(item.category == .recovery ? 0.12 : 0.18), in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)

                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(item.category.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.appSurface, in: Capsule())

                            Image(systemName: expandedItemID == item.id ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }

                    HStack(spacing: 12) {
                        metric("clock", "\(item.durationMinutes) min")
                        metric("flame", item.calories > 0 ? "\(item.calories) kcal" : "scan")
                    }

                    if expandedItemID == item.id {
                        Divider()

                        Text(detailText(for: item))
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.appSurfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.bottom, 12)
            }
        }
        .buttonStyle(.plain)
    }

    private func metric(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextSecondary)
    }

    private func category(for recommendation: WorkoutRecommendation) -> PlanCategory {
        let searchable = "\(recommendation.title) \(recommendation.systemImage)".lowercased()

        if searchable.contains("dumbbell") || searchable.contains("strength") || searchable.contains("muscle") {
            return .muscle
        }

        if recommendation.intensity == .low ||
            searchable.contains("cooldown") ||
            (searchable.contains("walk") && recommendation.durationMinutes <= 15) {
            return .recovery
        }

        return .cardio
    }

    private func detailText(for item: PlanItem) -> String {
        switch item.category {
        case .cardio:
            return "Keep the pace steady and stop with enough energy left for the rest of the day."
        case .muscle:
            return "Move with control, rest when your form drops, and keep the last reps clean."
        case .form:
            return "Open the Form tab when you are ready. The camera feedback will check posture, squat depth, and knee tracking."
        case .recovery:
            return "Use this as a low-pressure reset: breathe slowly, move gently, and avoid chasing calories."
        case .all:
            return "This item is part of today's adaptive plan."
        }
    }

    private func endTime(from startTime: String, adding minutes: Int) -> String {
        let parts = startTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return startTime }

        let total = parts[0] * 60 + parts[1] + minutes
        return String(format: "%02d:%02d", (total / 60) % 24, total % 60)
    }
}

private struct PlanItem: Identifiable {
    let id: String
    let startTime: String
    let endTime: String
    let title: String
    let subtitle: String
    let category: PlanCategory
    let durationMinutes: Int
    let calories: Int
    let systemImage: String
}
