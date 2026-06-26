import Foundation

/// One exercise from the ExerciseDB API (RapidAPI). This API version does not return a
/// `gifUrl`; the animated GIF is fetched separately from the `/image` endpoint by `id`
/// (see `ExerciseDBService.imageURLString(for:)`).
struct ExerciseDBItem: Identifiable, Decodable, Equatable {
    let id: String
    let name: String
    let bodyPart: String
    let target: String
    let equipment: String
    let secondaryMuscles: [String]?
    let instructions: [String]?
    // Fields present on newer ExerciseDB responses (optional for forward/backward compatibility).
    let description: String?
    let difficulty: String?
    let category: String?
}

enum ExerciseDBError: LocalizedError {
    case missingKey
    case badResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your ExerciseDB API key in Settings to load the exercise library."
        case .badResponse:
            return "Couldn't reach ExerciseDB. Check your API key and internet connection."
        case .decoding:
            return "ExerciseDB returned data in an unexpected format."
        }
    }
}

/// Fetches exercises (name, target muscles, equipment, animated GIF) from the ExerciseDB
/// API on RapidAPI. The user pastes their own `X-RapidAPI-Key` in Settings — there is no
/// built-in key, so an empty key surfaces a friendly "add your key" state in the UI.
final class ExerciseDBService {
    static let apiKeyDefaultsKey = "exerciseDBAPIKey"

    /// ExerciseDB's body-part categories (used as filter chips so we avoid an extra call).
    static let bodyParts = [
        "back", "cardio", "chest", "lower arms", "lower legs",
        "neck", "shoulders", "upper arms", "upper legs", "waist"
    ]

    private let host = "exercisedb.p.rapidapi.com"

    /// Hardcode your X-RapidAPI-Key here for local dev to skip the Settings field.
    /// Leave empty ("") to require the in-app Settings entry instead.
    private let fallbackKey = "" // Do NOT commit a real key here

    private var apiKey: String {
        // The Settings field takes priority; otherwise fall back to the hardcoded key above.
        let stored = UserDefaults.standard.string(forKey: Self.apiKeyDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let stored, !stored.isEmpty { return stored }
        return fallbackKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasKey: Bool { !apiKey.isEmpty }

    /// The `/image` endpoint URL for an exercise's animated GIF at the given resolution
    /// (180 / 360 / 720 / 1080). The request must carry `imageHeaders`.
    func imageURLString(for id: String, resolution: Int = 360) -> String {
        "https://\(host)/image?exerciseId=\(id)&resolution=\(resolution)"
    }

    /// Headers required for both data and image requests.
    var imageHeaders: [String: String] {
        ["x-rapidapi-key": apiKey, "x-rapidapi-host": host]
    }

    func fetchAll(limit: Int = 30, offset: Int = 0) async throws -> [ExerciseDBItem] {
        try await fetch(
            path: "/exercises",
            query: [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)")
            ]
        )
    }

    func fetch(bodyPart: String, limit: Int = 30) async throws -> [ExerciseDBItem] {
        let encoded = bodyPart.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bodyPart
        return try await fetch(
            path: "/exercises/bodyPart/\(encoded)",
            query: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
    }

    private func fetch(path: String, query: [URLQueryItem]) async throws -> [ExerciseDBItem] {
        guard hasKey else { throw ExerciseDBError.missingKey }

        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = query

        guard let url = components.url else { throw ExerciseDBError.badResponse }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue(host, forHTTPHeaderField: "x-rapidapi-host")
        request.timeoutInterval = 20

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            throw ExerciseDBError.badResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw ExerciseDBError.badResponse
        }

        do {
            return try JSONDecoder().decode([ExerciseDBItem].self, from: data)
        } catch {
            throw ExerciseDBError.decoding
        }
    }
}
