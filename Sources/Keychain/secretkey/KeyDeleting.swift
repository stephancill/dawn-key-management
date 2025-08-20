import Foundation

public protocol KeyDeletable {
    func delete(with reference: String, accessGroup: String) throws -> OSStatus
}

public final class KeyDeleting: KeyDeletable {

    private let security: SecurityWrapper
    private let keyStore: KeyStorage

    enum Error: Swift.Error {
        case deleteCiphertext(OSStatus)
    }

    public convenience init() {
        self.init(security: SecurityWrapperImp(), keyStore: KeyStorage())
    }

    private init(security: SecurityWrapper, keyStore: KeyStorage) {
        self.security = security
        self.keyStore = keyStore
    }

    public func delete(with reference: String, accessGroup: String) throws -> OSStatus {
        let params: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: reference.data(using: .utf8) as Any,
            kSecAttrAccessGroup as String: accessGroup,
        ]

        // 1. Delete the ciphertext stored at reference
        let status = keyStore.delete(key: reference)

        guard status == errSecSuccess else {
            throw Error.deleteCiphertext(status)
        }

        // 2. Delete the secret used to encrypt the private key
        return security.SecItemDelete(params as CFDictionary)
    }
}
