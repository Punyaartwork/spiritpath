//
//  ReflectionView.swift
//  SpiritPath
//
//  Phase 1.3 · post-session reflection · port of prototype screen-reflection.jsx.
//  Report card (tone=low) + Note card (tone=primary when focused) + Complete button
//  + Discard ghost link. Mixpanel fires reflection_submitted on Complete · Discard
//  fires no event (per skill: not a funnel completion · just unwinds).
//
//  SessionContext read via @Binding · carries session_uuid that matches the
//  session_started / session_ended events fired by SessionView.
//

import SwiftUI

struct ReflectionView: View {
    @Binding var context: SessionContext?
    let onExit: () -> Void

    @State private var note: String = ""
    @State private var didFireSubmit = false

    // Mock · real values land Phase 1.6 (HealthKit + CoreMotion)
    private var mindfulSteps: Int { context?.mindfulSteps ?? 320 }
    private var totalSteps: Int { context?.totalSteps ?? 500 }
    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(mindfulSteps) / Double(totalSteps)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                intro
                reportCard
                noteCard
                completeButton
                discardButton
            }
        }
    }

    // MARK: · header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text("Reflection")
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: · intro copy

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A journey\ncompleted.")
                .font(.custom("DMSerifDisplay-Regular", size: 32))
                .foregroundStyle(AppTheme.Ink.primary)
            Text("Rest your steps and reflect on the\nquality of your presence.")
                .appText(.bodySmall)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: · report card (tone low)

    private var reportCard: some View {
        VStack(spacing: 0) {
            AtmCard(tone: .low, padding: 30) {
                VStack(spacing: 0) {
                    sessionCompleteMark
                        .padding(.bottom, 18)
                    Eyebrow(text: "Mindful Steps Report", color: AppTheme.Accent.primary)
                    Text("You stayed\npresent, most of\nthe way.")
                        .font(.custom("DMSerifDisplay-Regular", size: 26))
                        .foregroundStyle(AppTheme.Ink.primary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                    Text("\(mindfulSteps) of your \(totalSteps) steps were walked\nwith awareness.")
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(AppTheme.Ink.soft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                    SacredLine(progress: progress, color: AppTheme.Accent.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var sessionCompleteMark: some View {
        // Simple concentric ring + check badge · proto uses SessionComplete glyph
        ZStack {
            Circle()
                .strokeBorder(AppTheme.Accent.primary.opacity(0.4), lineWidth: 1)
                .frame(width: 84, height: 84)
            Circle()
                .strokeBorder(AppTheme.Accent.primary.opacity(0.7), lineWidth: 1)
                .frame(width: 60, height: 60)
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.Accent.primary)
        }
    }

    // MARK: · note card (tone primary · gold)

    private var noteCard: some View {
        AtmCard(tone: .primary, padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Accent.onPrimary)
                    Text("What did you find today?")
                        .font(.custom("DMSerifDisplay-Italic", size: 16))
                        .foregroundStyle(AppTheme.Accent.onPrimary)
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Surface.raised)
                        .frame(minHeight: 100)

                    if note.isEmpty {
                        Text("The cool air against my skin, the sound of dry leaves…")
                            .font(.custom("Manrope", size: 14))
                            .foregroundStyle(AppTheme.Ink.muted)
                            .padding(14)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $note)
                        .font(.custom("Manrope", size: 14))
                        .foregroundStyle(AppTheme.Ink.primary)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 100)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    // MARK: · Complete

    private var completeButton: some View {
        Button(action: complete) {
            HStack(spacing: 8) {
                Text("Complete Reflection")
                    .font(.custom("Manrope", size: 15))
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.Accent.onPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.pill)
                    .fill(AppTheme.Accent.primary)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    // MARK: · Discard

    private var discardButton: some View {
        Button(action: discard) {
            Text("Discard Session")
                .font(.custom("Manrope", size: 11))
                .fontWeight(.semibold)
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Ink.muted)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    // MARK: · actions

    private func complete() {
        guard !didFireSubmit, let ctx = context else {
            onExit()
            return
        }
        didFireSubmit = true

        let gap: Int = {
            guard let endedAt = ctx.endedAt else { return 0 }
            return max(0, Int(Date().timeIntervalSince(endedAt)))
        }()

        Analytics.track(.reflectionSubmitted(
            sessionUuid: ctx.uuid,
            noteLengthChars: note.count,
            anchorPhraseSet: false,   // Phase 1.7 · anchor-phrase picker
            timeSinceSessionEndSec: gap
        ))

        onExit()
    }

    private func discard() {
        // Skill rule: discard fires no Mixpanel event · just unwinds.
        onExit()
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
            paceMode: "forest",
            elapsedSec: 1650,
            endedAt: Date(),
            endedReason: "natural",
            completed: true
        )
        var body: some View {
            ZStack {
                AppBackground(style: .day)
                ReflectionView(context: $ctx, onExit: {})
            }
        }
    }
    return PreviewWrapper()
}
