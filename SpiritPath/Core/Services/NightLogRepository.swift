//
//  NightLogRepository.swift
//  SpiritPath
//
//  Phase 2.4b · Night Log persistence · client-side AES-256-GCM (NightLogCrypto) →
//  Supabase night_log_entries (V7). Plaintext shape matches Android verbatim ·
//  cross-platform parity for the encrypted body bytes.
//
//  Sync queue intentionally NOT used here · iOS writes Supabase direct for now
//  (per Phase 2.4b brief · sync queue lands later). M17 reflection_submitted-equivalent
//  Mixpanel firing is out of scope for this delivery.
//

import Foundation
import Supabase

// MARK: · Plaintext shape · matches Android Json serialization

/// JSON shape encrypted into `body_ciphertext`. Field order locked cross-platform.
/// `let_go` snake_case matches Android `Json` default · do NOT change without
/// a paired migration on both platforms.
struct NightLogPlaintext: Codable, Equatable {
    let one: String         // ONE WORD FOR TODAY · max 20 chars (enforced at the view)
    let letGo: String       // SOMETHING TO SET DOWN
    let tomorrow: String    // A SMALL INTENTION FOR TOMORROW

    enum CodingKeys: String, CodingKey {
        case one
        case letGo = "let_go"
        case tomorrow
    }
}

/// Decrypted row · returned by listDecrypted() for any future history surface.
struct NightLogDisplayItem: Identifiable, Equatable {
    let id: String
    let loggedAt: Date
    let plaintext: NightLogPlaintext
    let mood: String?
}

// MARK: · Repository

@MainActor
final class NightLogRepository {
    static let shared = NightLogRepository()
    private init() {}

    enum RepositoryError: Error {
        case notAuthenticated
        case decryptFailed
    }

    /// Encrypt + insert. Server stores opaque ciphertext only.
    func save(_ plaintext: NightLogPlaintext, mood: String? = nil) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }

        let json = try JSONEncoder().encode(plaintext)
        guard let jsonString = String(data: json, encoding: .utf8) else {
            throw RepositoryError.decryptFailed
        }
        let ciphertext = try NightLogCrypto.shared.encrypt(jsonString)

        struct InsertRow: Encodable {
            let id: String
            let user_id: String
            let logged_at: String
            let body_ciphertext: Data
            let mood: String?
        }

        let row = InsertRow(
            id: UUID().uuidString,
            user_id: userId.uuidString,
            logged_at: ISO8601DateFormatter().string(from: Date()),
            body_ciphertext: ciphertext,
            mood: mood
        )

        try await supabase
            .from("night_log_entries")
            .insert(row)
            .execute()
    }

    /// Recent-first list · decrypted in-process · soft-deleted entries excluded.
    /// Used by future history view · also a build-verification round-trip target.
    func listDecrypted() async throws -> [NightLogDisplayItem] {
        guard let userId = supabase.auth.currentUser?.id else { return [] }

        struct Row: Decodable {
            let id: String
            let logged_at: Date
            let body_ciphertext: Data
            let mood: String?
        }

        let rows: [Row] = try await supabase
            .from("night_log_entries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .is("deleted_at", value: nil)
            .order("logged_at", ascending: false)
            .execute()
            .value

        return rows.compactMap { row in
            guard
                let decrypted = try? NightLogCrypto.shared.decrypt(row.body_ciphertext),
                let pt = try? JSONDecoder().decode(NightLogPlaintext.self, from: Data(decrypted.utf8))
            else { return nil }
            return NightLogDisplayItem(
                id: row.id,
                loggedAt: row.logged_at,
                plaintext: pt,
                mood: row.mood
            )
        }
    }
}
