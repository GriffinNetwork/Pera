import Observation
import Foundation

@Observable
@MainActor
class TransactionViewModel {
    var transactions: [Transaction] = []
    var dateFilter: DateFilter = .month(Date())
    var selectedMonth: String = Date().monthKey  // used by budget views
    var isLoading = false
    var errorMessage: String?

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

    func earnedByCategory(_ categoryId: String) -> Double {
        transactions
            .filter { $0.type == .income && $0.categoryId == categoryId }
            .reduce(0) { $0 + $1.amount }
    }

    func transactions(for categoryId: String) -> [Transaction] {
        transactions.filter { $0.categoryId == categoryId }
    }

    var groupedByDate: [(key: Date, value: [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    // MARK: - Actions

    func load() async {
        isLoading = true
        do {
            let (start, end) = dateFilter.dateRange
            transactions = try await service.fetchTransactions(userId: userId, start: start, end: end)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    func add(_ transaction: Transaction, receiptImageData: Data? = nil) async -> Bool {
        do {
            var tx = transaction
            if let data = receiptImageData {
                let url = try await service.uploadReceipt(
                    imageData: data, userId: userId, transactionId: tx.id)
                tx.receiptImageURL = url
            }
            try await service.addTransaction(tx)
            // Insert locally so the receipt URL is immediately visible without
            // a server round-trip that may race against the pending write.
            transactions.insert(tx, at: 0)
            transactions.sort { $0.date > $1.date }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func importTransactions(_ transactions: [Transaction]) async {
        isLoading = true
        do {
            for tx in transactions {
                try await service.addTransaction(tx)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    @discardableResult
    func update(_ transaction: Transaction, receiptImageData: Data? = nil) async -> Bool {
        do {
            var tx = transaction
            let oldReceiptURL = transactions.first(where: { $0.id == tx.id })?.receiptImageURL
            if let data = receiptImageData {
                let url = try await service.uploadReceipt(
                    imageData: data, userId: userId, transactionId: tx.id)
                tx.receiptImageURL = url
            }
            // Receipt was removed without a replacement — delete from Storage.
            if oldReceiptURL != nil && receiptImageData == nil && tx.receiptImageURL == nil {
                try? await service.deleteReceipt(userId: tx.userId, transactionId: tx.id)
            }
            try await service.updateTransaction(tx)
            if let idx = transactions.firstIndex(where: { $0.id == tx.id }) {
                transactions[idx] = tx
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ transaction: Transaction) async {
        do {
            try await service.deleteTransaction(userId: userId, id: transaction.id)
            transactions.removeAll { $0.id == transaction.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMultiple(_ ids: Set<String>) async {
        do {
            for id in ids {
                try await service.deleteTransaction(userId: userId, id: id)
            }
            transactions.removeAll { ids.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setFilter(_ filter: DateFilter) async {
        dateFilter = filter
        await load()
    }

    func setMonth(_ month: String) async {
        selectedMonth = month
        await load()
    }

    func fetchTrends(months: [String]) async -> [(month: String, expenses: Double, income: Double)] {
        var results: [(month: String, expenses: Double, income: Double)] = []
        for month in months {
            let (start, end) = month.monthDateRange()
            let txs = (try? await service.fetchTransactions(userId: userId, start: start, end: end)) ?? []
            let exp = txs.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let inc = txs.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            results.append((month: month, expenses: exp, income: inc))
        }
        return results
    }
}
