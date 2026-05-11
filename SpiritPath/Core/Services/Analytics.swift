//
//  Analytics.swift
//  SpiritPath
//
//  Mixpanel wrapper · R22 baseline + R28 Phase 2 events · snake_case event names · typed enum prevents drift.
//  Consent gate: reads profiles.tracking_opt_out (cached in UserDefaults) before any track.
//
//  R28 events added Phase 2.1+:
//    - stage_opened          (M14 · Phase 2.1 active · second-fire on TeachingView mode pick · Phase 2.2)
//    - lineage_changed       (M15 · Phase 2.1 active · fires after profile UPDATE succeeds)
//    - stillness_opened      (M16 · Phase 2.3 active · once-per-session via SessionEventThrottle)
//    - feature_flag_evaluated(M17 · Phase 2.x stub · enum case wired · no fire-site this batch)
//
//  Phase 2.4 expansion:
//    - sessionStarted/sessionEnded place/ground/paceMode/stageIndexAtTime now optional
//      so breath + quiet can OMIT (Section 4.3 spec) rather than send empty strings.
//

import Foundation
import Mixpanel

/// Locked Phase 1.5 + Phase 2 event set · R22 + R28.
enum AnalyticsEvent {
    case onboardingCompleted(
        lineageId: String,      // mun / sodh / chah
        pathId: String,         // mindful_walking / everyday / body / retreat
        meditationExperience: String,
        peaceContext: String,
        environmentTagsCount: Int,
        guidanceTagsCount: Int,
        notificationsGranted: Bool,
        locationGranted: Bool
    )

    /// Phase 2.4 · place/ground/paceMode/stageIndexAtTime are nil for breath/quiet (Section 4.3).
    case sessionStarted(
        sessionUuid: String,
        sessionType: String,    // walking / quiet / breath / sound_bath
        lineageId: String,
        stageIndexAtTime: Int?, // walking only · OMIT for breath/quiet
        durationTargetSec: Int,
        place: String?,         // walking only
        ground: String?,        // walking only
        paceMode: String?       // walking only
    )

    /// Phase 2.4 · place/ground/paceMode/stageIndexAtTime are nil for breath/quiet (Section 4.3).
    case sessionEnded(
        sessionUuid: String,
        sessionType: String,
        lineageId: String,
        stageIndexAtTime: Int?, // walking only
        durationTargetSec: Int,
        durationActualSec: Int,
        mindfulSteps: Int,
        totalSteps: Int,
        momentsOfReturn: Int,
        completed: Bool,
        endedReason: String?    // natural / user_abort / user_complete / user_pause / auto_complete · M21
    )

    case reflectionSubmitted(
        sessionUuid: String,
        noteLengthChars: Int,
        anchorPhraseSet: Bool,
        timeSinceSessionEndSec: Int
    )

    case paywallViewed(
        paywallVariant: String,
        triggerSource: String,  // onboarding / paywall_gate / settings_upgrade / feature_locked / stage_locked
        hasPreviousTrial: Bool
    )

    // MARK: · R28 Phase 2 events

    /// M14 · Phase 2.1 active (modeFirstOpened="browse") · Phase 2.2 second-fire on first tab pick.
    /// Cohort attribution: stage_index + lineage_id + is_current_stage drives funnel slicing.
    case stageOpened(
        lineageId: String,
        stageIndex: Int,
        modeFirstOpened: String,    // "browse" Phase 2.1 default · "listen"/"understand"/"reflect" Phase 2.2
        isCurrentStage: Bool
    )

    /// M15 · Phase 2.1 active · fires AFTER profiles UPDATE succeeds, before bottom sheet dismiss.
    /// Same-selection no-ops (no event). Failed update fires no event.
    case lineageChanged(
        fromLineageId: String,
        toLineageId: String,
        currentStage: Int
    )

    /// M16 · Phase 2.3 active · throttled per app session via SessionEventThrottle.
    /// Re-fires only after process death.
    case stillnessOpened(
        timeOfDayHour: Int,         // 0-23 local
        hadSessionToday: Bool,
        entrySource: String         // "tab_bar" · "notification" · "home_card" · "deep_link"
    )

    /// M17 · Phase 2.x stub · enum case wired so call-sites compile · no fire-site this batch.
    /// Throttled per (flag_key, app session) when wired.
    case featureFlagEvaluated(
        flagKey: String,
        flagValue: String,
        defaultUsed: Bool,
        source: String              // "cache" · "server" · "default"
    )

    /// M25 · Phase 2.7a · fires when journey_progress.current_stage advances (silent, server-validated).
    /// Fired exactly once per advancement · idempotent guard inside JourneyProgressService.
    case stageAdvanced(
        fromStage: Int,             // 1–4
        toStage: Int,               // 2–5
        triggerRule: String,        // "composite_v1"
        sessionsInStage: Int,       // ≥ threshold
        daysInStage: Int            // ≥ threshold
    )

    /// M27 · Phase 2.7d-prep · fires per onboarding step Next button tap · funnel drop-off analysis.
    /// step_index: canonical R30 position (0..6) · NOT iOS screen number · NOT firing order.
    /// step_name: one of welcome / lineage_match / quiz_experience / quiz_teaching / quiz_focus / quiz_intent / result_reveal.
    /// time_on_step_sec: seconds spent on that R30 step screen before advancing (interstitial time excluded by go(to:) reset).
    /// variant_id: "default" Phase 2.7d-prep · replaced with feature_flag onboarding_variant value Phase 2.7d-impl.
    case onboardingStepAdvanced(
        stepIndex: Int,
        stepName: String,
        timeOnStepSec: Int,
        variantId: String
    )

    /// M28 · Phase 2.7c · Settings Privacy toggle · cross-platform contract with Android.
    /// Caller MUST sequence vs Mixpanel SDK opt-state correctly:
    ///   - Opting OUT → fire event BEFORE Analytics.setOptOut(true) so it isn't suppressed
    ///   - Opting IN  → fire event AFTER  Analytics.setOptOut(false) so the local consent
    ///                  gate has been lifted before track() runs
    /// SettingsRepository.updateTrackingOptOut handles this ordering.
    case trackingOptOutChanged(optedOut: Bool)

    var name: String {
        switch self {
        case .onboardingCompleted:    return "onboarding_completed"
        case .sessionStarted:         return "session_started"
        case .sessionEnded:           return "session_ended"
        case .reflectionSubmitted:    return "reflection_submitted"
        case .paywallViewed:          return "paywall_viewed"
        case .stageOpened:            return "stage_opened"
        case .lineageChanged:         return "lineage_changed"
        case .stillnessOpened:        return "stillness_opened"
        case .featureFlagEvaluated:   return "feature_flag_evaluated"
        case .stageAdvanced:          return "stage_advanced"
        case .onboardingStepAdvanced: return "onboarding_step_advanced"
        case .trackingOptOutChanged:  return "tracking_opt_out_changed"
        }
    }

    var properties: [String: MixpanelType] {
        switch self {
        case .onboardingCompleted(let lineageId, let pathId, let exp, let peace, let envCount, let guideCount, let notif, let loc):
            return [
                "selected_lineage_id": lineageId,
                "chosen_path_id": pathId,
                "meditation_experience": exp,
                "peace_context": peace,
                "environment_tags_count": envCount,
                "guidance_tags_count": guideCount,
                "notifications_granted": notif,
                "location_granted": loc
            ]
        case .sessionStarted(let uuid, let type, let lineage, let stage, let target, let place, let ground, let pace):
            var props: [String: MixpanelType] = [
                "session_uuid": uuid,
                "session_type": type,
                "lineage_id": lineage,
                "duration_target_sec": target
            ]
            if let stage  { props["stage_index_at_time"] = stage }
            if let place  { props["place"] = place }
            if let ground { props["ground"] = ground }
            if let pace   { props["pace_mode"] = pace }
            return props
        case .sessionEnded(let uuid, let type, let lineage, let stage, let target, let actual, let mSteps, let tSteps, let returns, let completed, let reason):
            var props: [String: MixpanelType] = [
                "session_uuid": uuid,
                "session_type": type,
                "lineage_id": lineage,
                "duration_target_sec": target,
                "duration_actual_sec": actual,
                "mindful_steps": mSteps,
                "total_steps": tSteps,
                "moments_of_return": returns,
                "completed": completed
            ]
            if let stage  { props["stage_index_at_time"] = stage }
            if let reason { props["ended_reason"] = reason }
            return props
        case .reflectionSubmitted(let uuid, let length, let anchor, let gap):
            return [
                "session_uuid": uuid,
                "note_length_chars": length,
                "anchor_phrase_set": anchor,
                "time_since_session_end_sec": gap
            ]
        case .paywallViewed(let variant, let trigger, let hasTrial):
            return [
                "paywall_variant": variant,
                "trigger_source": trigger,
                "has_previous_trial": hasTrial
            ]
        case .stageOpened(let lineageId, let stageIndex, let modeFirstOpened, let isCurrentStage):
            return [
                "lineage_id": lineageId,
                "stage_index": stageIndex,
                "mode_first_opened": modeFirstOpened,
                "is_current_stage": isCurrentStage
            ]
        case .lineageChanged(let from, let to, let currentStage):
            return [
                "from_lineage_id": from,
                "to_lineage_id": to,
                "current_stage": currentStage
            ]
        case .stillnessOpened(let hour, let hadSession, let entry):
            return [
                "time_of_day_hour": hour,
                "had_session_today": hadSession,
                "entry_source": entry
            ]
        case .featureFlagEvaluated(let key, let value, let defaultUsed, let source):
            return [
                "flag_key": key,
                "flag_value": value,
                "default_used": defaultUsed,
                "source": source
            ]
        case .stageAdvanced(let fromStage, let toStage, let triggerRule, let sessionsInStage, let daysInStage):
            return [
                "from_stage": fromStage,
                "to_stage": toStage,
                "trigger_rule": triggerRule,
                "sessions_in_stage": sessionsInStage,
                "days_in_stage": daysInStage
            ]
        case .onboardingStepAdvanced(let stepIndex, let stepName, let timeOnStepSec, let variantId):
            return [
                "step_index": stepIndex,
                "step_name": stepName,
                "time_on_step_sec": timeOnStepSec,
                "variant_id": variantId
            ]
        case .trackingOptOutChanged(let optedOut):
            return [
                "opted_out": optedOut
            ]
        }
    }
}

/// Central analytics client · handles init · consent · identity · tracking.
enum Analytics {
    private static let token = "373e5c078bbe0d04b8be993cfb818df5"
    private static let optOutKey = "spiritpath.tracking_opt_out"

    /// Call once at app launch · after SpiritFonts.registerAll() in SpiritPathApp.init()
    static func initialize() {
        Mixpanel.initialize(token: token, trackAutomaticEvents: false)

        // Read cached opt-out · default false (opt-in · CCPA notice model)
        let optOut = UserDefaults.standard.bool(forKey: optOutKey)
        if optOut {
            Mixpanel.mainInstance().optOutTracking()
        }

        registerSuperProperties()
    }

    /// Fire once on app launch with cached session · and on every new sign-in.
    /// Call on every app foreground too (skill rule M4 · prevents session merge bugs).
    static func identify(userId: String, userProperties: [String: MixpanelType] = [:]) {
        guard !Mixpanel.mainInstance().hasOptedOutTracking() else { return }
        Mixpanel.mainInstance().identify(distinctId: userId)
        if !userProperties.isEmpty {
            Mixpanel.mainInstance().people.set(properties: userProperties)
        }
    }

    /// Call on sign-out · critical · prevents next user's events merging into previous session.
    static func reset() {
        Mixpanel.mainInstance().reset()
    }

    /// Update opt-out state · called when user toggles Settings (Phase 3 UI) or profiles.tracking_opt_out changes cross-device.
    static func setOptOut(_ optOut: Bool) {
        UserDefaults.standard.set(optOut, forKey: optOutKey)
        if optOut {
            Mixpanel.mainInstance().optOutTracking()
        } else {
            Mixpanel.mainInstance().optInTracking()
        }
    }

    /// Single track entry point · consent gate enforced here · no raw SDK call elsewhere.
    static func track(_ event: AnalyticsEvent) {
        guard !Mixpanel.mainInstance().hasOptedOutTracking() else { return }
        Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
    }

    private static func registerSuperProperties() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        Mixpanel.mainInstance().registerSuperProperties([
            "app_version": version,
            "build_number": build,
            "platform": "ios",
            "locale": Locale.current.identifier
            // device_model + os_version auto-collected by SDK
            // selected_lineage_id · current_stage · has_active_subscription set after auth + profile load
        ])
    }
}
