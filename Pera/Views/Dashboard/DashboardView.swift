import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel
    @State private var showAddTransaction = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCard()
                    BudgetOverviewSection()
                    RecentTransactionsSection()
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle(Date().displayMonth)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .refreshable {
                await txVM.load()
                await budgetVM.load(month: txVM.selectedMonth)
            }
        }
    }
}

// MARK: - Balance Card

private struct BalanceCard: View {
    @EnvironmentObject var txVM: TransactionViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(txVM.netAmount.currencyString)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(txVM.netAmount >= 0 ? .primary : .red)

            Divider()

            HStack {
                StatPill(label: "Income", amount: txVM.totalIncome, icon: "arrow.down.circle.fill", color: .green)
                Spacer()
                StatPill(label: "Expenses", amount: txVM.totalExpenses, icon: "arrow.up.circle.fill", color: .red)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StatPill: View {
    let label: String
    let amount: Double
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount.currencyString)
                    .font(.subheadline.bold())
            }
        }
    }
}

// MARK: - Budget Overview

private struct BudgetOverviewSection: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel

    private var topEnvelopes: [BudgetEnvelope] {
        budgetVM.envelopes
            .filter { $0.allocated > 0 }
            .sorted { $0.allocated > $1.allocated }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        if topEnvelopes.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Budget Overview")
                    .font(.headline)

                ForEach(topEnvelopes) { envelope in
                    if let cat = catVM.category(for: envelope.categoryId) {
                        EnvelopeProgressRow(
                            category: cat,
                            envelope: envelope,
                            spent: txVM.spentByCategory(envelope.categoryId)
                        )
                    }
                }
            }
        }
    }
}

struct EnvelopeProgressRow: View {
    let category: Category
    let envelope: BudgetEnvelope
    let spent: Double

    private var progress: Double {
        guard envelope.totalAvailable > 0 else { return 0 }
        return min(spent / envelope.totalAvailable, 1.0)
    }

    private var remaining: Double { max(envelope.totalAvailable - spent, 0) }

    private var progressColor: Color {
        switch progress {
        case ..<0.7:  return .green
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(category.name, systemImage: category.icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(category.color)
                Spacer()
                Text("\(spent.currencyString) / \(envelope.totalAvailable.currencyString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(.tertiarySystemBackground))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 8)

            Text("\(remaining.currencyString) remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Recent Transactions

private struct RecentTransactionsSection: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(destination: TransactionListView()) {
                HStack {
                    Text("Recent Transactions")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            }

            if txVM.recentTransactions.isEmpty {
                Text("No transactions yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(txVM.recentTransactions) { tx in
                        TransactionRowView(transaction: tx,
                                           category: catVM.category(for: tx.categoryId))
                        if tx.id != txVM.recentTransactions.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
