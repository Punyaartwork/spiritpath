//
//  SessionContext.swift
//  SpiritPath
//
//  Phase 1.3 · shared state between Session → Reflection flow.
//  Created in RootTabView when user taps Begin (Practice) or play (Home quick-start).
//  Carries the session UUID that ties session_started · session_ended · reflection_submitted
//  together for Mixpanel funnel matching + future Supabase sessions row.
//
//  Mock step/return values land Phase 1.6 (HealthKit read + CoreMotion pedometer).
//  Supabase persistence lands Phase 1.7 (auth + offline-first write).
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

    // Updated during session
    var elapsedSec: Int = 0

    // Set at session end
    var endedAt: Date?
    var endedReason: String?    // "natural" · "user_abort"
    var completed: Bool = false

    // Mock values · Phase 1.6 wire HealthKit + CoreMotion
    var mindfulSteps: Int = 320
    var totalSteps: Int = 500
    var momentsOfReturn: Int = 0
}
