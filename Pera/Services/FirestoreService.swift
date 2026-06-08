import Foundation
import FirebaseFirestore
import FirebaseStorage
import CryptoKit

final class FirestoreService: @unchecked Sendable {
    private let db = Firestore.firestore()

    // MARK: - Transactions

    func fetchTransactions(userId: String, start: Date, end: Date) async throws -> [Transaction] {
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
            .setData(from: t)
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

    func deleteEnvelope(userId: String, id: String) async throws {
        try await db.collection("users").document(userId)
            .collection("envelopes").document(id).delete()
    }

    // MARK: - Receipt Storage

    func uploadReceipt(imageData: Data, userId: String, transactionId: String) async throws -> String {
        let key = try KeychainHelper.receiptEncryptionKey(for: userId)
        let sealed = try AES.GCM.seal(imageData, using: key)
        guard let encryptedData = sealed.combined else {
            throw NSError(domain: "Encryption", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Encryption failed."])
        }

        let ref = Storage.storage().reference()
            .child("receipts/\(userId)/\(transactionId).enc")
        let metadata = StorageMetadata()
        metadata.contentType = "application/octet-stream"

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.putData(encryptedData, metadata: metadata) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            ref.downloadURL { url, error in
                if let error { cont.resume(throwing: error) }
                else if let url { cont.resume(returning: url.absoluteString) }
                else { cont.resume(throwing: NSError(domain: "Storage", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No download URL returned."])) }
            }
        }
    }

    func deleteReceipt(userId: String, transactionId: String) async throws {
        for ext in ["enc", "jpg", "pdf"] {
            let ref = Storage.storage().reference()
                .child("receipts/\(userId)/\(transactionId).\(ext)")
            try? await ref.delete()
        }
    }

    // MARK: - User Profile

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await db.collection("users").document(userId).getDocument()
        return try? doc.data(as: UserProfile.self)
    }

    func saveUserProfile(_ p: UserProfile) async throws {
        try db.collection("users").document(p.id).setData(from: p)
    }

    // MARK: - Account Deletion

    func deleteAllUserData(userId: String) async throws {
        let userRef = db.collection("users").document(userId)

        // Wipe every subcollection
        for sub in ["transactions", "categories", "envelopes"] {
            let docs = try await userRef.collection(sub).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }

        // Delete the user document itself
        try await userRef.delete()

        // Delete receipt files from Storage (best-effort — don't block account deletion)
        let storageRef = Storage.storage().reference().child("receipts/\(userId)")
        if let result = try? await storageRef.listAll() {
            for item in result.items {
                try? await item.delete()
            }
        }
    }
}
