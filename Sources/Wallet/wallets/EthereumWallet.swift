import Foundation
import Model
import Keychain

public class EthereumWallet {

    internal let privateKey: EthereumPrivateKey
    private let keyEncrypt: KeyEncryptable
    private let keyStorage: KeyStoring

    enum Error: Swift.Error {
        case keychainStore(OSStatus)
    }

    public convenience init(privateKey: EthereumPrivateKey) {
        self.init(privateKey: privateKey, keyEncrypt: KeyEncrypting(), keyStorage: KeyStorage())
    }

    private init(privateKey: EthereumPrivateKey, keyEncrypt: KeyEncryptable, keyStorage: KeyStoring) {
        self.privateKey = privateKey
        self.keyEncrypt = keyEncrypt
        self.keyStorage = keyStorage
    }

    var publicKey: Model.EthereumPublicKey {
        get throws {
            try privateKey.publicKey(compressed: false)
        }
    }

    public var address: Model.EthereumAddress {
        get throws {
            let publicKey = try privateKey
                .publicKey(compressed: false)
            return try EthereumAddress(publicKey: publicKey)
        }
    }
}

extension EthereumWallet {
    @discardableResult
    public func encryptWallet(accessGroup: String) throws -> EthereumWallet {
        let privateKey = Data(privateKey.rawBytes)
        let address = try address.eip55Description

        // 1. Encrypt the private key using the address checksum as reference
        let ciphertext = try keyEncrypt.encrypt(privateKey, with: address, accessGroup: accessGroup)

        // 2. Store the ciphertext in the keychain
        let status = keyStorage.set(data: ciphertext as Data, key: address)

        guard status == errSecSuccess else {
            throw Error.keychainStore(status)
        }

        return self
    }
}
