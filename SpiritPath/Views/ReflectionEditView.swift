//
//  ReflectionEditView.swift
//  SpiritPath
//
//  Phase 2.7b · edit form for a previously submitted reflection · pushed from
//  ReflectionHistoryView card tap · pre-fills note_text + anchor_phrase from the
//  loaded ReflectionRow · "Save changes" UPDATE-by-id · M26 reflection_edited fires
//  AFTER UPDATE succeeds (best-effort · network failure = no fire · view stays open).
//
//  Privacy lock (M11 baseline preserved):
//    - Mixpanel receives char COUNTS only (before + after) · NEVER note text
//    - Supabase receives the text payload over TLS (storage authoritative)
//
//  Tone (verbatim per brief):
//    - "Save changes" button (NOT "Save" · NOT "Update" · NOT "Done")
//    - Disabled: gold/40 · enabled: gold/100
//    - No exclamation marks · no toast · silent dismiss on success
//

import SwiftUI

// MARK: · ViewModel · @Observable (iOS 17+ Observation framework)

@MainActor
@Observable
final class ReflectionEditViewModel {

    /// Loaded reflection · captured at view creation · drives "before" snapshots for M26.
    let originalRow: ReflectionRow

    // MARK: · Editable state · @Bindable in ReflectionEditView

    var noteText: String
    var anchorPhrase: String

    // MARK: · Save lifecycle

    var savingInProgress: Bool = false
    var errorMessage: String?

    /// True iff user has changed note_text OR anchor_phrase from loaded values.
    /// Drives "Save changes" enabled state (gold/100) vs disabled (gold/40).
    /// Trim before compare so accidental trailing whitespace doesn't enable the button.
    var hasEdits: Bool {
        let originalNote = originalRow.noteText ?? ""
        let originalAnchor = (originalRow.anchorPhrase ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let newAnchor = anchorPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return noteText != originalNote || newAnchor != originalAnchor
    }

    init(originalRow: ReflectionRow) {
        self.originalRow = originalRow
        self.noteText = originalRow.noteText ?? ""
        self.anchorPhrase = originalRow.anchorPhrase ?? ""
    }

    /// Save edited reflection · fires M26 AFTER UPDATE succeeds.
    /// Returns true on success · caller dismisses view.
    /// On failure: errorMessage set · view stays open · button re-enabled.
    func save() async -> Bool {
        guard hasEdits, !savingInProgress else { return false }
        savingInProgress = true
        errorMessage = nil
        defer { savingInProgress = false }

        let normalizedAnchor = anchorPhrase.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await SessionRepository.shared.updateReflection(
                id: originalRow.id,
                noteText: noteText,
                anchorPhrase: normalizedAnchor.isEmpty ? nil : normalizedAnchor
            )
        } catch {
            // Single-line · no exclamation · per brief tone rules.
            errorMessage = "Couldn't save. Check connection and try again."
            return false
        }

        // M26 fires AFTER UPDATE succeeds · privacy lock: char COUNTS only · NEVER text.
        let before = originalRow.noteLengthChars
        let after = noteText.count
        let timeSince = max(0, Int(Date().timeIntervalSince(originalRow.createdAt)))
        let originalAnchor = (originalRow.anchorPhrase ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let anchorChanged = normalizedAnchor != originalAnchor

        Analytics.track(.reflectionEdited(
            noteLengthCharsBefore: before,
            noteLengthCharsAfter: after,
            timeSinceSubmitSec: timeSince,
            anchorPhraseChanged: anchorChanged
        ))

        return true
    }
}

// MARK: · View

struct ReflectionEditView: View {
    @State private var viewModel: ReflectionEditViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var noteFocused: Bool

    init(reflection: ReflectionRow) {
        _viewModel = State(initialValue: ReflectionEditViewModel(originalRow: reflection))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                noteCard(viewModel: viewModel)
                anchorCard(viewModel: viewModel)
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(AppTheme.Accent.primary)
                        .padding(.horizontal, 22)
                }
                Spacer(minLength: 60)
            }
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground(style: .day))
        .navigationTitle("Edit reflection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        let success = await viewModel.save()
                        if success { dismiss() }
                    }
                } label: {
                    Text("Save changes")
                        .font(.custom("Manrope", size: 14))
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            viewModel.hasEdits
                                ? AppTheme.Accent.primary
                                : AppTheme.Accent.primary.opacity(0.4)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.hasEdits || viewModel.savingInProgress)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { noteFocused = false }
                    .font(.system(size: 17, weight: .semibold))
            }
        }
    }

    // MARK: · header · echoes Phase 1.5 ReflectionView tone

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: "Reflection")
            Text(relativeCreatedAt)
                .font(.custom("DMSerifDisplay-Italic", size: 18))
                .foregroundStyle(AppTheme.Ink.soft)
        }
        .padding(.horizontal, 22)
    }

    private var relativeCreatedAt: String {
        Self.relativeFormatter.localizedString(for: viewModel.originalRow.createdAt, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    // MARK: · note card · mirrors Phase 1.5 ReflectionView styling

    private func noteCard(viewModel: ReflectionEditViewModel) -> some View {
        @Bindable var bound = viewModel

        return AtmCard(tone: .high, padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Accent.secondary)
                    Text("Your reflection")
                        .font(.custom("DMSerifDisplay-Italic", size: 16))
                        .foregroundStyle(AppTheme.Ink.primary)
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Surface.card)
                        .frame(minHeight: 140)

                    if bound.noteText.isEmpty {
                        // Placeholder · no encouragement · matches Phase 1.5 tone.
                        Text("Edit your reflection…")
                            .font(.custom("Manrope", size: 14))
                            .foregroundStyle(AppTheme.Ink.muted)
                            .padding(14)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $bound.noteText)
                        .font(.custom("Manrope", size: 14))
                        .foregroundStyle(AppTheme.Ink.primary)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 140)
                        .focused($noteFocused)
                }
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: · anchor card · TextField · pre-filled · Phase 1.5 picker not yet built · free-form OK

    private func anchorCard(viewModel: ReflectionEditViewModel) -> some View {
        @Bindable var bound = viewModel

        return AtmCard(tone: .high, padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Accent.secondary)
                    Text("Anchor phrase")
                        .font(.custom("DMSerifDisplay-Italic", size: 16))
                        .foregroundStyle(AppTheme.Ink.primary)
                }

                TextField(
                    "",
                    text: $bound.anchorPhrase,
                    prompt: Text("e.g. Buddho")
                        .font(.custom("Manrope", size: 14))
                        .foregroundStyle(AppTheme.Ink.muted)
                )
                .font(.custom("DMSerifDisplay-Italic", size: 16))
                .foregroundStyle(AppTheme.Ink.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Surface.card)
                )
            }
        }
        .padding(.horizontal, 22)
    }
}

#Preview {
    let preview = ReflectionRow(
        id: UUID().uuidString,
        userId: UUID().uuidString,
        sessionId: UUID().uuidString,
        noteText: "The cool air against my skin, the sound of dry leaves underfoot, a faint chime from somewhere distant.",
        anchorPhrase: "Buddho",
        createdAt: Date().addingTimeInterval(-3 * 86400),
        updatedAt: nil,
        sessions: ReflectionRow.SessionEmbed(lineageId: "sodh", stageIndexAtTime: 2)
    )
    return NavigationStack {
        ReflectionEditView(reflection: preview)
    }
}
