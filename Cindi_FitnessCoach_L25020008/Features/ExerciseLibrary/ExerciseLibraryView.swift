import SwiftUI

struct ExerciseLibraryView: View {
    @AppStorage(ExerciseDBService.apiKeyDefaultsKey) private var apiKey = ""

    @State private var exercises: [ExerciseDBItem] = []
    @State private var selectedBodyPart: String?      // nil = All
    @State private var isLoading = false
    @State private var errorText: String?

    private let service = ExerciseDBService()
    private let accent = Color.appPrimary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !service.hasKey {
                    noKeyState
                } else {
                    bodyPartChips
                    content
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .navigationTitle("Exercise Library")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskKey) {
            await load()
        }
    }

    /// Re-runs the loader whenever the key is added or the body-part filter changes.
    private var taskKey: String {
        "\(apiKey)-\(selectedBodyPart ?? "all")"
    }

    // MARK: - Sections

    private var bodyPartChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedBodyPart == nil) {
                    selectedBodyPart = nil
                }
                ForEach(ExerciseDBService.bodyParts, id: \.self) { part in
                    chip(title: part.capitalized, isSelected: selectedBodyPart == part) {
                        selectedBodyPart = part
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? Color.appOnPrimary : Color.appTextSecondary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(isSelected ? accent : Color.appSurface, in: Capsule())
                .overlay {
                    Capsule().stroke(isSelected ? Color.clear : Color.appBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading exercises…")
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let errorText {
            infoState(icon: "wifi.exclamationmark", title: "Couldn't load", message: errorText)
        } else if exercises.isEmpty {
            infoState(icon: "magnifyingglass", title: "No exercises", message: "Try another body part.")
        } else {
            LazyVStack(spacing: 12) {
                ForEach(exercises) { item in
                    NavigationLink {
                        ExerciseDetailView(item: item)
                    } label: {
                        exerciseRow(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func exerciseRow(_ item: ExerciseDBItem) -> some View {
        HStack(spacing: 14) {
            AnimatedGIFView(
                urlString: service.imageURLString(for: item.id, resolution: 180),
                headers: service.imageHeaders,
                contentMode: .fill
            )
                .frame(width: 64, height: 64)
                .background(Color.appSurfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name.capitalized)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(2)

                Text("\(item.bodyPart.capitalized) · \(item.target.capitalized)")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(12)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var noKeyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(accent)

            Text("Add your ExerciseDB key")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)

            Text("Open Settings → Exercise Library and paste your X-RapidAPI-Key from the ExerciseDB API to load the catalog with animated demos.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private func infoState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    // MARK: - Loading

    private func load() async {
        guard service.hasKey else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            if let part = selectedBodyPart {
                exercises = try await service.fetch(bodyPart: part)
            } else {
                exercises = try await service.fetchAll(limit: 30)
            }
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            exercises = []
        }
    }
}

// MARK: - Detail

private struct ExerciseDetailView: View {
    let item: ExerciseDBItem
    private let service = ExerciseDBService()
    private let accent = Color.appPrimary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                AnimatedGIFView(
                    urlString: service.imageURLString(for: item.id, resolution: 360),
                    headers: service.imageHeaders,
                    contentMode: .fit
                )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.appSurfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(item.name.capitalized)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                HStack(spacing: 10) {
                    badge("figure.strengthtraining.traditional", item.bodyPart.capitalized)
                    badge("target", item.target.capitalized)
                    badge("dumbbell.fill", item.equipment.capitalized)
                }

                if let description = item.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let secondary = item.secondaryMuscles, !secondary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Secondary muscles")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text(secondary.map { $0.capitalized }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                if let instructions = item.instructions, !instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Instructions")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)

                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.appOnPrimary)
                                    .frame(width: 22, height: 22)
                                    .background(accent, in: Circle())

                                Text(step)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.appBorder, lineWidth: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func badge(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(Color.appTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.appSurfaceMuted, in: Capsule())
    }
}
