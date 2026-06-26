import SwiftUI

struct HealthStatusCard: View {
    let status: String
    let state: HealthConnectionState
    let lastUpdated: Date?
    let isLoading: Bool
    let requestPermission: () -> Void
    let refresh: () -> Void
    let loadMockA2A: () -> Void
    let switchBackToHealth: () -> Void
    private let accent = Color.appPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(state == .usingA2AMock ? Color.appOnPrimary : tint)
                    .frame(width: 40, height: 40)
                    .background(state == .usingA2AMock ? accent : tint.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Apple Health")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)

                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)

                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let lastUpdated {
                        Text("Last updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }

                Spacer()

                if isLoading {
                    ProgressView()
                }
            }

            actionPanel
        }
        .padding()
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appBorder, lineWidth: 1)
        }
    }

    private var actionPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if showsPermissionButton {
                    healthActionButton(
                        title: "Connect",
                        systemImage: "heart.text.square",
                        tint: .red,
                        isProminent: true,
                        foreground: .white,
                        action: requestPermission
                    )
                }

                healthActionButton(
                    title: state == .usingA2AMock ? "Sync A2A" : "Sync Health",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: state == .usingA2AMock ? accent : .red,
                    isDisabled: isLoading || syncDisabled,
                    action: refresh
                )
            }

            if state == .usingA2AMock {
                healthActionButton(
                    title: "Back to Apple Health",
                    systemImage: "heart.text.square",
                    tint: .red,
                    isDisabled: isLoading,
                    action: switchBackToHealth
                )
            } else {
                healthActionButton(
                    title: "Try A2A Demo",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    tint: accent,
                    isProminent: true,
                    foreground: Color.appOnPrimary,
                    isDisabled: isLoading,
                    action: loadMockA2A
                )
            }
        }
    }

    private func healthActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isProminent: Bool = false,
        foreground: Color? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground ?? (isProminent ? .white : tint))
        .background(
            isProminent ? tint : Color.appSurfaceMuted,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isProminent ? 0 : 0.24), lineWidth: 1)
        }
        .opacity(isDisabled ? 0.48 : 1)
        .disabled(isDisabled)
    }

    private var statusTitle: String {
        switch state {
        case .unavailable:
            return "Unavailable"
        case .permissionNeeded:
            return "Permission needed"
        case .requestingPermission:
            return "Requesting permission"
        case .loadingData:
            return "Reading today's active energy"
        case .permissionDenied:
            return "Permission or data access issue"
        case .emptyToday:
            return "No active energy yet today"
        case .hasData:
            return "Connected"
        case .usingA2AMock:
            return "A2A mock loaded"
        }
    }

    private var iconName: String {
        switch state {
        case .unavailable, .permissionDenied:
            return "exclamationmark.triangle.fill"
        case .permissionNeeded, .requestingPermission:
            return "heart.text.square"
        case .emptyToday:
            return "tray"
        case .loadingData:
            return "arrow.triangle.2.circlepath"
        case .hasData:
            return "heart.fill"
        case .usingA2AMock:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    private var tint: Color {
        switch state {
        case .unavailable, .permissionDenied:
            return .appIntensityModerate
        case .emptyToday:
            return .appAccent
        case .usingA2AMock:
            return accent
        default:
            return .appIntensityHigh
        }
    }

    private var showsPermissionButton: Bool {
        state == .permissionNeeded || state == .permissionDenied
    }

    private var syncDisabled: Bool {
        state == .unavailable ||
        state == .permissionNeeded ||
        state == .requestingPermission ||
        state == .permissionDenied
    }
}

struct HealthStatusCard_Previews: PreviewProvider {
    static var previews: some View {
        HealthStatusCard(
            status: "Connect Apple Health to read today's active energy.",
            state: .permissionNeeded,
            lastUpdated: nil,
            isLoading: false,
            requestPermission: {},
            refresh: {},
            loadMockA2A: {},
            switchBackToHealth: {}
        )
            .padding()
    }
}
