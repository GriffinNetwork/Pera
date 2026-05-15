import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill((category?.color ?? .gray).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: category?.icon ?? "questionmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(category?.color ?? .gray)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName ?? category?.name ?? "Transaction")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(transaction.date.shortDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(transaction.type == .income ? .green : .primary)

                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
