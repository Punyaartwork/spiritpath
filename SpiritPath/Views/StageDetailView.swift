//
//  StageDetailView.swift
//  SpiritPath
//
//  Phase 2.2 · port of prototype src/screen-teaching.jsx · 3-mode tab interface.
//  Modes: listen · understand · reflect · maps to V9 teaching_units.mode column.
//
//  Cross-platform locked with Android e1157b1 (Wave 23).
//
//  Subscription gate: stageIndex >= 2 && !hasActiveSubscription → PaywallStubView.
//
//  M14 second-fire (R28 line 28):
//    - JourneyView fires stage_opened with mode_first_opened="browse" on stage card tap.
//    - StageDetailView fires stage_opened AGAIN with the actual default mode ("listen")
//      on first composition. Subsequent tab switches do NOT fire.
//    - Navigating away + back creates a new view model = new fire (session granularity).
//

import SwiftUI
import Combine

// MARK: · Param wrapper · used by RootTabView fullScreenCover

struct StageDetailParams: Identifiable, Equatable {
    let lineageId: String
    let stageIndex: Int
    let isCurrentStage: Bool
    var id: String { "\(lineageId)_\(stageIndex)" }
}

// MARK: · ViewModel

@MainActor
final class StageDetailViewModel: ObservableObject {

    enum Mode: String, CaseIterable, Identifiable {
        case listen, understand, reflect
        var id: String { rawValue }
        var label: String { rawValue }
    }

    enum LoadState {
        case loading
        case loaded(
            listen: [TeachingUnitRow<ListenBody>],
            understand: [TeachingUnitRow<UnderstandBody>],
            reflect: [TeachingUnitRow<ReflectBody>],
            quote: TeacherQuoteRow?
        )
        case error(String)
    }

    @Published var state: LoadState = .loading
    @Published var selectedMode: Mode = .listen
    @Published var hasActiveSubscription: Bool = false
    @Published var subscriptionResolved: Bool = false

    private var didFireSecondFire = false

    let params: StageDetailParams

    init(params: StageDetailParams) {
        self.params = params
    }

    func bootstrap() async {
        let active = await SubscriptionRepository.shared.hasActiveSubscription()
        hasActiveSubscription = active
        subscriptionResolved = true

        guard active || params.stageIndex == 1 else {
            // Stage gated · don't fetch content · paywall renders.
            return
        }

        state = .loading
        async let listen = ContentRepository.shared.fetchListenUnitsForStage(
            lineageId: params.lineageId,
            stageIndex: params.stageIndex
        )
        async let understand = ContentRepository.shared.fetchUnderstandUnitsForStage(
            lineageId: params.lineageId,
            stageIndex: params.stageIndex
        )
        async let reflect = ContentRepository.shared.fetchReflectUnitsForStage(
            lineageId: params.lineageId,
            stageIndex: params.stageIndex
        )
        async let quote = ContentRepository.shared.fetchTeacherQuoteForStage(
            lineageId: params.lineageId,
            stageIndex: params.stageIndex
        )

        do {
            let l = try await listen
            let u = try await understand
            let r = try await reflect
            let q = (try? await quote) ?? nil
            state = .loaded(listen: l, understand: u, reflect: r, quote: q)
        } catch {
            state = .error(error.localizedDescription)
        }

        fireSecondFireOnce()
    }

    /// M14 second-fire · fires once on initial composition with the default mode.
    /// Tab switches afterwards do NOT fire (cohort attribution rule).
    private func fireSecondFireOnce() {
        guard !didFireSecondFire else { return }
        didFireSecondFire = true
        Analytics.track(.stageOpened(
            lineageId: params.lineageId,
            stageIndex: params.stageIndex,
            modeFirstOpened: selectedMode.rawValue,
            isCurrentStage: params.isCurrentStage
        ))
    }

    func onTabPicked(_ mode: Mode) {
        // No event fires on subsequent picks · selectedMode just updates.
        selectedMode = mode
    }
}

// MARK: · View

struct StageDetailView: View {
    @StateObject private var viewModel: StageDetailViewModel
    let onDismiss: () -> Void

    init(params: StageDetailParams, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: StageDetailViewModel(params: params))
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            AppBackground(style: .day)
            content
        }
        .task { await viewModel.bootstrap() }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.subscriptionResolved {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.Accent.primary)
        } else if !viewModel.hasActiveSubscription && viewModel.params.stageIndex >= 2 {
            PaywallStubView(
                stageIndex: viewModel.params.stageIndex,
                onDismiss: onDismiss
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    titleBlock
                    modeTabs
                    modeBody
                    Color.clear.frame(height: 40)
                }
            }
        }
    }

    // MARK: · Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Journey")
                        .font(.custom("Manrope", size: 13))
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.Ink.soft)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Teaching")
                .font(.custom("DMSerifDisplay-Italic", size: 16))
                .foregroundStyle(AppTheme.Ink.primary)

            Spacer()

            // Right-side bookmark glyph · placeholder · Phase 3 favorites.
            Image(systemName: "star")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.Ink.soft)
                .padding(.trailing, 6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    // MARK: · Title block

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "Stage \(stageDisplayNumber)", color: AppTheme.Accent.primary)
            Text(stageTitle)
                .font(.custom("DMSerifDisplay-Regular", size: 32))
                .foregroundStyle(AppTheme.Ink.primary)
            if let summary = stageSummary {
                Text(summary)
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(AppTheme.Ink.soft)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private var stageDisplayNumber: String {
        String(format: "%02d", viewModel.params.stageIndex)
    }

    private var stageTitle: String {
        // Phase 2.2 · use stage title from V9 if available · fallback to canonical title.
        let titles = ["The Outer Path", "The Quiet Ground", "The Inner Forest", "The Silent Temple", "Open Awareness"]
        let idx = viewModel.params.stageIndex - 1
        return (idx >= 0 && idx < titles.count) ? titles[idx] : "Stage"
    }

    /// Per-stage summary line · Phase 2.2 falls back to canonical copy until stage_summary
    /// is queried directly from the stages row.
    private var stageSummary: String? {
        switch viewModel.params.stageIndex {
        case 1: return "Begin where the body is. The first walk is to leave the house — to step out of self into noticing."
        case 2: return "Moments of stillness begin to appear. Notice them without grasping."
        case 3: return "Attention softens. The mind stops pushing, and begins to listen."
        case 4: return "The mind rests, clear and unhurried. The temple is the body grown quiet."
        case 5: return "No effort. Just being. The path is not elsewhere."
        default: return nil
        }
    }

    // MARK: · Mode tabs · 3-segment pill

    private var modeTabs: some View {
        HStack(spacing: 4) {
            ForEach(StageDetailViewModel.Mode.allCases) { mode in
                tabButton(mode)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Surface.card)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private func tabButton(_ mode: StageDetailViewModel.Mode) -> some View {
        let active = viewModel.selectedMode == mode
        return Button {
            viewModel.onTabPicked(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tabIcon(mode))
                    .font(.system(size: 16))
                    .foregroundStyle(active ? AppTheme.Accent.primary : AppTheme.Ink.muted)
                Text(mode.label)
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(active ? .bold : .medium)
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(active ? AppTheme.Accent.primary : AppTheme.Ink.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? AppTheme.Surface.selected : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        active ? AppTheme.Accent.primary.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func tabIcon(_ mode: StageDetailViewModel.Mode) -> String {
        switch mode {
        case .listen:     return "headphones"
        case .understand: return "circle.dashed.inset.filled"
        case .reflect:    return "location.north.line"
        }
    }

    // MARK: · Mode bodies

    @ViewBuilder
    private var modeBody: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppTheme.Accent.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        case .error(let msg):
            Text("Could not load · \(msg)")
                .font(.custom("Manrope", size: 12))
                .foregroundStyle(AppTheme.Ink.muted)
                .padding(.horizontal, 22)
        case .loaded(let listen, let understand, let reflect, let quote):
            switch viewModel.selectedMode {
            case .listen:
                if let unit = listen.first {
                    ListenModeView(unit: unit)
                } else {
                    unavailableNote
                }
            case .understand:
                if let unit = understand.first {
                    UnderstandModeView(unit: unit, quote: quote)
                } else {
                    unavailableNote
                }
            case .reflect:
                if let unit = reflect.first {
                    ReflectModeView(unit: unit)
                } else {
                    unavailableNote
                }
            }
        }
    }

    private var unavailableNote: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf")
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.Ink.muted)
            Text("This teaching is not yet available.")
                .font(.custom("DMSerifDisplay-Italic", size: 14))
                .foregroundStyle(AppTheme.Ink.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: · Listen mode

private struct ListenModeView: View {
    let unit: TeachingUnitRow<ListenBody>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
            meta
            transport
            chapters
        }
    }

    private var cover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#1e3a6f"), Color(hex: "#0a1628")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            // Simple moon glyph · stand-in for prototype's PodcastArt SVG (Phase 3 polish).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "#fef4d6"), AppTheme.Accent.primary, AppTheme.Accent.primaryDeep],
                        center: .center,
                        startRadius: 0,
                        endRadius: 55
                    )
                )
                .frame(width: 110, height: 110)
                .shadow(color: AppTheme.Accent.primary.opacity(0.4), radius: 30)
        }
        .frame(maxWidth: 280)
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private var meta: some View {
        VStack(spacing: 6) {
            Text("EPISODE \(unit.body.episode)")
                .font(.custom("Manrope", size: 10))
                .fontWeight(.semibold)
                .tracking(2.0)
                .foregroundStyle(AppTheme.Accent.primary)
            Text(unit.title)
                .font(.custom("DMSerifDisplay-Italic", size: 20))
                .foregroundStyle(AppTheme.Ink.primary)
                .multilineTextAlignment(.center)
            Text("Narrated by \(unit.body.narrator)")
                .font(.custom("Manrope", size: 12))
                .foregroundStyle(AppTheme.Ink.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private var transport: some View {
        HStack(spacing: 30) {
            transportButton(systemImage: "backward.end")
            transportButton(systemImage: "gobackward.15", size: 48)
            playButton
            transportButton(systemImage: "goforward.15", size: 48)
            transportButton(systemImage: "speedometer")
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private func transportButton(systemImage: String, size: CGFloat = 40) -> some View {
        ZStack {
            Circle()
                .fill(AppTheme.Ink.primary.opacity(0.06))
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                .frame(width: size, height: size)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(AppTheme.Ink.soft)
        }
    }

    private var playButton: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.Accent.primaryTint, AppTheme.Accent.primary, AppTheme.Accent.primaryDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: AppTheme.Accent.primary.opacity(0.35), radius: 18, y: 6)
            Image(systemName: "play.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppTheme.Accent.onPrimary)
        }
    }

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Chapters")
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            AtmCard(tone: .low, padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(unit.body.chapters.enumerated()), id: \.element.id) { idx, ch in
                        if idx > 0 {
                            Rectangle()
                                .fill(AppTheme.Ink.ghost)
                                .frame(height: 1)
                        }
                        chapterRow(ch)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private func chapterRow(_ ch: ListenChapter) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(ch.t)
                .font(.custom("Manrope", size: 11))
                .tracking(1.4)
                .foregroundStyle(AppTheme.Accent.primary)
                .frame(width: 50, alignment: .leading)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(ch.name)
                    .font(.custom("DMSerifDisplay-Italic", size: 14))
                    .foregroundStyle(AppTheme.Ink.primary)
                Text(ch.note)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .lineSpacing(2)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.Accent.primary.opacity(0.12))
                    .frame(width: 28, height: 28)
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: · Understand mode

private struct UnderstandModeView: View {
    let unit: TeachingUnitRow<UnderstandBody>
    let quote: TeacherQuoteRow?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mindModelCard
            conceptsHeader
            conceptCards
            comparisonCard
            quoteFooter
        }
    }

    private var mindModelCard: some View {
        AtmCard(tone: .low, padding: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "The mind in motion")
                Text(unit.body.modelTitle)
                    .font(.custom("DMSerifDisplay-Italic", size: 17))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .lineSpacing(4)
                    .padding(.top, 4)
                LayeredCircles(layers: unit.body.layers, coreLabel: unit.body.coreLabel)
                    .frame(height: 240)
                    .padding(.top, 14)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private var conceptsHeader: some View {
        Eyebrow(text: "Three markers")
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
    }

    private var conceptCards: some View {
        VStack(spacing: 10) {
            ForEach(Array(unit.body.concepts.enumerated()), id: \.element.id) { idx, c in
                AtmCard(tone: .low, padding: 20) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.Accent.primary.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Text("\(idx + 1)")
                                .font(.custom("DMSerifDisplay-Italic", size: 22))
                                .foregroundStyle(AppTheme.Accent.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.term)
                                .font(.custom("DMSerifDisplay-Italic", size: 17))
                                .foregroundStyle(AppTheme.Ink.primary)
                            Text(c.romanized)
                                .font(.custom("Manrope", size: 10))
                                .fontWeight(.semibold)
                                .tracking(2.0)
                                .foregroundStyle(AppTheme.Accent.primary)
                                .padding(.top, 2)
                            Text(c.note)
                                .font(.custom("Manrope", size: 13))
                                .foregroundStyle(AppTheme.Ink.soft)
                                .lineSpacing(3)
                                .padding(.top, 8)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private var comparisonCard: some View {
        AtmCard(tone: .low, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Attention pattern")
                ForEach(unit.body.comparison) { row in
                    VStack(spacing: 6) {
                        HStack {
                            Text(row.label)
                                .font(.custom("Manrope", size: 12))
                                .foregroundStyle(AppTheme.Ink.soft)
                            Spacer()
                            Text("\(Int(row.v * 100))%")
                                .font(.custom("Manrope", size: 11))
                                .fontWeight(.semibold)
                                .tracking(1.0)
                                .foregroundStyle(AppTheme.Accent.primary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.Ink.ghost)
                                    .frame(height: 6)
                                Capsule()
                                    .fill(AppTheme.Accent.primary)
                                    .frame(width: proxy.size.width * row.v, height: 6)
                                    .shadow(color: AppTheme.Accent.primary.opacity(0.4), radius: 4)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var quoteFooter: some View {
        if let quote {
            VStack(spacing: 10) {
                Text("\u{201C}\(quote.englishText)\u{201D}")
                    .font(.custom("DMSerifDisplay-Italic", size: 16))
                    .foregroundStyle(AppTheme.Ink.soft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                if let source = quote.sourceRef {
                    Text("— \(source)")
                        .font(.custom("Manrope", size: 10))
                        .tracking(2.0)
                        .foregroundStyle(AppTheme.Ink.muted)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 36)
        }
    }
}

private struct LayeredCircles: View {
    let layers: [UnderstandLayer]
    let coreLabel: String

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let cx = w / 2
            let cy = h / 2
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Accent.primary.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .position(x: cx, y: cy)

                ForEach(Array(layers.enumerated()), id: \.element.id) { idx, layer in
                    let r: CGFloat = 110 - CGFloat(idx) * 26
                    let isInnermost = idx == layers.count - 1
                    Circle()
                        .strokeBorder(
                            AppTheme.Ink.ghost,
                            style: StrokeStyle(
                                lineWidth: 1,
                                dash: isInnermost ? [] : [3, 4]
                            )
                        )
                        .frame(width: r * 2, height: r * 2)
                        .position(x: cx, y: cy)
                    Text(layer.label.uppercased())
                        .font(.custom("Manrope", size: 9))
                        .fontWeight(.semibold)
                        .tracking(1.5)
                        .foregroundStyle(AppTheme.Ink.muted)
                        .position(x: cx, y: cy - r + 14)
                }

                Circle()
                    .fill(AppTheme.Accent.primary.opacity(0.25))
                    .frame(width: 44, height: 44)
                    .position(x: cx, y: cy)
                Circle()
                    .fill(AppTheme.Accent.primary)
                    .frame(width: 28, height: 28)
                    .position(x: cx, y: cy)
                Text(coreLabel)
                    .font(.custom("DMSerifDisplay-Italic", size: 13))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .position(x: cx, y: cy + 40)
            }
        }
    }
}

// MARK: · Reflect mode

private struct ReflectModeView: View {
    let unit: TeachingUnitRow<ReflectBody>

    @State private var idx: Int = 0
    @State private var answers: [Int: Int] = [:]   // question idx → choice value

    private var questions: [ReflectQuestion] { unit.body.questions }
    private var done: Bool { idx >= questions.count }

    var body: some View {
        if done {
            ResultView(
                bands: unit.body.bands,
                questions: questions,
                answers: answers,
                onRestart: {
                    idx = 0
                    answers = [:]
                }
            )
        } else {
            questionView(questions[idx])
        }
    }

    private func questionView(_ q: ReflectQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            progress
            VStack(alignment: .leading, spacing: 10) {
                Text(q.prompt)
                    .font(.custom("DMSerifDisplay-Italic", size: 24))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .lineSpacing(4)
                if let sub = q.sub, !sub.isEmpty {
                    Text(sub)
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(AppTheme.Ink.muted)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)

            VStack(spacing: 10) {
                ForEach(q.choices) { choice in
                    choiceRow(choice)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)

            HStack {
                Text("RARELY")
                Spacer()
                Text("OFTEN")
            }
            .font(.custom("Manrope", size: 10))
            .tracking(1.4)
            .foregroundStyle(AppTheme.Ink.muted)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: "Question \(idx + 1) of \(questions.count)")
                Spacer()
                Text("~2 min")
                    .font(.custom("Manrope", size: 11))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            HStack(spacing: 4) {
                ForEach(0..<questions.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= idx ? AppTheme.Accent.primary : AppTheme.Ink.ghost)
                        .frame(height: 3)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    private func choiceRow(_ choice: ReflectChoice) -> some View {
        let selected = answers[idx] == choice.v
        return Button {
            answers[idx] = choice.v
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                idx += 1
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selected ? AppTheme.Accent.primary : AppTheme.Ink.faint,
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    if selected {
                        Circle()
                            .fill(AppTheme.Accent.primary)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(choice.label)
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? AppTheme.Surface.selected : AppTheme.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        selected ? AppTheme.Accent.primary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ResultView: View {
    let bands: [ReflectBand]
    let questions: [ReflectQuestion]
    let answers: [Int: Int]
    let onRestart: () -> Void

    private var pct: Double {
        let total = answers.values.reduce(0, +)
        let max = questions.count * 4
        return max > 0 ? Double(total) / Double(max) : 0
    }

    private var band: ReflectBand? {
        guard !bands.isEmpty else { return nil }
        if pct < 0.34 { return bands[0] }
        if pct < 0.67 { return bands.indices.contains(1) ? bands[1] : bands[0] }
        return bands.indices.contains(2) ? bands[2] : bands.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ring
            if let b = band {
                bandBlock(b)
                suggestionCard(b)
            }
            answerSummary
            restartButton
        }
    }

    private var ring: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(AppTheme.Ink.ghost, lineWidth: 8)
                    .frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(AppTheme.Accent.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppTheme.Accent.primary.opacity(0.7), radius: 6)
                VStack(spacing: 6) {
                    Text("YOUR PRESENCE")
                        .font(.custom("Manrope", size: 10))
                        .fontWeight(.semibold)
                        .tracking(2.0)
                        .foregroundStyle(AppTheme.Ink.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(Int(pct * 100))")
                            .font(.custom("DMSerifDisplay-Regular", size: 56))
                            .foregroundStyle(AppTheme.Accent.primary)
                        Text("%")
                            .font(.custom("DMSerifDisplay-Regular", size: 22))
                            .foregroundStyle(AppTheme.Ink.muted)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private func bandBlock(_ b: ReflectBand) -> some View {
        VStack(spacing: 10) {
            Text(b.label)
                .font(.custom("Manrope", size: 10))
                .fontWeight(.bold)
                .tracking(2.5)
                .foregroundStyle(AppTheme.Accent.primary)
            Text(b.title)
                .font(.custom("DMSerifDisplay-Regular", size: 24))
                .foregroundStyle(AppTheme.Ink.primary)
                .multilineTextAlignment(.center)
            Text(b.note)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(AppTheme.Ink.soft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func suggestionCard(_ b: ReflectBand) -> some View {
        AtmCard(tone: .high, padding: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(text: "A suggestion", color: AppTheme.Accent.primary)
                Text(b.suggestion)
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .lineSpacing(4)
                Button {
                    // Phase 2.7 · deep-link to Practice with prefilled prefs.
                } label: {
                    Text("Begin that walk")
                        .font(.custom("Manrope", size: 13))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Accent.onPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(AppTheme.Accent.primary)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private var answerSummary: some View {
        AtmCard(tone: .low, padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Your answers")
                ForEach(Array(questions.enumerated()), id: \.element.id) { i, q in
                    let v = answers[i] ?? 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(q.prompt)
                                .font(.custom("Manrope", size: 12))
                                .foregroundStyle(AppTheme.Ink.soft)
                                .lineSpacing(2)
                            Spacer()
                            Text("\(v)/4")
                                .font(.custom("Manrope", size: 10))
                                .fontWeight(.bold)
                                .tracking(1.5)
                                .foregroundStyle(AppTheme.Accent.primary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.Ink.ghost).frame(height: 3)
                                Capsule().fill(AppTheme.Accent.primary)
                                    .frame(width: proxy.size.width * (Double(v) / 4), height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 22)
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Text("REFLECT AGAIN")
                .font(.custom("Manrope", size: 11))
                .fontWeight(.semibold)
                .tracking(1.8)
                .foregroundStyle(AppTheme.Ink.soft)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }
}

#Preview {
    StageDetailView(
        params: StageDetailParams(lineageId: "mun", stageIndex: 1, isCurrentStage: true),
        onDismiss: {}
    )
}
