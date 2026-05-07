//
//  LineageCompareCard.swift
//  SpiritPath
//
//  Phase 2.6 · single lineage card · body swaps by selected lens.
//  Cross-platform parity with Android LineageCompareCard composable.
//

import SwiftUI

struct LineageCompareCard: View {
    let lineage: LineageDisplay
    let stage: StageRow?
    let lens: CompareViewModel.Lens

    private var hue: Color { Color(hex: lineage.accentHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .background(AppTheme.Ink.ghost)
            body(stage: stage)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(AppTheme.Surface.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .stroke(hue.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: · header strip · gradient tint + glyph dot + name + tradition

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(hue)
                .frame(width: 10, height: 10)
                .shadow(color: hue.opacity(0.55), radius: 4, x: 0, y: 0)

            Text(lineage.fullName)
                .font(.custom("DMSerifDisplay-Italic", size: 15))
                .foregroundStyle(AppTheme.Ink.primary)

            Spacer(minLength: 8)

            Eyebrow(text: lineage.tradition)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [hue.opacity(0.13), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: · body · 4 lens variants

    @ViewBuilder
    private func body(stage: StageRow?) -> some View {
        if let stage {
            switch lens {
            case .summary: lensSummary(stage: stage)
            case .image:   lensImage(stage: stage)
            case .candy:   lensCandy(stage: stage)
            case .arc:     lensArc(stage: stage)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Not yet seeded")
                Text("—")
                    .appText(.body)
                    .foregroundStyle(AppTheme.Ink.muted)
            }
        }
    }

    // ── summary · "Entry point" · subtitle in serif italic, preserve \n ──

    private func lensSummary(stage: StageRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Entry point", color: hue)
            Text(stage.subtitle ?? "—")
                .font(.custom("DMSerifDisplay-Italic", size: 16))
                .foregroundStyle(AppTheme.Ink.primary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
    }

    // ── image · "Key image" · 80×80 hue-tinted glyph (real assets deferred) ──

    private func lensImage(stage: StageRow) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [hue.opacity(0.20), hue.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(hue.opacity(0.30), lineWidth: 1)
                    )
                Text(lineage.glyph)
                    .font(.system(size: 40))
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "Key image", color: hue)
                Text(stage.title)
                    .font(.custom("DMSerifDisplay-Italic", size: 16))
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("Asset library lands in a later release.")
                    .appText(.bodySmall)
                    .foregroundStyle(AppTheme.Ink.muted)
            }
        }
    }

    // ── candy · "⚠️ Trap" · trap_warning ──

    private func lensCandy(stage: StageRow) -> some View {
        let warning = stage.trapWarning ?? "—"
        let isNoneStage = warning.lowercased().hasPrefix("none")
        return VStack(alignment: .leading, spacing: 8) {
            Eyebrow(
                text: isNoneStage ? "No warning needed" : "⚠️ The trap at this stage",
                color: hue
            )
            Text(warning)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(AppTheme.Ink.soft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ── arc · "ผู้รู้ / anchor" · anchor_phrase centered gold serif italic ──

    private func lensArc(stage: StageRow) -> some View {
        VStack(alignment: .center, spacing: 10) {
            Eyebrow(text: "Anchor at this stage", color: hue)
            Text(stage.anchorPhrase ?? "—")
                .font(.custom("DMSerifDisplay-Italic", size: 22))
                .foregroundStyle(AppTheme.Accent.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let mock = StageRow(
        lineageId: "mun",
        stageIndex: 1,
        title: "The Outer Path",
        subtitle: "A whole-in-motion,\nnoticing the world",
        keyImageRef: nil,
        anchorPhrase: "Buddho",
        trapWarning: "Austerity as identity — The practices become a badge. The forest becomes a costume."
    )
    ScrollView {
        VStack(spacing: 12) {
            LineageCompareCard(lineage: .mun, stage: mock, lens: .summary)
            LineageCompareCard(lineage: .sodh, stage: mock, lens: .image)
            LineageCompareCard(lineage: .chah, stage: mock, lens: .candy)
            LineageCompareCard(lineage: .mun, stage: mock, lens: .arc)
        }
        .padding(18)
    }
    .background(AppBackground(style: .day))
}
