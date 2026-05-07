//
//  Screen.swift
//  SpiritPath
//
//  Flat state machine nav · 6 cases · cross-platform locked · Phase 1.1.
//  Mirrors Android Screen enum · raw values are wire values for future deep links / Mixpanel.
//  Do not change raw values without a sync round.
//

import Foundation

enum Screen: String, CaseIterable {
    // Tab screens · 4 main tabs
    case home       = "home"
    case practice   = "practice"
    case journey    = "journey"
    case stillness  = "stillness"

    // Modal / pushed fullscreen · tab bar hidden
    case session    = "session"
    case reflection = "reflection"
    case nightlog   = "nightlog"   // Phase 2.4b · before-sleep reflection

    var showsTabBar: Bool {
        switch self {
        case .home, .practice, .journey, .stillness: return true
        case .session, .reflection, .nightlog:       return false
        }
    }
}
