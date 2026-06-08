import SwiftUI
import PhotosUI

struct AddTransactionView: View {
    var editing: Transaction? = nil

    @Environment(TransactionViewModel.self) var txVM
    @Environment(CategoryViewModel.self) var catVM
    @Environment(\.dismiss) private var dismiss

    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var selectedCategoryId = ""
    @State private var merchantName = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var subcategory = ""
    @State private var isRecurring = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    @State private var hasRecurringEndDate = false
    @State private var recurringEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var showSaveError = false

    // Receipt
    @State private var receiptImage: UIImage? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCamera = false
    @State private var showPhotosPicker = false
    @State private var removeExistingReceipt = false

    @FocusState private var amountFocused: Bool

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
                                .focused($amountFocused)
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
                    Toggle("Recurring", isOn: $isRecurring.animation())
                }
                .listRowBackground(Color(.secondarySystemBackground))

                if isRecurring {
                    Section("Recurring Schedule") {
                        Picker("Frequency", selection: $recurringFrequency) {
                            ForEach(RecurringFrequency.allCases) { freq in
                                Text(freq.label).tag(freq)
                            }
                        }
                        Toggle("Set End Date", isOn: $hasRecurringEndDate.animation())
                        if hasRecurringEndDate {
                            DatePicker("End Date", selection: $recurringEndDate,
                                       in: date..., displayedComponents: .date)
                        }
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                }

                if editing != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Transaction", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                }

                receiptSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(editing == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(editing == nil ? "Save" : "Update") { save() }
                            .disabled(!canSave)
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .alert("Delete this transaction?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task {
                        if let tx = editing { await txVM.delete(tx) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This transaction will be permanently removed.")
            }
            .alert("Attachment Failed", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(txVM.errorMessage ?? "Could not save the attachment. Please try again.")
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $receiptImage)
                    .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItem) { _, item in
                Task {
                    guard let item else { return }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        receiptImage = image
                    }
                }
            }
        }
        .onAppear {
            if let tx = editing {
                amount = String(format: "%.2f", tx.amount)
                type = tx.type
                merchantName = tx.merchantName ?? ""
                note = tx.note ?? ""
                date = tx.date
                subcategory = tx.subcategory ?? ""
                isRecurring = tx.isRecurring
                recurringFrequency = tx.recurringFrequency
                if let end = tx.recurringEndDate {
                    hasRecurringEndDate = true
                    recurringEndDate = end
                }
                // Set categoryId after type is applied so onChange doesn't clear it
                Task { @MainActor in selectedCategoryId = tx.categoryId }
            } else {
                if let first = categories.first { selectedCategoryId = first.id }
            }
        }
    }

    private var hasAttachment: Bool {
        receiptImage != nil
            || (!(editing?.receiptImageURL ?? "").isEmpty && !removeExistingReceipt)
    }

    private func removeAttachment() {
        receiptImage = nil
        selectedPhotoItem = nil
        removeExistingReceipt = true
    }

    @ViewBuilder private var receiptSection: some View {
        Section("Receipt") {
            // Preview new image selected this session
            if let image = receiptImage {
                Image(uiImage: image)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.vertical, 4)
            } else if let urlString = editing?.receiptImageURL,
                      !urlString.isEmpty, !removeExistingReceipt,
                      let url = URL(string: urlString) {
                EncryptedReceiptView(url: url, userId: txVM.userId)
                    .frame(maxHeight: 200)
                    .padding(.vertical, 4)
            }

            if hasAttachment {
                Button(role: .destructive) { removeAttachment() } label: {
                    Label("Remove Receipt", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Menu {
                    Button { showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                    Button { showPhotosPicker = true } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Add Receipt", systemImage: "paperclip")
                }
            }
        }
        .listRowBackground(Color(.secondarySystemBackground))
    }

    private func save() {
        isSaving = true
        let receiptData = receiptImage?.jpegData(compressionQuality: 0.75)

        Task {
            let ok: Bool
            if var tx = editing {
                tx.amount = amountDouble
                tx.type = type
                tx.categoryId = selectedCategoryId
                tx.subcategory = subcategory.isEmpty ? nil : subcategory
                tx.note = note.isEmpty ? nil : note
                tx.date = date
                tx.merchantName = merchantName.isEmpty ? nil : merchantName
                tx.isRecurring = isRecurring
                tx.recurringFrequency = recurringFrequency
                tx.recurringEndDate = isRecurring && hasRecurringEndDate ? recurringEndDate : nil
                if removeExistingReceipt { tx.receiptImageURL = nil }
                ok = await txVM.update(tx, receiptImageData: receiptData)
            } else {
                let tx = Transaction(
                    userId: txVM.userId,
                    amount: amountDouble,
                    type: type,
                    categoryId: selectedCategoryId,
                    subcategory: subcategory.isEmpty ? nil : subcategory,
                    note: note.isEmpty ? nil : note,
                    date: date,
                    merchantName: merchantName.isEmpty ? nil : merchantName,
                    isRecurring: isRecurring,
                    recurringFrequency: recurringFrequency,
                    recurringEndDate: isRecurring && hasRecurringEndDate ? recurringEndDate : nil
                )
                ok = await txVM.add(tx, receiptImageData: receiptData)
            }
            isSaving = false
            if ok { dismiss() } else { showSaveError = true }
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
                    CategoryIconView(icon: category.icon, size: 18,
                                     color: isSelected ? .white : category.color)
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

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
