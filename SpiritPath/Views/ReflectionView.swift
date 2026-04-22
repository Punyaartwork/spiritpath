//
//  ReflectionView.swift
//  SpiritPath
//
//  Placeholder · Phase 1.3 fills with anchor phrase · note text entry · save → .home.
//  Port from prototype src/screen-reflection.jsx.
//  Fires reflection_submitted event (stubbed in Analytics enum · Phase 1.3).
//

import SwiftUI

struct ReflectionView: View {
    @Binding var screen: Screen

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Reflection").appText(.displayLG)
            Text("anchor phrase · note · save").appText(.body)

            Button {
                withAnimation(.easeInOut(duration: 0.5)) {
                    screen = .home
                }
            } label: {
                Text("Save · return to Home")
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
        @State var screen: Screen = .reflection
        var body: some View {
            ZStack {
                AppBackground(style: .day)
                ReflectionView(screen: $screen)
            }
        }
    }
    return PreviewWrapper()
}
