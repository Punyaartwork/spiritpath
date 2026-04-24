//
//  SacredLine.swift
//  SpiritPath
//
//  Thin progress bar · gold fill over ghost rail · 2pt height.
//  Used by HomeView MomentsCard to show mindful-steps progress.
//

import SwiftUI

struct SacredLine: View {
    let progress: Double  // 0.0 – 1.0 · clamped internally
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.Ink.ghost)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 2)
    }
}

#Preview {
    VStack(spacing: 24) {
        SacredLine(progress: 0.3, color: AppTheme.Accent.primary)
        SacredLine(progress: 0.62, color: AppTheme.Accent.primary)
        SacredLine(progress: 0.95, color: AppTheme.Accent.primary)
    }
    .padding()
    .background(AppTheme.Surface.background)
}
