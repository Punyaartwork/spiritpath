//
//  ProfileRepository.swift
//  SpiritPath
//
//  Phase 2.1 · profile mutations · selected_lineage_id update is the only operation
//  this batch ships. RLS Pattern A: profiles row is owner-scoped · UPDATE WHERE id = auth.uid().
//
//  Auth is not yet wired (Phase 1.7a parked) · so updates may fail with notAuthenticated
//  until then. JourneyView swallows the error and keeps the local @AppStorage value.
//

import Foundation
import Supabase
import PostgREST

enum ProfileRepositoryError: Error {
    case notAuthenticated
}

@MainActor
final class ProfileRepository {
    static let shared = ProfileRepository()
    private init() {}

    /// UPDATE profiles SET selected_lineage_id = ? WHERE id = auth.uid().
    /// Caller fires lineage_changed event ONLY if this succeeds.
    func updateLineage(_ newLineageId: String) async throws {
        guard let userId = supabase.auth.currentUser?.id else {
            throw ProfileRepositoryError.notAuthenticated
        }
        try await supabase
            .from("profiles")
            .update(["selected_lineage_id": newLineageId])
            .eq("id", value: userId)
            .execute()
    }

    /// Phase 2.7c stub · contract surface for callers that mutate the profile row
    /// (e.g. SettingsRepository.updateTrackingOptOut) and want any cached state to
    /// re-pull. ProfileRepository is currently stateless · so this is a no-op
    /// placeholder kept stable so caching can land later without churning call sites.
    func refresh() async {
        // No-op · cache wiring lands Phase 2.7c+ when ProfileRepository becomes
        // the source-of-truth for profile reads (currently views read directly).
    }
}
