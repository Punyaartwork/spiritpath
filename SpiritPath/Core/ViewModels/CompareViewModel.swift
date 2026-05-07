//
//  CompareViewModel.swift
//  SpiritPath
//
//  Phase 2.6 · cross-lineage CompareView state.
//  Mirrors Android CompareViewModel contract · enum Lens with verbatim
//  cross-platform labels · single load() against ContentRepository.
//

import Foundation
import Observation

@Observable
@MainActor
final class CompareViewModel {

    enum Lens: String, CaseIterable, Identifiable {
        case summary
        case image
        case candy
        case arc

        var id: String { rawValue }

        /// VERBATIM cross-platform · brief tone-rules section 6.
        var label: String {
            switch self {
            case .summary: return "Entry point"
            case .image:   return "Key image"
            case .candy:   return "⚠️ Trap"
            case .arc:     return "ผู้รู้ / anchor"
            }
        }
    }

    enum State {
        case loading
        case loaded(stagesByLineage: [String: [StageRow]])
        case error(String)
    }

    var state: State = .loading
    var stageIndex: Int = 1   // 1..5 · default · Phase 2.x may hydrate from journey_progress
    var lens: Lens = .summary

    func load() async {
        state = .loading
        do {
            let byLineage = try await ContentRepository.shared.fetchStagesAllLineages()
            state = .loaded(stagesByLineage: byLineage)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func currentStageRow(for lineageId: String) -> StageRow? {
        guard case .loaded(let map) = state else { return nil }
        return map[lineageId]?.first(where: { $0.stageIndex == stageIndex })
    }

    /// Stage title is shared across lineages · pull from any lineage that has a row.
    /// Falls back to canonical 5-stage list if not loaded yet.
    func stageTitle() -> String {
        if case .loaded(let map) = state,
           let row = map.values.flatMap({ $0 }).first(where: { $0.stageIndex == stageIndex }) {
            return row.title
        }
        return CompareViewModel.canonicalStageTitles[max(0, min(4, stageIndex - 1))]
    }

    /// Canonical 5-stage list · matches V9 stages.title across lineages.
    static let canonicalStageTitles = [
        "The Outer Path",
        "The Quiet Ground",
        "The Inner Forest",
        "The Silent Temple",
        "Open Awareness",
    ]
}
