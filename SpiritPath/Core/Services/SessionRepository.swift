//
//  SessionRepository.swift
//  SpiritPath
//
//  Phase 2.1+ · session reads · Supabase direct · no local cache (Phase 1.7e+).
//  Phase 1.5-followup (audit-gap #11) · session writes · INSERT at start · UPDATE at end.
//
//  Methods:
//    - insertSession(...)                     · Phase 1.5-followup · INSERT row at session_started fire-site
//    - endSession(...)                        · Phase 1.5-followup · UPDATE row at session_ended fire-site
//    - totalMindfulSteps(userId:)             · Phase 2.1 · JourneyView Steps in Stillness halo
//    - countCompletedSessionsSince(userId:since:) · Phase 2.3 · M16 had_session_today property
//
//  RLS Pattern A: sessions WHERE user_id = auth.uid() enforced server-side · explicit eq is
//  defense-in-depth (unauthenticated calls return nil userId · we never query without one).
//
//  M8 invariant: sessions.id == Mixpanel session_uuid (passed by caller from SessionContext).
//

import Foundation
import Supabase
import PostgREST

@MainActor
final class SessionRepository {
    static let shared = SessionRepository()
    private init() {}

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // MARK: · Phase 1.5-followup · writes (audit-gap #11)

    /// INSERT new session row at session_started fire-site · idempotent via
    /// `Prefer: resolution=ignore-duplicates` (== `ON CONFLICT (id) DO NOTHING`).
    /// Best-effort · caller is fire-and-forget · network failure = lost row (acceptable
    /// until Phase 1.7e+ sync queue lands · Mixpanel still fires regardless · M8 holds).
    ///
    /// Schema reference (0002_practice.sql · canonical):
    ///   - column `type`               (not `session_type` per brief example · brief deviates)
    ///   - column `stage_index_at_time`(not `stage_index`  per brief example · brief deviates)
    ///   - no `device_info` / `client_app_version` / `ended_reason` columns exist on this table
    ///   - `prefs_snapshot` jsonb (not null default '{}'::jsonb)
    func insertSession(
        id: String,
        sessionType: String,
        lineageId: String,
        stageIndex: Int,
        targetSec: Int,
        place: String,
        paceMode: String,
        ground: String,
        startedAt: Date
    ) async {
        guard let userId = supabase.auth.currentUser?.id else { return }

        let startedString = Self.isoFormatter.string(from: startedAt)

        struct PrefsSnapshot: Encodable {
            let place: String
            let pace: String
            let ground: String
            let duration_target: Int
        }
        let prefs = PrefsSnapshot(
            place: place,
            pace: paceMode,
            ground: ground,
            duration_target: targetSec
        )

        struct SessionInsert: Encodable {
            let id: String
            let user_id: String
            let type: String
            let started_at: String
            let client_created_at: String
            let duration_target_sec: Int
            let lineage_id: String
            let stage_index_at_time: Int
            let prefs_snapshot: PrefsSnapshot
        }

        let row = SessionInsert(
            id: id,
            user_id: userId.uuidString,
            type: sessionType,
            started_at: startedString,
            client_created_at: startedString,
            duration_target_sec: targetSec,
            lineage_id: lineageId,
            stage_index_at_time: stageIndex,
            prefs_snapshot: prefs
        )

        do {
            try await supabase
                .from("sessions")
                .upsert(row, onConflict: "id", ignoreDuplicates: true)
                .execute()
        } catch {
            // Best-effort · network blip = lost INSERT (sync queue lands Phase 1.7e+).
        }
    }

    /// UPDATE session row at session_ended fire-site · 5 mutable fields per brief §1B
    /// (mapped to actual schema · `ended_reason` column does not exist · `ended_at` substitutes).
    /// Naturally idempotent (UPDATE-by-id with same values is a no-op on retry).
    /// Caller should `await` this BEFORE invoking JourneyProgressService.checkAndAdvanceStage()
    /// so countCompletedSessionsSince() sees this row · M25 stage_advanced fires on threshold.
    func endSession(
        id: String,
        durationActualSec: Int,
        completed: Bool,
        mindfulSteps: Int,
        totalSteps: Int,
        endedAt: Date
    ) async {
        let endedString = Self.isoFormatter.string(from: endedAt)

        struct SessionUpdate: Encodable {
            let ended_at: String
            let duration_actual_sec: Int
            let completed: Bool
            let mindful_steps: Int
            let total_steps: Int
        }

        let payload = SessionUpdate(
            ended_at: endedString,
            duration_actual_sec: durationActualSec,
            completed: completed,
            mindful_steps: mindfulSteps,
            total_steps: totalSteps
        )

        do {
            try await supabase
                .from("sessions")
                .update(payload)
                .eq("id", value: id)
                .execute()
        } catch {
            // Best-effort · UPDATE retry on next session is a no-op (different id).
        }
    }

    // MARK: · reads

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

    // MARK: · Phase 2.7b · reflections lifecycle (M26 fire-site companion)

    /// List user reflections · ordered desc by created_at · joined sessions row carries
    /// lineage_id + stage_index_at_time for filtering/display (audit-gap #12 verified ·
    /// those columns DO NOT exist on reflections · only sessions).
    ///
    /// Schema notes (0002_practice.sql:66 · audit-gap #12 verified):
    ///   - column `note_text` (NOT `note` per brief example · brief deviates · adapted)
    ///   - no `note_length_chars` column · computed client-side on ReflectionRow.noteLengthChars
    ///   - lineage_id + stage_index_at_time live on joined public.sessions · embed via select
    ///
    /// Filtering strategy:
    ///   - anchor_phrase: server-side ilike (case-insensitive substring match)
    ///   - lineage/stage: client-side post-fetch (PostgREST embed-filter via .filter("sessions.x",...)
    ///     would work but loses .eq() builder type safety · client-side filter acceptable at 50-row cap)
    ///
    /// Throws on network/auth/decode failure · caller (ReflectionHistoryViewModel) renders
    /// error state with "Couldn't load history. Pull to retry." copy.
    /// Deviates from countCompletedSessionsSince defensive-default pattern because this read
    /// is foreground/user-driven · error visibility matters (vs background read which silently 0s).
    func listReflections(
        userId: String,
        lineageId: String? = nil,
        stageIndex: Int? = nil,
        searchAnchor: String? = nil,
        limit: Int = 50
    ) async throws -> [ReflectionRow] {
        var query = supabase
            .from("reflections")
            .select("id, user_id, session_id, note_text, anchor_phrase, created_at, updated_at, sessions(lineage_id, stage_index_at_time)")
            .eq("user_id", value: userId)
            .is("deleted_at", value: nil)

        if let trimmed = searchAnchor?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            query = query.ilike("anchor_phrase", pattern: "%\(trimmed)%")
        }

        let rows: [ReflectionRow] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.filter { row in
            if let lineageId, row.lineageId != lineageId { return false }
            if let stageIndex, row.stageIndex != stageIndex { return false }
            return true
        }
    }

    /// UPDATE reflection note_text + anchor_phrase · idempotent UPDATE-by-id.
    /// Throws on failure so caller (ReflectionEditViewModel.save) can gate M26 fire on success.
    /// updated_at refreshed via Self.isoFormatter (microsecond precision matches other writes).
    ///
    /// Privacy: payload travels over TLS to Supabase · M11 lock unchanged (text never goes to Mixpanel).
    func updateReflection(
        id: String,
        noteText: String,
        anchorPhrase: String?
    ) async throws {
        struct ReflectionUpdate: Encodable {
            let note_text: String
            let anchor_phrase: String?
            let updated_at: String
        }

        let trimmedAnchor = anchorPhrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = ReflectionUpdate(
            note_text: noteText,
            anchor_phrase: (trimmedAnchor?.isEmpty ?? true) ? nil : trimmedAnchor,
            updated_at: Self.isoFormatter.string(from: Date())
        )

        try await supabase
            .from("reflections")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }
}
