import Foundation

public protocol KeyEncryptable {
    func encrypt(_ privateKey: Data, with reference: String, accessGroup: String) throws -> CFData
}

public final class KeyEncrypting: KeyEncryptable {

    private let security: SecurityWrapper

    public convenience init() {
        self.init(security: SecurityWrapperImp())
    }

    private init(security: SecurityWrapper) {
        self.security = security
    }

    enum Error: Swift.Error {
        case referenceNotFound
        case unexpectedStatus(OSStatus)
        case invalidFormat
        case publicKey
        case failedEncryption
        case resolvingPublicKey
        case duplicatedKey
    }

    /// Encrypt the private key using a secret generated in the secure enclave
    /// - Parameters:
    ///   - privateKey: Private key
    ///   - reference: Reference used to place the generated secret
    ///   - accessGroup: Access group used for keychain segregation
    /// - Returns: Ciphertext
    public func encrypt(_ privateKey: Data, with reference: String, accessGroup: String) throws -> CFData {
        let secretReference: SecKey
        do {
            // 1. Check if there is a secret stored in the secure enclave using the address as tag (tag is not involved in the encryption process, it's used only to fetch the secret reference)
            // Value returned is the reference used to interact with the secure enclave. The secret itself never gets exposed.
            secretReference = try retrieveSecret(with: reference, accessGroup: accessGroup)
        } catch {
            // 2. If not, a secret using the address as tag is generated
            secretReference = try generateSecret(with: reference, accessGroup: accessGroup)
        }

        // 3. Resolve the public key using the reference retrieved / generated before
        guard let publicKey = security.SecKeyCopyPublicKey(secretReference) else {
            throw Error.resolvingPublicKey
        }

        // 4. Encrypt the private key data using the secret reference applying the eciesEncryptionCofactorVariableIVX963SHA256AESGCM algorithm
        var encryptionError: Unmanaged<CFError>?
        guard let ciphertext = security.SecKeyCreateEncryptedData(publicKey, Constants.algorithm, privateKey as CFData, &encryptionError) else {
            throw Error.failedEncryption
        }

        return ciphertext
    }

    /// Fetch the reference of the secret, throw an error in case it does not exist
    private func retrieveSecret(with reference: String, accessGroup: String) throws -> SecKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: reference.data(using: .utf8) as Any,
            kSecReturnRef as String: true,
        ]
        query[kSecAttrAccessGroup as String] = accessGroup

        // 1. SecItemCopyMatching will attempt to copy the secret reference identified by the query to the reference secretRef
        var secretRef: CFTypeRef?
        let status = security.SecItemCopyMatching(
            query as CFDictionary,
            &secretRef
        )

        // 2. In case the expected secret does not exist, we throw a referenceNotFound error
        guard status != errSecItemNotFound else {
            throw Error.referenceNotFound
        }

        // 3. Other than success, we throw an error with the status
        guard status == errSecSuccess else {
            throw Error.unexpectedStatus(status)
        }

        return secretRef as! SecKey
    }

    /// Generate a secret in the secure enclave, return the reference
    private func generateSecret(with reference: String, accessGroup: String) throws -> SecKey {
        guard getSecretCount(with: reference, accessGroup: accessGroup) == 0 else { throw Error.duplicatedKey }

        var error: Unmanaged<CFError>?
        let query = secretQuery(with: reference, accessGroup: accessGroup)
        guard let secKey = security.SecKeyCreateRandomKey(query as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Swift.Error
        }
        return secKey
    }

    /// Query used to generate the secret
    private func secretQuery(with reference: String, accessGroup: String) -> [String: Any] {
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .userPresence],
            nil
        )
        var result: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: reference.data(using: .utf8) as Any,
                kSecAttrAccessControl as String: access as Any,
            ],
        ]
        result[kSecAttrAccessGroup as String] = accessGroup

        if Platform.isRealDevice {
            result[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }

        return result
    }

    /// Fetch number of secrets using address as reference
    private func getSecretCount(with reference: String, accessGroup: String) -> Int {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrApplicationTag as String: reference.data(using: .utf8) as Any,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        query[kSecAttrAccessGroup as String] = accessGroup

        // 1. SecItemCopyMatching will query how many secrets are currently stored in the secure enclave
        var secretRef: CFTypeRef?
        let status = security.SecItemCopyMatching(
            query as CFDictionary,
            &secretRef
        )

        // 2. Return how many secrets were retrieved from the secure enclave
        if status == noErr, let secrets = secretRef as? [SecKey] {
            return secrets.count
        }

        // 3. Return 0 otherwise
        return 0
    }
}
