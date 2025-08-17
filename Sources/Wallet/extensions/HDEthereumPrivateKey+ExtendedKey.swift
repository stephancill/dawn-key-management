import Foundation
import CryptoSwift

import class Model.HDEthereumPrivateKey
import class Model.EthereumPrivateKey
import class Model.EthereumPublicKey

extension HDEthereumPrivateKey {
    public func publicKey(compressed: Bool) throws -> EthereumPublicKey {
        try key
            .publicKey(compressed: compressed)
    }
}

extension HDEthereumPrivateKey {

    func derivePath() throws -> HDEthereumPrivateKey {
        // TODO: Injecting an actual BIP39 address path instead of hardcoding the ethereum one
        try self
            .deriveChild(44, hardened: true)
            .deriveChild(60, hardened: true)
            .deriveChild(0, hardened: true)
            .deriveChild(0)
    }

    func deriveChild(_ index: UInt32, hardened: Bool = false) throws -> HDEthereumPrivateKey {
        let pubKey = try publicKey(compressed: true)

        var data = Data()

        if hardened {
            data.append(UInt8(0))
            data.append(key.rawBytes, count: key.rawBytes.count)
        } else {
            data.append(pubKey.data, count: pubKey.data.count)
        }

        let childIndex = (hardened ? (0x8000_0000 | index) : index).bigEndian
        data.append(childIndex.data)

        let hmac = HMAC(key: chainCode, variant: .sha2(.sha512))
        let digest = try hmac.authenticate([UInt8](data))

        let parentKey = digest[0..<32]
        let chainCode = digest[32..<64]

        let childKey = try tweakChildKey(privateKey: key.rawBytes, derivedPrivateKey: parentKey)

        return HDEthereumPrivateKey(
            key: EthereumPrivateKey(rawBytes: childKey),
            chainCode: [UInt8](chainCode),
            depth: depth + 1,
            parentFingerprint: parentFingerprint,
            childNumber: childNumber
        )
    }

    func privateKey() -> EthereumPrivateKey {
        key
    }
}
