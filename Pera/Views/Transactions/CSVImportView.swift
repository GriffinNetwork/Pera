import SwiftUI

// MARK: - Draft model

struct TransactionDraft: Identifiable {
    let id: UUID
    var date: Date
    var amount: Double
    var type: TransactionType
    var memo: String
    var categoryId: String
    var subcategory: String = ""
    var include: Bool = true

    init(from parsed: ParsedTransaction, defaultCategoryId: String) {
        self.id = parsed.id
        self.date = parsed.date
        self.amount = parsed.amount
        self.type = parsed.type
        self.memo = parsed.memo
        self.categoryId = defaultCategoryId
    }
}

// MARK: - Container

struct CSVImportView: View {
    let file: CSVFile

    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .mapping
    @State private var mapping: ColumnMapping
    @State private var drafts: [TransactionDraft] = []
    @State private var isImporting = false

    enum Step { case mapping, categorize }

    init(file: CSVFile) {
        self.file = file
        _mapping = State(initialValue: CSVImporter.autoDetect(file))
    }

    // MARK: - Validation

    private var canAdvance: Bool {
        guard mapping.dateCol != nil else { return false }
        if mapping.useSplitAmount {
            return mapping.debitCol != nil || mapping.creditCol != nil
        }
        return mapping.amountCol != nil
    }

    private var selectedCount: Int { drafts.filter(\.include).count }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .mapping:
                    ColumnMappingStep(file: file, mapping: $mapping)
                case .categorize:
                    CategorizationStep(drafts: $drafts)
                }
            }
            .navigationTitle(step == .mapping ? "Map Columns" : "Categorize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .mapping {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Back") { step = .mapping }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == .mapping {
                        Button("Next") { advance() }
                            .fontWeight(.semibold)
                            .disabled(!canAdvance)
                    } else {
                        if isImporting {
                            ProgressView()
                        } else {
                            Button("Import (\(selectedCount))") { runImport() }
                                .fontWeight(.semibold)
                                .disabled(selectedCount == 0)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func advance() {
        let parsed = CSVImporter.parse(file, mapping: mapping)
        let defaultId = catVM.expenseCategories
            .first(where: { $0.name.lowercased().contains("other") })?.id
            ?? catVM.expenseCategories.first?.id
            ?? catVM.categories.first?.id ?? ""
        drafts = parsed.map { TransactionDraft(from: $0, defaultCategoryId: defaultId) }
        step = .categorize
    }

    private func runImport() {
        isImporting = true
        let toImport = drafts.filter(\.include).map { d in
            Transaction(
                userId: txVM.userId,
                amount: d.amount,
                type: d.type,
                categoryId: d.categoryId,
                subcategory: d.subcategory.isEmpty ? nil : d.subcategory,
                date: d.date,
                merchantName: d.memo.isEmpty ? nil : d.memo
            )
        }
        Task {
            await txVM.importTransactions(toImport)
            dismiss()
        }
    }
}

// MARK: - Step 1: Column Mapping

private struct ColumnMappingStep: View {
    let file: CSVFile
    @Binding var mapping: ColumnMapping

    // Picker tag: -1 = none, 0...n = column index
    private func colBinding(_ keyPath: WritableKeyPath<ColumnMapping, Int?>) -> Binding<Int> {
        Binding(
            get: { mapping[keyPath: keyPath] ?? -1 },
            set: { mapping[keyPath: keyPath] = $0 == -1 ? nil : $0 }
        )
    }

    var body: some View {
        Form {
            // Header preview
            Section("Columns in your file") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(file.headers.indices, id: \.self) { i in
                            Text(file.headers[i])
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(.tint)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listRowBackground(Color(.secondarySystemBackground))

            // Required fields
            Section {
                colPicker("Date", icon: "calendar", binding: colBinding(\.dateCol), required: true)

                Toggle(isOn: $mapping.useSplitAmount) {
                    Label("Separate Debit / Credit columns", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline)
                }

                if mapping.useSplitAmount {
                    colPicker("Debit (expenses)", icon: "arrow.up.circle", binding: colBinding(\.debitCol), required: false)
                    colPicker("Credit (income)", icon: "arrow.down.circle", binding: colBinding(\.creditCol), required: false)
                } else {
                    colPicker("Amount", icon: "dollarsign.circle", binding: colBinding(\.amountCol), required: true)
                }
            } header: {
                Text("Required")
            }
            .listRowBackground(Color(.secondarySystemBackground))

            // Optional fields
            Section("Optional") {
                colPicker("Transaction Type", icon: "tag", binding: colBinding(\.typeCol), required: false)
                colPicker("Description", icon: "text.alignleft", binding: colBinding(\.descCol), required: false)
            }
            .listRowBackground(Color(.secondarySystemBackground))

            // Data preview
            if !file.rows.isEmpty {
                Section("Data preview (first 3 rows)") {
                    ForEach(Array(file.rows.prefix(3).enumerated()), id: \.offset) { _, row in
                        let visible = row.prefix(min(file.headers.count, row.count))
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(zip(file.headers, visible)), id: \.0) { header, value in
                                HStack(alignment: .top) {
                                    Text(header)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 110, alignment: .leading)
                                    Text(value.trimmingCharacters(in: .init(charactersIn: " \"")))
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func colPicker(_ label: String, icon: String, binding: Binding<Int>, required: Bool) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            if required {
                Text("*")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            Spacer()
            Picker("", selection: binding) {
                Text("Select…").tag(-1)
                ForEach(file.headers.indices, id: \.self) { i in
                    Text(file.headers[i]).tag(i)
                }
            }
            .labelsHidden()
        }
    }
}

// MARK: - Step 2: Categorization

private struct CategorizationStep: View {
    @Binding var drafts: [TransactionDraft]
    @Environment(CategoryViewModel.self) var catVM

    @State private var globalCategoryId = ""

    private var includedCount: Int { drafts.filter(\.include).count }
    private var globalCategory: Category? { catVM.category(for: globalCategoryId) }

    var body: some View {
        List {
            // Global setter
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set all categories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        if let cat = globalCategory {
                            CategoryIconView(icon: cat.icon, size: 13, color: cat.color)
                        }
                        Picker("", selection: Binding(
                            get: { globalCategoryId },
                            set: { newVal in
                                globalCategoryId = newVal
                                for i in drafts.indices { drafts[i].categoryId = newVal }
                            }
                        )) {
                            Text("Select a category…").tag("")
                            ForEach(catVM.categories) { cat in
                                Text(cat.name).tag(cat.id)
                            }
                        }
                        .labelsHidden()
                        .tint(globalCategory?.color ?? .accentColor)
                    }
                }
                .padding(.vertical, 2)
            } footer: {
                Text("\(includedCount) of \(drafts.count) transactions selected.")
            }
            .listRowBackground(Color(.secondarySystemBackground))

            // Per-transaction rows
            Section("Transactions") {
                ForEach($drafts) { $draft in
                    DraftRow(draft: $draft)
                }
            }
            .listRowBackground(Color(.secondarySystemBackground))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .onAppear {
            globalCategoryId = drafts.first?.categoryId ?? ""
        }
    }
}

private struct DraftRow: View {
    @Binding var draft: TransactionDraft
    @Environment(CategoryViewModel.self) var catVM
    @State private var showCategoryPicker = false
    @State private var showSubcategoryPicker = false

    private var expenseColor: Color { Color(red: 0.95, green: 0.2, blue: 0.2) }
    private var incomeColor:  Color { Color(red: 0.2, green: 0.75, blue: 0.4) }
    private var rowColor: Color { draft.type == .expense ? expenseColor : incomeColor }
    private var selectedCategory: Category? { catVM.category(for: draft.categoryId) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Include toggle
            Button {
                draft.include.toggle()
            } label: {
                Image(systemName: draft.include ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(draft.include ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                // Memo + amount
                HStack(alignment: .top) {
                    Text(draft.memo.isEmpty ? "No description" : draft.memo)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                    Text("\(draft.type == .expense ? "-" : "+")\(draft.amount.currencyString)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(rowColor)
                }

                // Date (left) + type toggle (right, under amount)
                HStack {
                    Text(draft.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        draft.type = draft.type == .expense ? .income : .expense
                    } label: {
                        Text(draft.type == .expense ? "Expense" : "Income")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(rowColor.opacity(0.15))
                            .foregroundStyle(rowColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Category + subcategory
                HStack(spacing: 6) {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        if let cat = selectedCategory {
                            CategoryIconView(icon: cat.icon, size: 20, color: cat.color)
                        } else {
                            Image(systemName: "tag.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showCategoryPicker) {
                        CategoryPickerSheet(selectedId: $draft.categoryId) {
                            draft.subcategory = ""
                        }
                    }

                    let subs = selectedCategory?.subcategories ?? []
                    if let cat = selectedCategory {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Button {
                            showSubcategoryPicker = true
                        } label: {
                            Text(draft.subcategory.isEmpty ? "Subcategory" : draft.subcategory)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showSubcategoryPicker) {
                            SubcategoryPickerSheet(
                                category: cat,
                                selected: $draft.subcategory
                            )
                        }
                    }
                }
            }
            .opacity(draft.include ? 1 : 0.4)
        }
        .padding(.vertical, 4)
    }
}

private struct CategoryPickerSheet: View {
    @Binding var selectedId: String
    let onSelect: () -> Void
    @Environment(CategoryViewModel.self) var catVM
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCategory = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(catVM.categories) { cat in
                    Button {
                        selectedId = cat.id
                        onSelect()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(cat.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                CategoryIconView(icon: cat.icon, size: 16, color: cat.color)
                            }
                            Text(cat.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if cat.id == selectedId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(Color.peraSurface)
                }

                Button {
                    showAddCategory = true
                } label: {
                    Label("New Category", systemImage: "plus.circle.fill")
                        .foregroundStyle(.tint)
                }
                .listRowBackground(Color.peraSurface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddEnvelopeView()
            }
        }
    }
}

private struct SubcategoryPickerSheet: View {
    let category: Category
    @Binding var selected: String
    @Environment(CategoryViewModel.self) var catVM
    @Environment(\.dismiss) private var dismiss
    @State private var newSubcategoryName = ""
    @State private var isAdding = false

    private var subcategories: [String] {
        catVM.category(for: category.id)?.subcategories ?? category.subcategories
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selected = ""
                    dismiss()
                } label: {
                    HStack {
                        Text("None").foregroundStyle(.primary)
                        Spacer()
                        if selected.isEmpty {
                            Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                        }
                    }
                }
                .listRowBackground(Color.peraSurface)

                ForEach(subcategories, id: \.self) { sub in
                    Button {
                        selected = sub
                        dismiss()
                    } label: {
                        HStack {
                            Text(sub).foregroundStyle(.primary)
                            Spacer()
                            if selected == sub {
                                Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                            }
                        }
                    }
                    .listRowBackground(Color.peraSurface)
                }

                Section("New Subcategory") {
                    HStack {
                        TextField("Name", text: $newSubcategoryName)
                        if isAdding {
                            ProgressView()
                        } else {
                            Button("Add") {
                                let name = newSubcategoryName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty, !subcategories.contains(name) else { return }
                                isAdding = true
                                Task {
                                    var updated = catVM.category(for: category.id) ?? category
                                    updated.subcategories.append(name)
                                    await catVM.add(updated)
                                    selected = name
                                    isAdding = false
                                    dismiss()
                                }
                            }
                            .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .listRowBackground(Color.peraSurface)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle("Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.medium, .large])
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
