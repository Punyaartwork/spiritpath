//
//  StillnessView.swift
//  SpiritPath
//
//  Placeholder · Phase 2 fills with breathing orb · sound bath · quiet session cards.
//  Phase 2.4b · Night Log nav stub wired to .nightlog route via onOpenNightLog.
//  Port from prototype src/screen-stillness.jsx + screen-stillness-subs.jsx.
//  Background: .night (deeper midnight) per tone · set in RootTabView.
//

import SwiftUI

struct StillnessView: View {
    let onOpenNightLog: () -> Void

    init(onOpenNightLog: @escaping () -> Void = {}) {
        self.onOpenNightLog = onOpenNightLog
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            VStack(spacing: AppTheme.Spacing.md) {
                Text("Stillness").appText(.displayLG)
                Text("breathing orb · sound bath").appText(.body)
            }

            Button(action: onOpenNightLog) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppTheme.Accent.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Night log").appText(.label)
                        Text("Before sleep · 3 quiet lines")
                            .appText(.bodySmall)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.Ink.muted)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                        .fill(AppTheme.Surface.card)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .night)
        StillnessView(onOpenNightLog: {})
    }
}
