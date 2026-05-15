import Foundation
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()

    // MARK: - Transactions

    func fetchTransactions(userId: String, month: String) async throws -> [Transaction] {
        let (start, end) = month.monthDateRange()
        let snap = try await db.collection("users").document(userId)
            .collection("transactions")
            .whereField("date", isGreaterThanOrEqualTo: start)
            .whereField("date", isLessThanOrEqualTo: end)
            .order(by: "date", descending: true)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Transaction.self) }
    }

    func addTransaction(_ t: Transaction) async throws {
        try db.collection("users").document(t.userId)
            .collection("transactions").document(t.id)
            .setData(from: t)
    }

    func updateTransaction(_ t: Transaction) async throws {
        try db.collection("users").document(t.userId)
            .collection("transactions").document(t.id)
            .setData(from: t, merge: true)
    }

    func deleteTransaction(userId: String, id: String) async throws {
        try await db.collection("users").document(userId)
            .collection("transactions").document(id).delete()
    }

    // MARK: - Categories

    func fetchCategories(userId: String) async throws -> [Category] {
        let snap = try await db.collection("users").document(userId)
            .collection("categories")
            .order(by: "sortOrder")
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: Category.self) }
    }

    func saveCategory(_ c: Category) async throws {
        try db.collection("users").document(c.userId)
            .collection("categories").document(c.id)
            .setData(from: c)
    }

    func deleteCategory(userId: String, id: String) async throws {
        try await db.collection("users").document(userId)
            .collection("categories").document(id).delete()
    }

    func seedDefaultCategories(userId: String) async throws {
        for (i, var cat) in Category.defaults(for: userId).enumerated() {
            cat.sortOrder = i
            try await saveCategory(cat)
        }
    }

    // MARK: - Budget Envelopes

    func fetchEnvelopes(userId: String, month: String) async throws -> [BudgetEnvelope] {
        let snap = try await db.collection("users").document(userId)
            .collection("envelopes")
            .whereField("month", isEqualTo: month)
            .getDocuments()
        return snap.documents.compactMap { try? $0.data(as: BudgetEnvelope.self) }
    }

    func saveEnvelope(_ e: BudgetEnvelope) async throws {
        try db.collection("users").document(e.userId)
            .collection("envelopes").document(e.id)
            .setData(from: e)
    }

    // MARK: - User Profile

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(userId).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    func saveUserProfile(_ p: UserProfile) async throws {
        try db.collection("users").document(p.id).setData(from: p)
    }
}
