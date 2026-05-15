import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel

    @State private var selectedTab: ReportTab = .spending

    enum ReportTab: String, CaseIterable {
        case spending = "Spending"
        case trends = "Trends"
        case income = "Income"
    }

    var body: some View {
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
                    case .trends:   MonthlyTrends()
                    case .income:   IncomeBreakdown()
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPickerButton(selectedMonth: $txVM.selectedMonth) {
                        Task { await txVM.load() }
                    }
                }
            }
        }
    }
}

// MARK: - Spending by Category

private struct SpendingByCategory: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel

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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.pie",
                    description: Text("Add some transactions to see your spending breakdown."))
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.55),
                        angularInset: 2
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 220)
                .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(data) { item in
                        HStack {
                            Circle().fill(item.color).frame(width: 10, height: 10)
                            Label(item.name, systemImage: item.icon)
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
                .background(Color(.secondarySystemBackground))
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
    @EnvironmentObject var txVM: TransactionViewModel

    struct MonthPoint: Identifiable {
        let id = UUID()
        let month: String
        let label: String
        let expenses: Double
        let income: Double
    }

    @State private var points: [MonthPoint] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Trends")
                .font(.headline)
                .padding(.horizontal)

            Chart(points) { pt in
                BarMark(x: .value("Month", pt.label),
                        y: .value("Expenses", pt.expenses))
                    .foregroundStyle(.red.opacity(0.8))
                    .annotation(position: .top, alignment: .center) {
                        if pt.expenses > 0 {
                            Text(pt.expenses.compactCurrencyString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                LineMark(x: .value("Month", pt.label),
                         y: .value("Income", pt.income))
                    .foregroundStyle(.green)
                    .symbol(Circle())
            }
            .frame(height: 240)
            .padding(.horizontal)

            HStack(spacing: 20) {
                Legend(color: .red.opacity(0.8), label: "Expenses")
                Legend(color: .green, label: "Income")
            }
            .padding(.horizontal)
        }
        .onAppear { buildPoints() }
        .onChange(of: txVM.selectedMonth) { _, _ in buildPoints() }
    }

    private func buildPoints() {
        points = (-5...0).map { offset in
            let month = Date().adding(months: offset).monthKey
            let (start, _) = month.monthDateRange()
            let label = DateFormatter().then {
                $0.dateFormat = "MMM"
            }.string(from: start)
            return MonthPoint(month: month, label: label, expenses: 0, income: 0)
        }
    }
}

extension DateFormatter {
    func then(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self)
        return self
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
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel

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
            .background(Color(.secondarySystemBackground))
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
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
    }
}
