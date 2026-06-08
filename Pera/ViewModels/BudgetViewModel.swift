import Observation
import Foundation

@Observable
@MainActor
class BudgetViewModel {
    var envelopes: [BudgetEnvelope] = []
    var isLoading = false
    var errorMessage: String?

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
        isLoading = true
        do {
            envelopes = try await service.fetchEnvelopes(userId: userId, month: month)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func upsert(_ envelope: BudgetEnvelope) async {
        do {
            try await service.saveEnvelope(envelope)
            if let idx = envelopes.firstIndex(where: { $0.id == envelope.id }) {
                envelopes[idx] = envelope
            } else {
                envelopes.append(envelope)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ envelope: BudgetEnvelope) async {
        do {
            try await service.deleteEnvelope(userId: userId, id: envelope.id)
            envelopes.removeAll { $0.id == envelope.id }
        } catch {
            errorMessage = error.localizedDescription
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
