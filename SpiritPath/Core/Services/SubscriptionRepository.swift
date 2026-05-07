//
//  SubscriptionRepository.swift
//  SpiritPath
//
//  Phase 2.2 stub · returns false until Phase 1.7b (StoreKit · Apple Developer-parked).
//  Contract surface stable for swap · adding StoreKit2 later wires `currentEntitlements`
//  query without changing call sites.
//
//  StageDetailView consumes this to gate stages 2-5 behind paywall.
//

import Foundation

@MainActor
final class SubscriptionRepository {
    static let shared = SubscriptionRepository()
    private init() {}

    /// Phase 2.2: always false · all stage gates resolve to PaywallStubView.
    /// Phase 1.7b will return true when StoreKit2 reports an active subscription
    /// for any of the SpiritPath product ids.
    func hasActiveSubscription() async -> Bool {
        false
    }
}
