import Foundation
import CryptoKit
import Security

enum KeychainHelper {
    private static let service = "com.pera.receipt-key"

    /// Returns the AES-256 receipt encryption key for the given user, generating
    /// and storing one in iCloud Keychain if it doesn't exist yet.
    static func receiptEncryptionKey(for userId: String) throws -> SymmetricKey {
        if let existing = try fetchKey(account: userId) { return existing }
        return try createKey(account: userId)
    }

    private static func fetchKey(account: String) throws -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, data.count == 32 else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    private static func createKey(account: String) throws -> SymmetricKey {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: kCFBooleanTrue!,
            kSecValueData: keyData
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status),
                userInfo: [NSLocalizedDescriptionKey: "Could not save encryption key."])
        }
        return key
    }
}
