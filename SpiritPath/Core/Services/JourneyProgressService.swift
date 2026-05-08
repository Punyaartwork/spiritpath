//
//  JourneyProgressService.swift
//  SpiritPath
//
//  Phase 2.7a · cohort-driven stage advancement · Supabase-direct (Phase 1.7e+ adds local cache).
//
//  Responsibilities
//    1. Read journey_progress (server-of-truth · sync_journey_progress trigger seeds it on
//       first completed session · stages_entered_at["1"] = ended_at of first walking session).
//    2. Compute sessions-in-stage (walking · completed · started_at >= entered_at)
//       and days-in-stage (Calendar.current).
//    3. Apply StageAdvancementRule.canAdvance(...) · single-step gate.
//    4. UPDATE journey_progress · current_stage += 1 · stages_entered_at[next] = now (APPEND-ONLY).
//       RLS server-side gate (can_advance_stage · 0012) revalidates with server now() · this is
//       defense-in-depth against tampered clients.
//    5. Fire Mixpanel `stage_advanced` (M25) once per advancement.
//
//  Idempotency
//    - Early-return if currentStage >= 5 (terminal · no event)
//    - Early-return if stages_entered_at[currentStage] is missing (no row · no entry yet)
//    - Early-return if thresholds not met
//    - stages_entered_at[next] is never overwritten (V2 invariant: append-only)
//
//  Cross-platform
//    - Android (Phase 2.7a) JourneyProgressService.kt mirrors this contract
//    - SQL function can_advance_stage validates server-side with same thresholds
//
//  Brief reference: codereview/briefs/codereview-phase2.7a-ios-prompt.md
//

import Foundation
import Supabase
import PostgREST

enum JourneyProgressServiceError: Error {
    case notAuthenticated
}

@MainActor
final class JourneyProgressService {
    static let shared = JourneyProgressService()
    private init() {}

    // MARK: · Models

    private struct ProgressRow: Decodable {
        let user_id: String
        let current_stage: Int
        let stages_entered_at: [String: String?]   // jsonb {"1": "2026-04-22T10:00:00Z", ...}
    }

    private struct AdvancePayload: Encodable {
        let current_stage: Int
        let stages_entered_at: [String: String]
    }

    private struct CountRow: Decodable { let id: String }

    // MARK: · Public API

    /// Called on session-end for walking + completed sessions · idempotent · no-op if already advanced.
    /// Returns the new stage if advanced, nil otherwise.
    @discardableResult
    func checkAndAdvanceStage() async throws -> Int? {
        guard let userId = supabase.auth.currentUser?.id else {
            throw JourneyProgressServiceError.notAuthenticated
        }
        let userIdString = userId.uuidString

        // 1. Read current journey_progress row
        let rows: [ProgressRow] = try await supabase
            .from("journey_progress")
            .select("user_id, current_stage, stages_entered_at")
            .eq("user_id", value: userIdString)
            .limit(1)
            .execute()
            .value

        guard let progress = rows.first else {
            // Row not yet created · sync_journey_progress trigger seeds it on first
            // completed session · acceptable to no-op until then.
            return nil
        }

        // 2. Stage 5 is terminal · early-return, no event.
        guard progress.current_stage < 5 else { return nil }

        // 3. Read stages_entered_at[currentStage]
        let currentKey = String(progress.current_stage)
        guard
            let enteredAtString = progress.stages_entered_at[currentKey] ?? nil,
            let enteredAt = Self.iso8601.date(from: enteredAtString)
                         ?? Self.iso8601NoFractional.date(from: enteredAtString)
        else {
            // Shouldn't happen post-onboarding · trigger seeds entry on first session.
            return nil
        }

        // 4. sessions-in-stage · walking · completed · started_at >= enteredAt
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceString = isoFormatter.string(from: enteredAt)

        let sessionRows: [CountRow] = try await supabase
            .from("sessions")
            .select("id")
            .eq("user_id", value: userIdString)
            .eq("session_type", value: "walking")
            .eq("completed", value: true)
            .is("deleted_at", value: nil)
            .gte("started_at", value: sinceString)
            .execute()
            .value
        let sessionsInStage = sessionRows.count

        // 5. days-in-stage · Calendar floor
        let daysInStage = max(
            0,
            Calendar.current.dateComponents([.day], from: enteredAt, to: Date()).day ?? 0
        )

        // 6. Apply rule
        guard StageAdvancementRule.canAdvance(
            fromStage: progress.current_stage,
            sessionsInStage: sessionsInStage,
            daysInStage: daysInStage
        ) else {
            return nil
        }

        let nextStage = progress.current_stage + 1
        let now = Date()

        // 7. Build payload · stages_entered_at is APPEND-ONLY (V2 invariant)
        var updatedEnteredAt: [String: String] = [:]
        for (key, value) in progress.stages_entered_at {
            if let v = value { updatedEnteredAt[key] = v }
        }
        let nextKey = String(nextStage)
        if updatedEnteredAt[nextKey] == nil {
            updatedEnteredAt[nextKey] = isoFormatter.string(from: now)
        }

        let payload = AdvancePayload(
            current_stage: nextStage,
            stages_entered_at: updatedEnteredAt
        )

        // 8. UPDATE · RLS gate (can_advance_stage) revalidates server-side
        try await supabase
            .from("journey_progress")
            .update(payload)
            .eq("user_id", value: userIdString)
            .execute()

        // 9. Fire Mixpanel · M25
        Analytics.track(.stageAdvanced(
            fromStage: progress.current_stage,
            toStage: nextStage,
            triggerRule: StageAdvancementRule.triggerRule,
            sessionsInStage: sessionsInStage,
            daysInStage: daysInStage
        ))

        return nextStage
    }

    // MARK: · ISO8601 parsers

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601NoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
