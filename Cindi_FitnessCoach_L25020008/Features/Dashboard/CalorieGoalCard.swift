import SwiftUI

struct CalorieGoalCard: View {
    let currentGoal: Double
    let saveGoal: (Double) -> Void

    @State private var draftGoal: Double
    private let accent = Color.appPrimary

    init(currentGoal: Double, saveGoal: @escaping (Double) -> Void) {
        self.currentGoal = currentGoal
        self.saveGoal = saveGoal
        _draftGoal = State(initialValue: currentGoal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Daily calorie goal", systemImage: "target")
                    .font(.headline)

                Spacer()

                Text("\(Int(draftGoal)) kcal")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.appAccent)
            }

            Slider(value: $draftGoal, in: 250...1600, step: 10) {
                Text("Daily calorie goal")
            } minimumValueLabel: {
                Text("250")
            } maximumValueLabel: {
                Text("1600")
            }
            .tint(accent)

            HStack {
                Text(goalLabel)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)

                Spacer()

                Button {
                    saveGoal(draftGoal)
                } label: {
                    Label("Save", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.appOnPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(accent, in: Capsule())
                .disabled(Int(draftGoal) == Int(currentGoal))
            }
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .onChange(of: currentGoal) { newValue in
            draftGoal = newValue
        }
    }

    private var goalLabel: String {
        switch draftGoal {
        case 250..<500:
            return "Light activity target"
        case 500..<900:
            return "Balanced daily target"
        default:
            return "Ambitious burn target"
        }
    }
}

struct CalorieGoalCard_Previews: PreviewProvider {
    static var previews: some View {
        CalorieGoalCard(currentGoal: 640) { _ in }
            .padding()
    }
}
