//
//  StillnessView.swift
//  SpiritPath
//
//  Placeholder · Phase 2 fills with breathing orb · Night Log entry · sound bath ·
//  quiet session cards.
//  Port from prototype src/screen-stillness.jsx + screen-stillness-subs.jsx.
//  Background: .night (deeper midnight) per tone · set in RootTabView.
//

import SwiftUI

struct StillnessView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Stillness").appText(.displayLG)
            Text("breathing orb · Night Log · sound bath").appText(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .night)
        StillnessView()
    }
}
