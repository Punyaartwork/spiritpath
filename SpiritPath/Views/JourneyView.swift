//
//  JourneyView.swift
//  SpiritPath
//
//  Phase 1.1 placeholder · Phase 2.1 will fill 5-stage arc + lineage picker +
//  Steps in Stillness halo + awareness trend.
//
//  Phase 2.6 catchup slice · adds the "Compare lineages" entry-point card so
//  Compare is reachable without the full Phase 2.1 ship.
//

import SwiftUI

struct JourneyView: View {
    var onCompareLineages: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("Journey").appText(.displayLG)
                Text("5-stage arc · lineage · Steps in Stillness").appText(.body)

                CompareLineagesCard(onTap: onCompareLineages)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: · Compare lineages entry-point card

private struct CompareLineagesCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Three paths · one stage at a time", color: AppTheme.Accent.primary)
                Text("Compare lineages")
                    .font(.custom("DMSerifDisplay-Italic", size: 22))
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("How each teacher meets you at the same stage.")
                    .appText(.bodySmall)
                    .foregroundStyle(AppTheme.Ink.soft)
                    .multilineTextAlignment(.leading)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(AppTheme.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .stroke(AppTheme.Accent.primary.opacity(0.33), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens cross-lineage comparison")
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        JourneyView()
    }
}
