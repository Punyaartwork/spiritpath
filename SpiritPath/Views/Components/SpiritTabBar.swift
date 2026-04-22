//
//  SpiritTabBar.swift
//  SpiritPath
//
//  4-tab custom bar · gold active · muted ink inactive · easeInOut 0.5s on tap.
//  Rendered as overlay in RootTabView · hidden on modal screens (session · reflection).
//  SF Symbols for Phase 1.1 · replace with custom stroke icons in Phase 2 polish.
//

import SwiftUI

struct SpiritTabBar: View {
    @Binding var screen: Screen

    private struct Tab: Identifiable {
        let id: Screen
        let icon: String
        let label: String
    }

    private let tabs: [Tab] = [
        Tab(id: .home,      icon: "house.fill",      label: "Home"),
        Tab(id: .practice,  icon: "figure.walk",     label: "Practice"),
        Tab(id: .journey,   icon: "map.fill",        label: "Journey"),
        Tab(id: .stillness, icon: "moon.stars.fill", label: "Stillness")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        screen = tab.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .regular))
                        Text(tab.label)
                            .font(.custom("Manrope", size: 10))
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(
                        screen == tab.id
                            ? AppTheme.Accent.primary
                            : AppTheme.Ink.muted
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.xs)
        .frame(height: 56)
        .background(
            ZStack(alignment: .top) {
                AppTheme.Surface.card
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(AppTheme.Ink.ghost)
            }
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var screen: Screen = .home
        var body: some View {
            VStack {
                Spacer()
                SpiritTabBar(screen: $screen)
            }
            .background(AppTheme.Surface.background)
        }
    }
    return PreviewWrapper()
}
