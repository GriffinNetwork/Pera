import Foundation

struct UserProfile: Identifiable, Codable {
    var id: String
    var email: String
    var displayName: String?
    var currency: String = "USD"
    var createdAt: Date = Date()
    var monthlyIncomeGoal: Double = 0
}
