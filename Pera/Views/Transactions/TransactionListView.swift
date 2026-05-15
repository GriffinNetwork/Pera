import SwiftUI

struct TransactionListView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel

    @State private var showAddTransaction = false
    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil

    private var filtered: [Transaction] {
        txVM.transactions.filter { tx in
            let matchesSearch = searchText.isEmpty
                || tx.merchantName?.localizedCaseInsensitiveContains(searchText) == true
                || tx.note?.localizedCaseInsensitiveContains(searchText) == true
                || catVM.category(for: tx.categoryId)?.name.localizedCaseInsensitiveContains(searchText) == true
            let matchesType = selectedType == nil || tx.type == selectedType
            return matchesSearch && matchesType
        }
    }

    private var grouped: [(key: Date, value: [Transaction])] {
        let g = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
        return g.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if txVM.isLoading && txVM.transactions.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        filterChips
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())

                        if filtered.isEmpty {
                            ContentUnavailableView("No Transactions",
                                systemImage: "doc.text.magnifyingglass",
                                description: Text(searchText.isEmpty ? "Add your first transaction." : "No results for "\(searchText)""))
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(grouped, id: \.key) { day, txs in
                                Section(header: Text(day.shortDisplay).font(.caption).foregroundStyle(.secondary)) {
                                    ForEach(txs) { tx in
                                        TransactionRowView(transaction: tx, category: catVM.category(for: tx.categoryId))
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color(.secondarySystemBackground))
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    Task { await txVM.delete(tx) }
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    MonthPickerButton(selectedMonth: $txVM.selectedMonth) {
                        Task { await txVM.load() }
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .refreshable { await txVM.load() }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: selectedType == nil) {
                    selectedType = nil
                }
                FilterChip(label: "Expenses", isSelected: selectedType == .expense) {
                    selectedType = selectedType == .expense ? nil : .expense
                }
                FilterChip(label: "Income", isSelected: selectedType == .income) {
                    selectedType = selectedType == .income ? nil : .income
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct MonthPickerButton: View {
    @Binding var selectedMonth: String
    let onChange: () -> Void

    @State private var showPicker = false

    private var displayLabel: String {
        let (start, _) = selectedMonth.monthDateRange()
        return start.displayMonth
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Text(displayLabel)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .confirmationDialog("Select Month", isPresented: $showPicker, titleVisibility: .visible) {
            ForEach(-12...0, id: \.self) { offset in
                let month = Date().adding(months: offset).monthKey
                let (start, _) = month.monthDateRange()
                Button(start.displayMonth) {
                    selectedMonth = month
                    onChange()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
