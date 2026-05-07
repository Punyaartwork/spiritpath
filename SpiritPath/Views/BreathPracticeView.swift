//
//  BreathPracticeView.swift
//  SpiritPath
//
//  Phase 2.4 · port of prototype src/screen-stillness-subs.jsx:30-152.
//  4 · 7 · 8 box breath · 260×260 orb · 1Hz timer · cycle counter.
//
//  Mixpanel:
//    - session_started fires on first Begin tap (NOT on view appear · matches prototype).
//      session_type="breath" · target_sec=0 · place/ground/pace_mode/stage_index OMITTED (M20).
//    - session_ended fires on dismiss with one of:
//        user_complete  · cycleCount >= 3 (M20 lock · ~57s · trivial gate)
//        user_pause     · paused mid-session and never resumed before dismiss (M21)
//        user_abort     · dismissed without completing 3 cycles (M21)
//
//  HealthKit (Section 4.5):
//    - Mindful session WRITE attempted at end · best-effort · stage_index nil · 2-key metadata.
//    - No step query (indoor practice · pedometer doesn't apply · M11 path unchanged).
//    - No HK permission gate (breath does not require step access).
//
//  Tone rule: Ajahn Chah quote in footer is unattributed in UI per prototype line 144-148.
//

import SwiftUI

private enum BreathPhase: String, CaseIterable {
    case inhale, hold, exhale

    var seconds: Int {
        switch self {
        case .inhale: return 4
        case .hold:   return 7
        case .exhale: return 8
        }
    }

    var label: String {
        switch self {
        case .inhale: return "Breathe in"
        case .hold:   return "Hold gently"
        case .exhale: return "Release"
        }
    }

    var next: BreathPhase {
        switch self {
        case .inhale: return .hold
        case .hold:   return .exhale
        case .exhale: return .inhale
        }
    }
}

struct BreathPracticeView: View {
    let onDismiss: () -> Void

    @AppStorage("selected_lineage_id") private var lineageId: String = "sodh"

    @State private var sessionUuid: String = UUID().uuidString
    @State private var sessionStartedAt: Date?
    @State private var didFireStarted: Bool = false
    @State private var didFireEnded: Bool = false

    @State private var running: Bool = false
    @State private var phase: BreathPhase = .inhale
    @State private var phaseSec: Int = 0
    @State private var totalSec: Int = 0
    @State private var cycleCount: Int = 0

    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#1a3564"), Color(hex: "#0a1628")],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                stillnessBackRow
                titleBlock
                orb
                stats
                control
                quoteFooter
            }
        }
        .onDisappear { handleDisappear() }
    }

    // MARK: · Top section

    private var stillnessBackRow: some View {
        HStack {
            Button(action: dismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Stillness")
                        .font(.custom("Manrope", size: 11))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.Ink.primary.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.Ink.primary.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Eyebrow(text: "4 · 7 · 8 breath")
            Text("The breath remembers you.")
                .font(.custom("DMSerifDisplay-Italic", size: 22))
                .foregroundStyle(AppTheme.Ink.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
        .padding(.bottom, 30)
    }

    // MARK: · Orb · 260×260 with reference + progress + breathing core

    private var orb: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    AppTheme.Accent.primary.opacity(0.18),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
                .frame(width: 260, height: 260)
            Circle()
                .strokeBorder(AppTheme.Accent.primary.opacity(0.15), lineWidth: 1.5)
                .frame(width: 248, height: 248)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.Accent.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 248, height: 248)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Accent.primary.opacity(0.6),
                            AppTheme.Accent.primary.opacity(0.15),
                            .clear
                        ],
                        center: UnitPoint(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .scaleEffect(orbScale)
                .shadow(color: AppTheme.Accent.primary.opacity(0.35), radius: 30)
                .animation(.easeInOut(duration: 1), value: orbScale)

            VStack(spacing: 8) {
                Text(running ? phase.label.uppercased() : "TAP TO BEGIN")
                    .font(.custom("Manrope", size: 11))
                    .fontWeight(.semibold)
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.Ink.primary.opacity(0.7))
                Text(running ? "\(phase.seconds - phaseSec)" : "\u{2014}")
                    .font(.custom("DMSerifDisplay-Italic", size: 40))
                    .foregroundStyle(AppTheme.Ink.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 12)
    }

    private var progress: Double {
        Double(phaseSec) / Double(phase.seconds)
    }

    /// Section 4.1 formula:
    ///   inhale → 0.6 + progress * 0.4
    ///   hold   → 1.0
    ///   exhale → 1.0 - progress * 0.4
    private var orbScale: CGFloat {
        switch phase {
        case .inhale:  return CGFloat(0.6 + progress * 0.4)
        case .hold:    return 1.0
        case .exhale:  return CGFloat(1.0 - progress * 0.4)
        }
    }

    // MARK: · Stats

    private var stats: some View {
        HStack(spacing: 40) {
            statColumn(label: "DURATION", value: durationString)
            statColumn(label: "CYCLES", value: "\(cycleCount)")
        }
        .padding(.top, 6)
        .padding(.bottom, 24)
    }

    private func statColumn(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.custom("Manrope", size: 9))
                .fontWeight(.semibold)
                .tracking(2.0)
                .foregroundStyle(AppTheme.Ink.muted)
            Text(value)
                .font(.custom("DMSerifDisplay-Regular", size: 22))
                .foregroundStyle(AppTheme.Ink.primary)
        }
    }

    private var durationString: String {
        let mm = String(format: "%02d", totalSec / 60)
        let ss = String(format: "%02d", totalSec % 60)
        return "\(mm):\(ss)"
    }

    // MARK: · Control

    private var control: some View {
        Button(action: toggleRunning) {
            Text(buttonLabel)
                .font(.custom("Manrope", size: 12))
                .fontWeight(.bold)
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(running ? AppTheme.Ink.primary : AppTheme.Accent.onPrimary)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(running ? Color.clear : AppTheme.Accent.primary)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    running ? AppTheme.Ink.primary.opacity(0.4) : .clear,
                                    lineWidth: 1
                                )
                        )
                )
                .shadow(color: running ? .clear : AppTheme.Accent.primary.opacity(0.35), radius: 20, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 24)
    }

    private var buttonLabel: String {
        if running { return "Pause" }
        if cycleCount > 0 { return "Resume" }
        return "Begin"
    }

    // MARK: · Quote footer · unattributed per prototype

    private var quoteFooter: some View {
        Text("\u{201C}Whoever sees that things aren't for sure,\nsees for sure that that's the way they are.\u{201D}")
            .font(.custom("DMSerifDisplay-Italic", size: 13))
            .foregroundStyle(AppTheme.Ink.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
    }

    // MARK: · Lifecycle

    private func toggleRunning() {
        if running {
            // Pause
            running = false
            timerTask?.cancel()
            timerTask = nil
        } else {
            // Begin or Resume
            if !didFireStarted {
                fireSessionStarted()
            }
            running = true
            startTimer()
        }
    }

    private func fireSessionStarted() {
        guard !didFireStarted else { return }
        didFireStarted = true
        sessionStartedAt = Date()
        Analytics.track(.sessionStarted(
            sessionUuid: sessionUuid,
            sessionType: "breath",
            lineageId: lineageId,
            stageIndexAtTime: nil,        // OMIT for breath
            durationTargetSec: 0,         // cycle-based · no time target
            place: nil,                   // OMIT for breath
            ground: nil,                  // OMIT for breath
            paceMode: nil                 // OMIT for breath
        ))
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                guard running else { break }
                tickOneSecond()
            }
        }
    }

    private func tickOneSecond() {
        totalSec += 1
        let limit = phase.seconds
        if phaseSec + 1 >= limit {
            let nextPhase = phase.next
            phase = nextPhase
            phaseSec = 0
            if nextPhase == .inhale {
                cycleCount += 1
            }
        } else {
            phaseSec += 1
        }
    }

    private func dismiss() {
        fireSessionEnded(reason: endReasonOnDismiss())
        onDismiss()
    }

    private func handleDisappear() {
        timerTask?.cancel()
        timerTask = nil
        // Defensive · in case dismiss() didn't fire (system-driven disappearance).
        if didFireStarted, !didFireEnded {
            fireSessionEnded(reason: endReasonOnDismiss())
        }
    }

    /// M21 ended_reason for breath:
    ///   user_complete · cycleCount >= 3
    ///   user_pause    · cycleCount > 0 but < 3 and currently paused (had begun cycles, then stopped)
    ///   user_abort    · cycleCount == 0 (didn't even land first cycle)
    private func endReasonOnDismiss() -> String {
        if cycleCount >= 3 { return "user_complete" }
        if cycleCount > 0 && !running { return "user_pause" }
        return "user_abort"
    }

    private func fireSessionEnded(reason: String) {
        guard didFireStarted, !didFireEnded else { return }
        didFireEnded = true
        let endedAt = Date()
        let started = sessionStartedAt ?? endedAt.addingTimeInterval(-Double(totalSec))
        let completed = cycleCount >= 3
        let capturedUuid = sessionUuid
        let capturedLineage = lineageId

        // HealthKit best-effort write (no permission gate · throws are ignored).
        Task.detached {
            try? await HealthService.shared.writeMindfulSession(
                start: started,
                end: endedAt,
                sessionUuid: capturedUuid,
                lineageId: capturedLineage,
                stageIndex: nil    // OMIT for breath
            )
        }

        Analytics.track(.sessionEnded(
            sessionUuid: sessionUuid,
            sessionType: "breath",
            lineageId: lineageId,
            stageIndexAtTime: nil,
            durationTargetSec: 0,
            durationActualSec: totalSec,
            mindfulSteps: 0,
            totalSteps: 0,
            momentsOfReturn: 0,
            completed: completed,
            endedReason: reason
        ))
    }
}

#Preview {
    BreathPracticeView(onDismiss: {})
}
