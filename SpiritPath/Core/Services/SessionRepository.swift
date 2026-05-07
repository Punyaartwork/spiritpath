//
//  SessionRepository.swift
//  SpiritPath
//
//  Phase 2.1+ · read-only session aggregates · Supabase direct · no local cache (Phase 1.7e+).
//
//  Methods:
//    - totalMindfulSteps(userId:)             · Phase 2.1 · JourneyView Steps in Stillness halo
//    - countCompletedSessionsSince(userId:since:) · Phase 2.3 · M16 had_session_today property
//
//  RLS Pattern A: sessions WHERE user_id = auth.uid() enforced server-side · explicit eq is
//  defense-in-depth (unauthenticated calls return nil userId · we never query without one).
//

import Foundation
import Supabase
import PostgREST

@MainActor
final class SessionRepository {
    static let shared = SessionRepository()
    private init() {}

    /// SUM(mindful_steps) for completed, non-deleted sessions of `userId`.
    /// Returns 0 on any error (network · no auth · empty result).
    func totalMindfulSteps(userId: String) async -> Int {
        struct StepRow: Decodable { let mindful_steps: Int }
        do {
            let rows: [StepRow] = try await supabase
                .from("sessions")
                .select("mindful_steps")
                .eq("user_id", value: userId)
                .eq("completed", value: true)
                .is("deleted_at", value: nil)
                .execute()
                .value
            return rows.reduce(0) { $0 + $1.mindful_steps }
        } catch {
            return 0
        }
    }

    /// COUNT(*) of completed, non-deleted sessions for `userId` since `since` (inclusive).
    /// Returns 0 on any error · matches M16 had_session_today defensive default.
    func countCompletedSessionsSince(userId: String, since: Date) async -> Int {
        struct CountRow: Decodable { let id: String }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = isoFormatter.string(from: since)
        do {
            let rows: [CountRow] = try await supabase
                .from("sessions")
                .select("id")
                .eq("user_id", value: userId)
                .eq("completed", value: true)
                .is("deleted_at", value: nil)
                .gte("created_at", value: sinceString)
                .execute()
                .value
            return rows.count
        } catch {
            return 0
        }
    }
}
