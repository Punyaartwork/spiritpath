//
//  Typography.swift
//  SpiritPath
//
//  Unified type system · iOS + Android · master plan §04 Design system
//  Source of truth: /Users/punyapath/Downloads/SpiritPath/src/tokens.jsx
//  Font registration at app launch · see SpiritFonts.registerAll() in SpiritPathApp.swift
//

import SwiftUI

/// Semantic text styles for the post-onboarding SpiritPath app.
///
/// Use `Text(...).appText(.display)` pattern at call sites.
/// DM Serif Display = poetic moments (stage titles, Stillness headings, teacher quotes).
/// Manrope = UI / body / labels.
/// JetBrains Mono = numerals (steps, minutes).
enum AppTextStyle {
    // Display · serif italic · poetic
    case displayXL     // 48 · big metric numbers (Mindful Steps)
    case displayLG     // 34 · greeting · "Evening Stillness."
    case displayMD     // 28 · "Your Sacred Journey" · Stillness headings
    case displaySM     // 20 · stage titles
    case serifCard     // 17 · italic · lineage card names · meditation titles

    // UI · Manrope · sans
    case title         // 22 · section titles
    case body          // 16 · paragraph body
    case bodySmall     // 13 · subtitle under card
    case label         // 14 · button labels
    case caption       // 12 · metadata · timestamps
    case eyebrow       // 10 · uppercase · "WALKING THE PATH OF"

    // Mono · JetBrains · numerals
    case monoNumeral   // 12 · inline stats
}

extension Text {
    /// Apply a semantic text style from the master plan type scale.
    @ViewBuilder
    func appText(_ style: AppTextStyle) -> some View {
        switch style {
        case .displayXL:
            self.font(.custom("DMSerifDisplay-Italic", size: 48))
                .foregroundStyle(Color.spiritCream)

        case .displayLG:
            self.font(.custom("DMSerifDisplay-Regular", size: 34))
                .foregroundStyle(Color.spiritCream)

        case .displayMD:
            self.font(.custom("DMSerifDisplay-Italic", size: 28))
                .foregroundStyle(Color.spiritCream)

        case .displaySM:
            self.font(.custom("DMSerifDisplay-Italic", size: 20))
                .foregroundStyle(Color.spiritCream)

        case .serifCard:
            self.font(.custom("DMSerifDisplay-Italic", size: 17))
                .foregroundStyle(Color.spiritGold)

        case .title:
            self.font(.custom("Manrope", size: 22))
                .fontWeight(.bold)
                .foregroundStyle(Color.spiritCream)

        case .body:
            self.font(.custom("Manrope", size: 16))
                .fontWeight(.regular)
                .foregroundStyle(Color.spiritInkSoft)

        case .bodySmall:
            self.font(.custom("Manrope", size: 13))
                .fontWeight(.regular)
                .foregroundStyle(Color.spiritInkSoft)

        case .label:
            self.font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .foregroundStyle(Color.spiritCream)

        case .caption:
            self.font(.custom("Manrope", size: 12))
                .fontWeight(.regular)
                .foregroundStyle(Color.spiritInkMuted)

        case .eyebrow:
            self.font(.custom("Manrope", size: 10))
                .fontWeight(.semibold)
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.spiritInkMuted)

        case .monoNumeral:
            self.font(.custom("JetBrainsMono-Regular", size: 12))
                .foregroundStyle(Color.spiritCream)
        }
    }
}
