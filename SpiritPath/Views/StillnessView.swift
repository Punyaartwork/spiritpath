//
//  StillnessView.swift
//  SpiritPath
//
//  Phase 2.3 · port of prototype src/screen-stillness.jsx (lines 1-111).
//  4 sections · header · breathing orb · hero text + sound bath pill · 3 quiet cards.
//
//  Background: prototype gradient #122952 → #0a1628 · navy-to-midnight.
//
//  M16 stillness_opened event fires once per app session via SessionEventThrottle
//  (commit 02b55be parity). Re-fires only after process death.
//
//  Sub-screen routing: 4 fullScreenCover destinations (breath · quiet · nightlog · soundbath).
//  Phase 2.4 ships breath + quiet · Phase 2.4b nightlog · Phase 2.5 soundbath.
//

import SwiftUI
import Combine
import Supabase

// MARK: · Sub-screen routing

enum StillnessSubScreen: Identifiable {
    case breath
    case quiet(sessionKey: QuietSessionKey)
    case nightLog
    case soundBath

    var id: String {
        switch self {
        case .breath:                    return "breath"
        case .quiet(let key):            return "quiet_\(key.rawValue)"
        case .nightLog:                  return "nightLog"
        case .soundBath:                 return "soundBath"
        }
    }
}

// MARK: · Quiet session catalog · used by both StillnessView card list and QuietSessionView

enum QuietSessionKey: String, CaseIterable, Identifiable {
    case eveningBreath = "Evening Breath"
    case lettingGo = "Letting Go"
    case bodySoftening = "Body Softening"

    var id: String { rawValue }
    var displayTitle: String { rawValue }

    var subtitle: String {
        switch self {
        case .eveningBreath: return "12 min · Quiet presence"
        case .lettingGo:     return "8 min · Release the day"
        case .bodySoftening: return "15 min · Gentle awareness"
        }
    }

    var iconSystemName: String {
        switch self {
        case .eveningBreath: return "moon"
        case .lettingGo:     return "leaf"
        case .bodySoftening: return "sparkles"
        }
    }
}

// MARK: · ViewModel · M16 fire-site

@MainActor
final class StillnessViewModel: ObservableObject {

    func onScreenEntered(entrySource: String = "tab_bar") async {
        guard SessionEventThrottle.shared.firstFireThisSession("stillness_opened") else { return }

        let userId = supabase.auth.currentUser?.id.uuidString
        let hadSessionToday: Bool = await {
            guard let userId else { return false }
            let count = await SessionRepository.shared.countCompletedSessionsSince(
                userId: userId,
                since: Calendar.current.startOfDay(for: Date())
            )
            return count > 0
        }()

        let nowHour = Calendar.current.component(.hour, from: Date())

        Analytics.track(.stillnessOpened(
            timeOfDayHour: nowHour,
            hadSessionToday: hadSessionToday,
            entrySource: entrySource
        ))
    }
}

// MARK: · View

struct StillnessView: View {
    @StateObject private var viewModel = StillnessViewModel()
    @State private var subScreen: StillnessSubScreen?
    @State private var orbScale: CGFloat = 1.0

    /// Phase 2.7c · gear icon callback · invoked from header.
    var onOpenSettings: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                breathingOrb
                heroText
                soundBathPill
                quietHeader
                quietCardList
                Color.clear.frame(height: 80)   // tab bar spacer
            }
        }
        .task {
            await viewModel.onScreenEntered()
            // Start the 6s breathing pulse once view is mounted.
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                orbScale = 1.15
            }
        }
        .fullScreenCover(item: $subScreen) { sub in
            switch sub {
            case .breath:
                BreathPracticeView(onDismiss: { subScreen = nil })
            case .quiet(let key):
                QuietSessionView(sessionKey: key, onDismiss: { subScreen = nil })
            case .nightLog:
                NightLogView(onDismiss: { subScreen = nil })
            case .soundBath:
                SoundBathView(onDismiss: { subScreen = nil })
            }
        }
    }

    // MARK: · Section A · Header

    private var header: some View {
        HStack {
            Text("Stillness")
                .font(.custom("DMSerifDisplay-Italic", size: 18))
                .foregroundStyle(AppTheme.Ink.primary)
            Spacer()
            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundStyle(AppTheme.Ink.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: · Section B · Breathing orb

    private var breathingOrb: some View {
        Button {
            subScreen = .breath
        } label: {
            ZStack {
                ForEach(0..<4) { i in
                    let s = [1.0, 0.82, 0.62, 0.42][i]
                    let alpha = 0.35 - Double(i) * 0.06
                    Circle()
                        .strokeBorder(
                            AppTheme.Accent.primary.opacity(alpha),
                            lineWidth: 1
                        )
                        .frame(width: 240 * s, height: 240 * s)
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AppTheme.Accent.primary, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .frame(width: 60, height: 60)
                Text("TAP TO BREATHE")
                    .font(.custom("Manrope", size: 9))
                    .fontWeight(.semibold)
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.Ink.muted)
                    .offset(y: 132)
            }
            .scaleEffect(orbScale)
            .frame(width: 240, height: 240)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 40)
    }

    // MARK: · Section C · Hero text → NightLog

    private var heroText: some View {
        VStack(spacing: 14) {
            Button {
                subScreen = .nightLog
            } label: {
                Text("The night is long enough\nfor rest.")
                    .font(.custom("DMSerifDisplay-Italic", size: 28))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            Text("Breathe with the light. Let the day\nfinish its own sentence.")
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.muted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: · Section D · Sound Bath pill

    private var soundBathPill: some View {
        Button {
            subScreen = .soundBath
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text("SOUND BATH")
                    .font(.custom("Manrope", size: 10))
                    .fontWeight(.semibold)
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.Ink.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(AppTheme.Ink.primary.opacity(0.06))
                    .overlay(
                        Capsule()
                            .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }

    // MARK: · Section E · Quiet sessions

    private var quietHeader: some View {
        HStack {
            Eyebrow(text: "Tonight's Stillness")
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private var quietCardList: some View {
        VStack(spacing: 10) {
            ForEach(QuietSessionKey.allCases) { key in
                quietCard(key)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 30)
    }

    private func quietCard(_ key: QuietSessionKey) -> some View {
        Button {
            subScreen = .quiet(sessionKey: key)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Accent.primary.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: key.iconSystemName)
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.Accent.primary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(key.displayTitle)
                        .font(.custom("DMSerifDisplay-Italic", size: 17))
                        .foregroundStyle(AppTheme.Ink.primary)
                    Text(key.subtitle)
                        .font(.custom("Manrope", size: 11))
                        .foregroundStyle(AppTheme.Ink.muted)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.Ink.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(AppTheme.Ink.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .night)
        StillnessView()
    }
}
