import SwiftUI

struct BudgetView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel
    @State private var showEditor = false
    @State private var editingEnvelope: BudgetEnvelope?

    private var totalBudget: Double { budgetVM.totalAllocated }
    private var totalSpent: Double { txVM.totalExpenses }
    private var unallocated: Double {
        txVM.totalIncome - budgetVM.totalAllocated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard
                    envelopeList
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
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
                    Button { showEditor = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                BudgetEditorView()
            }
            .refreshable {
                await txVM.load()
                await budgetVM.load(month: txVM.selectedMonth)
            }
        }
    }

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
                    Text("Unallocated")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(unallocated.currencyString)
                        .font(.title2.bold())
                        .foregroundStyle(unallocated < 0 ? .red : .green)
                }
            }

            Divider()

            HStack {
                Text("Spent: \(totalSpent.currencyString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((totalBudget > 0 ? totalSpent / totalBudget : 0) * 100))% of budget")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var envelopeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Envelopes")
                .font(.headline)

            if budgetVM.envelopes.isEmpty {
                ContentUnavailableView("No Envelopes",
                    systemImage: "envelope",
                    description: Text("Tap the sliders icon to set up your budget envelopes."))
            } else {
                ForEach(budgetVM.envelopes.sorted { $0.allocated > $1.allocated }) { envelope in
                    if let cat = catVM.category(for: envelope.categoryId) {
                        EnvelopeProgressRow(
                            category: cat,
                            envelope: envelope,
                            spent: txVM.spentByCategory(envelope.categoryId)
                        )
                        .onTapGesture {
                            editingEnvelope = envelope
                        }
                    }
                }
            }
        }
        .sheet(item: $editingEnvelope) { env in
            EnvelopeDetailView(envelope: env)
        }
    }
}

// MARK: - Budget Editor

struct BudgetEditorView: View {
    @EnvironmentObject var catVM: CategoryViewModel
    @EnvironmentObject var budgetVM: BudgetViewModel
    @EnvironmentObject var txVM: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var allocations: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Set Monthly Envelope Amounts") {
                    ForEach(catVM.expenseCategories) { cat in
                        HStack {
                            Label(cat.name, systemImage: cat.icon)
                                .foregroundStyle(cat.color)
                            Spacer()
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0", text: Binding(
                                    get: { allocations[cat.id] ?? "" },
                                    set: { allocations[cat.id] = $0 }
                                ))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
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
        for cat in catVM.expenseCategories {
            if let env = budgetVM.envelope(for: cat.id) {
                allocations[cat.id] = env.allocated > 0 ? String(format: "%.2f", env.allocated) : ""
            } else if cat.budgetAmount > 0 {
                allocations[cat.id] = String(format: "%.2f", cat.budgetAmount)
            }
        }
    }

    private func save() async {
        let month = txVM.selectedMonth
        for cat in catVM.expenseCategories {
            let amount = Double(allocations[cat.id] ?? "") ?? 0
            let existing = budgetVM.envelope(for: cat.id)
            var env = existing ?? BudgetEnvelope(userId: budgetVM.userId, categoryId: cat.id,
                                                  month: month, allocated: 0)
            env.allocated = amount
            await budgetVM.upsert(env)
        }
    }
}

// MARK: - Envelope Detail

struct EnvelopeDetailView: View {
    let envelope: BudgetEnvelope
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel
    @Environment(\.dismiss) private var dismiss

    private var spent: Double { txVM.spentByCategory(envelope.categoryId) }
    private var category: Category? { catVM.category(for: envelope.categoryId) }
    private var transactions: [Transaction] { txVM.transactions(for: envelope.categoryId) }

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

                Section("Transactions") {
                    if transactions.isEmpty {
                        Text("No transactions this month.")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color(.secondarySystemBackground))
                    } else {
                        ForEach(transactions) { tx in
                            TransactionRowView(transaction: tx, category: category)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color(.secondarySystemBackground))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(category?.name ?? "Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
