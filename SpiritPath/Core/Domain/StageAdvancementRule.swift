//
//  StageAdvancementRule.swift
//  SpiritPath
//
//  Phase 2.7a · cohort-driven stage advancement thresholds.
//  Composite rule per stage transition: sessions-in-stage + days-in-stage cumulative
//  since stages_entered_at[currentStage].
//
//  Threshold table MUST stay in sync with:
//    - SQL: supabase/migrations/0012_stage_advancement_rls.sql · can_advance_stage()
//    - Android (Phase 2.7a): app/.../core/domain/StageAdvancementRule.kt
//
//  Mixpanel `stage_advanced` event uses triggerRule = "composite_v1" to allow
//  rule-version cohorting if thresholds change in a future phase.
//

import Foundation

enum StageAdvancementRule {

    /// Bumped when threshold values change so dashboards can cohort-slice cleanly.
    static let triggerRule = "composite_v1"

    struct Threshold: Equatable {
        let sessionsInStage: Int
        let daysInStage: Int
    }

    /// Threshold to ENTER a given stage (so [2] = entering stage 2 from stage 1).
    /// Keep in sync with SQL `can_advance_stage` case branches and Android constants.
    static let thresholds: [Int: Threshold] = [
        2: Threshold(sessionsInStage: 7,  daysInStage: 14),
        3: Threshold(sessionsInStage: 14, daysInStage: 30),
        4: Threshold(sessionsInStage: 21, daysInStage: 45),
        5: Threshold(sessionsInStage: 30, daysInStage: 60),
    ]

    /// Returns true if practice in current stage meets the threshold to advance to fromStage + 1.
    /// `fromStage` must be in 1...4. Stage 5 is terminal (no further advance).
    static func canAdvance(
        fromStage: Int,
        sessionsInStage: Int,
        daysInStage: Int
    ) -> Bool {
        guard fromStage >= 1, fromStage <= 4 else { return false }
        guard let threshold = thresholds[fromStage + 1] else { return false }
        return sessionsInStage >= threshold.sessionsInStage
            && daysInStage     >= threshold.daysInStage
    }
}
