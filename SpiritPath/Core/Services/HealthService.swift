//
//  HealthService.swift
//  SpiritPath
//
//  Phase 1.6 · single async/await surface to HealthKit · idempotent.
//  Reads HKQuantityType.stepCount across a date range · writes HKCategoryType.mindfulSession
//  per completed meditation · attaches session_uuid · lineage_id · stage_index metadata
//  so a session in Apple Health can be matched back to the SpiritPath sessions row later.
//
//  Per skill rule C5 · health data stays on device · NO Supabase write of step or mindful
//  payload · only metadata that lives inside HealthKit itself.
//
//  Permission model · ask once on first Begin · proceed regardless of grant outcome
//  (graceful degradation · 0 steps shows "Step tracking unavailable for this session.").
//

import Foundation
import HealthKit

enum HealthServiceError: Error {
    case notAvailable
    case authorizationFailed(Error)
    case queryFailed(Error)
    case writeFailed(Error)
}

@MainActor
final class HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()

    private let stepType    = HKQuantityType(.stepCount)
    private let mindfulType = HKCategoryType(.mindfulSession)

    private init() {}

    /// `true` only on iPhone (HealthKit unavailable on simulator macOS host · iPad).
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Authorization status for the WRITE type (mindful session).
    /// Read-only types always return `.sharingDenied` on iOS — we use mindful (write)
    /// as proxy for "have we asked the user yet?".
    var mindfulWriteStatus: HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return store.authorizationStatus(for: mindfulType)
    }

    /// True when the user has not yet been asked · drives PracticeView micro-copy
    /// + first-tap-on-Begin permission flow. Hides HKAuthorizationStatus from views.
    var permissionUndetermined: Bool {
        mindfulWriteStatus == .notDetermined
    }

    /// View-friendly status for PracticeView micro-copy · hides HK enum.
    enum PermissionState {
        case undetermined  // first session · prompt will fire on Begin
        case granted       // user said yes · steps + mindful flowing
        case denied        // user said no · sessions still work · 0 steps
        case unavailable   // simulator / iPad / device with no HK
    }

    var permissionState: PermissionState {
        guard isAvailable else { return .unavailable }
        switch store.authorizationStatus(for: mindfulType) {
        case .notDetermined:    return .undetermined
        case .sharingAuthorized: return .granted
        case .sharingDenied:    return .denied
        @unknown default:       return .undetermined
        }
    }

    /// Idempotent · no-op if already determined.
    func requestAuthorization() async throws {
        guard isAvailable else { throw HealthServiceError.notAvailable }
        do {
            try await store.requestAuthorization(
                toShare: [mindfulType],
                read:    [stepType]
            )
        } catch {
            throw HealthServiceError.authorizationFailed(error)
        }
    }

    /// Sum of step count between `from` and `to` · returns `0` if denied or no samples.
    func stepCount(from: Date, to: Date) async throws -> Int {
        guard isAvailable else { return 0 }
        let predicate = HKQuery.predicateForSamples(
            withStart: from,
            end: to,
            options: .strictStartDate
        )
        return try await withCheckedThrowingContinuation { cont in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    cont.resume(throwing: HealthServiceError.queryFailed(error))
                    return
                }
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(query)
        }
    }

    /// Writes a mindful session sample · skill rule C5 · 3 metadata keys (session_uuid ·
    /// lineage_id · stage_index) so the entry can round-trip to a Supabase sessions row
    /// without leaking step/duration data.
    func writeMindfulSession(
        start: Date,
        end: Date,
        sessionUuid: String,
        lineageId: String,
        stageIndex: Int
    ) async throws {
        guard isAvailable else { return }
        let metadata: [String: Any] = [
            "session_uuid": sessionUuid,
            "lineage_id":   lineageId,
            "stage_index":  stageIndex
        ]
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end,
            metadata: metadata
        )
        do {
            try await store.save(sample)
        } catch {
            throw HealthServiceError.writeFailed(error)
        }
    }
}
