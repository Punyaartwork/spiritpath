//
//  ContentRepository.swift
//  SpiritPath
//
//  Phase 2.1 · read-only access to lineages · stages · teaching_units · teacher_quotes.
//  All rows are server-published content (Supabase RLS Pattern A · public read).
//  iOS reads Supabase directly · no local cache yet (Phase 1.7e+).
//
//  Phase 2.6 · adds fetchStagesAllLineages for cross-lineage Compare view ·
//  single SELECT + Dictionary(grouping:) is cheaper than 3 sequential queries.
//
//  DTOs decode from V1 + V3 + V9 schema · CodingKeys map snake_case → camelCase.
//

import Foundation
import Supabase
import PostgREST

// MARK: · Row DTOs

struct StageRow: Codable, Identifiable, Equatable, Hashable {
    let lineageId: String
    let stageIndex: Int
    let title: String
    let subtitle: String?
    let keyImageRef: String?         // Phase 2.6 · used by CompareView image lens
    let anchorPhrase: String?
    let trapWarning: String?

    var id: String { "\(lineageId)_\(stageIndex)" }

    enum CodingKeys: String, CodingKey {
        case title, subtitle
        case lineageId = "lineage_id"
        case stageIndex = "stage_index"
        case keyImageRef = "key_image_ref"
        case anchorPhrase = "anchor_phrase"
        case trapWarning = "trap_warning"
    }
}

struct LineageRow: Codable, Identifiable, Equatable {
    let id: String                  // "mun" · "sodh" · "chah"
    let name: String
    let accentColorHex: String?
    let glyphSymbol: String?
    let tradition: String?

    enum CodingKeys: String, CodingKey {
        case id, name, tradition
        case accentColorHex = "accent_color_hex"
        case glyphSymbol = "glyph_symbol"
    }
}

// MARK: · Repository

@MainActor
final class ContentRepository {
    static let shared = ContentRepository()
    private init() {}

    /// All published stages for a lineage · ordered by stage_index 1…5.
    func fetchStagesForLineage(_ lineageId: String) async throws -> [StageRow] {
        try await supabase
            .from("stages")
            .select()
            .eq("lineage_id", value: lineageId)
            .order("stage_index")
            .execute()
            .value
    }

    /// Phase 2.6 · fetch all 15 stage rows (3 lineages × 5 stages) and group by lineage_id.
    /// Returns `[lineageId: [StageRow]]` where each value is sorted by stageIndex ascending.
    /// Used by CompareView for cross-lineage parallel display.
    func fetchStagesAllLineages() async throws -> [String: [StageRow]] {
        let all: [StageRow] = try await supabase
            .from("stages")
            .select()
            .execute()
            .value

        return Dictionary(grouping: all, by: { $0.lineageId })
            .mapValues { $0.sorted(by: { $0.stageIndex < $1.stageIndex }) }
    }

    /// Active lineages · used by LineagePickerSheet.
    /// Returns empty array if `lineages` table is missing the `active` column (V3 schema).
    func fetchLineages() async throws -> [LineageRow] {
        try await supabase
            .from("lineages")
            .select()
            .order("id")
            .execute()
            .value
    }

    /// Teacher quote pinned to a stage · returns nil if no quote exists.
    func fetchTeacherQuoteForStage(lineageId: String, stageIndex: Int) async throws -> TeacherQuoteRow? {
        let rows: [TeacherQuoteRow] = try await supabase
            .from("teacher_quotes")
            .select()
            .eq("lineage_id", value: lineageId)
            .eq("stage_index", value: stageIndex)
            .limit(1)
            .execute()
            .value
        return rows.first
    }
}

// MARK: · TeacherQuote row (V3 schema)

struct TeacherQuoteRow: Codable, Identifiable, Equatable {
    let id: String?
    let lineageId: String
    let stageIndex: Int
    let englishText: String
    let thaiText: String?
    let transliteration: String?
    let sourceRef: String?

    enum CodingKeys: String, CodingKey {
        case id, transliteration
        case lineageId = "lineage_id"
        case stageIndex = "stage_index"
        case englishText = "english_text"
        case thaiText = "thai_text"
        case sourceRef = "source_ref"
    }
}
