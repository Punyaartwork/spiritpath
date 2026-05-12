//
//  ReflectionHistoryView.swift
//  SpiritPath
//
//  Phase 2.7b · list of past reflections · pushed from Settings → "Past reflections" row.
//  Search anchor_phrase (server-side ilike · 300ms debounced) · filter by lineage + stage
//  (client-side post-fetch · 50-row cap makes it perceptibly free). Tap card → ReflectionEditView
//  (pushed onto same NavigationStack · pop-back triggers .task re-fetch · row reflects edits).
//
//  Tone (verbatim per brief):
//    - "Past reflections" eyebrow header (NOT "History" · NOT "Journal")
//    - "No reflections yet" empty state (period · no encouragement)
//    - "Couldn't load history. Pull to retry." error state (no exclamation)
//    - Anchor phrase displayed in DM Serif Display Italic
//    - Card preview 3 lines · "…" Unicode ellipsis (iOS default truncation)
//    - Relative date format ("2 days ago" / "yesterday" / "today")
//

import SwiftUI
import Supabase

// MARK: · ViewModel · @Observable

@MainActor
@Observable
final class ReflectionHistoryViewModel {

    enum LoadState: Equatable {
        case loading
        case loaded(rows: [ReflectionRow])
        case empty
        case error(String)

        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.empty, .empty): return true
            case (.loaded(let l), .loaded(let r)):       return l.map(\.id) == r.map(\.id)
            case (.error(let l), .error(let r)):         return l == r
            default:                                     return false
            }
        }
    }

    var state: LoadState = .loading
    var searchAnchor: String = ""
    var filterLineage: String? = nil   // nil = all
    var filterStage: Int? = nil         // nil = all

    /// Debounce handle · cancelled on next keystroke so only the trailing-edge query fires.
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    /// Fetch reflections with current filter state.
    /// Sets `.loading` first · then `.loaded` / `.empty` / `.error` based on outcome.
    func load() async {
        state = .loading
        guard let userId = supabase.auth.currentUser?.id.uuidString else {
            // Auth not wired (Phase 1.7a parked) · render empty rather than error · matches
            // SettingsViewModel.loadProfile defensive default.
            state = .empty
            return
        }
        do {
            let rows = try await SessionRepository.shared.listReflections(
                userId: userId,
                lineageId: filterLineage,
                stageIndex: filterStage,
                searchAnchor: searchAnchor.isEmpty ? nil : searchAnchor
            )
            state = rows.isEmpty ? .empty : .loaded(rows: rows)
        } catch {
            state = .error("Couldn't load history. Pull to retry.")
        }
    }

    /// Debounced reload · 300ms after last keystroke fires the actual `load()`.
    /// Cancels any in-flight debounce so only one network call runs per pause.
    func scheduleSearchReload() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    /// Filter chip taps reload immediately (no debounce · single discrete event).
    func setLineageFilter(_ value: String?) {
        filterLineage = value
        Task { await load() }
    }

    func setStageFilter(_ value: Int?) {
        filterStage = value
        Task { await load() }
    }
}

// MARK: · View

struct ReflectionHistoryView: View {
    @State private var viewModel = ReflectionHistoryViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchField(viewModel: viewModel)
                filterChipsRow(viewModel: viewModel)
                content(viewModel: viewModel)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(AppBackground(style: .day))
        .navigationTitle("Past reflections")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: · header (eyebrow)

    private var header: some View {
        Eyebrow(text: "Past reflections")
            .padding(.horizontal, 4)
    }

    // MARK: · search field

    private func searchField(viewModel: ReflectionHistoryViewModel) -> some View {
        @Bindable var bound = viewModel

        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Ink.muted)

            TextField(
                "",
                text: $bound.searchAnchor,
                prompt: Text("Search anchor phrase")
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(AppTheme.Ink.muted)
            )
            .font(.custom("Manrope", size: 14))
            .foregroundStyle(AppTheme.Ink.primary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: bound.searchAnchor) { _, _ in
                bound.scheduleSearchReload()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Surface.card)
        )
    }

    // MARK: · filter chips (3 lineage · 5 stage · default "All")

    private func filterChipsRow(viewModel: ReflectionHistoryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            chipRow(
                label: "Lineage",
                options: [
                    ("All",  nil as String?),
                    ("Mun",  "mun"),
                    ("Sodh", "sodh"),
                    ("Chah", "chah")
                ],
                current: viewModel.filterLineage,
                onChange: { viewModel.setLineageFilter($0) }
            )

            chipRow(
                label: "Stage",
                options: [
                    ("All", nil as Int?),
                    ("1",   1),
                    ("2",   2),
                    ("3",   3),
                    ("4",   4),
                    ("5",   5)
                ],
                current: viewModel.filterStage,
                onChange: { viewModel.setStageFilter($0) }
            )
        }
    }

    private func chipRow<T: Equatable>(
        label: String,
        options: [(label: String, value: T?)],
        current: T?,
        onChange: @escaping (T?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("Manrope", size: 11))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Ink.muted)
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options.indices, id: \.self) { idx in
                        let option = options[idx]
                        let active = option.value == current
                        Button {
                            onChange(option.value)
                        } label: {
                            Text(option.label)
                                .font(.custom("Manrope", size: 12))
                                .fontWeight(.medium)
                                .foregroundStyle(
                                    active ? AppTheme.Accent.onPrimary : AppTheme.Ink.soft
                                )
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(
                                            active
                                                ? AppTheme.Accent.primary
                                                : AppTheme.Surface.raised
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: · content · loading / loaded / empty / error

    @ViewBuilder
    private func content(viewModel: ReflectionHistoryViewModel) -> some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(AppTheme.Accent.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

        case .loaded(let rows):
            LazyVStack(spacing: 12) {
                ForEach(rows) { row in
                    NavigationLink(value: row.id) {
                        ReflectionCard(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: String.self) { reflectionId in
                if case .loaded(let rows) = viewModel.state,
                   let row = rows.first(where: { $0.id == reflectionId }) {
                    ReflectionEditView(reflection: row)
                } else {
                    Text("Not available")
                        .foregroundStyle(AppTheme.Ink.muted)
                }
            }

        case .empty:
            Text("No reflections yet")
                .font(.custom("Manrope", size: 15))
                .foregroundStyle(AppTheme.Ink.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 60)

        case .error(let message):
            Text(message)
                .font(.custom("Manrope", size: 14))
                .foregroundStyle(AppTheme.Ink.soft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }
}

// MARK: · ReflectionCard · single row in the list

private struct ReflectionCard: View {
    let row: ReflectionRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(relativeDateString)
                    .font(.custom("Manrope", size: 12))
                    .foregroundStyle(AppTheme.Ink.muted)
                Spacer()
                if let stageIndex = row.stageIndex {
                    stageBadge(stageIndex)
                }
            }

            if let anchor = row.anchorPhrase?.trimmingCharacters(in: .whitespacesAndNewlines),
               !anchor.isEmpty {
                Text(anchor)
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Accent.primary)
                    .lineLimit(1)
            }

            if let preview = previewText {
                Text(preview)
                    .font(.custom("Manrope", size: 14))
                    .foregroundStyle(AppTheme.Ink.soft)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                .fill(AppTheme.Surface.card)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                        .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                )
        )
    }

    private var previewText: String? {
        let text = (row.noteText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private var relativeDateString: String {
        Self.relativeFormatter.localizedString(for: row.createdAt, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    @ViewBuilder
    private func stageBadge(_ stageIndex: Int) -> some View {
        Text("Stage \(stageIndex)")
            .font(.custom("Manrope", size: 10))
            .fontWeight(.semibold)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(AppTheme.Accent.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .strokeBorder(AppTheme.Accent.primary.opacity(0.4), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        ReflectionHistoryView()
    }
}
