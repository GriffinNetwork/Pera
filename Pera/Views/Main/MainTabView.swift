import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthService

    @StateObject private var txVM: TransactionViewModel
    @StateObject private var catVM: CategoryViewModel
    @StateObject private var budgetVM: BudgetViewModel

    private let service = FirestoreService()

    init(userId: String) {
        let svc = FirestoreService()
        _txVM = StateObject(wrappedValue: TransactionViewModel(userId: userId, service: svc))
        _catVM = StateObject(wrappedValue: CategoryViewModel(userId: userId, service: svc))
        _budgetVM = StateObject(wrappedValue: BudgetViewModel(userId: userId, service: svc))
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
        .environmentObject(txVM)
        .environmentObject(catVM)
        .environmentObject(budgetVM)
        .task {
            async let tx: () = txVM.load()
            async let cats: () = catVM.load()
            _ = await (tx, cats)
            await budgetVM.load(month: txVM.selectedMonth)
            await budgetVM.syncFromCategories(catVM.categories, month: txVM.selectedMonth)
        }
    }
}
