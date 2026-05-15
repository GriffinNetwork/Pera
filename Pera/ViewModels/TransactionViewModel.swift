import Foundation
import Combine

class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var selectedMonth: String = Date().monthKey
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: FirestoreService
    let userId: String

    init(userId: String, service: FirestoreService) {
        self.userId = userId
        self.service = service
    }

    // MARK: - Computed

    var totalExpenses: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var netAmount: Double { totalIncome - totalExpenses }

    var recentTransactions: [Transaction] { Array(transactions.prefix(5)) }

    func spentByCategory(_ categoryId: String) -> Double {
        transactions
            .filter { $0.type == .expense && $0.categoryId == categoryId }
            .reduce(0) { $0 + $1.amount }
    }

    func transactions(for categoryId: String) -> [Transaction] {
        transactions.filter { $0.categoryId == categoryId }
    }

    var groupedByDate: [(key: Date, value: [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { t -> Date in
            Calendar.current.startOfDay(for: t.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    // MARK: - Actions

    func load() async {
        await set(loading: true)
        do {
            let result = try await service.fetchTransactions(userId: userId, month: selectedMonth)
            await MainActor.run { transactions = result }
        } catch {
            await set(error: error.localizedDescription)
        }
        await set(loading: false)
    }

    func add(_ transaction: Transaction) async {
        do {
            try await service.addTransaction(transaction)
            await load()
        } catch {
            await set(error: error.localizedDescription)
        }
    }

    func delete(_ transaction: Transaction) async {
        do {
            try await service.deleteTransaction(userId: userId, id: transaction.id)
            await MainActor.run { transactions.removeAll { $0.id == transaction.id } }
        } catch {
            await set(error: error.localizedDescription)
        }
    }

    func setMonth(_ month: String) async {
        await MainActor.run { selectedMonth = month }
        await load()
    }

    // MARK: - Helpers

    private func set(loading: Bool) async {
        await MainActor.run { isLoading = loading }
    }

    private func set(error: String) async {
        await MainActor.run { errorMessage = error }
    }
}
