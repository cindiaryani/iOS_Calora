import SwiftUI

struct MetricGrid: View {
    let snapshot: DailyFitnessSnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            MetricTile(title: "Active Energy", value: "\(Int(snapshot.activeEnergyBurned))", unit: "kcal", systemImage: "flame.fill", tint: .appAccent)
            MetricTile(title: "Remaining", value: "\(Int(snapshot.remainingCalories))", unit: "kcal", systemImage: "scope", tint: .appAccent)
            MetricTile(title: "Est. Steps", value: "\(snapshot.steps)", unit: "steps", systemImage: "shoeprints.fill", tint: .appPrimary)
            MetricTile(title: "Mindful Time", value: "\(snapshot.mindfulMinutes)", unit: "min", systemImage: "brain.head.profile", tint: .purple)
        }
    }
}

struct MetricGrid_Previews: PreviewProvider {
    static var previews: some View {
        MetricGrid(snapshot: .sample)
            .padding()
    }
}
