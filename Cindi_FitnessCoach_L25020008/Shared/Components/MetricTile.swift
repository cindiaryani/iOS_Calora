import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.18), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile_Previews: PreviewProvider {
    static var previews: some View {
        MetricTile(title: "Active Energy", value: "385", unit: "kcal", systemImage: "flame.fill", tint: .orange)
            .padding()
    }
}
