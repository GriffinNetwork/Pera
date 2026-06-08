import SwiftUI
import UniformTypeIdentifiers

struct TransactionListView: View {
    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @State private var showAddTransaction = false
    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var editingTransaction: Transaction? = nil
    @State private var detailTransaction: Transaction? = nil
    @State private var showFilePicker = false
    @State private var csvFile: CSVFile? = nil
    @State private var showImportError = false
    @State private var isSelecting = false
    @State private var selectedIds = Set<String>()
    @State private var showDeleteConfirm = false

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
        @Bindable var txVM = txVM
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
                                description: Text(searchText.isEmpty ? "Add your first transaction." : "No results for \"\(searchText)\""))
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(grouped, id: \.key) { day, txs in
                                Section(header: Text(day.shortDisplay).font(.caption).foregroundStyle(.secondary)) {
                                    ForEach(txs) { tx in
                                        let isSelected = selectedIds.contains(tx.id)
                                        HStack(spacing: 0) {
                                            if isSelecting {
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                                                    .font(.title3)
                                                    .padding(.leading, 14)
                                                    .animation(.spring(response: 0.2), value: isSelected)
                                            }
                                            TransactionRowView(transaction: tx, category: catVM.category(for: tx.categoryId))
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            if isSelecting {
                                                if isSelected { selectedIds.remove(tx.id) }
                                                else { selectedIds.insert(tx.id) }
                                            } else {
                                                detailTransaction = tx
                                            }
                                        }
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(isSelected ? Color.accentColor.opacity(0.08) : Color.peraSurface)
                                        .contextMenu {
                                            if !isSelecting {
                                                Button { editingTransaction = tx } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                Button {
                                                    isSelecting = true
                                                    selectedIds = [tx.id]
                                                } label: {
                                                    Label("Select", systemImage: "checkmark.circle")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.peraBackground)
                }
            }
            .navigationTitle(isSelecting
                ? (selectedIds.isEmpty ? "Select Items" : "\(selectedIds.count) Selected")
                : "Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                if isSelecting {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            isSelecting = false
                            selectedIds.removeAll()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                        .disabled(selectedIds.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                showAddTransaction = true
                            } label: {
                                Label("Add Transaction", systemImage: "plus")
                            }
                            Button {
                                showFilePicker = true
                            } label: {
                                Label("Import CSV", systemImage: "doc.badge.arrow.up")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        DateFilterButton(filter: $txVM.dateFilter) {
                            Task { await txVM.load() }
                        }
                    }
                }
            }
            .alert(
                "Delete \(selectedIds.count) transaction\(selectedIds.count == 1 ? "" : "s")?",
                isPresented: $showDeleteConfirm
            ) {
                Button("Delete", role: .destructive) {
                    let ids = selectedIds
                    isSelecting = false
                    selectedIds.removeAll()
                    Task { await txVM.deleteMultiple(ids) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction) { tx in
                AddTransactionView(editing: tx)
            }
            .sheet(item: $detailTransaction) { tx in
                TransactionDetailSheet(transaction: tx, category: catVM.category(for: tx.categoryId))
            }
            .sheet(item: $csvFile) { file in
                CSVImportView(file: file)
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Couldn't Read File", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The file appears to be empty or isn't a valid CSV. Make sure it has a header row with column names.")
            }
            .refreshable { await txVM.load() }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        let text = (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .utf16))
            ?? ""

        if let file = CSVImporter.load(text) {
            csvFile = file
        } else {
            showImportError = true
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

// MARK: - Transaction Detail Sheet

struct TransactionDetailSheet: View {
    let transaction: Transaction
    let category: Category?
    @State private var editingTransaction: Transaction? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    amountHeader
                    detailsCard
                    if let urlString = transaction.receiptImageURL, !urlString.isEmpty {
                        receiptCard(urlString: urlString)
                    }
                }
                .padding()
            }
            .background(Color.peraBackground)
            .navigationTitle(transaction.merchantName ?? category?.name ?? "Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { editingTransaction = transaction }
                }
            }
            .sheet(item: $editingTransaction) { tx in
                AddTransactionView(editing: tx)
            }
        }
    }

    private var amountHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((category?.color ?? .gray).opacity(0.15))
                    .frame(width: 60, height: 60)
                CategoryIconView(icon: category?.icon ?? "questionmark",
                                 size: 26, color: category?.color ?? .gray)
            }
            Text(amountText)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(transaction.type == .income ? Color.peraIncome : Color.peraExpense)
        }
        .padding(.top, 4)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow("Category",  category?.name ?? "—")
            Divider().padding(.leading)
            detailRow("Date", transaction.date.formatted(date: .long, time: .omitted))
            if let m = transaction.merchantName, !m.isEmpty {
                Divider().padding(.leading)
                detailRow("Merchant", m)
            }
            if let s = transaction.subcategory, !s.isEmpty {
                Divider().padding(.leading)
                detailRow("Subcategory", s)
            }
            if let n = transaction.note, !n.isEmpty {
                Divider().padding(.leading)
                detailRow("Note", n)
            }
        }
        .background(Color.peraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func receiptCard(urlString: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Receipt", systemImage: "paperclip")
                .font(.headline)

            if let url = URL(string: urlString) {
                EncryptedReceiptView(url: url, userId: transaction.userId)
            }
        }
    }

    private var amountText: String {
        (transaction.type == .income ? "+" : "-") + transaction.amount.currencyString
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
                .background(isSelected ? Color.accentColor : Color.peraSecondary)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct MonthPickerButton: View {
    @Binding var selectedMonth: String
    let onChange: () -> Void

    @State private var showPicker = false
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())

    private var displayLabel: String {
        let (start, _) = selectedMonth.monthDateRange()
        return start.displayMonth
    }

    var body: some View {
        Button {
            let (start, _) = selectedMonth.monthDateRange()
            pickerMonth = Calendar.current.component(.month, from: start)
            pickerYear = Calendar.current.component(.year, from: start)
            showPicker = true
        } label: {
            HStack(spacing: 4) {
                Text(displayLabel)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .sheet(isPresented: $showPicker) {
            MonthYearPickerSheet(
                month: $pickerMonth,
                year: $pickerYear,
                onDone: {
                    var comps = DateComponents()
                    comps.year = pickerYear
                    comps.month = pickerMonth
                    comps.day = 1
                    if let date = Calendar.current.date(from: comps) {
                        selectedMonth = date.monthKey
                        onChange()
                    }
                    showPicker = false
                },
                onCancel: { showPicker = false }
            )
        }
    }
}

private struct MonthYearPickerSheet: View {
    @Binding var month: Int
    @Binding var year: Int
    let onDone: () -> Void
    let onCancel: () -> Void

    private let monthSymbols = Calendar.current.monthSymbols
    private let currentYear = Calendar.current.component(.year, from: Date())
    private var years: [Int] { Array((currentYear - 10)...currentYear) }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Month", selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(monthSymbols[m - 1]).tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Year", selection: $year) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 110)
            }
            .padding(.horizontal)
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
        .onChange(of: year) { _, newYear in
            if newYear == currentYear {
                let nowMonth = Calendar.current.component(.month, from: Date())
                if month > nowMonth { month = nowMonth }
            }
        }
    }
}

// MARK: - DateFilterButton

struct DateFilterButton: View {
    @Binding var filter: DateFilter
    let onChange: () -> Void

    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 4) {
                Text(filter.label)
                    .font(.subheadline)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .sheet(isPresented: $showSheet) {
            DateFilterSheet(filter: $filter) {
                showSheet = false
                onChange()
            }
        }
    }
}

// MARK: - DateFilterSheet

struct DateFilterSheet: View {
    @Binding var filter: DateFilter
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable {
        case month = "Month"
        case range = "Range"
    }

    @State private var mode: Mode = .month
    @State private var pickedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var pickedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedRangeFilter: DateFilter = .sixMonths
    @State private var customStart: Date = Date().adding(months: -1).startOfMonth
    @State private var customEnd: Date = Date().endOfMonth
    @State private var showCustom: Bool = false

    private let currentYear = Calendar.current.component(.year, from: Date())
    private var availableYears: [Int] { Array((currentYear - 5)...currentYear) }
    private let monthSymbols = Calendar.current.monthSymbols

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)

                Divider().padding(.top)

                if mode == .month {
                    monthPickerContent
                } else {
                    rangePickerContent
                }

                Spacer()
            }
            .navigationTitle("Select Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { applyAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { syncFromFilter() }
    }

    private var monthPickerContent: some View {
        HStack(spacing: 0) {
            Picker("Month", selection: $pickedMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(monthSymbols[m - 1]).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)

            Picker("Year", selection: $pickedYear) {
                ForEach(availableYears, id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 110)
        }
        .padding(.horizontal)
    }

    private var rangePickerContent: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                presetButton("This Quarter", preset: .quarter)
                presetButton("Last 6 Months", preset: .sixMonths)
                presetButton("This Year", preset: .year)
                presetButton("Custom", preset: nil)
            }
            .padding(.horizontal)

            if showCustom {
                VStack(spacing: 0) {
                    DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    Divider().padding(.leading)
                    DatePicker("To", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                }
                .background(Color.peraSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.top)
        .animation(.spring(response: 0.3), value: showCustom)
    }

    @ViewBuilder
    private func presetButton(_ title: String, preset: DateFilter?) -> some View {
        let isSelected = isPresetSelected(preset)
        Button {
            if preset == nil {
                showCustom = true
                selectedRangeFilter = .custom(start: customStart, end: customEnd)
            } else {
                showCustom = false
                selectedRangeFilter = preset!
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.accentColor : Color.peraSurface)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func isPresetSelected(_ preset: DateFilter?) -> Bool {
        if preset == nil {
            if case .custom = selectedRangeFilter { return true }
            return false
        }
        return selectedRangeFilter == preset
    }

    private func syncFromFilter() {
        let cal = Calendar.current
        switch filter {
        case .month(let date):
            mode = .month
            pickedMonth = cal.component(.month, from: date)
            pickedYear = cal.component(.year, from: date)
        case .quarter:
            mode = .range; selectedRangeFilter = .quarter
        case .sixMonths:
            mode = .range; selectedRangeFilter = .sixMonths
        case .year:
            mode = .range; selectedRangeFilter = .year
        case .custom(let s, let e):
            mode = .range
            customStart = s; customEnd = e
            showCustom = true
            selectedRangeFilter = .custom(start: s, end: e)
        }
    }

    private func applyAndDismiss() {
        switch mode {
        case .month:
            var comps = DateComponents()
            comps.year = pickedYear
            comps.month = pickedMonth
            filter = .month(Calendar.current.date(from: comps) ?? Date())
        case .range:
            if case .custom = selectedRangeFilter {
                filter = .custom(start: customStart, end: customEnd)
            } else {
                filter = selectedRangeFilter
            }
        }
        onApply()
    }
}
