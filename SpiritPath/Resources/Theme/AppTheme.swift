//
//  AppTheme.swift
//  SpiritPath
//
//  Unified theme · iOS + Android · master plan §04
//  Phase 1+ surfaces read from here. Onboarding (Phase 0) keeps its own B&W palette.
//

import SwiftUI

/// Semantic theme tokens for the post-onboarding app.
/// Maps to prototype's `SP` object in tokens.jsx 1:1.
enum AppTheme {
    enum Surface {
        static let background = Color.appSurface         // navy default
        static let card       = Color.appSurfaceLow      // card
        static let raised     = Color.appSurfaceRaised   // raised card
        static let selected   = Color.appSurfaceHigh     // selected state
        static let stillness  = Color.appMidnight        // Stillness tab deepest
    }

    enum Ink {
        static let primary = Color.appCream
        static let soft    = Color.appInkSoft
        static let muted   = Color.appInkMuted
        static let faint   = Color.appInkFaint
        static let ghost   = Color.appInkGhost
    }

    enum Accent {
        static let primary     = Color.appGold
        static let primaryDeep = Color.appGoldDeep
        static let primaryTint = Color.appGoldTint
        static let onPrimary   = Color.appOnGold     // dark text on gold pill
        static let secondary   = Color.appRiver      // river blue accents
    }

    enum Radii {
        static let chip: CGFloat = 14
        static let card: CGFloat = 18
        static let hero: CGFloat = 22
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40
        static let hero: CGFloat = 64
    }

    enum Shadow {
        /// shadowSoft · ambient lift for card on surface
        static let soft = (color: Color.black.opacity(0.35), radius: 32.0, x: 0.0, y: 8.0)
        /// shadowCard · default card lift
        static let card = (color: Color.black.opacity(0.22), radius: 18.0, x: 0.0, y: 2.0)
        /// shadowFloat · bottom sheet / modal
        static let float = (color: Color.black.opacity(0.45), radius: 40.0, x: 0.0, y: 10.0)
    }
}

/// Background style enum · used by post-onboarding surfaces to pick tone
enum AppBackgroundStyle {
    case day            // standard navy surface · Home · Path · Journey
    case night          // deeper midnight · Stillness
    case gradientCalm   // soft navy gradient · Onboarding-to-Home transition
    case gradientDepth  // deeper gradient · Session
}

/// Reusable background view · wraps AppTheme surface tokens
struct AppBackground: View {
    let style: AppBackgroundStyle

    var body: some View {
        backgroundView.ignoresSafeArea()
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .day:
            AppTheme.Surface.background

        case .night:
            AppTheme.Surface.stillness

        case .gradientCalm:
            LinearGradient(
                colors: [AppTheme.Accent.secondary.opacity(0.25), AppTheme.Surface.background],
                startPoint: .top,
                endPoint: .bottom
            )

        case .gradientDepth:
            LinearGradient(
                colors: [AppTheme.Surface.selected, AppTheme.Surface.stillness],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
