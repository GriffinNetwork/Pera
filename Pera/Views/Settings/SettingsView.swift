import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var catVM: CategoryViewModel
    @State private var showDeleteConfirm = false
    @State private var showAddCategory = false

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
                                .foregroundStyle(.accentColor)
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
                .listRowBackground(Color(.secondarySystemBackground))

                // Categories
                Section("Categories") {
                    ForEach(catVM.categories) { cat in
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(cat.color.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: cat.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(cat.color)
                            }
                            Text(cat.name)
                            Spacer()
                            Text(cat.type == .expense ? "Expense" : "Income")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indices in
                        let toDelete = indices.map { catVM.categories[$0] }
                        Task {
                            for cat in toDelete { await catVM.delete(cat) }
                        }
                    }

                    Button {
                        showAddCategory = true
                    } label: {
                        Label("Add Category", systemImage: "plus")
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))

                // Account
                Section("Account") {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(Color(.secondarySystemBackground))

                // About
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)
                }
                .listRowBackground(Color(.secondarySystemBackground))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
            .confirmationDialog("Sign out of Pera?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
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
    @EnvironmentObject var catVM: CategoryViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorHex = "#5E6AD2"
    @State private var type: TransactionType = .expense
    @State private var budgetAmount = ""

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Name & Type") {
                    TextField("Category Name", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
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
                .listRowBackground(Color(.secondarySystemBackground))

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { sym in
                            Button {
                                icon = sym
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(icon == sym ? Color(hex: colorHex) : Color(.tertiarySystemBackground))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: sym)
                                        .foregroundStyle(icon == sym ? .white : .primary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.secondarySystemBackground))

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
                .listRowBackground(Color(.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(name.isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let cat = Category(
            userId: catVM.userId,
            name: name,
            icon: icon,
            colorHex: colorHex,
            type: type,
            budgetAmount: Double(budgetAmount) ?? 0,
            sortOrder: catVM.categories.count
        )
        Task { await catVM.add(cat); dismiss() }
    }
}
