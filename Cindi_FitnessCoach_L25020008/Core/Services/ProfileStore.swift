import Foundation

/// Persistence boundary for the user's profile. The onboarding and dashboard only talk to
/// this protocol, so the backend can change without touching the UI.
///
/// To add Firebase later: create `FirebaseProfileStore: ProfileStoring` (Firestore + Auth),
/// and use it instead of `LocalProfileStore`. No UI changes required.
protocol ProfileStoring {
    func load() -> UserProfile?
    func save(_ profile: UserProfile)
    func clear()
}

/// UserDefaults-backed implementation used until Firebase is wired up.
final class LocalProfileStore: ProfileStoring {
    static let shared = LocalProfileStore()

    private let key = "userProfile"

    func load() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
