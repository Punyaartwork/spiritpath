//
//  RootTabView.swift
//  SpiritPath
//
//  Flat state-machine root · ZStack + switch · no TabView · no NavigationStack.
//  Tab bar overlay shown/hidden per Screen.showsTabBar.
//  Mirrors prototype app.jsx structure · cross-platform parity with Android RootTabView.
//
//  Phase 1.3 · owns the shared SessionContext lift · reads @AppStorage prefs when
//  building context from HomeView quick-start or PracticeView Begin · passes via
//  @Binding to SessionView + ReflectionView so one UUID ties the 3 Mixpanel events.
//

import SwiftUI

struct RootTabView: View {
    @Binding var screen: Screen

    // MARK: · prefs read at session-start time (source: PracticeView @AppStorage)
    @AppStorage("pref.duration") private var prefDuration: String = "30 MINS"
    @AppStorage("pref.place")    private var prefPlace: String    = "forest"
    @AppStorage("pref.ground")   private var prefGround: String   = "grass"
    @AppStorage("pref.pace")     private var prefPace: String     = "forest"
    @AppStorage("selected_lineage_id") private var lineageId: String = "sodh"

    // MARK: · shared Session → Reflection state
    @State private var sessionContext: SessionContext?

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch screen {
                case .home:
                    HomeView(onStartSession: startSession)
                case .practice:
                    PracticeView(onBegin: startSession)
                case .journey:
                    JourneyView()
                case .stillness:
                    StillnessView()
                case .session:
                    SessionView(
                        context: $sessionContext,
                        onEnd: navigateToReflection
                    )
                case .reflection:
                    ReflectionView(
                        context: $sessionContext,
                        onExit: navigateHome
                    )
                case .nightlog:
                    NightLogView(onDismiss: navigateToStillness)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground(style: backgroundStyle))

            if screen.showsTabBar {
                SpiritTabBar(screen: $screen)
                    .transition(.opacity)
            }
        }
    }

    private var backgroundStyle: AppBackgroundStyle {
        switch screen {
        case .stillness, .nightlog: return .night
        case .session:              return .gradientDepth
        default:                    return .day
        }
    }

    // MARK: · session lifecycle

    private func startSession() {
        sessionContext = SessionContext(
            uuid: UUID().uuidString,
            sessionType: "walking",
            lineageId: lineageId,
            stageIndex: 1,                     // Phase 1.6 reads journey_progress
            targetSec: targetSecFromPref(),
            place: prefPlace,
            ground: prefGround,
            paceMode: prefPace
        )
        withAnimation(.easeInOut(duration: 0.5)) {
            screen = .session
        }
    }

    private func navigateToReflection() {
        withAnimation(.easeInOut(duration: 0.5)) {
            screen = .reflection
        }
    }

    private func navigateToNightLog() {
        withAnimation(.easeInOut(duration: 0.5)) {
            screen = .nightlog
        }
    }

    private func navigateToStillness() {
        withAnimation(.easeInOut(duration: 0.5)) {
            screen = .stillness
        }
    }

    private func navigateHome() {
        withAnimation(.easeInOut(duration: 0.5)) {
            screen = .home
        }
        // Clear after transition so ReflectionView doesn't flash empty state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            sessionContext = nil
        }
    }

    /// "15 MINS" / "30 MINS" / "60 MINS" → seconds
    private func targetSecFromPref() -> Int {
        let digits = prefDuration.filter(\.isNumber)
        let mins = Int(digits) ?? 30
        return mins * 60
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var screen: Screen = .home
        var body: some View { RootTabView(screen: $screen) }
    }
    return PreviewWrapper()
}
