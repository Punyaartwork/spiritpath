//
//  SessionEventThrottle.swift
//  SpiritPath
//
//  Phase 2.3 · process-scoped per-key dedupe for once-per-session R28 events.
//
//  iOS analog of Android's @Singleton @Inject SessionEventThrottle (commit 02b55be).
//  State is @MainActor-isolated · all M16 fire-sites originate from view body or .task,
//  so MainActor isolation is sufficient and equivalent to actor isolation here.
//
//  Reused for M17 feature_flag_evaluated (Phase 2.x) with composite keys like
//  "flag_audio_delivery" so each flag's first evaluation per session fires exactly once.
//
//  R28 line 113 contract: "session = launch-to-backgrounded" · throttle resets on
//  process death · re-entering app from background reuses the same set.
//

import Foundation

@MainActor
final class SessionEventThrottle {
    static let shared = SessionEventThrottle()
    private init() {}

    private var firedKeys: Set<String> = []

    /// Returns true on first call for `key` this app session · false thereafter.
    /// Caller fires the analytics event only when this returns true.
    func firstFireThisSession(_ key: String) -> Bool {
        firedKeys.insert(key).inserted
    }
}
