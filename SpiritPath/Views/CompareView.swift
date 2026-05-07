//
//  CompareView.swift
//  SpiritPath
//
//  Phase 2.6 · cross-lineage stage compare · 4 lenses × 5 stages × 3 lineages.
//  Reachable from JourneyView "Compare lineages" card · reads V9 stages.
//  Tone strings are VERBATIM cross-platform · do not paraphrase.
//
//  Prototype: /Users/punyapath/Downloads/SpiritPath/src/screen-compare.jsx (1-345)
//  Android contract: feature/compare/CompareScreen.kt (Phase 2.6 parallel)
//

import SwiftUI

struct CompareView: View {
    let onBack: () -> Void

    @State private var vm = CompareViewModel()

    var body: some View {
        ZStack {
            AppBackground(style: .day)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar
                    intro
                    stageScrubber
                    lensSwitcher
                    cards
                    footer
                }
                .padding(.bottom, 36)
            }
        }
        .task {
            if case .loading = vm.state {
                await vm.load()
            }
        }
    }

    // MARK: · top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(AppTheme.Surface.card)
                    )
            }
            .accessibilityLabel("Back")

            Text("Compare lineages")
                .font(.custom("DMSerifDisplay-Italic", size: 18))
                .foregroundStyle(AppTheme.Ink.primary)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: · intro card · gold eyebrow · 28pt display · body line

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Three paths · one stage at a time", color: AppTheme.Accent.primary)

            Text("How each teacher would meet you here.")
                .font(.custom("DMSerifDisplay-Italic", size: 28))
                .foregroundStyle(AppTheme.Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Text("The five-stage arc is shared. What changes is the entry point, the image, the tone — and what each teacher names as the trap.")
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.soft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 6)
        .padding(.bottom, 18)
    }

    // MARK: · stage scrubber · 5 buttons · gold-active

    private var stageScrubber: some View {
        VStack(spacing: 14) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { idx in
                    stageChip(idx: idx)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.Surface.card)
            )

            // Stage title display · 20pt serif italic gold centered
            Text(vm.stageTitle())
                .font(.custom("DMSerifDisplay-Italic", size: 20))
                .foregroundStyle(AppTheme.Accent.primary)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func stageChip(idx: Int) -> some View {
        let isActive = idx == vm.stageIndex
        let title = CompareViewModel.canonicalStageTitles[idx - 1]
        let firstWord = title.replacingOccurrences(of: "The ", with: "").split(separator: " ").first.map(String.init) ?? title

        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                vm.stageIndex = idx
            }
        } label: {
            VStack(spacing: 3) {
                Text(String(format: "%02d", idx))
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(.bold)
                    .tracking(1.4)
                    .foregroundStyle(isActive ? AppTheme.Accent.primary : AppTheme.Ink.muted)

                Text(firstWord)
                    .font(.custom("DMSerifDisplay-Italic", size: 10))
                    .foregroundStyle(isActive ? AppTheme.Ink.primary : AppTheme.Ink.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? AppTheme.Surface.selected : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive ? AppTheme.Accent.primary.opacity(0.33) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stage \(idx) · \(title)")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: · lens switcher · 4 chip buttons · gold pill when selected

    private var lensSwitcher: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Lens")

            // Use a flow-ish layout · 4 chips usually fit on one row,
            // but Thai char + emoji can push width · let it wrap naturally.
            HStack(spacing: 6) {
                ForEach(CompareViewModel.Lens.allCases) { l in
                    lensChip(lens: l)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func lensChip(lens: CompareViewModel.Lens) -> some View {
        let isActive = lens == vm.lens
        Button {
            withAnimation(.easeInOut(duration: 0.4)) {
                vm.lens = lens
            }
        } label: {
            Text(lens.label)
                .font(.custom("Manrope", size: 11))
                .fontWeight(.semibold)
                .tracking(0.4)
                .foregroundStyle(isActive ? AppTheme.Accent.onPrimary : AppTheme.Ink.soft)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isActive ? AppTheme.Accent.primary : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(isActive ? Color.clear : AppTheme.Ink.ghost, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lens.label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    // MARK: · 3 lineage cards · stacked vertical

    private var cards: some View {
        VStack(spacing: 12) {
            switch vm.state {
            case .loading:
                ForEach(LineageDisplay.all) { lin in
                    skeletonCard(lineage: lin)
                }
            case .loaded:
                ForEach(LineageDisplay.all) { lin in
                    LineageCompareCard(
                        lineage: lin,
                        stage: vm.currentStageRow(for: lin.id),
                        lens: vm.lens
                    )
                }
            case .error(let msg):
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Could not load lineages", color: AppTheme.Accent.primary)
                    Text(msg)
                        .appText(.bodySmall)
                        .foregroundStyle(AppTheme.Ink.muted)
                    Button("Try again") {
                        Task { await vm.load() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.Accent.primary)
                    .padding(.top, 6)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                        .fill(AppTheme.Surface.card)
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func skeletonCard(lineage: LineageDisplay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: lineage.accentHex).opacity(0.4))
                    .frame(width: 10, height: 10)
                Text(lineage.fullName)
                    .font(.custom("DMSerifDisplay-Italic", size: 15))
                    .foregroundStyle(AppTheme.Ink.muted)
                Spacer()
            }
            Text("Loading…")
                .appText(.bodySmall)
                .foregroundStyle(AppTheme.Ink.muted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(AppTheme.Surface.card)
        )
    }

    // MARK: · shared spine footer · gold-tinted card · italic body

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "The shared ground", color: AppTheme.Accent.primary)
            Text("Five stages. One walk. Three teachers who met their own traps — and pointed at them plainly, so yours would be harder to hide inside.")
                .font(.custom("DMSerifDisplay-Italic", size: 14))
                .foregroundStyle(AppTheme.Ink.soft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.Accent.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.Accent.primary.opacity(0.33), lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }
}

#Preview {
    CompareView(onBack: {})
}
