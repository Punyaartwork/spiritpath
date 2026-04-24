//
//  RootTabView.swift
//  SpiritPath
//
//  Flat state-machine root · ZStack + switch · no TabView · no NavigationStack.
//  Tab bar overlay shown/hidden per Screen.showsTabBar.
//  Mirrors prototype app.jsx structure · cross-platform parity with Android RootTabView.
//

import SwiftUI

struct RootTabView: View {
    @Binding var screen: Screen

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch screen {
                case .home:
                    HomeView(onStartSession: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            screen = .session
                        }
                    })
                case .practice:   PracticeView()
                case .journey:    JourneyView()
                case .stillness:  StillnessView()
                case .session:    SessionView(screen: $screen)
                case .reflection: ReflectionView(screen: $screen)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground(style: screen == .stillness ? .night : .day))

            if screen.showsTabBar {
                SpiritTabBar(screen: $screen)
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var screen: Screen = .home
        var body: some View { RootTabView(screen: $screen) }
    }
    return PreviewWrapper()
}
