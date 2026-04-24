//
//  AtmCard.swift
//  SpiritPath
//
//  Atmospheric card wrapper · 3 tones matching prototype <AtmCard tone="low|lowest|primary">.
//  low     → Surface.card   (#111D33)  regular card
//  lowest  → Surface.raised (#152544)  elevated
//  primary → Accent.primary (#F0C870)  gold · use OnGold ink inside
//

import SwiftUI

struct AtmCard<Content: View>: View {
    enum Tone {
        case low
        case lowest
        case primary
    }

    let tone: Tone
    let padding: CGFloat
    let content: () -> Content

    init(
        tone: Tone = .low,
        padding: CGFloat = 22,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tone = tone
        self.padding = padding
        self.content = content
    }

    private var fill: Color {
        switch tone {
        case .low:     return AppTheme.Surface.card
        case .lowest:  return AppTheme.Surface.raised
        case .primary: return AppTheme.Accent.primary
        }
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(fill)
            )
    }
}

#Preview {
    VStack(spacing: 12) {
        AtmCard(tone: .lowest) {
            Text("lowest · raised card").appText(.body)
        }
        AtmCard(tone: .low) {
            Text("low · default card").appText(.body)
        }
        AtmCard(tone: .primary) {
            Text("primary · gold card")
                .foregroundStyle(AppTheme.Accent.onPrimary)
        }
    }
    .padding()
    .background(AppTheme.Surface.background)
}
