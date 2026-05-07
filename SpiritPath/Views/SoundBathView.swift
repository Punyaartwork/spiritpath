//
//  SoundBathView.swift
//  SpiritPath
//
//  Phase 2.3 nav stub · placeholder · Phase 2.5 ships ambient bundle + AVAudioEngine
//  player + 5-soundscape picker (silence · rain · forest · bells · stream).
//
//  Reading: prototype src/screen-stillness-subs.jsx:399-523.
//

import SwiftUI

struct SoundBathView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(hex: "#152d55"), Color(hex: "#0a1628")],
                center: .top,
                startRadius: 0,
                endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                stillnessBackRow
                Spacer(minLength: 60)
                Eyebrow(text: "Sound bath")
                Text("Choose your room.")
                    .font(.custom("DMSerifDisplay-Italic", size: 26))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .padding(.top, 10)
                Text("Phase 2.5 · ambient soundscapes · coming next.")
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
    SoundBathView(onDismiss: {})
}
