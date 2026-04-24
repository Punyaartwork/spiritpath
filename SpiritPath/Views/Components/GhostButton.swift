//
//  GhostButton.swift
//  SpiritPath
//
//  Ghost-style pill · ink-ghost border · cream text · uppercase tracking.
//  Used for End Session · Discard · other non-primary actions.
//

import SwiftUI

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Manrope", size: 12))
                .fontWeight(.semibold)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Ink.primary)
                .padding(.horizontal, 36)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        GhostButton(title: "End Session", action: {})
    }
}
