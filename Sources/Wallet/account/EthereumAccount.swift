import Foundation
import Model
import Keychain

public final class EthereumAccount {

    enum Error: Swift.Error {
        case notImported
        case wrongAddress
        case memoryBound
        case createContext
        case parseECDSA
        case invalidKey
    }

    private let address: EthereumAddress
    private let keyDecrypt: KeyDecryptable
    private let keyStorage: KeyStoring

    public convenience init(address: EthereumAddress) {
        self.init(address: address, keyDecrypt: KeyDecrypting(), keyStorage: KeyStorage())
    }

    private init(address: EthereumAddress, keyDecrypt: KeyDecryptable, keyStorage: KeyStoring) {
        self.address = address
        self.keyDecrypt = keyDecrypt
        self.keyStorage = keyStorage
    }
}

extension EthereumAccount {
    public func accessPrivateKey<T>(accessGroup: String, _ content: (ByteArray) -> T) throws -> T {
        // 1. Get the ciphertext stored in the keychain
        guard let ciphertext = try keyStorage.get(key: address.eip55Description) else {
            throw Error.notImported
        }

        // 2. Decrypt ciphertext, return the key
        return try keyDecrypt.decrypt(address.eip55Description, cipherText: ciphertext, accessGroup: accessGroup, handler: { key in
            content(key)
        })
    }

    public func signDigest(_ digest: ByteArray, accessGroup: String) throws -> Signature {
        // 1. Get the ciphertext stored in the keychain
        guard let ciphertext = try keyStorage.get(key: address.eip55Description) else {
            throw Error.notImported
        }

        // 2. Decrypt ciphertext, return the signature
        return try keyDecrypt.decrypt(address.eip55Description, cipherText: ciphertext, accessGroup: accessGroup, handler: { key in
            try sign(digest, privateKey: key)
        })
    }

    /// Sign multiple digests within just one access to the keychain
    public func signMultiple(_ digests: [ByteArray], accessGroup: String) throws -> [Signature] {
        // 1. Get the ciphertext stored in the keychain
        guard let ciphertext = try keyStorage.get(key: address.eip55Description) else {
            throw Error.notImported
        }

        // 2. Decrypt ciphertext, return the array of signatures
        return try keyDecrypt.decrypt(address.eip55Description, cipherText: ciphertext, accessGroup: accessGroup, handler: { key in
            return try digests.map { try sign($0, privateKey: key) }
        })
    }
}
