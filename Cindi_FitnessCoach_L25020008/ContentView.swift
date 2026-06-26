import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @StateObject private var viewModel = FitnessCoachViewModel()
    @State private var selection: AppTab = .today

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                FloatingTabBar(selection: $selection)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
            }
        }
        .tint(Color.appPrimary)
        .task {
            await viewModel.prepare()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .today:
            DashboardView(viewModel: viewModel)
        case .coach:
            RecommendationsView(viewModel: viewModel)
        case .stats:
            StatisticsView(viewModel: viewModel)
        case .goals:
            GoalsView(viewModel: viewModel)
        }
    }
}

// MARK: - Tabs

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case coach
    case stats
    case goals

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: return "house.fill"
        case .coach: return "figure.run"
        case .stats: return "chart.bar.fill"
        case .goals: return "target"
        }
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .coach: return "Coach"
        case .stats: return "Statistics"
        case .goals: return "Goals"
        }
    }
}

// MARK: - Floating tab bar

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: .semibold))

                        if selection == tab {
                            Text(tab.title)
                                .font(.subheadline.weight(.bold))
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(selection == tab ? Color.appOnPrimary : Color.appTextSecondary)
                    .padding(.horizontal, selection == tab ? 16 : 12)
                    .frame(height: 46)
                    .background {
                        if selection == tab {
                            Capsule().fill(Color.appPrimary)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color.appSurface, in: Capsule())
        .overlay {
            Capsule().stroke(Color.appBorder, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 18, x: 0, y: 10)
    }
}

private enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var title: String { self == .metric ? "Metric (kg)" : "Imperial (lb)" }
}

struct SettingsView: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("unitSystem") private var unitSystem = UnitSystem.metric.rawValue
    @AppStorage(FitnessCoachViewModel.bodyWeightKgKey) private var bodyWeightKg = 72.0
    @AppStorage("heightCm") private var heightCm = 170.0
    @AppStorage("restSeconds") private var restSeconds = 20
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showResetConfirm = false

    private var units: UnitSystem { UnitSystem(rawValue: unitSystem) ?? .metric }

    /// Body weight is stored in kg; show/edit in the user's chosen unit.
    private var weightBinding: Binding<Double> {
        Binding(
            get: { units == .metric ? bodyWeightKg : bodyWeightKg * 2.2046226218 },
            set: {
                bodyWeightKg = units == .metric ? $0 : $0 / 2.2046226218
                viewModel.applyProfileChanges()
            }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let email = Auth.auth().currentUser?.email {
                        HStack {
                            Text("Signed in")
                            Spacer()
                            Text(email)
                                .foregroundStyle(Color.appTextSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Button(role: .destructive) {
                        try? Auth.auth().signOut()
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }

                Section("Profile") {
                    Picker("Units", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases) { unit in
                            Text(unit.title).tag(unit.rawValue)
                        }
                    }

                    Stepper(value: weightBinding, in: units == .metric ? 35...200 : 77...440, step: units == .metric ? 0.5 : 1) {
                        HStack {
                            Text("Body weight")
                            Spacer()
                            Text(units == .metric ? "\(bodyWeightKg, specifier: "%.1f") kg" : "\(bodyWeightKg * 2.2046226218, specifier: "%.0f") lb")
                                .foregroundStyle(Color.appTextSecondary)
                                .monospacedDigit()
                        }
                    }

                    Stepper(value: $heightCm, in: 120...220, step: 1) {
                        HStack {
                            Text("Height")
                            Spacer()
                            Text("\(heightCm, specifier: "%.0f") cm")
                                .foregroundStyle(Color.appTextSecondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    Stepper(value: $restSeconds, in: 0...90, step: 5) {
                        HStack {
                            Text("Rest between blocks")
                            Spacer()
                            Text(restSeconds == 0 ? "Off" : "\(restSeconds)s")
                                .foregroundStyle(Color.appTextSecondary)
                                .monospacedDigit()
                        }
                    }
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                } header: {
                    Text("Workout")
                } footer: {
                    Text("Rest is the short break the live workout session adds between exercise blocks.")
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset workout history", systemImage: "trash")
                    }

                    Button {
                        LocalProfileStore.shared.clear()
                        hasCompletedOnboarding = false
                    } label: {
                        Label("Restart onboarding", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Data")
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Calora")
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(Color.appTextSecondary)
                            .monospacedDigit()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            .confirmationDialog("Reset workout history?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "workoutSessionHistory")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears locally saved completed sessions.")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
