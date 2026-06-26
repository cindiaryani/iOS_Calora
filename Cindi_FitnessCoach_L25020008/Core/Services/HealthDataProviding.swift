import Foundation

protocol HealthDataProviding {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws
    func todayActiveEnergyBurned() async throws -> Double
}
