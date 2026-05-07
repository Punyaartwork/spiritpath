//
//  NightLogView.swift
//  SpiritPath
//
//  Phase 2.3 nav stub · placeholder · Phase 2.4b ships C1 AES-256-GCM encryption +
//  3-prompt night log layout (one_word · let_go · tomorrow_intention).
//
//  Reading: prototype src/screen-stillness-subs.jsx:330-394.
//

import SwiftUI

struct NightLogView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#0a1628"), Color(hex: "#04080f")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                stillnessBackRow
                Spacer(minLength: 60)
                Eyebrow(text: "Before sleep")
                Text("The night is long enough\nfor rest.")
                    .font(.custom("DMSerifDisplay-Italic", size: 28))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                Text("Phase 2.4b · encrypted night log · coming next.")
                    .font(.custom("Manrope", size: 12))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                Spacer()
            }
        }
    }

    private var stillnessBackRow: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Stillness")
                        .font(.custom("Manrope", size: 11))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(AppTheme.Ink.primary.opacity(0.08))
                        .overlay(
                            Capsule()
                                .strokeBorder(AppTheme.Ink.primary.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Ink.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 52)
    }
}

#Preview {
    NightLogView(onDismiss: {})
}
