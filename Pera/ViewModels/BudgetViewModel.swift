import Foundation

class BudgetViewModel: ObservableObject {
    @Published var envelopes: [BudgetEnvelope] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: FirestoreService
    let userId: String

    init(userId: String, service: FirestoreService) {
        self.userId = userId
        self.service = service
    }

    var totalAllocated: Double { envelopes.reduce(0) { $0 + $1.allocated } }

    func envelope(for categoryId: String) -> BudgetEnvelope? {
        envelopes.first { $0.categoryId == categoryId }
    }

    func load(month: String) async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await service.fetchEnvelopes(userId: userId, month: month)
            await MainActor.run { envelopes = result }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func upsert(_ envelope: BudgetEnvelope) async {
        do {
            try await service.saveEnvelope(envelope)
            await MainActor.run {
                if let idx = envelopes.firstIndex(where: { $0.id == envelope.id }) {
                    envelopes[idx] = envelope
                } else {
                    envelopes.append(envelope)
                }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func syncFromCategories(_ categories: [Category], month: String) async {
        for cat in categories where cat.type == .expense && cat.budgetAmount > 0 {
            guard envelope(for: cat.id) == nil else { continue }
            let env = BudgetEnvelope(userId: userId, categoryId: cat.id,
                                     month: month, allocated: cat.budgetAmount)
            await upsert(env)
        }
    }
}
