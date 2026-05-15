import Foundation

class CategoryViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: FirestoreService
    let userId: String

    init(userId: String, service: FirestoreService) {
        self.userId = userId
        self.service = service
    }

    var expenseCategories: [Category] { categories.filter { $0.type == .expense } }
    var incomeCategories: [Category] { categories.filter { $0.type == .income } }

    func category(for id: String) -> Category? {
        categories.first { $0.id == id }
    }

    func load() async {
        await MainActor.run { isLoading = true }
        do {
            var cats = try await service.fetchCategories(userId: userId)
            if cats.isEmpty {
                try await service.seedDefaultCategories(userId: userId)
                cats = try await service.fetchCategories(userId: userId)
            }
            await MainActor.run { categories = cats }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func add(_ category: Category) async {
        do {
            try await service.saveCategory(category)
            await load()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    func delete(_ category: Category) async {
        do {
            try await service.deleteCategory(userId: userId, id: category.id)
            await MainActor.run { categories.removeAll { $0.id == category.id } }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}
