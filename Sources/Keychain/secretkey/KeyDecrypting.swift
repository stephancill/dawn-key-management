import Foundation
import Model
import class Model.EthereumPrivateKey

public protocol KeyDecryptable {
    func decrypt<R>(_ id: String, cipherText: Data, accessGroup: String, handler: ((ByteArray) throws -> R)) throws -> R
}

public final class KeyDecrypting: KeyDecryptable {

    enum Error: Swift.Error {
        case copyingSecret
    }

    private let security: SecurityWrapper

    public convenience init() {
        self.init(security: SecurityWrapperImp())
    }

    private init(security: SecurityWrapper) {
        self.security = security
    }

    public func decrypt<R>(_ id: String, cipherText: Data, accessGroup: String, handler: ((ByteArray) throws -> R)) throws -> R {
        // 1. Get the reference of the secret stored in the secure enclave
        let secret = try secretReference(with: id, cipherText: cipherText, accessGroup: accessGroup)

        // 2. Decrypt privateKey using the secret reference, and ciphertext
        var error: Unmanaged<CFError>?
        let plainTextData = security.SecKeyCreateDecryptedData(secret as! SecKey, Constants.algorithm, cipherText as CFData, &error) as? Data

        // 3. Get the value of the unmanaged error reference
        guard let plainTextData = plainTextData else {
            throw error!.takeRetainedValue() as Swift.Error
        }

        // 4. Return the Private Key using the array of bytes
        return try ByteArray(plainTextData).withDecryptedBytes { key in
            try handler(key)
        }
    }

    private func secretReference(with reference: String, cipherText: Data, accessGroup: String) throws -> CFTypeRef? {
        let params: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrApplicationTag as String: reference.data(using: .utf8) as Any,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnRef as String: true,
        ]
        var raw: CFTypeRef?
        let status = security.SecItemCopyMatching(params as CFDictionary, &raw)
        guard status == errSecSuccess else { throw Error.copyingSecret }
        return raw
    }
}
