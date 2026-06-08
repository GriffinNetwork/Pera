import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(AuthService.self) var auth
    @Environment(CategoryViewModel.self) var catVM
    @AppStorage("colorSchemePreference") private var colorSchemePreference = "system"
    @AppStorage("dashboardHiddenEnvelopeIds") private var hiddenIds = ""
    @AppStorage("dashboardEnvelopeOrder") private var orderIds = ""
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountStep1 = false
    @State private var showDeleteAccountStep2 = false

    private var orderedExpenseCategories: [Category] {
        let ids = orderIds.split(separator: ",").map(String.init)
        let lookup = Dictionary(uniqueKeysWithValues: catVM.expenseCategories.map { ($0.id, $0) })
        var result = ids.compactMap { lookup[$0] }
        let seen = Set(result.map { $0.id })
        result += catVM.expenseCategories.filter { !seen.contains($0.id) }
        return result
    }

    private var hiddenIdSet: Set<String> {
        Set(hiddenIds.split(separator: ",").map(String.init))
    }

    private func isShown(_ categoryId: String) -> Bool {
        !hiddenIdSet.contains(categoryId)
    }

    private func toggleShown(_ categoryId: String) {
        var set = hiddenIdSet
        if set.contains(categoryId) { set.remove(categoryId) } else { set.insert(categoryId) }
        hiddenIds = set.joined(separator: ",")
    }

    var body: some View {
        NavigationStack {
            List {
                // Profile section
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Text(initials)
                                .font(.title3.bold())
                                .foregroundStyle(.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auth.currentUser?.displayName ?? "User")
                                .font(.headline)
                            Text(auth.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.peraSurface)

                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $colorSchemePreference) {
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Light", systemImage: "sun.max.fill").tag("light")
                        Label("Dark", systemImage: "moon.fill").tag("dark")
                    }
                    .pickerStyle(.menu)
                }
                .listRowBackground(Color.peraSurface)

                // Dashboard
                Section {
                    ForEach(orderedExpenseCategories) { cat in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(cat.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                CategoryIconView(icon: cat.icon, size: 14, color: cat.color)
                            }
                            Text(cat.name)
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { isShown(cat.id) },
                                set: { _ in toggleShown(cat.id) }
                            ))
                            .labelsHidden()
                        }
                    }
                    NavigationLink {
                        DashboardEnvelopeOrderView()
                    } label: {
                        Label("Reorder Envelopes", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                } header: {
                    Text("Budget Overview")
                } footer: {
                    Text("Choose which envelopes appear in the Dashboard budget overview and their display order.")
                }
                .listRowBackground(Color.peraSurface)

                // Account
                Section("Account") {
                    Button(role: .destructive) {
                        showSignOutConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        showDeleteAccountStep1 = true
                    } label: {
                        Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    }
                }
                .listRowBackground(Color.peraSurface)
                .alert("Sign out of Pera?", isPresented: $showSignOutConfirm) {
                    Button("Sign Out", role: .destructive) { auth.signOut() }
                    Button("Cancel", role: .cancel) {}
                }
                .alert("Delete your account?", isPresented: $showDeleteAccountStep1) {
                    Button("Yes, Continue", role: .destructive) { showDeleteAccountStep2 = true }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your account and all associated data will be permanently deleted.")
                }
                .alert("Permanently delete account?", isPresented: $showDeleteAccountStep2) {
                    Button("Delete Account", role: .destructive) {
                        Task { await auth.deleteAccount() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone. All your transactions, categories, and budgets will be deleted forever.")
                }

                // About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
                .listRowBackground(Color.peraSurface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle("Settings")
        }
    }

    private var initials: String {
        let name = auth.currentUser?.displayName ?? auth.currentUser?.email ?? "U"
        return name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Add Category

struct AddCategoryView: View {
    var editing: Category? = nil
    var forcedType: TransactionType? = nil

    @Environment(CategoryViewModel.self) var catVM
    @Environment(BudgetViewModel.self) var budgetVM
    @Environment(TransactionViewModel.self) var txVM
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorHex = "#5E6AD2"
    @State private var type: TransactionType = .expense
    @State private var budgetAmount = ""
    @State private var subcategories: [String] = []
    @State private var newSubcategory = ""
    @State private var emojiInput = ""
    @State private var showDeleteConfirm = false

    private let iconOptions = [
        "tag.fill", "cart.fill", "house.fill", "car.fill", "airplane",
        "gift.fill", "heart.fill", "book.fill", "gamecontroller.fill",
        "fork.knife", "cup.and.saucer.fill", "dumbbell.fill", "pawprint.fill",
        "music.note", "camera.fill", "tv.fill", "phone.fill", "laptopcomputer"
    ]

    private let colorOptions = [
        "#5E6AD2", "#E8543A", "#F5A623", "#E91E8C", "#9B59B6",
        "#1ABC9C", "#3498DB", "#2ECC71", "#E74C3C", "#95A5A6"
    ]

    private func subcategoryBinding(_ index: Int) -> Binding<String> {
        Binding(get: { subcategories[index] }, set: { subcategories[index] = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name & Type") {
                    TextField("Category Name", text: $name)
                    if forcedType == nil {
                        Picker("Type", selection: $type) {
                            Text("Expense").tag(TransactionType.expense)
                            Text("Income").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                    }
                    if type == .expense {
                        HStack {
                            Text("Monthly Budget")
                            Spacer()
                            HStack(spacing: 2) {
                                Text("$").foregroundStyle(.secondary)
                                TextField("0", text: $budgetAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 80)
                            }
                        }
                    }
                }
                .listRowBackground(Color.peraSurface)

                Section("Icon") {
                    // Current icon preview + emoji input
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: colorHex).opacity(0.15))
                                .frame(width: 44, height: 44)
                            CategoryIconView(icon: icon, size: 20, color: Color(hex: colorHex))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current").font(.caption).foregroundStyle(.secondary)
                            Text(icon.isEmojiIcon ? icon : icon)
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
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
                .listRowBackground(Color.peraSurface)

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
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.peraSurface)

                Section("Subcategories") {
                    ForEach(subcategories.indices, id: \.self) { i in
                        TextField("Subcategory", text: subcategoryBinding(i))
                    }
                    .onDelete { indices in
                        subcategories.remove(atOffsets: indices)
                    }
                    HStack {
                        TextField("Add subcategory…", text: $newSubcategory)
                            .onSubmit { addSubcategory() }
                        Button { addSubcategory() } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                                .opacity(newSubcategory.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(newSubcategory.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .listRowBackground(Color.peraSurface)

                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Category", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listRowBackground(Color.peraSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.peraBackground)
            .navigationTitle(editing == nil ? (forcedType == .income ? "New Income" : "New Category") : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(editing == nil ? "Add" : "Save") { save() }
                        .disabled(name.isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .alert("Delete \"\(name)\"?", isPresented: $showDeleteConfirm) {
                Button("Delete Category", role: .destructive) {
                    Task {
                        if let cat = editing { await catVM.delete(cat) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the category. Transactions will not be deleted.")
            }
        }
        .onAppear {
            if let forced = forcedType { type = forced }
            guard let cat = editing else { return }
            name = cat.name
            icon = cat.icon
            colorHex = cat.colorHex
            type = cat.type
            budgetAmount = cat.budgetAmount > 0 ? String(format: "%.2f", cat.budgetAmount) : ""
            subcategories = cat.subcategories
            if cat.icon.isEmojiIcon { emojiInput = cat.icon }
        }
    }

    private func addSubcategory() {
        let trimmed = newSubcategory.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !subcategories.contains(trimmed) else { return }
        subcategories.append(trimmed)
        newSubcategory = ""
    }

    private func save() {
        var cat = Category(
            userId: catVM.userId,
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            subcategories: subcategories.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            budgetAmount: Double(budgetAmount) ?? 0,
            sortOrder: editing?.sortOrder ?? catVM.categories.count
        )
        if let existing = editing { cat.id = existing.id }
        Task {
            await catVM.add(cat)
            if cat.type == .expense {
                await budgetVM.syncFromCategories([cat], month: txVM.selectedMonth)
            }
            dismiss()
        }
    }
}

// MARK: - Dashboard Envelope Order

struct DashboardEnvelopeOrderView: View {
    @Environment(CategoryViewModel.self) var catVM
    @AppStorage("dashboardEnvelopeOrder") private var orderIds = ""

    private var orderedCategories: [Category] {
        let ids = orderIds.split(separator: ",").map(String.init)
        let lookup = Dictionary(uniqueKeysWithValues: catVM.expenseCategories.map { ($0.id, $0) })
        var result = ids.compactMap { lookup[$0] }
        let seen = Set(result.map { $0.id })
        result += catVM.expenseCategories.filter { !seen.contains($0.id) }
        return result
    }

    var body: some View {
        List {
            ForEach(orderedCategories) { cat in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(cat.color.opacity(0.15))
                            .frame(width: 36, height: 36)
                        CategoryIconView(icon: cat.icon, size: 16, color: cat.color)
                    }
                    Text(cat.name)
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 2)
                .listRowBackground(Color.peraSurface)
            }
            .onMove { source, destination in
                var cats = orderedCategories
                cats.move(fromOffsets: source, toOffset: destination)
                orderIds = cats.map { $0.id }.joined(separator: ",")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Reorder Envelopes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

