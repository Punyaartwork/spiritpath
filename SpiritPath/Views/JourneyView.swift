//
//  JourneyView.swift
//  SpiritPath
//
//  Placeholder · Phase 2 fills with 5-stage arc · lineage picker · Compare entry ·
//  Steps in Stillness halo · awareness trend.
//  Port from prototype src/screen-journey.jsx.
//

import SwiftUI

struct JourneyView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Journey").appText(.displayLG)
            Text("5-stage arc · lineage · Steps in Stillness").appText(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        JourneyView()
    }
}
