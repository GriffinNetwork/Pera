import Foundation

struct BudgetEnvelope: Identifiable, Codable {
    var id: String = UUID().uuidString
    var userId: String
    var categoryId: String
    var month: String
    var allocated: Double
    var rolloverAmount: Double = 0

    var totalAvailable: Double { allocated + rolloverAmount }
}
