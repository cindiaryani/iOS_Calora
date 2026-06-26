//
//  Cindi_FitnessCoach_L25020008App.swift
//  Cindi_FitnessCoach_L25020008
//
//  Created by 20 on 2026/5/8.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

#if canImport(SwiftData)
import SwiftData
#endif

@main
struct Cindi_FitnessCoach_L25020008App: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The app uses a single fixed dark palette and never follows
                // the system light/dark setting.
                .preferredColorScheme(.dark)
                // Completes the Google Sign-In flow when it returns to the app.
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .workoutSessionModelContainer()
    }
}

/// Decides what the app opens on: sign-in (no Firebase user) → onboarding (first launch) → app.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isSignedIn = Auth.auth().currentUser != nil

    var body: some View {
        Group {
            if !isSignedIn {
                AuthView()
            } else if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .onAppear {
            Auth.auth().addStateDidChangeListener { _, user in
                isSignedIn = (user != nil)
            }
        }
    }
}

private extension Scene {
    @SceneBuilder
    func workoutSessionModelContainer() -> some Scene {
        #if canImport(SwiftData)
        self.modelContainer(for: WorkoutSessionRecord.self)
        #else
        self
        #endif
    }
}
