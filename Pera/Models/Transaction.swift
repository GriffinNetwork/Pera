import Foundation

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        }
    }
}

struct Transaction: Identifiable, Codable {
    var id: String = UUID().uuidString
    var userId: String
    var amount: Double
    var type: TransactionType
    var categoryId: String
    var subcategory: String?
    var note: String?
    var date: Date
    var merchantName: String?
    var tags: [String] = []
    var isRecurring: Bool = false
    var receiptImageURL: String?
    var createdAt: Date = Date()
}
