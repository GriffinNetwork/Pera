import SwiftUI

struct AddEnvelopeView: View {
    var editingCategory: Category? = nil

    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(TransactionViewModel.self) var txVM
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorHex = "#5E6AD2"
    @State private var amount = ""
    @State private var isSaving = false
    @State private var subcategories: [String] = []
    @State private var subcategoryBudgets: [String: String] = [:]
    @State private var newSubcategory = ""
    @State private var emojiInput = ""
    @State private var showDeleteConfirm = false

    private var subcategoryTotal: Double {
        subcategories.compactMap { subcategoryBudgets[$0].flatMap(Double.init) }
            .filter { $0 > 0 }
            .reduce(0, +)
    }
    private var hasSubcategoryBudgets: Bool { subcategoryTotal > 0 }

    private let iconOptions = [
        "tag.fill", "cart.fill", "house.fill", "car.fill", "airplane",
        "gift.fill", "heart.fill", "book.fill", "gamecontroller.fill",
        "fork.knife", "cup.and.saucer.fill", "dumbbell.fill", "pawprint.fill",
        "music.note", "camera.fill", "tv.fill", "phone.fill", "laptopcomputer",
        "bag.fill", "bolt.fill", "banknote.fill", "creditcard.fill", "bus.fill",
        "tram.fill", "bicycle", "leaf.fill", "star.fill", "moon.fill"
    ]

    private let colorOptions = [
        "#5E6AD2", "#E8543A", "#F5A623", "#E91E8C", "#9B59B6",
        "#1ABC9C", "#3498DB", "#2ECC71", "#E74C3C", "#95A5A6",
        "#F39C12", "#16A085", "#8E44AD", "#2980B9", "#27AE60"
    ]

    private var isEditing: Bool { editingCategory != nil }
    private var canSave: Bool { !name.isEmpty && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                iconSection
                colorSection
                subcategoriesSection
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Envelope", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listRowBackground(Color.peraSurface)
                }
            }
            .alert("Delete \"\(name)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete Envelope", role: .destructive) {
                    Task {
                        if let cat = editingCategory {
                            if let env = budgetVM.envelope(for: cat.id) {
                                await budgetVM.delete(env)
                            }
                            await catVM.delete(cat)
                        }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the envelope and its category. Transactions will not be deleted.")
            }
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle(isEditing ? "Edit Envelope" : "New Envelope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Add") { save() }
                            .disabled(!canSave)
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onAppear { populate() }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            TextField("Envelope Name", text: $name)
            HStack {
                Text("Monthly Budget")
                Spacer()
                if hasSubcategoryBudgets {
                    Text(subcategoryTotal.currencyString)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            if hasSubcategoryBudgets {
                Text("Total is calculated from subcategory budgets.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowBackground(Color.peraSurface)
    }

    private var iconSection: some View {
        Section("Icon") {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.15))
                        .frame(width: 44, height: 44)
                    CategoryIconView(icon: icon, size: 20, color: Color(hex: colorHex))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current").font(.caption).foregroundStyle(.secondary)
                    Text(icon).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Or use emoji").font(.caption).foregroundStyle(.secondary)
                    TextField("😀", text: $emojiInput)
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .onChange(of: emojiInput) { _, val in
                            if let ch = val.first, ch.unicodeScalars.first.map({ $0.value > 0x2000 }) == true {
                                icon = String(ch); emojiInput = String(ch)
                            } else if val.isEmpty && icon.isEmojiIcon {
                                icon = "tag.fill"
                            }
                        }
                }
            }
            .padding(.vertical, 4)

            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                ForEach(iconOptions, id: \.self) { sym in
                    Button {
                        icon = sym
                        emojiInput = ""
                    } label: {
                        ZStack {
                            Circle()
                                .fill(icon == sym ? Color(hex: colorHex) : Color.peraSecondary)
                                .frame(width: 44, height: 44)
                            Image(systemName: sym)
                                .foregroundStyle(icon == sym ? .white : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color(.secondarySystemBackground))
    }

    private var colorSection: some View {
        Section("Color") {
            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                ForEach(colorOptions, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                            if colorHex == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color(.secondarySystemBackground))
    }

    private func subcategoryBinding(_ index: Int) -> Binding<String> {
        Binding(get: { subcategories[index] }, set: { subcategories[index] = $0 })
    }

    private func subcategoryBudgetBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard index < self.subcategories.count else { return "" }
                return self.subcategoryBudgets[self.subcategories[index]] ?? ""
            },
            set: {
                guard index < self.subcategories.count else { return }
                self.subcategoryBudgets[self.subcategories[index]] = $0.isEmpty ? nil : $0
            }
        )
    }

    private var subcategoriesSection: some View {
        Section {
            ForEach(subcategories.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    TextField("Subcategory", text: subcategoryBinding(i))
                    Divider()
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(.secondary).font(.subheadline)
                        TextField("optional", text: subcategoryBudgetBinding(at: i))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)
                            .foregroundStyle(
                                (Double(subcategoryBudgetBinding(at: i).wrappedValue) ?? 0) > 0
                                    ? .primary : .secondary
                            )
                    }
                    Button {
                        let sub = subcategories[i]
                        subcategories.remove(at: i)
                        subcategoryBudgets.removeValue(forKey: sub)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Color.peraExpense)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("Add subcategory…", text: $newSubcategory)
                    .onSubmit { addSubcategory() }
                Button { addSubcategory() } label: {
                    let empty = newSubcategory.trimmingCharacters(in: .whitespaces).isEmpty
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.tint)
                        .opacity(empty ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(newSubcategory.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Subcategories")
        } footer: {
            Text("Optionally set a budget per subcategory — any amounts entered will become the envelope total.")
        }
        .listRowBackground(Color.peraSurface)
    }

    private func addSubcategory() {
        let trimmed = newSubcategory.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !subcategories.contains(trimmed) else { return }
        subcategories.append(trimmed)
        newSubcategory = ""
    }

    private func populate() {
        guard let cat = editingCategory else { return }
        name = cat.name
        icon = cat.icon
        colorHex = cat.colorHex
        subcategories = cat.subcategories
        if cat.icon.isEmojiIcon { emojiInput = cat.icon }
        subcategoryBudgets = cat.subcategoryBudgets
            .mapValues { $0 > 0 ? String(format: "%.2f", $0) : "" }
        let subTotal = cat.subcategoryBudgets.values.reduce(0, +)
        if subTotal == 0 {
            if let env = budgetVM.envelope(for: cat.id), env.allocated > 0 {
                amount = String(format: "%.2f", env.allocated)
            } else if cat.budgetAmount > 0 {
                amount = String(format: "%.2f", cat.budgetAmount)
            }
        }
    }

    private func save() {
        isSaving = true
        let month = txVM.selectedMonth
        let currentSubs = Set(subcategories.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        let budgetMap = subcategoryBudgets
            .filter { currentSubs.contains($0.key) }
            .compactMapValues { str -> Double? in
                guard let v = Double(str), v > 0 else { return nil }
                return v
            }
        let resolvedBudget = budgetMap.values.reduce(0, +) > 0
            ? budgetMap.values.reduce(0, +)
            : (Double(amount) ?? 0)

        if var cat = editingCategory {
            cat.name = name
            cat.icon = icon
            cat.colorHex = colorHex
            cat.subcategories = subcategories.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            cat.subcategoryBudgets = budgetMap
            cat.budgetAmount = resolvedBudget
            var env = budgetVM.envelope(for: cat.id)
                ?? BudgetEnvelope(userId: budgetVM.userId, categoryId: cat.id, month: month, allocated: 0)
            env.allocated = resolvedBudget
            Task {
                await catVM.add(cat)
                await budgetVM.upsert(env)
                dismiss()
            }
        } else {
            var cat = Category(
                userId: catVM.userId,
                name: name,
                icon: icon,
                colorHex: colorHex,
                type: .expense,
                subcategories: subcategories.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                budgetAmount: resolvedBudget,
                sortOrder: catVM.categories.count
            )
            cat.subcategoryBudgets = budgetMap
            let env = BudgetEnvelope(
                userId: budgetVM.userId,
                categoryId: cat.id,
                month: month,
                allocated: resolvedBudget
            )
            Task {
                await catVM.add(cat)
                await budgetVM.upsert(env)
                dismiss()
            }
        }
    }
}
