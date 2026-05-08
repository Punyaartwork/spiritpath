//
//  SettingsRepository.swift
//  SpiritPath
//
//  Phase 2.7c · iOS-side mirror of Android Phase 2.7c SettingsScreen contract.
//  Drives the SettingsView screen (Profile · Practice prefs · Notifications · Privacy ·
//  Night Log · About).
//
//  iOS pattern · no local cache · all reads/writes go directly to Supabase via the
//  shared SDK client. Caching is owned by ProfileRepository where appropriate.
//
//  RLS Pattern A: every row is owner-scoped via `WHERE id = auth.uid()` on profiles
//  or `user_id = auth.uid()` on the satellite tables. Auth is not yet wired
//  (Phase 1.7a parked) · so calls may throw `RepositoryError.notAuthenticated`
//  until then. Callers should treat that as a soft no-op.
//
//  M5 lock: profiles.tracking_opt_out is the source-of-truth · Mixpanel SDK
//  opt-state is mirrored from it · never written to in isolation.
//

import Foundation
import Mixpanel
import PostgREST
import Supabase

@MainActor
final class SettingsRepository {
    static let shared = SettingsRepository()
    private init() {}

    enum RepositoryError: Error {
        case notAuthenticated
    }

    // MARK: · Privacy · Mixpanel opt-out

    /// M5 lock: profiles.tracking_opt_out is source-of-truth.
    /// Updates the row · refreshes cached profile · fires the cross-platform
    /// `tracking_opt_out_changed` event · then mirrors the new state into the
    /// Mixpanel SDK so subsequent `Analytics.track` calls respect the user's choice.
    ///
    /// Event-vs-SDK ordering matters: when opting OUT we fire the event first
    /// (otherwise the SDK suppresses it). When opting IN we flip the SDK first
    /// (otherwise the local consent gate inside `Analytics.track` drops the event).
    func updateTrackingOptOut(_ optOut: Bool) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update(["tracking_opt_out": optOut])
            .eq("id", value: userId.uuidString)
            .execute()

        await ProfileRepository.shared.refresh()

        if optOut {
            Analytics.track(.trackingOptOutChanged(optedOut: true))
            Analytics.setOptOut(true)
        } else {
            Analytics.setOptOut(false)
            Analytics.track(.trackingOptOutChanged(optedOut: false))
        }
    }

    // MARK: · Notifications · 1:1 row in notification_prefs

    /// Phase 2.7c · upsert subset of notification_prefs the Settings screen owns.
    /// `enabled` toggles morning_bell + evening_reminder together (push toggle stays
    /// disabled in UI for Phase 2.7c · real APNS scheduling lands Phase 3).
    /// `timeOfDay` is "HH:mm" 24-hour string · used for morning_bell_at when supplied.
    /// `timezone` is an IANA identifier · stored on profiles row when supplied.
    func updateNotificationPrefs(
        enabled: Bool,
        timeOfDay: String?,
        timezone: String?
    ) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }

        struct PrefsUpsert: Encodable {
            let user_id: String
            let morning_bell_enabled: Bool
            let evening_reminder_enabled: Bool
            let morning_bell_at: String?
        }

        let prefs = PrefsUpsert(
            user_id: userId.uuidString,
            morning_bell_enabled: enabled,
            evening_reminder_enabled: enabled,
            morning_bell_at: timeOfDay
        )
        try await supabase
            .from("notification_prefs")
            .upsert(prefs, onConflict: "user_id")
            .execute()

        if let timezone {
            try await supabase
                .from("profiles")
                .update(["timezone": timezone])
                .eq("id", value: userId.uuidString)
                .execute()
        }
    }

    // MARK: · Practice window · 1:1 row in practice_window

    /// Phase 2.7c · upsert "When to practice" section state.
    /// `startHour` / `endHour` are 0-23 ints · `weekdaysOnly` is stored as a column
    /// flag once schema lands (Phase 2.7c+) · for now we forward but only the hours
    /// columns are persisted server-side.
    func updatePracticeWindow(
        startHour: Int,
        endHour: Int,
        weekdaysOnly: Bool
    ) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }

        struct WindowUpsert: Encodable {
            let user_id: String
            let start_hour: Int
            let end_hour: Int
        }

        let row = WindowUpsert(
            user_id: userId.uuidString,
            start_hour: max(0, min(23, startHour)),
            end_hour: max(0, min(23, endHour))
        )
        _ = weekdaysOnly  // accepted for contract parity · column lands later
        try await supabase
            .from("practice_window")
            .upsert(row, onConflict: "user_id")
            .execute()
    }

    // MARK: · CCPA "right to know" · async export

    /// Inserts a row into data_export_requests with status pending.
    /// Edge function aggregates user data → ZIP → presigned URL · client polls
    /// status afterward (out of scope for Phase 2.7c).
    func requestDataExport() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        struct ExportInsert: Encodable {
            let user_id: String
            let status: String
        }
        try await supabase
            .from("data_export_requests")
            .insert(ExportInsert(user_id: userId.uuidString, status: "pending"))
            .execute()
    }

    // MARK: · CCPA + GDPR "right to delete" · 30-day grace

    /// Inserts a row into account_deletion_requests with status pending.
    /// Trigger sets `scheduled_for = requested_at + 30 days` server-side · daily
    /// pg_cron processes due rows (hard-delete cascades). User can cancel by
    /// signing in within 30 days.
    func requestAccountDeletion() async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        struct DeletionInsert: Encodable {
            let user_id: String
            let status: String
        }
        try await supabase
            .from("account_deletion_requests")
            .insert(DeletionInsert(user_id: userId.uuidString, status: "pending"))
            .execute()
    }
}
