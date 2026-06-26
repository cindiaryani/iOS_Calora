import SwiftUI

struct RecommendationsView: View {
    @ObservedObject var viewModel: FitnessCoachViewModel
    @State private var showChat = false
    @State private var showForm = false
    private let accent = Color.appPrimary

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Coach")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color.appTextPrimary)

                            Text("Recommended for your progress")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "figure.run")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appOnPrimary)
                            .frame(width: 44, height: 44)
                            .background(accent, in: Circle())
                    }

                    askCoachCard

                    formCheckCard

                    libraryCard

                    calorieLookupCard

                    WorkoutPlanRecommendationCard(viewModel: viewModel)

                    ForEach(viewModel.recommendations) { recommendation in
                        WorkoutRecommendationRow(recommendation: recommendation)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Smart extras")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)

                        extraRow("Hydrate after workouts over 20 minutes", systemImage: "drop.fill")
                        extraRow("Take one easy day after two challenge sessions", systemImage: "bed.double.fill")
                        extraRow("Review your calorie goal every Sunday", systemImage: "calendar.badge.clock")
                    }
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
        }
        .sheet(isPresented: $showChat) {
            CoachChatView()
        }
        .fullScreenCover(isPresented: $showForm) {
            ExerciseFeedbackView()
        }
    }

    private var calorieLookupCard: some View {
        NavigationLink {
            NutritionLookupView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "fork.knife")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 46, height: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Calorie Lookup")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Calories & macros for any food")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var libraryCard: some View {
        NavigationLink {
            ExerciseLibraryView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "books.vertical.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 46, height: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Exercise Library")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Browse exercises with animated demos")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var formCheckCard: some View {
        Button {
            showForm = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 46, height: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Form Check")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Live camera posture & rep feedback")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var askCoachCard: some View {
        Button {
            showChat = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "message.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(width: 46, height: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Ask the AI Coach")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text("Workout, technique & fitness nutrition Q&A")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding()
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func extraRow(_ title: String, systemImage: String) -> some View {
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
}

struct RecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        RecommendationsView(viewModel: FitnessCoachViewModel())
    }
}
