//
//  SessionView.swift
//  SpiritPath
//
//  Placeholder · Phase 1.3 fills with active timer · phase guide · step counter ·
//  complete → .reflection · discard → .home.
//  Port from prototype src/screen-session.jsx.
//  Fires session_started + session_ended events (stubbed in Analytics enum · Phase 1.3).
//

import SwiftUI

struct SessionView: View {
    @Binding var screen: Screen

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Session").appText(.displayLG)
            Text("active timer · phase guide · step counter").appText(.body)

            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    screen = .home
                }
            } label: {
                Text("End · return to Home")
                    .appText(.label)
                    .padding(.horizontal, AppTheme.Spacing.xl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.pill)
                            .fill(AppTheme.Accent.primary)
                    )
                    .foregroundStyle(AppTheme.Accent.onPrimary)
            }
            .padding(.top, AppTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var screen: Screen = .session
        var body: some View {
            ZStack {
                AppBackground(style: .day)
                SessionView(screen: $screen)
            }
        }
    }
    return PreviewWrapper()
}
