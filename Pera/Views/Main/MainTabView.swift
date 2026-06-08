import SwiftUI

struct MainTabView: View {
    @Environment(AuthService.self) var auth

    @State private var txVM: TransactionViewModel
    @State private var catVM: CategoryViewModel
    @State private var budgetVM: BudgetViewModel

    private let service = FirestoreService()

    init(userId: String) {
        let svc = FirestoreService()
        _txVM = State(initialValue: TransactionViewModel(userId: userId, service: svc))
        _catVM = State(initialValue: CategoryViewModel(userId: userId, service: svc))
        _budgetVM = State(initialValue: BudgetViewModel(userId: userId, service: svc))
    }

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }

            BudgetView()
                .tabItem { Label("Budget", systemImage: "envelope.fill") }

            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(Color.peraAccent)
        .environment(txVM)
        .environment(catVM)
        .environment(budgetVM)
        .task {
            async let tx: () = txVM.load()
            async let cats: () = catVM.load()
            _ = await (tx, cats)
            await budgetVM.load(month: txVM.selectedMonth)
            await budgetVM.syncFromCategories(catVM.categories, month: txVM.selectedMonth)
        }
    }
}
