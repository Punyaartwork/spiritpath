//
//  NightLogCopy.swift
//  SpiritPath
//
//  Phase 2.7b · M23 lock · Settings Night Log copy locked verbatim cross-platform.
//  Source of truth: codereview/wiki-handoff/20260426-conventions.md line 32 · re-affirmed
//  20260507-conventions.md ("Night Log encryption copy ... unchanged").
//
//  DO NOT EDIT THE STRING. Any change requires a CodeReview sync round + Android mirror
//  update in the same wave (Android holds the same string in `R.string.night_log_m23_body`).
//

import Foundation

/// M23 · Night Log Settings copy · LOCKED verbatim · referenced in SettingsView §Night Log.
enum NightLogCopy {

    /// M23 body · do NOT paraphrase. Any change is a tone-rule sync round (Android mirror required).
    enum M23 {
        /// Verbatim from 20260426-conventions.md line 32.
        static let body: String =
            "Night Log entries are encrypted on this device. Uninstalling the app or switching devices will permanently lose access to older entries."
    }
}
