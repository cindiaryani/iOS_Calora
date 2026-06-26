import Foundation

struct AppleHealthA2AResponse: Decodable, Equatable {
    let protocolName: String
    let messageType: String
    let sender: Agent
    let receiver: Agent
    let payload: Payload

    enum CodingKeys: String, CodingKey {
        case protocolName = "protocol"
        case messageType = "message_type"
        case sender
        case receiver
        case payload
    }

    struct Agent: Decodable, Equatable {
        let id: String
        let role: String
    }

    struct Payload: Decodable, Equatable {
        let date: Date
        let activeEnergyBurnedKcal: Double
        let calorieGoalKcal: Double
        let steps: Int
        let mindfulMinutes: Int
        let confidence: Double

        enum CodingKeys: String, CodingKey {
            case date
            case activeEnergyBurnedKcal = "active_energy_burned_kcal"
            case calorieGoalKcal = "calorie_goal_kcal"
            case steps
            case mindfulMinutes = "mindful_minutes"
            case confidence
        }
    }

    static let mockJSON = """
    {
      "protocol": "A2A",
      "message_type": "health.calorie.summary",
      "sender": {
        "id": "apple_health_agent",
        "role": "AppleHealthAgent"
      },
      "receiver": {
        "id": "ui_agent",
        "role": "SwiftUIDashboardAgent"
      },
      "payload": {
        "date": "2026-05-15T07:30:00Z",
        "active_energy_burned_kcal": 420,
        "calorie_goal_kcal": 640,
        "steps": 8120,
        "mindful_minutes": 10,
        "confidence": 0.98
      }
    }
    """

    static func decodeMock() throws -> AppleHealthA2AResponse {
        try decoder.decode(AppleHealthA2AResponse.self, from: Data(mockJSON.utf8))
    }

    func makeSnapshot() -> DailyFitnessSnapshot {
        DailyFitnessSnapshot(
            date: payload.date,
            calorieGoal: payload.calorieGoalKcal,
            activeEnergyBurned: payload.activeEnergyBurnedKcal,
            steps: payload.steps,
            mindfulMinutes: payload.mindfulMinutes
        )
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
