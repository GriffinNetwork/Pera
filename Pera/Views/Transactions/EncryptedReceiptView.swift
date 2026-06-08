import SwiftUI
import CryptoKit

struct EncryptedReceiptView: View {
    let url: URL
    let userId: String

    @State private var image: UIImage?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 6) {
                    Label("Receipt unavailable", systemImage: "photo.slash")
                        .foregroundStyle(.secondary)
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let key = try KeychainHelper.receiptEncryptionKey(for: userId)
            let box = try AES.GCM.SealedBox(combined: data)
            let decrypted = try AES.GCM.open(box, using: key)
            image = UIImage(data: decrypted)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
