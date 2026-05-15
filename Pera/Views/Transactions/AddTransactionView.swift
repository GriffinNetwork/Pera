import SwiftUI

struct AddTransactionView: View {
    @EnvironmentObject var txVM: TransactionViewModel
    @EnvironmentObject var catVM: CategoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var selectedCategoryId = ""
    @State private var merchantName = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var subcategory = ""
    @State private var isRecurring = false
    @State private var isSaving = false

    private var categories: [Category] {
        type == .expense ? catVM.expenseCategories : catVM.incomeCategories
    }

    private var selectedCategory: Category? {
        catVM.category(for: selectedCategoryId)
    }

    private var amountDouble: Double { Double(amount) ?? 0 }

    private var canSave: Bool {
        amountDouble > 0 && !selectedCategoryId.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount + type
                Section {
                    VStack(spacing: 16) {
                        Picker("Type", selection: $type) {
                            ForEach(TransactionType.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: type) { _, _ in selectedCategoryId = "" }

                        HStack {
                            Text("$")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $amount)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color(.secondarySystemBackground))

                // Category
                Section("Category") {
                    if categories.isEmpty {
                        Text("No categories").foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(categories) { cat in
                                    CategoryChip(category: cat,
                                                 isSelected: selectedCategoryId == cat.id) {
                                        selectedCategoryId = cat.id
                                        subcategory = ""
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        if let cat = selectedCategory, !cat.subcategories.isEmpty {
                            Picker("Subcategory", selection: $subcategory) {
                                Text("None").tag("")
                                ForEach(cat.subcategories, id: \.self) { sub in
                                    Text(sub).tag(sub)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))

                // Details
                Section("Details") {
                    TextField("Merchant / Payee", text: $merchantName)
                    TextField("Note (optional)", text: $note)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Toggle("Recurring", isOn: $isRecurring)
                }
                .listRowBackground(Color(.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let first = categories.first { selectedCategoryId = first.id }
        }
    }

    private func save() {
        isSaving = true
        let tx = Transaction(
            userId: txVM.userId,
            amount: amountDouble,
            type: type,
            categoryId: selectedCategoryId,
            subcategory: subcategory.isEmpty ? nil : subcategory,
            note: note.isEmpty ? nil : note,
            date: date,
            merchantName: merchantName.isEmpty ? nil : merchantName,
            isRecurring: isRecurring
        )
        Task {
            await txVM.add(tx)
            dismiss()
        }
    }
}

private struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? category.color : category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? .white : category.color)
                }
                Text(category.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? category.color : .secondary)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
    }
}
