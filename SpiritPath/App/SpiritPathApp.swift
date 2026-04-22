//
//  SpiritPathApp.swift
//  SpiritPath
//

import Combine
import CoreLocation
import CoreText
import SwiftUI
import UserNotifications

@main
struct SpiritPathApp: App {
    @State private var screen: Screen = .home
    @State private var onboardingComplete = false

    init() {
        SpiritFonts.registerAll()
        Analytics.initialize()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !onboardingComplete {
                    OnboardingView(onComplete: {
                        onboardingComplete = true
                        screen = .home
                    })
                } else {
                    RootTabView(screen: $screen)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: screen)
            .animation(.easeInOut(duration: 0.5), value: onboardingComplete)
        }
    }
}

// Runtime font registration · avoids Info.plist UIAppFonts setup
// TTF files live in SpiritPath/Resources/Fonts/
private enum SpiritFonts {
    static let names: [String] = [
        "DMSerifDisplay-Regular",
        "DMSerifDisplay-Italic",
        "Manrope-VariableFont_wght",
        "JetBrainsMono-Regular",
        "JetBrainsMono-Medium"
    ]

    static func registerAll() {
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                #if DEBUG
                print("⚠️ SpiritFonts · file missing in bundle: \(name).ttf")
                #endif
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                #if DEBUG
                print("⚠️ SpiritFonts · register failed for \(name): \(String(describing: error?.takeUnretainedValue()))")
                #endif
            }
        }
    }

    // Font family names (usable in .font(.custom(...))) — must match PostScript names in the TTFs
    enum Family {
        static let serif = "DMSerifDisplay-Regular"
        static let serifItalic = "DMSerifDisplay-Italic"
        static let sans = "Manrope"                    // variable font · use .fontWeight modifier
        static let mono = "JetBrainsMono-Regular"
        static let monoMedium = "JetBrainsMono-Medium"
    }
}

private struct OnboardingState {
    var emotionalState = ""
    var hopedOutcome = ""
    var meditationExp = ""
    var peacefulMoment = ""
    var focusPlaces: Set<String> = []
    var teachingTypes: Set<String> = []
    var selectedPath = ""

    var painCopy: PainCopy {
        switch emotionalState {
        case "My mind won't slow down.":
            return PainCopy(
                stat: "47%",
                subtext: "of waking hours, the mind is somewhere else.",
                relief: "One intentional step changes everything that follows."
            )
        case "I'm exhausted but can't stop.":
            return PainCopy(
                stat: "6 min",
                subtext: "the average person goes without a single pause - all day.",
                relief: "SpiritPath gives you permission to stop - and it's enough."
            )
        case "I feel disconnected from myself.":
            return PainCopy(
                stat: "8,000",
                subtext: "steps walked today. Zero of them noticed.",
                relief: "What if one walk brought you back to yourself?"
            )
        default:
            return PainCopy(
                stat: "1 step",
                subtext: "taken with full awareness changes what follows.",
                relief: "A 2,500-year tradition is already waiting for you."
            )
        }
    }

    var spiritMatch: SpiritMatch {
        let beginner = meditationExp.contains("Never") || meditationExp.contains("A little")
        let experienced = meditationExp.contains("Yes")
        let silence = teachingTypes.contains("Silence-based")
        let nature = teachingTypes.contains("Nature connection") || focusPlaces.contains("Forest / Park") || focusPlaces.contains("Near water") || focusPlaces.contains("Open fields") || focusPlaces.contains("Mountains")
        let breathBody = teachingTypes.contains("Breathwork") || teachingTypes.contains("Body awareness")
        let storyTeaching = teachingTypes.contains("Story & wisdom") || teachingTypes.contains("Buddhist teaching") || teachingTypes.contains("Gentle guidance")
        let mantra = teachingTypes.contains("Sound & mantra")

        // Canonical 7-row matrix · synced with Android · see master plan Tab 04 C3
        // Do not diverge without cross-platform sync round.

        // Row 1 + 4: any experience + body/breath → Mun
        if breathBody { return .mun }
        // Row 2: experienced + nature/silence → Chah
        if experienced && (nature || silence) { return .chah }
        // Row 3: experienced + story/teaching → Chah
        if experienced && storyTeaching { return .chah }
        // Row 5: beginner + story/teaching → Chah
        if beginner && storyTeaching { return .chah }
        // Row 6a: mantra → Sodh · explicit intent · added C3b round 7
        if mantra { return .sodh }
        // Row 6: beginner + silence/nature → Sodh
        if beginner && (silence || nature) { return .sodh }
        // Row 7: fallback → Sodh
        return .sodh
    }
}

private struct PainCopy {
    let stat: String
    let subtext: String
    let relief: String
}

private struct SpiritMatch {
    let master: String
    let shortName: String
    let style: String
    let explanation: String
    let lineageId: String  // 'mun' | 'sodh' | 'chah' · Postgres enum wire value · Mixpanel property
}

extension SpiritMatch {
    static let mun = SpiritMatch(
        master: "Luang Pu Mun Bhūridatto",
        shortName: "Luang Pu Mun",
        style: "Forest · Kammaṭṭhāna",
        explanation: "His teachings turn walking itself into awareness — matching your answers from the quiz.",
        lineageId: "mun"
    )

    static let chah = SpiritMatch(
        master: "Luang Por Chah",
        shortName: "Luang Por Chah",
        style: "Forest · Wat Pah Pong",
        explanation: "His teachings meet nature with simple, direct wisdom — matching your answers from the quiz.",
        lineageId: "chah"
    )

    static let sodh = SpiritMatch(
        master: "Luang Pu Sodh Candasaro",
        shortName: "Luang Pu Sodh",
        style: "Inner Light · Mantra Stillness",
        explanation: "His teachings focus on calming the mind through inner stillness and light — matching your answers from the quiz.",
        lineageId: "sodh"
    )
}

private extension OnboardingState {
    /// Map UI label → Postgres path_id enum wire value · keep in sync with V1 enum.
    var pathIdWire: String {
        switch selectedPath {
        case "Mindful Walking":       return "mindful_walking"
        case "Everyday Mindfulness":  return "everyday"
        case "Awareness in Body":     return "body"
        case "Forest Retreat":        return "retreat"
        default:                      return "mindful_walking"
        }
    }
}

private struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var screen = 1
    @State private var previousScreen = 1
    @State private var state = OnboardingState()
    @State private var selectedPaywallPlan = "Yearly"
    @State private var settlingStep = 0
    @State private var soundOn = false
    @State private var didApplyDebugStart = false
    @State private var notificationsGranted = false
    @State private var outgoingGroup2Screen: Int?
    @State private var group2SlideDirection = 1
    @State private var group2SlideProgress = 1.0
    @StateObject private var locationRequester = LocationPermissionRequester()

    var body: some View {
        ZStack {
            if screen == 1 {
                MotionLogoScreen {
                    go(to: 2)
                }
                .transition(.opacity)
            } else if (2...10).contains(screen) {
                Group2PagerShell(progressIndex: screen - 1, showsBack: screen >= 3, onBack: back) {
                    Group2PageSlider(
                        screen: screen,
                        outgoingScreen: outgoingGroup2Screen,
                        direction: group2SlideDirection,
                        progress: group2SlideProgress
                    ) { page in
                        group2Screen(page)
                    }
                }
            } else {
                Color.white.ignoresSafeArea()

                currentScreen
                    .id(screenSpecificID)
                    .transition(.identity)
            }
        }
        .font(.system(.body, design: .default))
        .tint(.black)
        .preferredColorScheme(.light)
        .onAppear(perform: applyDebugStartIfNeeded)
    }

    private var screenSpecificID: String {
        screen == 13 ? "13-\(settlingStep)" : "\(screen)"
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screen {
        case 2:
            group2Screen(2)
        case 3:
            group2Screen(3)
        case 4:
            group2Screen(4)
        case 5:
            group2Screen(5)
        case 6:
            group2Screen(6)
        case 7:
            group2Screen(7)
        case 8:
            group2Screen(8)
        case 9:
            group2Screen(9)
        case 10:
            group2Screen(10)
        case 11:
            SpiritMatchScreen(match: state.spiritMatch) {
                go(to: 12)
            }
        case 12:
            PermissionTextScreen(
                title: "Stay on your path.",
                subtitle: "Daily reminders help you maintain a walking\npractice - even on busy days.",
                buttonTitle: "Allow Notifications",
                linkTitle: "Not now",
                onButton: {
                    requestNotifications()
                    go(to: 13)
                },
                onLink: { go(to: 13) }
            )
        case 13:
            SettlingFlowScreen(
                step: settlingStep,
                soundOn: $soundOn,
                onButton: advanceSettling,
                onSkipLocation: { advanceSettling() },
                onRequestLocation: {
                    locationRequester.request()
                    advanceSettling()
                }
            )
        case 14:
            PathSelectionScreen(selectedPath: $state.selectedPath) {
                go(to: 15)
            }
        case 15:
            PaywallScreen(selectedPlan: $selectedPaywallPlan) {
                go(to: 16)
            }
        case 16:
            AuthScreen {
                fireOnboardingCompleted()
                onComplete()
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func group2Screen(_ page: Int) -> some View {
        switch page {
        case 2:
            GetStartedScreen {
                go(to: 3)
            }
        case 3:
            ValuePropsScreen(onBack: back) {
                go(to: 4)
            }
        case 4:
            CardQuestionScreen(
                progressIndex: 3,
                eyebrow: "ABOUT YOU",
                title: "How are you feeling\nright now?",
                subtitle: "There's no wrong answer.",
                options: [
                    "My mind won't slow down.",
                    "I'm exhausted but can't stop.",
                    "I feel disconnected from myself.",
                    "I'm searching for something meaningful."
                ],
                selected: state.emotionalState,
                onBack: back,
                onSkip: { go(to: 5) },
                onSelect: { answer in
                    state.emotionalState = answer
                    autoAdvance(to: 5)
                }
            )
        case 5:
            CardQuestionScreen(
                progressIndex: 4,
                eyebrow: "ONE MORE",
                title: "What do you hope\nwalking gives you?",
                subtitle: nil,
                options: [
                    "A moment of stillness.",
                    "More energy and clarity.",
                    "A connection to something deeper.",
                    "A simple daily habit."
                ],
                selected: state.hopedOutcome,
                onBack: back,
                onSkip: { go(to: 6) },
                onSelect: { answer in
                    state.hopedOutcome = answer
                    autoAdvance(to: 6)
                }
            )
        case 6:
            PainMomentScreen(copy: state.painCopy, onBack: back) {
                go(to: 7)
            }
        case 7:
            CardQuestionScreen(
                progressIndex: 6,
                eyebrow: "QUESTION 1 OF 2",
                title: "Have you meditated\nbefore?",
                subtitle: nil,
                options: [
                    "Never - I'm completely new.",
                    "A little - I've tried a few times.",
                    "Yes - I have a regular practice."
                ],
                selected: state.meditationExp,
                onBack: back,
                onSkip: nil,
                onSelect: { answer in
                    state.meditationExp = answer
                    autoAdvance(to: 8)
                }
            )
        case 8:
            CardQuestionScreen(
                progressIndex: 7,
                eyebrow: "QUESTION 2 OF 2",
                title: "When do you feel most\nat peace?",
                subtitle: nil,
                options: [
                    "Walking outside in the morning.",
                    "Sitting quietly, doing nothing.",
                    "Being in nature or a garden.",
                    "Right before sleep, in silence."
                ],
                selected: state.peacefulMoment,
                onBack: back,
                onSkip: nil,
                onSelect: { answer in
                    state.peacefulMoment = answer
                    autoAdvance(to: 9)
                }
            )
        case 9:
            ChipQuestionScreen(
                progressIndex: 8,
                eyebrow: "PERSONALIZE YOUR PATH",
                title: "Where do you feel\nmost focused?",
                subtitle: "Select all that apply.",
                chips: ["Forest / Park", "City streets", "Temple grounds", "Around my home", "Near water", "Open fields", "Mountains", "Quiet indoor space"],
                emoji: ["🌲", "🏙️", "🕌", "🏡", "🌊", "🌄", "🏔️", "🏛️"],
                selected: $state.focusPlaces,
                buttonTitle: "Continue",
                onBack: back,
                onContinue: { go(to: 10) }
            )
        case 10:
            ChipQuestionScreen(
                progressIndex: 9,
                eyebrow: "ALMOST DONE",
                title: "What kind of\nguidance speaks to you?",
                subtitle: "Select all that apply.",
                chips: ["Silence-based", "Buddhist teaching", "Breathwork", "Body awareness", "Nature connection", "Gentle guidance", "Story & wisdom", "Sound & mantra"],
                emoji: ["🤫", "🙏", "🌬️", "🧘", "🌿", "💬", "📖", "🔔"],
                selected: $state.teachingTypes,
                buttonTitle: "Show My Spirit Match",
                onBack: back,
                onContinue: { go(to: 11) }
            )
        default:
            EmptyView()
        }
    }

    private func go(to nextScreen: Int) {
        previousScreen = screen
        if screen >= 2 && screen <= 10 && nextScreen >= 2 && nextScreen <= 10 {
            outgoingGroup2Screen = screen
            group2SlideDirection = nextScreen > screen ? 1 : -1
            group2SlideProgress = 0
            screen = nextScreen

            withAnimation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.56)) {
                group2SlideProgress = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                outgoingGroup2Screen = nil
            }
        } else {
            outgoingGroup2Screen = nil
            group2SlideProgress = 1
            withAnimation(.none) {
                screen = nextScreen
            }
        }
    }

    private func back() {
        guard screen > 2 else { return }
        go(to: screen - 1)
    }

    private func autoAdvance(to nextScreen: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            go(to: nextScreen)
        }
    }

    private func advanceSettling() {
        if settlingStep < 4 {
            withAnimation(.none) {
                settlingStep += 1
            }
        } else {
            go(to: 14)
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            Task { @MainActor in
                notificationsGranted = granted
            }
        }
    }

    private func currentLocationGranted() -> Bool {
        let status = CLLocationManager().authorizationStatus
        return status == .authorizedAlways || status == .authorizedWhenInUse
    }

    private func fireOnboardingCompleted() {
        Analytics.track(.onboardingCompleted(
            lineageId: state.spiritMatch.lineageId,
            pathId: state.pathIdWire,
            meditationExperience: state.meditationExp,
            peaceContext: state.peacefulMoment,
            environmentTagsCount: state.focusPlaces.count,
            guidanceTagsCount: state.teachingTypes.count,
            notificationsGranted: notificationsGranted,
            locationGranted: currentLocationGranted()
        ))
    }

    private func applyDebugStartIfNeeded() {
        #if DEBUG
        guard !didApplyDebugStart else { return }
        didApplyDebugStart = true

        guard let requestedScreen = ProcessInfo.processInfo.environment["SPIRITPATH_DEBUG_SCREEN"] else {
            return
        }

        state.emotionalState = "My mind won't slow down."
        state.hopedOutcome = "A moment of stillness."
        state.meditationExp = "Never - I'm completely new."
        state.peacefulMoment = "Walking outside in the morning."
        state.focusPlaces = ["Forest / Park", "Near water"]
        state.teachingTypes = ["Silence-based", "Nature connection"]
        state.selectedPath = "Mindful Walking"

        selectedPaywallPlan = "Yearly"
        settlingStep = 0

        if requestedScreen.hasPrefix("13") {
            screen = 13
            previousScreen = 13
            settlingStep = Int(requestedScreen.dropFirst(2)) ?? 0
            return
        }

        if let requestedNumber = Int(requestedScreen) {
            screen = requestedNumber
            previousScreen = requestedNumber
        }
        #endif
    }
}

private struct MotionLogoScreen: View {
    let onComplete: () -> Void
    @State private var showMoon = false
    @State private var showStar = false
    @State private var showWordmark = false

    var body: some View {
        ZStack {
            Color(hex: "#0B1628").ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack(alignment: .topTrailing) {
                    CrescentMoon(fill: .spiritGold, cutout: Color(hex: "#0B1628"))
                        .frame(width: 72, height: 72)
                        .scaleEffect(showMoon ? 1 : 0.6)
                        .opacity(showMoon ? 1 : 0)

                    Circle()
                        .fill(Color.spiritGold)
                        .frame(width: 8, height: 8)
                        .offset(x: 3, y: 4)
                        .scaleEffect(showStar ? 1 : 0.2)
                        .opacity(showStar ? 1 : 0)
                }

                Text("SpiritPath")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .offset(y: showWordmark ? 0 : 8)
                    .opacity(showWordmark ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showMoon = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    showStar = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showWordmark = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onComplete()
            }
        }
    }
}

private struct GetStartedScreen: View {
    let onStart: () -> Void

    var body: some View {
        Group2Screen(progressIndex: 1, showsBack: false, onBack: {}) {
            Spacer()

            VStack(spacing: 10) {
                OutlineMoon()
                    .frame(width: 48, height: 48)

                Text("SpiritPath")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.spiritPrimary)
            }

            Spacer().frame(height: 48)

            Text("Walk with intention.")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .frame(maxWidth: 280)

            Text("A 2,500-year tradition of mindful walking -\nmade for your daily life.")
                .font(.system(size: 16))
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 260)
                .padding(.top, 6)

            Spacer().frame(height: 56)

            PrimaryButton(title: "Get Started", action: onStart)

            Button(action: {}) {
                Text("Already have an account?  ")
                    .foregroundStyle(Color.spiritSecondary)
                + Text("Sign in")
                    .underline()
                    .foregroundStyle(Color.spiritSecondary)
            }
            .font(.system(size: 13))
            .padding(.top, 12)

            Spacer()
        }
    }
}

private struct ValuePropsScreen: View {
    let onBack: () -> Void
    let onReady: () -> Void

    var body: some View {
        Group2Screen(progressIndex: 2, showsBack: true, onBack: onBack) {
            Spacer().frame(height: 96)

            Text("Are you ready to walk\nwith purpose?")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .frame(maxWidth: 300)

            VStack(spacing: 0) {
                ValueRow(text: "Turn every step into meditation")
                Divider().background(Color(hex: "#E0E0E0"))
                ValueRow(text: "Find your spiritual guide")
                Divider().background(Color(hex: "#E0E0E0"))
                ValueRow(text: "Build a daily walking ritual")
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)

            Spacer()

            PrimaryButton(title: "I'm Ready", action: onReady)
                .padding(.bottom, 40)
        }
    }
}

private struct CardQuestionScreen: View {
    let progressIndex: Int
    let eyebrow: String
    let title: String
    let subtitle: String?
    let options: [String]
    let selected: String
    let onBack: () -> Void
    let onSkip: (() -> Void)?
    let onSelect: (String) -> Void

    var body: some View {
        Group2Screen(progressIndex: progressIndex, showsBack: true, onBack: onBack) {
            Spacer().frame(height: 82)

            Eyebrow(text: eyebrow)

            Text(title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.spiritMuted)
                    .padding(.top, 8)
            }

            VStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    SelectionCard(title: option, isSelected: selected == option) {
                        onSelect(option)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Spacer()

            if let onSkip {
                Button("Skip", action: onSkip)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#AAAAAA"))
                    .padding(.bottom, 34)
            }
        }
    }
}

private struct PainMomentScreen: View {
    let copy: PainCopy
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        Group2Screen(progressIndex: 5, showsBack: true, onBack: onBack) {
            Spacer().frame(height: 132)

            Text(copy.stat)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.spiritPrimary)

            Text(copy.subtext)
                .font(.system(size: 17))
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 260)
                .padding(.top, 8)

            Rectangle()
                .fill(Color.spiritPrimary)
                .frame(width: 40, height: 2)
                .padding(.vertical, 32)

            Text(copy.relief)
                .font(.system(size: 20, weight: .semibold))
                .lineSpacing(5)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .frame(maxWidth: 270)

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

private struct ChipQuestionScreen: View {
    let progressIndex: Int
    let eyebrow: String
    let title: String
    let subtitle: String
    let chips: [String]
    let emoji: [String]
    @Binding var selected: Set<String>
    let buttonTitle: String
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        Group2Screen(progressIndex: progressIndex, showsBack: true, onBack: onBack) {
            Spacer().frame(height: 82)

            Eyebrow(text: eyebrow)

            Text(title)
                .font(.system(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(Color.spiritMuted)
                .padding(.top, 8)

            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.element) { index, chip in
                    Chip(
                        title: "\(emoji[index]) \(chip)",
                        isSelected: selected.contains(chip)
                    ) {
                        if selected.contains(chip) {
                            selected.remove(chip)
                        } else {
                            selected.insert(chip)
                        }
                    }
                }
            }
            .frame(maxWidth: 342)
            .padding(.top, 20)

            Spacer()

            PrimaryButton(title: buttonTitle, isEnabled: !selected.isEmpty, action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

private struct SpiritMatchScreen: View {
    let match: SpiritMatch
    let onBegin: () -> Void

    var body: some View {
        CenterButtonScreen(buttonTitle: "Begin with \(match.shortName)", onButton: onBegin) {
            Text("Your spirit guide")
                .font(.system(size: 13))
                .tracking(1)
                .foregroundStyle(Color.spiritMuted)

            Text(match.shortName)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)
                .padding(.top, 8)

            Text(match.style)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .padding(.top, 8)

            Text(match.explanation)
                .font(.system(size: 15))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 280)
                .padding(.top, 48)
        }
    }
}

private struct PermissionTextScreen: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let linkTitle: String?
    let onButton: () -> Void
    let onLink: (() -> Void)?

    var body: some View {
        CenterButtonScreen(buttonTitle: buttonTitle, onButton: onButton, secondaryTitle: linkTitle, onSecondary: onLink) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)

            Text(subtitle)
                .font(.system(size: 16))
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 260)
                .padding(.top, 14)
        }
    }
}

private struct SettlingFlowScreen: View {
    let step: Int
    @Binding var soundOn: Bool
    let onButton: () -> Void
    let onSkipLocation: () -> Void
    let onRequestLocation: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PermissionTextScreen(
                title: content.title,
                subtitle: content.subtitle,
                buttonTitle: content.buttonTitle,
                linkTitle: step == 0 ? "Not now" : nil,
                onButton: step == 0 ? onRequestLocation : onButton,
                onLink: step == 0 ? onSkipLocation : nil
            )

            if (1...3).contains(step) {
                Button {
                    soundOn.toggle()
                } label: {
                    Text("🔔")
                        .font(.system(size: 20))
                        .opacity(soundOn ? 1 : 0.35)
                }
                .padding(.top, 58)
                .padding(.trailing, 26)
            }
        }
    }

    private var content: SettlingContent {
        switch step {
        case 0:
            return SettlingContent(title: "We walk with you.", subtitle: "To guide your steps accurately, SpiritPath\nneeds to know where you are.", buttonTitle: "Allow Location Access")
        case 1:
            return SettlingContent(title: "Soften your shoulders.", subtitle: "SETTLE INTO WALKING · 1 OF 3\n\nNotice the air touching your skin.", buttonTitle: "Next Step")
        case 2:
            return SettlingContent(title: "Let your breath move naturally.", subtitle: "SETTLE INTO WALKING · 2 OF 3\n\nThree unhurried steps. That's all.", buttonTitle: "Next Step")
        case 3:
            return SettlingContent(title: "Feel the ground beneath you.", subtitle: "SETTLE INTO WALKING · 3 OF 3\n\nIt has supported every step you've ever taken.", buttonTitle: "Finish Settling")
        default:
            return SettlingContent(title: "Something has already changed.", subtitle: "NOTICE WHAT SHIFTED\n\nMy breath feels steadier, and I notice more\nroom in my mind.", buttonTitle: "Continue")
        }
    }
}

private struct SettlingContent {
    let title: String
    let subtitle: String
    let buttonTitle: String
}

private struct PathSelectionScreen: View {
    @Binding var selectedPath: String
    let onContinue: () -> Void
    private let paths = ["Mindful Walking", "Everyday Mindfulness", "Awareness in Body", "Forest Retreat"]

    var body: some View {
        CenterButtonScreen(buttonTitle: "This Is My Path", isEnabled: !selectedPath.isEmpty, onButton: onContinue) {
            Text("Choose your path.")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)

            Text("Your choice shapes your first walking\nmeditations.")
                .font(.system(size: 16))
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 260)
                .padding(.top, 14)

            VStack(spacing: 24) {
                ForEach(paths, id: \.self) { path in
                    Button {
                        selectedPath = path
                    } label: {
                        Text(path)
                            .font(.system(size: 16, weight: .semibold))
                            .underline(selectedPath == path)
                            .foregroundStyle(Color.spiritPrimary)
                    }
                }
            }
            .padding(.top, 42)
        }
    }
}

private struct PaywallScreen: View {
    @Binding var selectedPlan: String
    let onTry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Walk further, together.")
                .onAppear {
                    Analytics.track(.paywallViewed(
                        paywallVariant: "default",     // Phase 2: read from feature_flags
                        triggerSource: "onboarding",   // this paywall fires during onboarding flow
                        hasPreviousTrial: false        // Phase 1.7: query user_subscriptions when auth wires
                    ))
                }
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)

            Text("Unlock your full practice and your\nmatched spirit guide's complete teachings.")
                .font(.system(size: 16))
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 280)
                .padding(.top, 14)

            VStack(spacing: 8) {
                Button {
                    selectedPlan = "Monthly"
                } label: {
                    Text("Monthly · ฿299 / month")
                        .font(.system(size: 15))
                        .underline(selectedPlan == "Monthly")
                        .foregroundStyle(Color.spiritSecondary)
                }

                Button {
                    selectedPlan = "Yearly"
                } label: {
                    VStack(spacing: 4) {
                        Text("Yearly · ฿149 / month")
                            .font(.system(size: 15, weight: .bold))
                            .underline(selectedPlan == "Yearly")
                            .foregroundStyle(Color.spiritPrimary)

                        Text("฿1,788 billed annually")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.spiritMuted)
                    }
                }
            }
            .padding(.top, 40)

            Text("★★★★★  4.9 * 2,400+ walkers")
                .font(.system(size: 13))
                .foregroundStyle(Color.spiritSecondary)
                .padding(.top, 28)

            Spacer()

            PrimaryButton(title: "Try Free for 7 Days", action: onTry)
                .padding(.bottom, 12)

            Text("No charge today · Cancel anytime")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#AAAAAA"))
                .padding(.bottom, 8)

            Text("Terms · Privacy · Restore")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "#CCCCCC"))
                .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct AuthScreen: View {
    let onAuth: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Create your account.")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritPrimary)

            Text("Save your path and spirit match\nacross all your devices.")
                .font(.system(size: 16))
                .lineSpacing(7)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.spiritSecondary)
                .frame(maxWidth: 260)
                .padding(.top, 14)

            VStack(spacing: 10) {
                AuthButton(title: "Continue with Apple", isPrimary: true, action: onAuth)
                AuthButton(title: "G  Continue with Google", action: onAuth)
                AuthButton(title: "Continue with Email", action: onAuth)
                AuthButton(title: "Continue with Phone", action: onAuth)
            }
            .padding(.horizontal, 24)
            .padding(.top, 46)

            Spacer()

            Text("By continuing, you agree to our Terms and Privacy Policy.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(hex: "#AAAAAA"))
                .frame(maxWidth: 260)
                .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
    }
}


private struct Group2Screen<Content: View>: View {
    let progressIndex: Int
    let showsBack: Bool
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

private struct Group2PagerShell<Content: View>: View {
    let progressIndex: Int
    let showsBack: Bool
    let onBack: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                ProgressSegments(active: progressIndex)
                    .frame(height: 3)
                    .padding(.top, 52)

                ZStack {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }

            if showsBack {
                Button(action: onBack) {
                    Text("←")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(Color.spiritPrimary)
                        .frame(width: 44, height: 44)
                }
                .padding(.top, 32)
                .padding(.leading, 12)
            }
        }
    }
}

private struct Group2PageSlider<Content: View>: View {
    let screen: Int
    let outgoingScreen: Int?
    let direction: Int
    let progress: Double
    let content: (Int) -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let outgoingScreen {
                    content(outgoingScreen)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .offset(x: -CGFloat(direction) * proxy.size.width * progress)
                }

                content(screen)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .offset(x: CGFloat(direction) * proxy.size.width * (1 - progress))
            }
            .compositingGroup()
            .animation(.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.56), value: progress)
        }
    }
}

private struct CenterButtonScreen<Content: View>: View {
    let buttonTitle: String
    var isEnabled = true
    let onButton: () -> Void
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: buttonTitle, isEnabled: isEnabled, action: onButton)
                .padding(.bottom, secondaryTitle == nil ? 40 : 12)

            if let secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    Text(secondaryTitle)
                        .font(.system(size: 14))
                        .underline()
                        .foregroundStyle(Color(hex: "#AAAAAA"))
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct ProgressSegments: View {
    let active: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...9, id: \.self) { index in
                Rectangle()
                    .fill(index <= active ? Color.spiritPrimary : Color(hex: "#E0E0E0"))
            }
        }
    }
}

private struct ValueRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.spiritPrimary)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.spiritPrimary)

            Spacer()
        }
        .padding(.vertical, 14)
    }
}

private struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .tracking(2)
            .foregroundStyle(Color.spiritMuted)
            .multilineTextAlignment(.center)
    }
}

private struct SelectionCard: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.spiritPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(isSelected ? Color(hex: "#F5F5F5") : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.spiritPrimary : Color(hex: "#CCCCCC"), lineWidth: isSelected ? 2 : 1)
            }
        }
    }
}

private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color.spiritPrimary)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(isSelected ? Color.spiritPrimary : .white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .clear : Color(hex: "#CCCCCC"), lineWidth: 1)
                }
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isEnabled ? Color.spiritPrimary : Color(hex: "#CCCCCC"))
                .clipShape(Capsule())
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 24)
    }
}

private struct AuthButton: View {
    let title: String
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isPrimary ? .white : Color.spiritPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(isPrimary ? Color.black : .white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isPrimary ? .clear : Color(hex: "#CCCCCC"), lineWidth: 1)
                }
        }
    }
}

private struct CrescentMoon: View {
    let fill: Color
    let cutout: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)

            Circle()
                .fill(cutout)
                .offset(x: 22, y: -6)
        }
        .compositingGroup()
    }
}

private struct OutlineMoon: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.spiritPrimary, lineWidth: 2)

            Circle()
                .fill(.white)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                }
                .offset(x: 14, y: -3)
        }
        .clipShape(Circle())
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 342
        let rows = rows(for: subviews, maxWidth: maxWidth)
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX + (bounds.width - row.width) / 2

            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }

            y += row.height + lineSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if proposedWidth > maxWidth, !currentItems.isEmpty {
                rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
                currentItems = [FlowItem(index: index, size: size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append(FlowItem(index: index, size: size))
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, width: currentWidth, height: currentHeight))
        }

        return rows
    }
}

private struct FlowRow {
    let items: [FlowItem]
    let width: CGFloat
    let height: CGFloat
}

private struct FlowItem {
    let index: Int
    let size: CGSize
}

private final class LocationPermissionRequester: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        let value = UInt64(sanitized, radix: 16) ?? 0

        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    // Onboarding palette · stark B&W editorial (unchanged · in-use across 21 screens)
    // Full reskin to navy/cream in a later round · preview-gated · see master plan §04
    static let spiritPrimary = Color(hex: "#111111")
    static let spiritSecondary = Color(hex: "#555555")
    static let spiritMuted = Color(hex: "#999999")
    static let spiritGold = Color(hex: "#F0C870")      // ← updated 2026-04-21 · matches prototype moon gold

    // Post-onboarding palette · warm dark devotional · from prototype tokens.jsx
    // Used by Phase 1+ surfaces: Home, Session, Reflection, Journey, Stillness, Profile, Settings
    // Ready-to-use tokens · wire into new SwiftUI views as they get built
    static let spiritNavy        = Color(hex: "#0A1424")     // surface · app bg
    static let spiritNavyLow     = Color(hex: "#111D33")     // surfaceLow · card
    static let spiritNavyRaised  = Color(hex: "#152544")     // surfaceLowest · raised card
    static let spiritNavyHigh    = Color(hex: "#1C2F54")     // surfaceHigh · selected
    static let spiritMidnight    = Color(hex: "#050A14")     // warmBlack · deepest bg (Stillness)
    static let spiritCream       = Color(hex: "#F4E8C8")     // ink · primary text on dark
    static let spiritCreamDeep   = Color(hex: "#E0D0A8")
    static let spiritGoldDeep    = Color(hex: "#C49A48")     // primaryDeep · accent shadow
    static let spiritGoldTint    = Color(hex: "#F7DCA0")     // primaryTint · highlight
    static let spiritRiver       = Color(hex: "#7FB3DD")     // secondary · river blue
    static let spiritOnGold      = Color(hex: "#0A1424")     // text on gold pill (reverse contrast)

    static let spiritInkSoft     = Color(hex: "#F4E8C8").opacity(0.82)   // body text on dark
    static let spiritInkMuted    = Color(hex: "#F4E8C8").opacity(0.58)   // captions
    static let spiritInkFaint    = Color(hex: "#F4E8C8").opacity(0.32)   // dormant UI
    static let spiritInkGhost    = Color(hex: "#F4E8C8").opacity(0.12)   // hairline borders
}

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
