import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

/// Sign-in / sign-up screen. Shown by `RootView` while no Firebase user is signed in.
/// Supports email + password and "Continue with Google". On success, Firebase's auth-state
/// listener in `RootView` swaps this out for onboarding / the dashboard automatically.
struct AuthView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var errorText: String?
    @State private var isBusy = false

    private let accent = Color.appPrimary

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(accent.opacity(0.16)).frame(width: 92, height: 92)
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 4) {
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.title.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                        Text("Sign in to sync your fitness plan.")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    VStack(spacing: 12) {
                        field("Email", text: $email, secure: false, keyboard: .emailAddress)
                        field("Password", text: $password, secure: true, keyboard: .default)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(Color.appIntensityHigh)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: emailAuth) {
                        ZStack {
                            if isBusy { ProgressView().tint(Color.appOnPrimary) }
                            else { Text(isSignUp ? "Sign up" : "Sign in").font(.headline.weight(.bold)) }
                        }
                        .foregroundStyle(Color.appOnPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy || email.isEmpty || password.isEmpty)
                    .opacity((isBusy || email.isEmpty || password.isEmpty) ? 0.6 : 1)

                    Button {
                        withAnimation { isSignUp.toggle(); errorText = nil }
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "New here? Create an account")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Rectangle().fill(Color.appBorder).frame(height: 1)
                        Text("or").font(.caption).foregroundStyle(Color.appTextSecondary)
                        Rectangle().fill(Color.appBorder).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    GoogleSignInButton {
                        Task { await googleSignIn() }
                    }
                    .frame(height: 50)
                    .disabled(isBusy)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, secure: Bool, keyboard: UIKeyboardType) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text).keyboardType(keyboard)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .foregroundStyle(Color.appTextPrimary)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.appBorder, lineWidth: 1) }
    }

    // MARK: - Auth actions

    private func emailAuth() {
        isBusy = true
        errorText = nil
        let completion: (AuthDataResult?, Error?) -> Void = { _, error in
            isBusy = false
            if let error { errorText = error.localizedDescription }
        }
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password, completion: completion)
        } else {
            Auth.auth().signIn(withEmail: email, password: password, completion: completion)
        }
    }

    @MainActor
    private func googleSignIn() async {
        errorText = nil
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorText = "Firebase is not configured."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let root = Self.rootViewController() else { return }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: root)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
