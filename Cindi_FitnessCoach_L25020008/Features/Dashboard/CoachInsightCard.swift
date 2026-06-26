import SwiftUI

struct CoachInsightCard: View {
    let snapshot: DailyFitnessSnapshot
    private let accent = Color.appPrimary

    init(snapshot: DailyFitnessSnapshot) {
        self.snapshot = snapshot
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.appOnPrimary)
                .frame(width: 36, height: 36)
                .background(accent, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("Coach note")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.appTextPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var message: String {
        if snapshot.progress < 0.35 {
            return "Start with something repeatable. A walk or light strength session is enough to turn today on."
        } else if snapshot.progress < 0.85 {
            return "You are moving well. Pick one focused workout and keep your effort steady."
        } else {
            return "Strong day. Recovery work now protects tomorrow's energy."
        }
    }
}

struct CoachInsightCard_Previews: PreviewProvider {
    static var previews: some View {
        CoachInsightCard(snapshot: .sample)
            .padding()
    }
}
