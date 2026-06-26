//
//  Color+App.swift
//  Cindi_FitnessCoach_L25020008
//
//  Created by 20 on 2026/5/27.
//

import SwiftUI

// Fixed, always-dark palette inspired by the reference fitness UI:
// near-black background, periwinkle feature surfaces, and a lime accent
// for primary actions / highlights. The app no longer follows the system
// light/dark setting — these values are intentionally constant.

extension Color {
    // MARK: - Brand

    /// Lime accent — primary action / active state (buttons, active tab, highlights).
    static let appPrimary = Color(hex: 0xCBF14B)
    /// Periwinkle — secondary emphasis, feature cards, gradient highlights.
    static let appSecondary = Color(hex: 0x6E72F0)
    /// Light periwinkle — accent for metrics & energetic numbers.
    static let appAccent = Color(hex: 0x9CA0F8)
    /// Deep indigo — dark end of hero / feature gradients.
    static let appPrimaryDeep = Color(hex: 0x3A3D9E)
    /// Near-black ink for text/icons placed on a lime `appPrimary` fill.
    static let appOnPrimary = Color(hex: 0x121507)

    // MARK: - Backgrounds & surfaces

    /// Screen background: deep charcoal with a faint warm-green cast.
    static let appBackground = Color(hex: 0x0F1311)
    /// Card surface, slightly elevated from the background.
    static let appSurface = Color(hex: 0x1A1F1C)
    /// Inner chips / inputs.
    static let appSurfaceMuted = Color(hex: 0x262C28)
    /// Hairline borders.
    static let appBorder = Color(white: 1.0, opacity: 0.10)

    // MARK: - Typography

    /// Headline text.
    static let appTextPrimary = Color(hex: 0xF4F7F2)
    /// Labels / supporting text.
    static let appTextSecondary = Color(white: 1.0, opacity: 0.66)
    /// Placeholders / hints.
    static let appTextHint = Color(white: 1.0, opacity: 0.42)

    // MARK: - Intensity semantics (cool → warm)

    /// Low intensity.
    static let appIntensityLow = Color(hex: 0x6E72F0)
    /// Moderate intensity.
    static let appIntensityModerate = Color(hex: 0xF5B33B)
    /// High intensity.
    static let appIntensityHigh = Color(hex: 0xEF5350)
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(white: Double, opacity: Double) {
        self.init(.sRGB, white: white, opacity: opacity)
    }
}
