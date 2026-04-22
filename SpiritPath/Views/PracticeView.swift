//
//  PracticeView.swift
//  SpiritPath
//
//  Placeholder · Phase 1.3 fills with Tonight's Path · pick path/duration/place ·
//  begin button that transitions to .session.
//  Port from prototype src/screen-practice.jsx.
//

import SwiftUI

struct PracticeView: View {
    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Text("Practice").appText(.displayLG)
            Text("Tonight's Path · duration · environment · begin").appText(.body)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        PracticeView()
    }
}
