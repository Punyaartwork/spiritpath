//
//  JourneyView.swift
//  SpiritPath
//
//  Phase 2.1 · port of prototype src/screen-journey.jsx · 7-section dashboard.
//  Sections: header · Steps in Stillness halo · hero · lineage card · compare card ·
//  zigzag stage timeline (1L · 2R · 3L · 4R · 5center) · awareness trend · quote footer.
//
//  Mirrors Android JourneyView.kt (commit b9d9a25 · Wave 22) · cross-platform-locked layout.
//
//  R28 events fired here:
//    - stage_opened   (M14 · Phase 2.1 active · modeFirstOpened="browse" · is_current_stage flag)
//    - lineage_changed(M15 · Phase 2.1 active · only after profile UPDATE succeeds)
//
//  Phase 2.7 will replace currentStage hardcoded 1 with a journey_progress query.
//

import SwiftUI
import Combine
import Supabase

// MARK: · ViewModel

@MainActor
final class JourneyViewModel: ObservableObject {

    enum LoadState: Equatable {
        case loading
        case loaded(stages: [StageRow], mindfulSteps: Int)
        case error(String)
    }

    @Published var state: LoadState = .loading
    @Published var lineageId: String
    @Published var pickerPresented: Bool = false

    /// Phase 2.1 default · journey_progress wiring lands Phase 2.7.
    let currentStage: Int = 1

    init(initialLineageId: String) {
        self.lineageId = initialLineageId
    }

    func load() async {
        state = .loading
        let lineage = lineageId
        async let stages = ContentRepository.shared.fetchStagesForLineage(lineage)
        async let stepsCount: Int = {
            guard let userId = supabase.auth.currentUser?.id.uuidString else { return 0 }
            return await SessionRepository.shared.totalMindfulSteps(userId: userId)
        }()

        do {
            let stageRows = try await stages
            let steps = await stepsCount
            state = .loaded(stages: stageRows, mindfulSteps: steps)
        } catch {
            // Don't block the screen on a fetch failure · show empty stage list and zero steps.
            state = .loaded(stages: [], mindfulSteps: 0)
        }
    }

    /// M14 · fires per stage card tap · modeFirstOpened="browse" before TeachingView refines.
    func onStageOpened(stageIndex: Int) {
        Analytics.track(.stageOpened(
            lineageId: lineageId,
            stageIndex: stageIndex,
            modeFirstOpened: "browse",
            isCurrentStage: stageIndex == currentStage
        ))
    }

    /// M15 · fires only after Supabase UPDATE succeeds.
    /// Same-selection no-ops upstream of this method.
    func onLineageSelected(_ newLineageId: String) async {
        guard newLineageId != lineageId else { return }
        let from = lineageId
        do {
            try await ProfileRepository.shared.updateLineage(newLineageId)
            // Persist locally too · keeps UI consistent if auth not yet wired (Phase 1.7a).
            UserDefaults.standard.set(newLineageId, forKey: "selected_lineage_id")
            Analytics.track(.lineageChanged(
                fromLineageId: from,
                toLineageId: newLineageId,
                currentStage: currentStage
            ))
            lineageId = newLineageId
            await load()
        } catch ProfileRepositoryError.notAuthenticated {
            // Phase 1.7a not wired yet · keep local state in sync, skip the event (no UPDATE happened).
            UserDefaults.standard.set(newLineageId, forKey: "selected_lineage_id")
            lineageId = newLineageId
            await load()
        } catch {
            // Network or other failure · do not fire event, do not change UI state.
        }
    }
}

// MARK: · View

struct JourneyView: View {
    @StateObject private var viewModel: JourneyViewModel
    @AppStorage("selected_lineage_id") private var storedLineageId: String = "sodh"
    @State private var presentedStage: StageDetailParams?

    init(initialLineageId: String? = nil) {
        let initial = initialLineageId
            ?? UserDefaults.standard.string(forKey: "selected_lineage_id")
            ?? "sodh"
        _viewModel = StateObject(wrappedValue: JourneyViewModel(initialLineageId: initial))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                halo
                hero
                lineageCard
                compareCard
                timeline
                awarenessTrendCard
                quoteFooter
                Color.clear.frame(height: 80)   // tab bar spacer
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.pickerPresented) {
            LineagePickerSheet(
                currentLineageId: viewModel.lineageId,
                onSelect: { newId in
                    Task { await viewModel.onLineageSelected(newId) }
                },
                isPresented: $viewModel.pickerPresented
            )
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $presentedStage) { params in
            StageDetailView(params: params, onDismiss: { presentedStage = nil })
        }
    }

    private func openStage(_ stageIndex: Int) {
        viewModel.onStageOpened(stageIndex: stageIndex)
        presentedStage = StageDetailParams(
            lineageId: viewModel.lineageId,
            stageIndex: stageIndex,
            isCurrentStage: stageIndex == viewModel.currentStage
        )
    }

    // MARK: · Sections

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text("Journey")
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            Spacer()
            Image(systemName: "gearshape")
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.Accent.primary)
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    private var halo: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Surface.raised, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 95
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                    )
                    .frame(width: 190, height: 190)

                VStack(spacing: 10) {
                    Eyebrow(text: "Steps in Stillness")
                    Text(haloNumber)
                        .font(.custom("DMSerifDisplay-Regular", size: 44))
                        .foregroundStyle(AppTheme.Accent.primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 6)
    }

    private var haloNumber: String {
        switch viewModel.state {
        case .loaded(_, let steps):
            return steps.formatted()
        default:
            return "—"
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Text("Your Sacred Journey")
                .font(.custom("DMSerifDisplay-Regular", size: 28))
                .foregroundStyle(AppTheme.Ink.primary)
            Text("Every step taken in stillness is a return to your true nature.")
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private var lineageCard: some View {
        Button {
            viewModel.pickerPresented = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Accent.primary.opacity(0.10))
                        .frame(width: 46, height: 46)
                    Circle()
                        .strokeBorder(AppTheme.Accent.primary.opacity(0.33), lineWidth: 1)
                        .frame(width: 46, height: 46)
                    Image(systemName: "tree")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.Accent.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("WALKING THE PATH OF")
                        .font(.custom("Manrope", size: 9))
                        .fontWeight(.semibold)
                        .tracking(2)
                        .foregroundStyle(AppTheme.Ink.muted)
                    Text(currentLineageDisplay.displayName)
                        .font(.custom("DMSerifDisplay-Italic", size: 16))
                        .foregroundStyle(AppTheme.Accent.primary)
                    Text(currentLineageDisplay.style)
                        .font(.custom("Manrope", size: 11))
                        .foregroundStyle(AppTheme.Ink.muted)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Ink.soft)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.Surface.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var currentLineageDisplay: LineagePickerOption {
        LineageDisplay.options.first(where: { $0.id == viewModel.lineageId })
            ?? LineageDisplay.options[0]
    }

    /// Phase 2.1 · placeholder navigation · Phase 2.6 ships Compare lineages screen.
    private var compareCard: some View {
        Button {
            // Phase 2.6 · Compare lineages destination · stub for now (no nav).
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Circle().fill(Color(hex: "#F0C870")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#C8A8F0")).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: "#A8D0A0")).frame(width: 8, height: 8)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("THREE PATHS · ONE STAGE")
                        .font(.custom("Manrope", size: 9))
                        .fontWeight(.semibold)
                        .tracking(1.8)
                        .foregroundStyle(AppTheme.Ink.muted)
                    Text("Compare the lineages")
                        .font(.custom("DMSerifDisplay-Italic", size: 14))
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Ink.soft)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        AppTheme.Ink.ghost,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: · Stage timeline · zigzag (1L · 2R · 3L · 4R · 5 center)

    private var timeline: some View {
        ZStack(alignment: .top) {
            // Vertical hairline · runs through all stage cards
            GeometryReader { proxy in
                Rectangle()
                    .fill(AppTheme.Ink.ghost)
                    .frame(width: 1)
                    .frame(maxWidth: .infinity)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }

            VStack(spacing: 0) {
                ForEach(stagesForTimeline, id: \.stageIndex) { stage in
                    if stage.stageIndex == viewModel.currentStage {
                        currentStageRow(stage)
                    } else {
                        zigzagStageRow(stage)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 14)
    }

    /// Returns the 5 stages for display · falls back to canonical titles if Supabase fetch failed.
    private var stagesForTimeline: [StageRow] {
        switch viewModel.state {
        case .loaded(let stages, _) where !stages.isEmpty:
            return stages
        default:
            return Self.fallbackStages(for: viewModel.lineageId)
        }
    }

    /// Cross-platform locked stage titles · matches prototype STAGE_SUBS keys.
    /// Used when Supabase fetch is in flight or fails · ensures the timeline always renders.
    private static func fallbackStages(for lineageId: String) -> [StageRow] {
        let titles = [
            "The Outer Path",
            "The Quiet Ground",
            "The Inner Forest",
            "The Silent Temple",
            "Open Awareness"
        ]
        return titles.enumerated().map { idx, title in
            StageRow(
                lineageId: lineageId,
                stageIndex: idx + 1,
                title: title,
                subtitle: nil,
                anchorPhrase: nil,
                trapWarning: nil
            )
        }
    }

    private func iconForStage(_ index: Int) -> String {
        switch index {
        case 1: return "figure.walk"
        case 2: return "leaf"
        case 3: return "leaf.fill"
        case 4: return "building.columns"
        case 5: return "sun.max"
        default: return "circle"
        }
    }

    private func currentStageRow(_ stage: StageRow) -> some View {
        Button {
            openStage(stage.stageIndex)
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Accent.primary.opacity(0.13))
                        .frame(width: 70, height: 70)
                    Circle()
                        .fill(AppTheme.Accent.primary)
                        .frame(width: 54, height: 54)
                        .shadow(color: AppTheme.Accent.primary.opacity(0.45), radius: 18)
                    Image(systemName: iconForStage(stage.stageIndex))
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                .padding(.top, 10)

                VStack(spacing: 4) {
                    Text(stage.title)
                        .font(.custom("DMSerifDisplay-Italic", size: 20))
                        .foregroundStyle(AppTheme.Accent.primary)
                    if let subtitle = stage.subtitle {
                        Text(subtitle)
                            .font(.custom("Manrope", size: 12))
                            .italic()
                            .foregroundStyle(AppTheme.Ink.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                Text("Current Presence")
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(.semibold)
                    .tracking(2.0)
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.Accent.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppTheme.Surface.card)
                            .overlay(
                                Capsule()
                                    .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                            )
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func zigzagStageRow(_ stage: StageRow) -> some View {
        let isLeft = stage.stageIndex % 2 == 1
        return Button {
            openStage(stage.stageIndex)
        } label: {
            HStack(alignment: .center, spacing: 0) {
                if isLeft {
                    stageTextBlock(stage, alignment: .trailing)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 14)
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }

                stageMarker(stage)
                    .frame(width: 60)

                if isLeft {
                    Color.clear.frame(maxWidth: .infinity)
                } else {
                    stageTextBlock(stage, alignment: .leading)
                        .frame(maxWidth: .infinity)
                        .padding(.leading, 14)
                }
            }
            .padding(.vertical, 22)
        }
        .buttonStyle(.plain)
    }

    private func stageTextBlock(_ stage: StageRow, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(stage.title)
                .font(.custom("DMSerifDisplay-Italic", size: 17))
                .foregroundStyle(AppTheme.Accent.primary)
            if let subtitle = stage.subtitle {
                Text(subtitle)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                    .lineSpacing(2)
            }
        }
    }

    private func stageMarker(_ stage: StageRow) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.Surface.raised)
                .frame(width: 34, height: 34)
            Circle()
                .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                .frame(width: 34, height: 34)
            Image(systemName: iconForStage(stage.stageIndex))
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(AppTheme.Accent.primary)
        }
    }

    // MARK: · Awareness trend card · 7-day mock · real data Phase 2.7+

    private var awarenessTrendCard: some View {
        AtmCard(tone: .low, padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your awareness is deepening")
                    .font(.custom("DMSerifDisplay-Regular", size: 18))
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("LAST 7 DAYS TREND")
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(AppTheme.Ink.muted)
                trendCurve
                HStack {
                    ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                        Text(d)
                            .font(.custom("Manrope", size: 10))
                            .tracking(1.0)
                            .foregroundStyle(AppTheme.Ink.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var trendCurve: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h: CGFloat = 60
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: h * 0.83))
                p.addCurve(
                    to: CGPoint(x: w * 0.43, y: h * 0.53),
                    control1: CGPoint(x: w * 0.14, y: h * 0.80),
                    control2: CGPoint(x: w * 0.29, y: h * 0.67)
                )
                p.addCurve(
                    to: CGPoint(x: w, y: h * 0.10),
                    control1: CGPoint(x: w * 0.71, y: h * 0.20),
                    control2: CGPoint(x: w * 0.86, y: h * 0.13)
                )
            }
            ZStack {
                path
                    .stroke(AppTheme.Accent.primary, lineWidth: 1.5)
                Path { p in
                    p.addPath(path)
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(AppTheme.Accent.primary.opacity(0.10))
            }
        }
        .frame(height: 60)
    }

    private var quoteFooter: some View {
        Text("\u{201C}The forest is a mirror. What you see is what you are.\u{201D}")
            .font(.custom("DMSerifDisplay-Italic", size: 14))
            .foregroundStyle(AppTheme.Ink.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 14)
            .padding(.bottom, 32)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        JourneyView(initialLineageId: "mun")
    }
}
