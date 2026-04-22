//
//  Color+App.swift
//  SpiritPath
//
//  Unified palette · iOS + Android · master plan §04 Design system
//  Source of truth: /Users/punyapath/Downloads/SpiritPath/src/tokens.jsx
//  Platform parity: all hex values match Android Compose Color tokens
//
//  Note · Onboarding uses `.spirit*` constants defined in SpiritPathApp.swift (stark B&W editorial).
//  Post-onboarding (Phase 1+) uses the tokens below. Both sets coexist during migration.
//

import SwiftUI

extension Color {

    // ── Surfaces · navy stack ──────────────────────────────────────────────
    /// Deepest bg · Stillness tab · warmBlack in tokens.jsx
    static let appMidnight      = Color(hex: "#050A14")
    /// App default bg · navy · surface in tokens.jsx
    static let appSurface       = Color(hex: "#0A1424")
    /// Card bg · surfaceLow
    static let appSurfaceLow    = Color(hex: "#111D33")
    /// Raised card · surfaceLowest
    static let appSurfaceRaised = Color(hex: "#152544")
    /// Selected state · surfaceHigh
    static let appSurfaceHigh   = Color(hex: "#1C2F54")

    // ── Accent · moon gold ─────────────────────────────────────────────────
    static let appGold       = Color(hex: "#F0C870")   // primary
    static let appGoldDeep   = Color(hex: "#C49A48")   // primaryDeep · shadow
    static let appGoldTint   = Color(hex: "#F7DCA0")   // primaryTint · highlight
    static let appOnGold     = Color(hex: "#0A1424")   // text on gold pill

    // ── Secondary · river blue ─────────────────────────────────────────────
    static let appRiver      = Color(hex: "#7FB3DD")

    // ── Ink · cream on dark ────────────────────────────────────────────────
    static let appCream      = Color(hex: "#F4E8C8")            // primary ink
    static let appCreamDeep  = Color(hex: "#E0D0A8")
    static let appInkSoft    = Color(hex: "#F4E8C8").opacity(0.82)  // body
    static let appInkMuted   = Color(hex: "#F4E8C8").opacity(0.58)  // captions
    static let appInkFaint   = Color(hex: "#F4E8C8").opacity(0.32)  // dormant
    static let appInkGhost   = Color(hex: "#F4E8C8").opacity(0.12)  // hairlines

    // ── Semantic · alerts (use sparingly) ─────────────────────────────────
    static let appAlert      = Color(hex: "#E8A87C")
    static let appOk         = Color(hex: "#9EC5A6")
}

// Note · `Color(hex:)` initializer is defined in SpiritPathApp.swift and reused here.
