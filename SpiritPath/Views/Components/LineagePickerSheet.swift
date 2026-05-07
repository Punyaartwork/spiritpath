//
//  LineagePickerSheet.swift
//  SpiritPath
//
//  Phase 2.1 · bottom sheet · 3 hardcoded lineage options · gold checkmark on current.
//  Mirrors Android b9d9a25 LineageDisplayConstants → ModalBottomSheet ordering.
//
//  Same-selection no-op handled by caller (JourneyViewModel) so we don't fire
//  lineage_changed when the user re-confirms their current lineage.
//

import SwiftUI

struct LineagePickerOption: Identifiable, Equatable {
    let id: String          // wire value · "mun" · "sodh" · "chah"
    let displayName: String
    let style: String       // descriptor under the name
}

/// Cross-platform locked · matches Android LineageDisplayConstants.
/// Order: mun (forest) · sodh (inner light) · chah (forest · WPP).
enum LineagePickerOptions {
    static let options: [LineagePickerOption] = [
        LineagePickerOption(
            id: "mun",
            displayName: "Luang Pu Mun",
            style: "Forest · Kammaṭṭhāna"
        ),
        LineagePickerOption(
            id: "sodh",
            displayName: "Luang Pu Sodh",
            style: "Inner Light · Mantra Stillness"
        ),
        LineagePickerOption(
            id: "chah",
            displayName: "Luang Por Chah",
            style: "Forest · Wat Pah Pong"
        )
    ]
}

struct LineagePickerSheet: View {
    let currentLineageId: String
    let onSelect: (String) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
                .padding(.top, 10)
                .padding(.bottom, 18)

            Eyebrow(text: "Choose your spirit guide")
                .padding(.horizontal, 22)

            Text("Your guide shapes the teachings\nyou walk through.")
                .font(.custom("DMSerifDisplay-Italic", size: 22))
                .foregroundStyle(AppTheme.Ink.primary)
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 18)

            VStack(spacing: 10) {
                ForEach(LineagePickerOptions.options) { option in
                    optionRow(option)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Surface.background)
    }

    private var handle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(AppTheme.Ink.faint)
                .frame(width: 36, height: 4)
            Spacer()
        }
    }

    private func optionRow(_ option: LineagePickerOption) -> some View {
        let active = option.id == currentLineageId
        return Button {
            onSelect(option.id)
            isPresented = false
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.displayName)
                        .font(.custom("DMSerifDisplay-Italic", size: 17))
                        .foregroundStyle(active ? AppTheme.Accent.primary : AppTheme.Ink.primary)
                    Text(option.style)
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(AppTheme.Ink.muted)
                }
                Spacer()
                if active {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Accent.primary)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.Accent.onPrimary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(active ? AppTheme.Surface.selected : AppTheme.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .strokeBorder(
                        active ? AppTheme.Accent.primary : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var current: String = "sodh"
        @State var presented: Bool = true
        var body: some View {
            ZStack {
                AppBackground(style: .day)
            }
            .sheet(isPresented: $presented) {
                LineagePickerSheet(
                    currentLineageId: current,
                    onSelect: { current = $0 },
                    isPresented: $presented
                )
                .presentationDetents([.medium])
            }
        }
    }
    return PreviewWrapper()
}
