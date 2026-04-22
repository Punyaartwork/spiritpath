//
//  Analytics.swift
//  SpiritPath
//
//  Mixpanel wrapper · R22 taxonomy · snake_case events · typed enum prevents drift.
//  Consent gate: reads profiles.tracking_opt_out (cached in UserDefaults) before any track.
//

import Foundation
import Mixpanel

/// Locked Phase 1.5 event set · R22 · M6.
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

    case sessionStarted(
        sessionUuid: String,
        sessionType: String,    // walking / quiet / breath / sound_bath
        lineageId: String,
        stageIndexAtTime: Int,
        durationTargetSec: Int,
        place: String,
        ground: String,
        paceMode: String
    )

    case sessionEnded(
        sessionUuid: String,
        sessionType: String,
        lineageId: String,
        stageIndexAtTime: Int,
        durationTargetSec: Int,
        durationActualSec: Int,
        mindfulSteps: Int,
        totalSteps: Int,
        momentsOfReturn: Int,
        completed: Bool,
        endedReason: String?    // natural / user_abort / background_timeout / other (nil = uncategorized)
    )

    case reflectionSubmitted(
        sessionUuid: String,
        noteLengthChars: Int,
        anchorPhraseSet: Bool,
        timeSinceSessionEndSec: Int
    )

    case paywallViewed(
        paywallVariant: String,
        triggerSource: String,  // onboarding / paywall_gate / settings_upgrade / feature_locked
        hasPreviousTrial: Bool
    )

    var name: String {
        switch self {
        case .onboardingCompleted:  return "onboarding_completed"
        case .sessionStarted:       return "session_started"
        case .sessionEnded:         return "session_ended"
        case .reflectionSubmitted:  return "reflection_submitted"
        case .paywallViewed:        return "paywall_viewed"
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
            return [
                "session_uuid": uuid,
                "session_type": type,
                "lineage_id": lineage,
                "stage_index_at_time": stage,
                "duration_target_sec": target,
                "place": place,
                "ground": ground,
                "pace_mode": pace
            ]
        case .sessionEnded(let uuid, let type, let lineage, let stage, let target, let actual, let mSteps, let tSteps, let returns, let completed, let reason):
            var props: [String: MixpanelType] = [
                "session_uuid": uuid,
                "session_type": type,
                "lineage_id": lineage,
                "stage_index_at_time": stage,
                "duration_target_sec": target,
                "duration_actual_sec": actual,
                "mindful_steps": mSteps,
                "total_steps": tSteps,
                "moments_of_return": returns,
                "completed": completed
            ]
            if let reason = reason { props["ended_reason"] = reason }
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
