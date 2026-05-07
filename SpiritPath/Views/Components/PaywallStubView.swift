//
//  PaywallStubView.swift
//  SpiritPath
//
//  Phase 2.2 stub paywall · shown when stageIndex >= 2 AND no active subscription.
//  Phase 1.7b ships StoreKit2 wiring · Apple Developer-parked separately.
//
//  Fires paywall_viewed event (M6 baseline) with trigger_source="stage_locked"
//  + stage-specific reason so analytics can slice paywall views by gate type.
//

import SwiftUI

struct PaywallStubView: View {
    let stageIndex: Int
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            backRow
            Spacer(minLength: 40)
            lockGlyph
            Text("Stage \(stageIndex)\nis on the path ahead.")
                .font(.custom("DMSerifDisplay-Italic", size: 28))
                .foregroundStyle(AppTheme.Ink.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 24)
            Text("Continue with the deeper teachings\nwhen you are ready.")
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(AppTheme.Ink.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)
            Spacer()
            Button {
                // Phase 1.7b · purchase flow · stub for now.
                onDismiss()
            } label: {
                Text("Continue the Journey")
                    .font(.custom("Manrope", size: 14))
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.Accent.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.pill)
                            .fill(AppTheme.Accent.primary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Button(action: onDismiss) {
                Text("NOT NOW")
                    .font(.custom("Manrope", size: 11))
                    .fontWeight(.semibold)
                    .tracking(2.0)
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground(style: .day))
        .onAppear {
            Analytics.track(.paywallViewed(
                paywallVariant: "default",
                triggerSource: "stage_locked",
                hasPreviousTrial: false
            ))
        }
    }

    private var backRow: some View {
        HStack {
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Back")
                        .font(.custom("Manrope", size: 13))
                        .fontWeight(.medium)
                }
                .foregroundStyle(AppTheme.Ink.soft)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var lockGlyph: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Accent.primary.opacity(0.10))
                .frame(width: 100, height: 100)
            Circle()
                .strokeBorder(AppTheme.Accent.primary.opacity(0.40), lineWidth: 1)
                .frame(width: 100, height: 100)
            Image(systemName: "lock")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(AppTheme.Accent.primary)
        }
    }
}

#Preview {
    PaywallStubView(stageIndex: 3, onDismiss: {})
}
