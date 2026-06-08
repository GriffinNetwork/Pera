import SwiftUI

struct BudgetView: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @State private var budgetTab: BudgetTab = .envelopes
    @State private var showAddEnvelope = false
    @State private var showAddIncome = false
    @State private var editingEnvelopeCategory: Category?
    @State private var editingIncomeCategory: Category?
    @State private var showingEnvelopeDetail: BudgetEnvelope?

    enum BudgetTab: String, CaseIterable {
        case envelopes = "Envelopes"
        case income = "Income"
    }

    private var totalBudget: Double {
        catVM.expenseCategories.reduce(0) { $0 + $1.budgetAmount }
    }
    private var totalSpent: Double { txVM.totalExpenses }
    private var remaining: Double { totalBudget - totalSpent }

    var body: some View {
        @Bindable var txVM = txVM
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard

                    Picker("Budget Tab", selection: $budgetTab) {
                        ForEach(BudgetTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch budgetTab {
                    case .envelopes: envelopesSection
                    case .income:    incomeSection
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color.peraBackground)
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonthPickerButton(selectedMonth: $txVM.selectedMonth) {
                        Task {
                            await txVM.load()
                            await budgetVM.load(month: txVM.selectedMonth)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if budgetTab == .envelopes { showAddEnvelope = true }
                        else { showAddIncome = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddEnvelope) {
                AddEnvelopeView()
            }
            .sheet(isPresented: $showAddIncome) {
                AddCategoryView(editing: nil, forcedType: .income)
            }
            .sheet(item: $editingEnvelopeCategory) { cat in
                AddEnvelopeView(editingCategory: cat)
            }
            .sheet(item: $editingIncomeCategory) { cat in
                AddCategoryView(editing: cat)
            }
            .sheet(item: $showingEnvelopeDetail) { env in
                EnvelopeDetailView(envelope: env)
            }
            .refreshable {
                await txVM.load()
                await budgetVM.load(month: txVM.selectedMonth)
            }
        }
        .background(Color.peraBackground.ignoresSafeArea())
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Budget")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(totalBudget.currencyString)
                        .font(.title2.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(remaining.currencyString)
                        .font(.title2.bold())
                        .foregroundStyle(remaining < 0 ? Color.peraExpense : Color.peraIncome)
                }
            }

            Divider()

            HStack {
                Text("Spent: \(totalSpent.currencyString)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((totalBudget > 0 ? totalSpent / totalBudget : 0) * 100))% of budget")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.peraAccent.opacity(0.10), Color.peraAccent.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.peraAccent.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.peraAccent.opacity(0.15), radius: 12, x: 0, y: 5)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func displayEnvelope(for cat: Category) -> BudgetEnvelope {
        var env = budgetVM.envelope(for: cat.id)
            ?? BudgetEnvelope(userId: budgetVM.userId, categoryId: cat.id,
                              month: txVM.selectedMonth, allocated: cat.budgetAmount)
        env.allocated = cat.budgetAmount
        return env
    }

    // MARK: - Envelopes Section

    private let envelopeColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var envelopesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let expenseCats = catVM.expenseCategories
            if expenseCats.isEmpty {
                ContentUnavailableView(
                    "No Envelopes",
                    systemImage: "envelope",
                    description: Text("Tap + to add your first envelope.")
                )
            } else {
                let sorted = expenseCats.sorted { $0.budgetAmount > $1.budgetAmount }
                LazyVGrid(columns: envelopeColumns, spacing: 12) {
                    ForEach(sorted) { cat in
                        let envelope = displayEnvelope(for: cat)
                        EnvelopeCard(
                            category: cat,
                            envelope: envelope,
                            spent: txVM.spentByCategory(cat.id)
                        )
                        .onTapGesture { showingEnvelopeDetail = envelope }
                        .contextMenu {
                            Button {
                                editingEnvelopeCategory = cat
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                showAddEnvelope = true
            } label: {
                Label("New Envelope", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.peraSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Income Section

    private let incomeColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let incomeCategories = catVM.incomeCategories

            if incomeCategories.isEmpty {
                ContentUnavailableView(
                    "No Income Categories",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap + to add an income category.")
                )
            } else {
                LazyVGrid(columns: incomeColumns, spacing: 12) {
                    ForEach(incomeCategories) { cat in
                        IncomeCategoryCard(
                            category: cat,
                            earned: txVM.earnedByCategory(cat.id)
                        )
                        .contextMenu {
                            Button {
                                editingIncomeCategory = cat
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Button {
                showAddIncome = true
            } label: {
                Label("New Income Category", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.peraSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Income Category Card

private struct IncomeWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.72))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY * 0.72),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.18)
        )
        path.closeSubpath()
        return path
    }
}

private struct IncomeCategoryCard: View {
    let category: Category
    let earned: Double

    var body: some View {
        VStack(spacing: 0) {
            // Wave header with icon
            ZStack {
                IncomeWaveShape()
                    .fill(category.color.opacity(0.13))
                    .frame(height: 72)

                ZStack {
                    Circle()
                        .fill(Color.peraSurface.opacity(0.75))
                        .frame(width: 40, height: 40)
                    Circle()
                        .strokeBorder(category.color.opacity(0.28), lineWidth: 1.5)
                        .frame(width: 40, height: 40)
                    CategoryIconView(icon: category.icon, size: 18, color: category.color)
                }
                .offset(y: -6)
            }

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if earned > 0 {
                    Text(earned.currencyString)
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.peraIncome)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Text("earned")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.peraSurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(category.color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Budget Editor (kept for internal use)

struct AllocationItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    var amountText: String
}

struct BudgetEditorView: View {
    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(TransactionViewModel.self) var txVM
    @Environment(\.dismiss) private var dismiss

    @State private var items: [AllocationItem] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Monthly Envelope Amounts") {
                    ForEach($items) { $item in
                        HStack {
                            HStack(spacing: 6) {
                                CategoryIconView(icon: item.icon, size: 14, color: item.color)
                                Text(item.name)
                            }
                            .foregroundStyle(item.color)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0", text: $item.amountText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                    }
                }
                .listRowBackground(Color.peraSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save(); dismiss() } }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadCurrentAllocations() }
        }
    }

    private func loadCurrentAllocations() {
        items = catVM.expenseCategories.map { cat in
            let amount: String
            if let env = budgetVM.envelope(for: cat.id), env.allocated > 0 {
                amount = String(format: "%.2f", env.allocated)
            } else if cat.budgetAmount > 0 {
                amount = String(format: "%.2f", cat.budgetAmount)
            } else {
                amount = ""
            }
            return AllocationItem(id: cat.id, name: cat.name, icon: cat.icon,
                                  color: cat.color, amountText: amount)
        }
    }

    private func save() async {
        let month = txVM.selectedMonth
        for item in items {
            let amount = Double(item.amountText) ?? 0
            let existing = budgetVM.envelope(for: item.id)
            var env = existing ?? BudgetEnvelope(userId: budgetVM.userId, categoryId: item.id,
                                                  month: month, allocated: 0)
            env.allocated = amount
            await budgetVM.upsert(env)
        }
    }
}

// MARK: - Envelope Detail

struct EnvelopeDetailView: View {
    let envelope: BudgetEnvelope
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(\.dismiss) private var dismiss

    private var spent: Double { txVM.spentByCategory(envelope.categoryId) }
    private var category: Category? { catVM.category(for: envelope.categoryId) }
    private var expenseTransactions: [Transaction] {
        txVM.transactions(for: envelope.categoryId).filter { $0.type == .expense }
    }
    private var allTransactions: [Transaction] { txVM.transactions(for: envelope.categoryId) }

    private var subcategoryBreakdown: [(name: String, amount: Double)] {
        var totals: [String: Double] = [:]
        // Seed all defined subcategories with $0
        for sub in category?.subcategories ?? [] {
            totals[sub] = 0
        }
        // Add actual transaction amounts
        for tx in expenseTransactions {
            let key = (tx.subcategory ?? "").isEmpty ? "Other" : tx.subcategory!
            totals[key, default: 0] += tx.amount
        }
        return totals.sorted { $0.value > $1.value }.map { (name: $0.key, amount: $0.value) }
    }

    private var showSubcategoryBreakdown: Bool {
        category?.subcategories.isEmpty == false
            || expenseTransactions.contains { !(($0.subcategory ?? "").isEmpty) }
    }

    @State private var detailTransaction: Transaction? = nil
    @State private var showingEdit = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let cat = category {
                        EnvelopeProgressRow(category: cat, envelope: envelope, spent: spent)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                if showSubcategoryBreakdown {
                    Section("By Subcategory") {
                        if subcategoryBreakdown.isEmpty {
                            Text("No transactions yet.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                                .listRowBackground(Color.peraSurface)
                        } else {
                            ForEach(subcategoryBreakdown, id: \.name) { item in
                                SubcategoryBreakdownRow(
                                    name: item.name,
                                    amount: item.amount,
                                    total: spent,
                                    color: category?.color ?? .accentColor
                                )
                                .listRowBackground(Color.peraSurface)
                            }
                        }
                    }
                }

                Section("Transactions") {
                    if allTransactions.isEmpty {
                        Text("No transactions this month.")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.peraSurface)
                    } else {
                        ForEach(allTransactions) { tx in
                            TransactionRowView(transaction: tx, category: category)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.peraSurface)
                                .contentShape(Rectangle())
                                .onTapGesture { detailTransaction = tx }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle(category?.name ?? "Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
            .sheet(item: $detailTransaction) { tx in
                TransactionDetailSheet(transaction: tx, category: catVM.category(for: tx.categoryId))
            }
            .sheet(isPresented: $showingEdit) {
                if let cat = category {
                    AddEnvelopeView(editingCategory: cat)
                }
            }
        }
    }
}

private struct SubcategoryBreakdownRow: View {
    let name: String
    let amount: Double
    let total: Double
    let color: Color

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(amount / total, 1.0)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                if amount > 0 {
                    Text(amount.currencyString)
                        .font(.subheadline.weight(.semibold))
                    Text("· \(Int(fraction * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.peraSecondary)
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * fraction, height: 5)
                        .animation(.spring(response: 0.4), value: fraction)
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, 4)
    }
}
