import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                // Category icon
                ZStack {
                    Circle()
                        .fill((category?.color ?? .gray).opacity(0.15))
                        .frame(width: 40, height: 40)
                    CategoryIconView(icon: category?.icon ?? "questionmark", size: 16,
                                     color: category?.color ?? .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.merchantName ?? category?.name ?? "Transaction")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(transaction.date.shortDisplay)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let url = transaction.receiptImageURL, !url.isEmpty {
                            Image(systemName: "paperclip")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(amountText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(transaction.type == .income ? Color.peraIncome : Color.primary)

                    if let note = transaction.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if category != nil || (transaction.subcategory != nil && !transaction.subcategory!.isEmpty) {
                HStack(spacing: 6) {
                    if let cat = category {
                        TagChip(text: cat.name, color: cat.color)
                    }
                    if let sub = transaction.subcategory, !sub.isEmpty {
                        TagChip(text: sub, color: category?.color ?? .gray)
                    }
                }
                .padding(.leading, 52)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var amountText: String {
        let prefix = transaction.type == .income ? "+" : "-"
        return "\(prefix)\(transaction.amount.currencyString)"
    }
}

private struct TagChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
