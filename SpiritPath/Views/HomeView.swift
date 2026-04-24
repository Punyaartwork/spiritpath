//
//  HomeView.swift
//  SpiritPath
//
//  Phase 1.2 · 6-section dashboard · port of prototype screen-home.jsx.
//  All copy locked verbatim · do not paraphrase.
//  Mock state with gentle tick · real data lands Phase 1.6 (HealthKit) + Phase 1.4+ (Supabase).
//

import SwiftUI

struct HomeView: View {
    let onStartSession: () -> Void

    // MARK: · Mock state · prototype parity
    @State private var steps: Int = 4281
    @State private var mindfulSteps: Int = 2780
    private let momentsOfReturn = 3
    private let daysWalked = 12
    private let weekActivity: [Double] = [0.45, 0.6, 0.3, 0.75, 0.9, 0.55, 0.7]
    private let activeMeditationTitle = "Moonlit Forest Walk"

    private var progress: Double { Double(mindfulSteps) / 4500.0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GreetingHeader()
                MomentsCard(steps: steps, progress: progress)
                MindfulCard(mindfulSteps: mindfulSteps, momentsOfReturn: momentsOfReturn)
                TonightsPathCard(title: activeMeditationTitle, onStartSession: onStartSession)
                DailyJourneyCard()
                StatRow(daysWalked: daysWalked, weekActivity: weekActivity)
                Color.clear.frame(height: 80)  // spacer for tab bar overlay
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(2800))
                if Task.isCancelled { break }
                steps &+= Int.random(in: 0...2)
                if Double.random(in: 0...1) > 0.7 {
                    mindfulSteps &+= 1
                }
            }
        }
    }
}

// MARK: · 1 · Greeting header

private struct GreetingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evening Stillness.")
                .appText(.displayLG)
            Text("The stars are appearing, and your\njourney finds its rhythm.")
                .appText(.bodySmall)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: · 2 · Moments in motion card

private struct MomentsCard: View {
    let steps: Int
    let progress: Double

    var body: some View {
        AtmCard(tone: .lowest, padding: 22) {
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Moments in motion")

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(steps.formatted())
                        .font(.custom("DMSerifDisplay-Regular", size: 44))
                        .foregroundStyle(AppTheme.Ink.primary)
                    Text("today")
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(AppTheme.Ink.muted)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.Ink.muted)
                }
                .padding(.top, 10)

                SacredLine(progress: progress, color: AppTheme.Accent.primary)
                    .padding(.top, 28)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}

// MARK: · 3 · Today's mindful steps card (gold)

private struct MindfulCard: View {
    let mindfulSteps: Int
    let momentsOfReturn: Int

    var body: some View {
        AtmCard(tone: .primary, padding: 22) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(
                        text: "Today's mindful steps",
                        color: AppTheme.Accent.onPrimary.opacity(0.7)
                    )

                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(mindfulSteps.formatted())
                            .font(.custom("DMSerifDisplay-Regular", size: 48))
                            .foregroundStyle(AppTheme.Accent.onPrimary)
                        Text("Drifting, then returning")
                            .font(.custom("Manrope", size: 13))
                            .italic()
                            .foregroundStyle(AppTheme.Accent.onPrimary.opacity(0.72))
                        Spacer()
                    }
                    .padding(.top, 44)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Accent.onPrimary)
                            .frame(width: 6, height: 6)
                        Text("\(momentsOfReturn) moments of return")
                            .font(.custom("Manrope", size: 12))
                            .foregroundStyle(AppTheme.Accent.onPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppTheme.Accent.onPrimary.opacity(0.18))
                    )
                    .padding(.top, 18)
                }

                TreeCornerView()
                    .frame(width: 28, height: 36)
                    .opacity(0.5)
                    .padding(.trailing, 0)
                    .padding(.top, 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 24)
    }
}

/// Small stylized tree icon · top-right corner of MindfulCard.
/// Prototype line 62-64 · path points in 28×36 viewBox.
private struct TreeCornerView: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x / 28 * w, y: y / 36 * h)
            }
            var path = Path()
            path.move(to:      p(14, 2))
            path.addLine(to:   p(5, 14))
            path.addLine(to:   p(9, 14))
            path.addLine(to:   p(2, 24))
            path.addLine(to:   p(8, 24))
            path.addLine(to:   p(14, 34))
            path.addLine(to:   p(20, 24))
            path.addLine(to:   p(26, 24))
            path.addLine(to:   p(19, 14))
            path.addLine(to:   p(23, 14))
            path.closeSubpath()
            context.stroke(
                path,
                with: .color(Color(hex: "#0a1424").opacity(0.5)),
                style: StrokeStyle(lineWidth: 1.2, lineJoin: .round)
            )
        }
    }
}

// MARK: · 4 · Tonight's Path · hero card with ForestScene

private struct TonightsPathCard: View {
    let title: String
    let onStartSession: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tonight's Path")
                    .appText(.title)
                Spacer()
                Text("EXPLORE ALL")
                    .font(.custom("Manrope", size: 11))
                    .fontWeight(.semibold)
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.Accent.secondary)
            }
            .padding(.horizontal, 22)

            ZStack {
                Color(hex: "#0a1628")
                ForestSceneView()
                LinearGradient(
                    colors: [
                        Color(hex: "#0a1628").opacity(0),
                        Color(hex: "#0a1628").opacity(0.9)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack {
                    Spacer()
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ACTIVE MEDITATION")
                                .font(.custom("Manrope", size: 10))
                                .fontWeight(.semibold)
                                .tracking(2.2)
                                .foregroundStyle(AppTheme.Ink.primary.opacity(0.75))
                            Text(title)
                                .font(.custom("DMSerifDisplay-Italic", size: 22))
                                .foregroundStyle(AppTheme.Ink.primary)
                                .frame(maxWidth: 180, alignment: .leading)
                        }
                        Spacer()
                        Button(action: onStartSession) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Accent.primary)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 4)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(AppTheme.Accent.onPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
            }
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.35), radius: 32, x: 0, y: 8)
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 28)
    }
}

// MARK: · 5 · Daily Journey card

private struct DailyJourneyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Journey")
                    .appText(.title)
                Spacer()
                Text("DETAIL")
                    .font(.custom("Manrope", size: 11))
                    .fontWeight(.semibold)
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.Accent.secondary)
            }
            .padding(.horizontal, 22)

            AtmCard(tone: .low, padding: 20) {
                VStack(spacing: 14) {
                    DayArcView()
                    HStack(spacing: 4) {
                        phaseLabel("MORNING", sub: "Dawn Routine", active: false)
                        phaseLabel("ACTIVE",  sub: "Current Focus", active: true)
                        phaseLabel("EVENING", sub: "Reflection",   active: false)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 18)
    }

    private func phaseLabel(_ label: String, sub: String, active: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.custom("Manrope", size: 10))
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(active ? AppTheme.Accent.primary : AppTheme.Ink.muted)
            Text(sub)
                .font(.custom("Manrope", size: 11))
                .italic()
                .foregroundStyle(active ? AppTheme.Accent.primary : AppTheme.Ink.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: · 6 · Stat row · Days Walked + 7-Day Activity

private struct StatRow: View {
    let daysWalked: Int
    let weekActivity: [Double]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AtmCard(tone: .low, padding: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Days Walked")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(daysWalked)")
                            .font(.custom("DMSerifDisplay-Regular", size: 28))
                            .foregroundStyle(AppTheme.Ink.primary)
                        Text("days")
                            .font(.custom("DMSerifDisplay-Regular", size: 16))
                            .foregroundStyle(AppTheme.Ink.muted)
                    }
                    .padding(.top, 6)
                    Text("Current streak")
                        .font(.custom("Manrope", size: 11))
                        .foregroundStyle(AppTheme.Ink.muted)
                        .padding(.top, 4)
                }
            }

            AtmCard(tone: .low, padding: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "7-Day Activity")
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(weekActivity.enumerated()), id: \.offset) { index, h in
                            Capsule()
                                .fill(index == 4 ? AppTheme.Accent.primary : AppTheme.Ink.faint)
                                .frame(maxWidth: .infinity)
                                .frame(height: CGFloat(h) * 40)
                        }
                    }
                    .frame(height: 40)
                    .padding(.top, 12)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 40)
    }
}

// MARK: · Preview

#Preview {
    ZStack {
        AppBackground(style: .day)
        HomeView(onStartSession: {})
    }
}
