//
//  SessionView.swift
//  SpiritPath
//
//  Phase 1.3 · active walking-session screen · port of prototype screen-session.jsx.
//  Elapsed timer · 4-1-6-1 breath cycle · 3 concentric ripple rings scaled to breath ·
//  walker icon · phrase rotation every 30s · pause / End Session · silent-haptic pulse.
//
//  Mixpanel · fires session_started on .onAppear · session_ended on end (natural or
//  user_abort) · session_uuid carried via @Binding SessionContext so ReflectionView
//  emits reflection_submitted with the SAME uuid · funnel match in Live View.
//

import SwiftUI

struct SessionView: View {
    @Binding var context: SessionContext?
    let onEnd: () -> Void

    // MARK: · timer + state
    @State private var elapsed: Int = 0
    @State private var paused: Bool = false
    @State private var phase: BreathPhase = .inhale
    @State private var phraseIdx: Int = 0
    @State private var breathTask: Task<Void, Never>?
    @State private var phraseTask: Task<Void, Never>?
    @State private var didFireStart = false
    @State private var didFireEnd = false

    // Copy locked from prototype · do not paraphrase
    private let phrases = [
        "Walk gently. Let your breath lead.",
        "Each step is an arrival.",
        "Notice what the ground gives you.",
        "You are already here."
    ]

    private enum BreathPhase: String {
        case inhale, hold, exhale, rest

        var eyebrow: String {
            switch self {
            case .inhale: return "Breathe in"
            case .hold:   return "Hold"
            case .exhale: return "Breathe out"
            case .rest:   return "Rest"
            }
        }

        var scale: CGFloat {
            switch self {
            case .inhale: return 1.12
            case .exhale: return 0.88
            case .hold, .rest: return 1.0
            }
        }

        var opacityMul: Double {
            switch self {
            case .inhale: return 0.9
            case .exhale: return 0.5
            case .hold, .rest: return 0.7
            }
        }

        var durationMs: UInt64 {
            switch self {
            case .inhale: return 4_000
            case .hold:   return 1_000
            case .exhale: return 6_000
            case .rest:   return 1_000
            }
        }
    }

    private var targetSec: Int { context?.targetSec ?? 1800 }
    private var progress: Double { min(1.0, Double(elapsed) / Double(max(targetSec, 1))) }
    private var targetMins: Int { targetSec / 60 }

    private var mmss: (mm: String, ss: String) {
        let mm = String(format: "%02d", elapsed / 60)
        let ss = String(format: "%02d", elapsed % 60)
        return (mm, ss)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            breathStage
            phraseBlock
            breathPrompt
            timerBlock
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: onAppearStart)
        .onDisappear(perform: stopTimers)
    }

    // MARK: · header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text("Session")
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: · breath ripples + walker icon

    private var breathStage: some View {
        ZStack {
            ForEach(Array([1.0, 0.82, 0.62].enumerated()), id: \.offset) { idx, s in
                Circle()
                    .strokeBorder(AppTheme.Accent.primary, lineWidth: 1)
                    .frame(
                        width: 280 * s * phase.scale,
                        height: 280 * s * phase.scale
                    )
                    .opacity((0.2 - Double(idx) * 0.05) * phase.opacityMul)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.Accent.primary.opacity(0.13), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 45 * phase.scale
                    )
                )
                .frame(width: 90 * phase.scale, height: 90 * phase.scale)

            VStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(AppTheme.Accent.primary)
                Rectangle()
                    .fill(AppTheme.Accent.primary.opacity(0.6))
                    .frame(width: 40, height: 1.5)
                    .padding(.top, 4)
            }
        }
        .frame(width: 280, height: 280)
        .animation(.easeInOut(duration: 4.0), value: phase)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: · phrase

    private var phraseBlock: some View {
        Text(phrases[phraseIdx])
            .font(.custom("DMSerifDisplay-Italic", size: 26))
            .foregroundStyle(AppTheme.Ink.primary)
            .multilineTextAlignment(.center)
            .frame(minHeight: 90)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .animation(.easeInOut(duration: 0.8), value: phraseIdx)
    }

    // MARK: · breath prompt + dots

    private var breathPrompt: some View {
        VStack(spacing: 8) {
            Eyebrow(text: phase.eyebrow)
            HStack(spacing: 4) {
                ForEach([BreathPhase.inhale, .hold, .exhale, .rest], id: \.rawValue) { p in
                    Capsule()
                        .fill(p == phase ? AppTheme.Accent.primary : AppTheme.Ink.faint)
                        .frame(width: p == phase ? 10 : 4, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
        }
        .padding(.top, 18)
    }

    // MARK: · timer

    private var timerBlock: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(mmss.mm)
                    .font(.custom("DMSerifDisplay-Regular", size: 36))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .tracking(2)
                Text(":")
                    .font(.custom("DMSerifDisplay-Regular", size: 36))
                    .foregroundStyle(AppTheme.Ink.faint)
                Text(mmss.ss)
                    .font(.custom("DMSerifDisplay-Regular", size: 36))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .tracking(2)
                Text("/ \(targetMins):00")
                    .font(.custom("Manrope", size: 12))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .tracking(1)
                    .padding(.leading, 8)
            }
            SacredLine(progress: progress, color: AppTheme.Accent.primary)
                .frame(width: UIScreen.main.bounds.width * 0.8)
        }
        .padding(.top, 32)
    }

    // MARK: · footer · haptic + controls

    private var footer: some View {
        VStack(spacing: 14) {
            hapticPill
            HStack(spacing: 10) {
                Button(action: togglePause) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Surface.background.opacity(0.4))
                            .overlay(
                                Circle()
                                    .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppTheme.Accent.primary)
                    }
                }
                .buttonStyle(.plain)

                GhostButton(title: "End Session", action: { endSession() })
            }
        }
        .padding(.bottom, 40)
    }

    private var hapticPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(AppTheme.Accent.primary)
                .frame(width: 6, height: 6)
                .shadow(color: AppTheme.Accent.primary.opacity(0.53), radius: 4)
                .opacity(paused ? 0.3 : 1.0)
                .animation(
                    paused
                        ? .default
                        : .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: paused
                )
            Text("Silent Haptic Feedback Active")
                .font(.custom("Manrope", size: 11))
                .fontWeight(.semibold)
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Ink.muted)
        }
    }

    // MARK: · lifecycle

    private func onAppearStart() {
        // Idempotent · guard replays if view re-appears.
        fireStartedOnce()
        startBreathLoop()
        startPhraseRotation()
        // Elapsed counter · SwiftUI .timer via Task to respect pause
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                if !paused { elapsed += 1 }
                // Natural end · target reached
                if elapsed >= targetSec, !didFireEnd {
                    await MainActor.run { endSession(natural: true) }
                    break
                }
            }
        }
    }

    private func togglePause() {
        paused.toggle()
    }

    private func startBreathLoop() {
        breathTask?.cancel()
        breathTask = Task { @MainActor in
            let cycle: [BreathPhase] = [.inhale, .hold, .exhale, .rest]
            var i = 0
            while !Task.isCancelled {
                if !paused {
                    phase = cycle[i]
                    try? await Task.sleep(nanoseconds: cycle[i].durationMs * 1_000_000)
                    i = (i + 1) % cycle.count
                } else {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }
            }
        }
    }

    private func startPhraseRotation() {
        phraseTask?.cancel()
        phraseTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { break }
                phraseIdx = (phraseIdx + 1) % phrases.count
            }
        }
    }

    private func stopTimers() {
        breathTask?.cancel()
        phraseTask?.cancel()
        breathTask = nil
        phraseTask = nil
    }

    // MARK: · Mixpanel

    private func fireStartedOnce() {
        guard !didFireStart, let ctx = context else { return }
        didFireStart = true
        Analytics.track(.sessionStarted(
            sessionUuid: ctx.uuid,
            sessionType: ctx.sessionType,
            lineageId: ctx.lineageId,
            stageIndexAtTime: ctx.stageIndex,
            durationTargetSec: ctx.targetSec,
            place: ctx.place,
            ground: ctx.ground,
            paceMode: ctx.paceMode
        ))
    }

    private func endSession(natural: Bool = false) {
        guard !didFireEnd else { return }
        didFireEnd = true

        let completed = natural
        let reason = natural ? "natural" : "user_abort"

        if var ctx = context {
            ctx.elapsedSec = elapsed
            ctx.endedAt = Date()
            ctx.endedReason = reason
            ctx.completed = completed
            context = ctx

            Analytics.track(.sessionEnded(
                sessionUuid: ctx.uuid,
                sessionType: ctx.sessionType,
                lineageId: ctx.lineageId,
                stageIndexAtTime: ctx.stageIndex,
                durationTargetSec: ctx.targetSec,
                durationActualSec: elapsed,
                mindfulSteps: ctx.mindfulSteps,
                totalSteps: ctx.totalSteps,
                momentsOfReturn: ctx.momentsOfReturn,
                completed: completed,
                endedReason: reason
            ))
        }

        stopTimers()
        onEnd()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var ctx: SessionContext? = SessionContext(
            uuid: UUID().uuidString,
            sessionType: "walking",
            lineageId: "sodh",
            stageIndex: 1,
            targetSec: 1800,
            place: "forest",
            ground: "grass",
            paceMode: "forest"
        )
        var body: some View {
            ZStack {
                AppBackground(style: .gradientDepth)
                SessionView(context: $ctx, onEnd: {})
            }
        }
    }
    return PreviewWrapper()
}
