//
//  NightLogCrypto.swift
//  SpiritPath
//
//  C1 spec encryption · matches V7 migration header (0007_night_log.sql) ·
//  cross-platform parity with Android NightLogCrypto.kt.
//
//  Algorithm: AES-256-GCM (CryptoKit AES.GCM)
//  Nonce:     12 bytes random · prepended to ciphertext (sealed.combined)
//  Tag:       16 bytes appended · standard GCM
//  Key alias: spiritpath.nightlog.v1 · Keychain
//             kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly · NOT synchronizable
//  Payload:   nonce(12) ‖ ciphertext ‖ tag(16) → bytea (server opaque)
//
//  Device-bound by design · same plaintext won't decrypt cross-device · uninstall =
//  permanent loss of older entries (documented verbatim in Settings copy).
//

import CryptoKit
import Foundation
import Security

final class NightLogCrypto {
    static let shared = NightLogCrypto()
    private init() {}

    private let keyAlias = "spiritpath.nightlog.v1"

    enum CryptoError: Error {
        case keyGenerationFailed(OSStatus)
        case keyLoadFailed(OSStatus)
        case payloadTooShort
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        // Try load first.
        let loadQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAlias,
            kSecAttrSynchronizable as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        if status != errSecItemNotFound {
            throw CryptoError.keyLoadFailed(status)
        }

        // Generate new · store in Keychain · device-bound.
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAlias,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: false,
            kSecValueData as String: keyData,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CryptoError.keyGenerationFailed(addStatus)
        }
        return key
    }

    /// Returns nonce(12) ‖ ciphertext ‖ tag(16) — matches Android payload bytes.
    func encrypt(_ plaintext: String) throws -> Data {
        let key = try loadOrCreateKey()
        let nonce = AES.GCM.Nonce()  // 12 random bytes
        let sealed = try AES.GCM.seal(
            Data(plaintext.utf8),
            using: key,
            nonce: nonce
        )
        // sealed.combined = nonce(12) + ciphertext + tag(16) — exact payload format.
        guard let combined = sealed.combined else {
            throw CryptoError.payloadTooShort
        }
        return combined
    }

    func decrypt(_ payload: Data) throws -> String {
        guard payload.count > 12 else { throw CryptoError.payloadTooShort }
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.SealedBox(combined: payload)
        let plaintext = try AES.GCM.open(sealed, using: key)
        guard let s = String(data: plaintext, encoding: .utf8) else {
            throw CryptoError.payloadTooShort
        }
        return s
    }

    /// True if a Keychain entry already exists (no creation).
    func hasKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyAlias,
            kSecAttrSynchronizable as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}
