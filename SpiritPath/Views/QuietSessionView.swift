//
//  QuietSessionView.swift
//  SpiritPath
//
//  Phase 2.4 · port of prototype src/screen-stillness-subs.jsx:157-325 (line 157-189 phase data verbatim).
//  3 hardcoded sessions × 13 phases · phase content cited verbatim from prototype.
//
//  Mixpanel:
//    - session_started fires on first Begin tap (NOT on view appear).
//      session_type="quiet" · target_sec = durationMin × 60 · place/ground/pace_mode/stage_index OMITTED.
//    - session_ended fires on dismiss / reset / auto-complete with one of:
//        auto_complete · timer reached target (M21 NEW)
//        user_complete · user dismissed with elapsed >= target × 0.8 (M7 rule)
//        user_abort    · user dismissed below the 80% threshold OR pressed Reset
//
//  HealthKit (Section 4.5):
//    - Mindful session WRITE attempted at end · best-effort · stage_index nil.
//    - No step query · indoor practice.
//    - mindful_steps + total_steps = 0 always.
//

import SwiftUI

// MARK: · Phase data · cited verbatim from prototype line 157-189

struct QuietPhase: Equatable, Identifiable {
    let at: Int           // seconds offset from session start
    let label: String
    let note: String
    var id: String { "\(at)_\(label)" }
}

struct QuietSessionConfig: Equatable {
    let key: QuietSessionKey
    let durationMin: Int
    let iconSystemName: String
    let descriptionText: String
    let phases: [QuietPhase]

    var totalSec: Int { durationMin * 60 }
    var displayTitle: String { key.displayTitle }
}

enum QuietSessionConfigs {
    /// Verbatim from prototype src/screen-stillness-subs.jsx:157-189.
    /// 3 sessions · 13 phases total · do NOT paraphrase any string.
    static func config(for key: QuietSessionKey) -> QuietSessionConfig {
        switch key {
        case .eveningBreath:
            return QuietSessionConfig(
                key: .eveningBreath,
                durationMin: 12,
                iconSystemName: "moon",
                descriptionText: "Twelve minutes of quiet presence. The day is finishing its own sentence \u{2014} just be the one who listens.",
                phases: [
                    QuietPhase(at: 0,   label: "Settling in",                note: "Find your posture. Let the shoulders fall."),
                    QuietPhase(at: 120, label: "Meeting the breath",         note: "Nothing to change. Just be where it is."),
                    QuietPhase(at: 360, label: "Letting it breathe you",     note: "Effort becomes thinner."),
                    QuietPhase(at: 600, label: "Open rest",                  note: "The breath continues without your help.")
                ]
            )
        case .lettingGo:
            return QuietSessionConfig(
                key: .lettingGo,
                durationMin: 8,
                iconSystemName: "leaf",
                descriptionText: "Eight minutes to release the day. Not forcing anything away \u{2014} just loosening the grip.",
                phases: [
                    QuietPhase(at: 0,   label: "Naming the weight",          note: "What did you carry today without choosing?"),
                    QuietPhase(at: 120, label: "Holding it lightly",         note: "Not pushing. Just lighter."),
                    QuietPhase(at: 300, label: "On the exhale \u{2014} release", note: "Each out-breath is a small letting-go."),
                    QuietPhase(at: 420, label: "Empty hands",                note: "You don't need to hold tomorrow yet.")
                ]
            )
        case .bodySoftening:
            return QuietSessionConfig(
                key: .bodySoftening,
                durationMin: 15,
                iconSystemName: "sparkles",
                descriptionText: "Fifteen minutes of gentle body awareness. Where there is tension, place a warm attention.",
                phases: [
                    QuietPhase(at: 0,   label: "Crown and forehead",         note: "Softening the thinking space."),
                    QuietPhase(at: 180, label: "Jaw and throat",             note: "Let the words rest."),
                    QuietPhase(at: 420, label: "Shoulders and chest",        note: "The breath has more room here."),
                    QuietPhase(at: 660, label: "Belly and hips",             note: "The grounded center."),
                    QuietPhase(at: 840, label: "Legs and feet",              note: "Back to the earth.")
                ]
            )
        }
    }
}

// MARK: · View

struct QuietSessionView: View {
    let sessionKey: QuietSessionKey
    let onDismiss: () -> Void

    @AppStorage("selected_lineage_id") private var lineageId: String = "sodh"

    @State private var sessionUuid: String = UUID().uuidString
    @State private var sessionStartedAt: Date?
    @State private var didFireStarted: Bool = false
    @State private var didFireEnded: Bool = false

    @State private var running: Bool = false
    @State private var elapsed: Int = 0

    @State private var timerTask: Task<Void, Never>?

    private var config: QuietSessionConfig { QuietSessionConfigs.config(for: sessionKey) }
    private var totalSec: Int { config.totalSec }
    private var progress: Double { totalSec > 0 ? Double(elapsed) / Double(totalSec) : 0 }

    /// Last phase at or before current elapsed · matches prototype line 211 reverse-find.
    private var currentPhase: QuietPhase {
        config.phases.last(where: { elapsed >= $0.at }) ?? config.phases[0]
    }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#1a3564"), Color(hex: "#0a1628")],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    stillnessBackRow
                    titleBlock
                    progressRing
                    phaseCallout
                    controls
                    phaseMap
                }
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
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Accent.primary.opacity(0.12))
                    .frame(width: 48, height: 48)
                Circle()
                    .strokeBorder(AppTheme.Accent.primary.opacity(0.3), lineWidth: 1)
                    .frame(width: 48, height: 48)
                Image(systemName: config.iconSystemName)
                    .font(.system(size: 20))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            Text(config.displayTitle + ".")
                .font(.custom("DMSerifDisplay-Italic", size: 26))
                .foregroundStyle(AppTheme.Ink.primary)
            Text(config.descriptionText)
                .font(.custom("Manrope", size: 12))
                .foregroundStyle(AppTheme.Ink.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)
        }
        .padding(.top, 30)
        .padding(.bottom, 30)
    }

    // MARK: · Progress ring + time

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Accent.primary.opacity(0.12), lineWidth: 1)
                .frame(width: 240, height: 240)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.Accent.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))

            // Phase markers · 2.5pt dots at each phase angle
            ForEach(config.phases) { phase in
                phaseMarkerDot(at: phase.at)
            }

            VStack(spacing: 6) {
                Text(elapsedString)
                    .font(.custom("DMSerifDisplay-Italic", size: 40))
                    .foregroundStyle(AppTheme.Ink.primary)
                Text("of \(config.durationMin):00")
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(.semibold)
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.Ink.muted)
            }
        }
        .padding(.bottom, 12)
    }

    private func phaseMarkerDot(at offsetSec: Int) -> some View {
        let frac = Double(offsetSec) / Double(max(totalSec, 1))
        // Convert into x/y on the 240-circle · radius 120 from center · (-90deg origin shift handled by sin/cos with offset)
        let angle = frac * 2 * .pi - .pi / 2
        let r: Double = 120
        let x: Double = r + cos(angle) * r
        let y: Double = r + sin(angle) * r
        return Circle()
            .fill(AppTheme.Accent.primary.opacity(0.6))
            .frame(width: 5, height: 5)
            .offset(x: x - r, y: y - r)
    }

    private var elapsedString: String {
        let mm = String(format: "%02d", elapsed / 60)
        let ss = String(format: "%02d", elapsed % 60)
        return "\(mm):\(ss)"
    }

    // MARK: · Phase callout

    private var phaseCallout: some View {
        VStack(spacing: 8) {
            Text(currentPhase.label.uppercased())
                .font(.custom("Manrope", size: 10))
                .fontWeight(.bold)
                .tracking(2.4)
                .foregroundStyle(AppTheme.Accent.primary)
            Text(currentPhase.note)
                .font(.custom("DMSerifDisplay-Italic", size: 15))
                .foregroundStyle(AppTheme.Ink.primary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .frame(minHeight: 70)
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
    }

    // MARK: · Controls · Reset + Begin/Pause/Resume

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: reset) {
                Text("RESET")
                    .font(.custom("Manrope", size: 11))
                    .fontWeight(.semibold)
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.Ink.soft)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .strokeBorder(AppTheme.Ink.primary.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

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
        }
        .padding(.top, 10)
        .padding(.bottom, 32)
    }

    private var buttonLabel: String {
        if running { return "Pause" }
        if elapsed > 0 { return "Resume" }
        return "Begin"
    }

    // MARK: · Phase map

    private var phaseMap: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Phase map")
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            VStack(spacing: 8) {
                ForEach(config.phases) { phase in
                    phaseMapRow(phase)
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 40)
    }

    private func phaseMapRow(_ phase: QuietPhase) -> some View {
        let isCurrent = phase == currentPhase
        let pMin = phase.at / 60
        let pSec = phase.at % 60
        let stamp = String(format: "%02d:%02d", pMin, pSec)
        return HStack(alignment: .top, spacing: 12) {
            Text(stamp)
                .font(.custom("Manrope", size: 10))
                .fontWeight(.semibold)
                .tracking(1.0)
                .foregroundStyle(isCurrent ? AppTheme.Accent.primary : AppTheme.Ink.muted)
                .frame(width: 36, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.label)
                    .font(.custom("DMSerifDisplay-Italic", size: 13))
                    .foregroundStyle(isCurrent ? AppTheme.Ink.primary : AppTheme.Ink.soft)
                Text(phase.note)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isCurrent ? AppTheme.Accent.primary.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isCurrent ? AppTheme.Accent.primary.opacity(0.33) : AppTheme.Ink.primary.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: · Lifecycle

    private func toggleRunning() {
        if running {
            running = false
            timerTask?.cancel()
            timerTask = nil
        } else {
            if !didFireStarted {
                fireSessionStarted()
            }
            running = true
            startTimer()
        }
    }

    private func reset() {
        // If we already started a session, end it as user_abort before zeroing.
        if didFireStarted, !didFireEnded {
            running = false
            timerTask?.cancel()
            timerTask = nil
            fireSessionEnded(reason: "user_abort")
        }
        // Fresh session shell · next Begin will fire a new session_started.
        sessionUuid = UUID().uuidString
        sessionStartedAt = nil
        didFireStarted = false
        didFireEnded = false
        elapsed = 0
        running = false
    }

    private func fireSessionStarted() {
        guard !didFireStarted else { return }
        didFireStarted = true
        sessionStartedAt = Date()
        Analytics.track(.sessionStarted(
            sessionUuid: sessionUuid,
            sessionType: "quiet",
            lineageId: lineageId,
            stageIndexAtTime: nil,
            durationTargetSec: totalSec,
            place: nil,
            ground: nil,
            paceMode: nil
        ))
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                guard running else { break }
                elapsed += 1
                if elapsed >= totalSec {
                    // Auto-stop at 100%
                    running = false
                    fireSessionEnded(reason: "auto_complete")
                    break
                }
            }
        }
    }

    private func dismiss() {
        if didFireStarted, !didFireEnded {
            fireSessionEnded(reason: endReasonOnDismiss())
        }
        onDismiss()
    }

    private func handleDisappear() {
        timerTask?.cancel()
        timerTask = nil
        if didFireStarted, !didFireEnded {
            fireSessionEnded(reason: endReasonOnDismiss())
        }
    }

    /// M21 ended_reason for quiet:
    ///   user_complete · elapsed >= target × 0.8
    ///   user_abort    · elapsed below 80% threshold
    private func endReasonOnDismiss() -> String {
        let threshold = Int(Double(totalSec) * 0.8)
        return elapsed >= threshold ? "user_complete" : "user_abort"
    }

    private func fireSessionEnded(reason: String) {
        guard didFireStarted, !didFireEnded else { return }
        didFireEnded = true
        let endedAt = Date()
        let started = sessionStartedAt ?? endedAt.addingTimeInterval(-Double(elapsed))
        let threshold = Int(Double(totalSec) * 0.8)
        let completed = elapsed >= threshold
        let capturedUuid = sessionUuid
        let capturedLineage = lineageId

        Task.detached {
            try? await HealthService.shared.writeMindfulSession(
                start: started,
                end: endedAt,
                sessionUuid: capturedUuid,
                lineageId: capturedLineage,
                stageIndex: nil
            )
        }

        Analytics.track(.sessionEnded(
            sessionUuid: sessionUuid,
            sessionType: "quiet",
            lineageId: lineageId,
            stageIndexAtTime: nil,
            durationTargetSec: totalSec,
            durationActualSec: elapsed,
            mindfulSteps: 0,
            totalSteps: 0,
            momentsOfReturn: 0,
            completed: completed,
            endedReason: reason
        ))
    }
}

#Preview {
    QuietSessionView(sessionKey: .eveningBreath, onDismiss: {})
}
