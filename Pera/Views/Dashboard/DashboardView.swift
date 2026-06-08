import SwiftUI

struct DashboardView: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @State private var showAddTransaction = false

    var body: some View {
        @Bindable var txVM = txVM
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BalanceCard()
                    if case .month(let date) = txVM.dateFilter {
                        BudgetOverviewSection(month: date.monthKey)
                    }
                    RecentTransactionsSection()
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(Color.peraBackground)
            .navigationTitle(txVM.dateFilter.label)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    DateFilterButton(filter: $txVM.dateFilter) {
                        Task {
                            await txVM.load()
                            if case .month(let date) = txVM.dateFilter {
                                await budgetVM.load(month: date.monthKey)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .refreshable {
                await txVM.load()
                if case .month(let date) = txVM.dateFilter {
                    await budgetVM.load(month: date.monthKey)
                }
            }
        }
        .background(Color.peraBackground.ignoresSafeArea())
    }
}

// MARK: - Balance Card

private struct BalanceCard: View {
    @Environment(TransactionViewModel.self) var txVM

    private var isPositive: Bool { txVM.netAmount >= 0 }

    private var amountColor: Color {
        isPositive ? Color.peraIncome : Color.peraExpense
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Net Balance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(txVM.netAmount.currencyString)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(amountColor)

            Divider()

            HStack {
                StatPill(label: "Income", amount: txVM.totalIncome,
                         icon: "arrow.down.circle.fill", color: Color.peraIncome)
                Spacer()
                StatPill(label: "Expenses", amount: txVM.totalExpenses,
                         icon: "arrow.up.circle.fill", color: Color.peraExpense)
            }
        }
        .padding(20)
        .background(Color.peraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: amountColor.opacity(0.25), radius: 14, x: 0, y: 5)
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
                .font(.system(size: 14))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount.currencyString)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Budget Overview

private struct BudgetOverviewSection: View {
    let month: String
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @AppStorage("dashboardHiddenEnvelopeIds") private var hiddenIds = ""
    @AppStorage("dashboardEnvelopeOrder") private var orderIds = ""
    @State private var selectedEnvelope: BudgetEnvelope?

    private var hiddenIdSet: Set<String> {
        Set(hiddenIds.split(separator: ",").map(String.init))
    }

    private func displayEnvelope(for cat: Category) -> BudgetEnvelope {
        var env = budgetVM.envelope(for: cat.id)
            ?? BudgetEnvelope(userId: budgetVM.userId, categoryId: cat.id,
                              month: month, allocated: cat.budgetAmount)
        env.allocated = cat.budgetAmount
        return env
    }

    private var visibleCategories: [Category] {
        let eligible = catVM.expenseCategories.filter { $0.budgetAmount > 0 && !hiddenIdSet.contains($0.id) }
        let ids = orderIds.split(separator: ",").map(String.init)
        guard !ids.isEmpty else { return eligible.sorted { $0.budgetAmount > $1.budgetAmount } }
        let lookup = Dictionary(uniqueKeysWithValues: eligible.map { ($0.id, $0) })
        var result = ids.compactMap { lookup[$0] }
        let seen = Set(result.map { $0.id })
        result += eligible.filter { !seen.contains($0.id) }
        return result
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        if visibleCategories.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Budget Overview")
                    .font(.headline)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(visibleCategories) { cat in
                        let envelope = displayEnvelope(for: cat)
                        EnvelopeCard(
                            category: cat,
                            envelope: envelope,
                            spent: txVM.spentByCategory(cat.id)
                        )
                        .onTapGesture { selectedEnvelope = envelope }
                    }
                }
            }
            .sheet(item: $selectedEnvelope) { env in
                EnvelopeDetailView(envelope: env)
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
        case ..<0.7:  return Color.peraIncome
        case ..<0.9:  return .orange
        default:      return Color.peraExpense
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    CategoryIconView(icon: category.icon, size: 14, color: category.color)
                    Text(category.name)
                }
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
                        .fill(Color.peraSecondary)
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
        .background(Color.peraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: category.color.opacity(0.2), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Envelope Card (grid style)

private struct EnvelopeFoldView: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cx = w / 2
            let cy = h / 2

            // Top flap — the sealed portion, slightly more prominent
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: cx, y: cy))
            }
            .fill(color.opacity(0.16))

            // Bottom triangle
            Path { p in
                p.move(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: cx, y: cy))
            }
            .fill(color.opacity(0.07))

            // Left triangle
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: 0, y: h))
                p.addLine(to: CGPoint(x: cx, y: cy))
            }
            .fill(color.opacity(0.07))

            // Right triangle
            Path { p in
                p.move(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: cx, y: cy))
            }
            .fill(color.opacity(0.07))

            // Seam lines from top two corners only (top flap crease)
            Path { p in
                p.move(to: .zero)
                p.addLine(to: CGPoint(x: cx, y: cy))
                p.move(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: cx, y: cy))
            }
            .stroke(color.opacity(0.22), lineWidth: 0.75)
        }
    }
}

struct EnvelopeCard: View {
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
        case ..<0.7: return Color.peraIncome
        case ..<0.9: return .orange
        default:     return Color.peraExpense
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Flap area — classic 4-corner envelope fold pattern
            ZStack(alignment: .topTrailing) {
                EnvelopeFoldView(color: category.color)
                    .frame(height: 68)

                // Stamp (top-right, like a real envelope)
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.peraSurface)
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(category.color.opacity(0.35), lineWidth: 1.5)
                        )
                    CategoryIconView(icon: category.icon, size: 14, color: category.color)
                }
                .padding(.top, 9)
                .padding(.trailing, 9)
            }

            // Fold crease line
            Rectangle()
                .fill(category.color.opacity(0.14))
                .frame(height: 1)

            // Content body
            VStack(alignment: .leading, spacing: 7) {
                Text(category.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack {
                    Text("\(spent.currencyString) of \(envelope.totalAvailable.currencyString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(progressColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.peraSecondary)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: geo.size.width * progress, height: 4)
                            .animation(.spring(response: 0.5), value: progress)
                    }
                }
                .frame(height: 4)

                Text("\(remaining.currencyString) remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(Color.peraSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(category.color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.09), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Recent Transactions

private struct RecentTransactionsSection: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM

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
                .background(Color.peraSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
            }
        }
    }
}
