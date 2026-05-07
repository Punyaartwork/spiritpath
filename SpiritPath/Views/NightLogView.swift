//
//  NightLogView.swift
//  SpiritPath
//
//  Phase 2.4b · Before-sleep reflection · 3-field encrypted log.
//  Port of prototype src/screen-stillness-subs.jsx:330-393 (NightLogScreen).
//
//  Tone rules locked verbatim cross-platform · do NOT paraphrase eyebrow labels,
//  placeholders, button labels, hero, subtext, or footer quote. Footer is
//  intentionally unattributed in UI per prototype.
//
//  Encryption: client-side AES-256-GCM via NightLogCrypto · server sees opaque
//  ciphertext only · key device-bound in Keychain (uninstall = permanent loss
//  of older entries · documented in Settings copy V7 line 65-69).
//
//  Save UX: tap "Close the day" → button flips to "Rest well" + save runs in
//  parallel with 0.9s grace · dismiss when save succeeds + grace elapsed.
//  Save failure reverts the button and surfaces saveError.
//

import Observation
import SwiftUI

// MARK: · ViewModel

@Observable
final class NightLogViewModel {
    var one: String = ""
    var letGo: String = ""
    var tomorrow: String = ""

    var saving: Bool = false
    var saved: Bool = false
    var saveError: String?

    @ObservationIgnored
    private let repo: NightLogRepository

    init(repo: NightLogRepository = .shared) {
        self.repo = repo
    }

    /// Encrypt + persist. Returns true on success.
    @MainActor
    func save() async -> Bool {
        guard !saving else { return false }
        saving = true
        saveError = nil
        defer { saving = false }

        let trim = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        let plaintext = NightLogPlaintext(
            one: trim(one),
            letGo: trim(letGo),
            tomorrow: trim(tomorrow)
        )
        do {
            try await repo.save(plaintext)
            saved = true
            return true
        } catch {
            saveError = String(describing: error)
            return false
        }
    }
}

// MARK: · View

struct NightLogView: View {
    let onDismiss: () -> Void

    @State private var vm = NightLogViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case one, letGo, tomorrow }

    var body: some View {
        ZStack(alignment: .top) {
            background
            content
            backButton
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    // MARK: · background

    private var background: some View {
        LinearGradient(
            colors: [Color(hex: "#0A1628"), Color(hex: "#04080F")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: · back button

    private var backButton: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appCream)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(Color.appCream.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: · content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                fieldOne
                fieldLetGo
                fieldTomorrow
                closeButton
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 80)        // clear back-button row
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: · header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Before sleep", color: AppTheme.Accent.primary)
            Text("The night is long enough\nfor rest.")
                .font(.custom("DMSerifDisplay-Italic", size: 28))
                .foregroundStyle(AppTheme.Ink.primary)
                .lineSpacing(2)
            Text("A small log before you close your eyes.\nNo pressure. Leave blank what doesn't fit.")
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.soft)
                .lineSpacing(3)
        }
        .padding(.bottom, 36)
    }

    // MARK: · fields

    private var fieldOne: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "ONE WORD FOR TODAY", color: AppTheme.Accent.primary)
            TextField("", text: $vm.one, prompt:
                Text("one word…")
                    .font(.custom("DMSerifDisplay-Italic", size: 20))
                    .foregroundColor(AppTheme.Ink.faint)
            )
            .font(.custom("DMSerifDisplay-Italic", size: 20))
            .foregroundStyle(AppTheme.Ink.primary)
            .multilineTextAlignment(.center)
            .submitLabel(.next)
            .focused($focusedField, equals: .one)
            .onChange(of: vm.one) { _, newValue in
                if newValue.count > 20 { vm.one = String(newValue.prefix(20)) }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(Color.appCream.opacity(0.05))
            )
        }
        .padding(.bottom, 28)
    }

    private var fieldLetGo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "SOMETHING TO SET DOWN", color: AppTheme.Accent.primary)
            multiLineEditor(
                text: $vm.letGo,
                placeholder: "What did you carry today that you don't need to carry into sleep?",
                minHeight: 84,
                field: .letGo
            )
        }
        .padding(.bottom, 28)
    }

    private var fieldTomorrow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "A SMALL INTENTION FOR TOMORROW", color: AppTheme.Accent.primary)
            multiLineEditor(
                text: $vm.tomorrow,
                placeholder: "One small thing. Not a plan.",
                minHeight: 64,
                field: .tomorrow
            )
        }
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func multiLineEditor(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat,
        field: Field
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(Color.appCream.opacity(0.05))
                .frame(minHeight: minHeight)

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .padding(14)
                    .allowsHitTesting(false)
            }

            TextEditor(text: text)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(AppTheme.Ink.primary)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: minHeight)
                .focused($focusedField, equals: field)
        }
    }

    // MARK: · close button

    private var closeButton: some View {
        Button(action: onCloseDay) {
            Text(vm.saved ? "Rest well" : "Close the day")
                .font(.custom("Manrope", size: 15))
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
        .disabled(vm.saved || vm.saving)
        .opacity(vm.saved ? 0.9 : 1.0)
        .padding(.bottom, 28)
    }

    // MARK: · footer (intentionally unattributed)

    private var footer: some View {
        Text("Let the day finish\nits own sentence.")
            .font(.custom("DMSerifDisplay-Italic", size: 13))
            .foregroundStyle(Color.appCream.opacity(0.4))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
    }

    // MARK: · save flow

    private func onCloseDay() {
        focusedField = nil
        vm.saved = true                        // optimistic flip · button shows "Rest well"
        let saveTask = Task { await vm.save() }
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)  // 0.9s grace
            let ok = await saveTask.value
            if ok {
                onDismiss()
            } else {
                vm.saved = false               // revert · saveError surfaced via vm
            }
        }
    }
}

#Preview {
    NightLogView(onDismiss: {})
}
