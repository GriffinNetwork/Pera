import SwiftUI
import Charts

struct ReportsView: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM

    @State private var selectedTab: ReportTab = .spending
    @State private var trendPoints: [MonthPoint] = []
    @State private var isLoadingTrends = false

    enum ReportTab: String, CaseIterable {
        case spending = "Spending"
        case trends = "Trends"
        case income = "Income"
    }

    var body: some View {
        @Bindable var txVM = txVM
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Report", selection: $selectedTab) {
                        ForEach(ReportTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedTab {
                    case .spending: SpendingByCategory()
                    case .trends:   MonthlyTrends(points: trendPoints, isLoading: isLoadingTrends)
                    case .income:   IncomeBreakdown()
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DateFilterButton(filter: $txVM.dateFilter) {
                        Task { await txVM.load() }
                    }
                }
            }
            .task(id: txVM.dateFilter) {
                async let txLoad: () = txVM.load()
                async let trends: () = loadTrends()
                _ = await (txLoad, trends)
            }
        }
    }

    private func loadTrends() async {
        isLoadingTrends = true
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let months = (-5...0).map { offset in Date().adding(months: offset).monthKey }
        let raw = await txVM.fetchTrends(months: months)
        trendPoints = raw.map { entry in
            let (start, _) = entry.month.monthDateRange()
            return MonthPoint(month: entry.month, label: formatter.string(from: start),
                              expenses: entry.expenses, income: entry.income)
        }
        isLoadingTrends = false
    }

}

struct MonthPoint: Identifiable {
    let id = UUID()
    let month: String
    let label: String
    let expenses: Double
    let income: Double
}

// MARK: - Spending by Category

private struct SpendingByCategory: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM

    struct CategorySpend: Identifiable {
        var id: String { categoryId }
        let categoryId: String
        let name: String
        let amount: Double
        let color: Color
        let icon: String
    }

    private var data: [CategorySpend] {
        catVM.expenseCategories.compactMap { cat in
            let spent = txVM.spentByCategory(cat.id)
            guard spent > 0 else { return nil }
            return CategorySpend(categoryId: cat.id, name: cat.name, amount: spent, color: cat.color, icon: cat.icon)
        }
        .sorted { $0.amount > $1.amount }
    }

    @State private var tappedItem: CategorySpend?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.pie",
                    description: Text("Add some transactions to see your spending breakdown."))
            } else {
                let total = data.reduce(0) { $0 + $1.amount }
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                    .annotation(position: .overlay) {
                        if total > 0 && item.amount / total >= 0.07 {
                            Button {
                                tappedItem = tappedItem?.id == item.id ? nil : item
                            } label: {
                                CategoryIconView(icon: item.icon, size: 15, color: .white)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: Binding(
                                get: { tappedItem?.id == item.id },
                                set: { if !$0 { tappedItem = nil } }
                            )) {
                                VStack(spacing: 4) {
                                    CategoryIconView(icon: item.icon, size: 18, color: item.color)
                                    Text(item.name)
                                        .font(.caption.weight(.semibold))
                                    Text(item.amount.currencyString)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(data) { item in
                        HStack {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            HStack(spacing: 6) {
                                CategoryIconView(icon: item.icon, size: 13, color: item.color)
                                Text(item.name)
                            }
                            .font(.subheadline)
                            .foregroundStyle(item.color)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(item.amount.currencyString)
                                    .font(.subheadline.bold())
                                Text(pct(item.amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        if item.id != data.last?.id { Divider().padding(.leading) }
                    }
                }
                .background(Color.peraSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    private func pct(_ amount: Double) -> String {
        guard txVM.totalExpenses > 0 else { return "0%" }
        return "\(Int(amount / txVM.totalExpenses * 100))%"
    }
}

// MARK: - Monthly Trends

private struct MonthlyTrends: View {
    let points: [MonthPoint]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trends")
                .font(.headline)
                .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
            } else {
                Chart(points) { pt in
                    BarMark(x: .value("Month", pt.label),
                            y: .value("Expenses", pt.expenses))
                        .foregroundStyle(Color.peraExpense.opacity(0.85))
                        .annotation(position: .top, alignment: .center) {
                            if pt.expenses > 0 {
                                Text(pt.expenses.compactCurrencyString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    LineMark(x: .value("Month", pt.label),
                             y: .value("Income", pt.income))
                        .foregroundStyle(Color.peraIncome)
                        .symbol(Circle())
                        .annotation(position: .top, alignment: .center) {
                            if pt.income > 0 {
                                Text(pt.income.compactCurrencyString)
                                    .font(.caption2)
                                    .foregroundStyle(Color.peraIncome)
                            }
                        }
                }
                .frame(height: 240)
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Legend(color: Color.peraExpense, label: "Expenses")
                    Legend(color: Color.peraIncome, label: "Income")
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct Legend: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 16, height: 10)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Income Breakdown

private struct IncomeBreakdown: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM

    private var incomeTxs: [Transaction] {
        txVM.transactions.filter { $0.type == .income }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income")
                .font(.headline)
                .padding(.horizontal)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Income")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(txVM.totalIncome.currencyString)
                        .font(.title.bold())
                }
                Spacer()
            }
            .padding()
            .background(Color.peraSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal)

            if incomeTxs.isEmpty {
                ContentUnavailableView("No Income", systemImage: "arrow.down.circle",
                    description: Text("No income recorded this month."))
            } else {
                VStack(spacing: 0) {
                    ForEach(incomeTxs) { tx in
                        TransactionRowView(transaction: tx, category: catVM.category(for: tx.categoryId))
                        if tx.id != incomeTxs.last?.id { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color.peraSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
    }
}
