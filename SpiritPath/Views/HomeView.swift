//
//  HomeView.swift
//  SpiritPath
//
//  Placeholder · Phase 1.2 fills with greeting · Moments in motion · gold mindful card ·
//  Tonight's Path · Daily Journey · stat row · ForestScene SVG · DayArc.
//  Port from prototype src/screen-home.jsx verbatim copy.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Home").appText(.displayLG)
            Text("greeting · Tonight's Path · insight pills").appText(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        HomeView()
    }
}
