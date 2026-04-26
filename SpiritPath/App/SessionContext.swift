//
//  SessionContext.swift
//  SpiritPath
//
//  Phase 1.3 · shared state between Session → Reflection flow.
//  Created in RootTabView when user taps Begin (Practice) or play (Home quick-start).
//  Carries the session UUID that ties session_started · session_ended · reflection_submitted
//  together for Mixpanel funnel matching + future Supabase sessions row.
//
//  Phase 1.6 · `startedAt` captured at SessionView .onAppear · used for HealthKit
//  stepCount(from:to:) range query at end + writeMindfulSession(start:end:) entry.
//  `mindfulSteps == totalSteps` per spec C5 (gait detection lands Phase 2).
//

import Foundation

struct SessionContext: Equatable {
    let uuid: String
    let sessionType: String     // "walking" · "quiet" · "breath" · "sound_bath"
    let lineageId: String       // "mun" · "sodh" · "chah"
    let stageIndex: Int         // 1–5
    let targetSec: Int          // 900 · 1800 · 3600
    let place: String           // "forest" · "temple"
    let ground: String          // "grass" · "earth" · "stone" · "indoors"
    let paceMode: String        // "forest" · "temple" · "street"

    // Phase 1.6 · stamped at SessionView .onAppear
    var startedAt: Date?

    // Updated during session
    var elapsedSec: Int = 0

    // Set at session end
    var endedAt: Date?
    var endedReason: String?    // "natural" · "user_abort"
    var completed: Bool = false

    // Phase 1.6 · real values from HealthKit · 0 if permission denied
    var mindfulSteps: Int = 0
    var totalSteps: Int = 0
    var momentsOfReturn: Int = 0
}
