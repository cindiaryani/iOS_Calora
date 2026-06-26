import SwiftUI

struct NutritionLookupView: View {
    @State private var query = ""
    @State private var results: [FoodResult] = []
    @State private var hasSearched = false

    private let accent = Color.appPrimary
    private let examples = ["2 eggs, 100g rice", "1 banana and 30g almonds", "chicken breast", "burger and fries"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                searchField

                if !examples.isEmpty && !hasSearched {
                    suggestions
                }

                if hasSearched {
                    if results.isEmpty {
                        infoState
                    } else {
                        totalCard
                        ForEach(results) { resultCard($0) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(Color.appBackground)
        .navigationTitle("Calorie Lookup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Search

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Type a food or meal to see its calories and macros.")
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.appTextSecondary)

                TextField("e.g. 2 eggs, 100g rice", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(runSearch)

                if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        hasSearched = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            }

            Button(action: runSearch) {
                Label("Look up calories", systemImage: "fork.knife")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appOnPrimary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(query.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            query = example
                            runSearch()
                        } label: {
                            Text(example)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.appTextSecondary)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.appSurfaceMuted, in: Capsule())
                                .overlay { Capsule().stroke(Color.appBorder, lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    // MARK: - Results

    private var totalCard: some View {
        let totalKcal = results.reduce(0) { $0 + $1.calories }
        let totalProtein = results.reduce(0) { $0 + $1.protein }
        let totalCarbs = results.reduce(0) { $0 + $1.carbs }
        let totalFat = results.reduce(0) { $0 + $1.fat }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Total")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(totalKcal))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("kcal")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 0) {
                macro("Protein", totalProtein)
                macroDivider
                macro("Carbs", totalCarbs)
                macroDivider
                macro("Fat", totalFat)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.appSecondary, Color.appPrimaryDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func macro(_ title: String, _ grams: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.75))
            Text("\(grams, specifier: "%.1f") g")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macroDivider: some View {
        Rectangle().fill(.white.opacity(0.18)).frame(width: 1, height: 30)
    }

    private func resultCard(_ result: FoodResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "fork.knife")
                .font(.headline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)
                Text("\(Int(result.grams)) g · P \(result.protein, specifier: "%.1f") · C \(result.carbs, specifier: "%.1f") · F \(result.fat, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            Text("\(Int(result.calories)) kcal")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color.appAccent)
        }
        .padding(12)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var infoState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
            Text("No matching foods")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appTextPrimary)
            Text("Try a common food like “2 eggs”, “100g rice”, or “chicken breast”.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }

    private func runSearch() {
        hasSearched = true
        results = NutritionDatabase.lookup(query)
    }
}
