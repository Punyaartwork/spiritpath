//
//  ContentRepository.swift
//  SpiritPath
//
//  Phase 2.1 catchup slice for Phase 2.6 · single fetch surface for stages.
//  Mirrors Android ContentRepository · single SELECT + groupBy(lineageId)
//  (cheaper than 3 sequential lineage-specific queries).
//

import Foundation
import Supabase

@MainActor
final class ContentRepository {
    static let shared = ContentRepository()

    private init() {}

    /// Fetch all 15 stage rows (3 lineages × 5 stages) and group by lineage_id.
    /// Returns `[lineageId: [StageRow]]` where each value is sorted by stageIndex ascending.
    func fetchStagesAllLineages() async throws -> [String: [StageRow]] {
        let all: [StageRow] = try await supabase
            .from("stages")
            .select()
            .execute()
            .value

        return Dictionary(grouping: all, by: { $0.lineageId })
            .mapValues { $0.sorted(by: { $0.stageIndex < $1.stageIndex }) }
    }
}
