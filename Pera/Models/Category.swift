import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var userId: String
    var name: String
    var icon: String
    var colorHex: String
    var type: TransactionType
    var subcategories: [String] = []
    var subcategoryBudgets: [String: Double] = [:]
    var budgetAmount: Double = 0
    var rollover: Bool = false
    var sortOrder: Int = 0

    var color: Color { Color(hex: colorHex) }
}

extension Category {
    static func defaults(for userId: String) -> [Category] {
        let expense: [(String, String, String, Double, [String])] = [
            ("Housing",        "house.fill",       "#5E6AD2", 1500, ["Rent", "Mortgage", "Insurance"]),
            ("Food & Dining",  "fork.knife",        "#E8543A", 600,  ["Groceries", "Restaurants", "Coffee"]),
            ("Transportation", "car.fill",          "#F5A623", 300,  ["Gas", "Transit", "Parking"]),
            ("Healthcare",     "heart.fill",        "#E91E8C", 200,  ["Doctor", "Pharmacy", "Gym"]),
            ("Entertainment",  "sparkles",          "#9B59B6", 200,  ["Streaming", "Events", "Hobbies"]),
            ("Shopping",       "bag.fill",          "#1ABC9C", 300,  ["Clothing", "Electronics", "Home"]),
            ("Utilities",      "bolt.fill",         "#3498DB", 200,  ["Electric", "Water", "Internet"]),
            ("Savings",        "banknote.fill",     "#2ECC71", 500,  []),
            ("Other",          "ellipsis.circle",   "#95A5A6", 0,    []),
        ]
        let income: [(String, String, String)] = [
            ("Salary",        "briefcase.fill",   "#2ECC71"),
            ("Freelance",     "laptopcomputer",   "#3498DB"),
            ("Other Income",  "plus.circle.fill", "#95A5A6"),
        ]

        var all: [Category] = []
        for (i, (name, icon, hex, budget, subs)) in expense.enumerated() {
            all.append(Category(userId: userId, name: name, icon: icon, colorHex: hex,
                                type: .expense, subcategories: subs, budgetAmount: budget, sortOrder: i))
        }
        for (i, (name, icon, hex)) in income.enumerated() {
            all.append(Category(userId: userId, name: name, icon: icon, colorHex: hex,
                                type: .income, sortOrder: 100 + i))
        }
        return all
    }
}
