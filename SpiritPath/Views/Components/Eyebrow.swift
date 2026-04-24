//
//  Eyebrow.swift
//  SpiritPath
//
//  Uppercase micro-label · Manrope 10pt semibold · letter-spacing 1.8.
//  Mirrors prototype <Eyebrow> helper · color overrides for on-gold contexts.
//

import SwiftUI

struct Eyebrow: View {
    let text: String
    let color: Color

    init(text: String, color: Color = AppTheme.Ink.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.custom("Manrope", size: 10))
            .fontWeight(.semibold)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Eyebrow(text: "Moments in motion")
        Eyebrow(text: "Today's mindful steps", color: AppTheme.Accent.onPrimary.opacity(0.7))
        Eyebrow(text: "Days Walked")
    }
    .padding()
    .background(AppTheme.Surface.background)
}
