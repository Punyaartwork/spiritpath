//
//  ReflectionRow.swift
//  SpiritPath
//
//  Phase 2.7b · DTO for ReflectionHistoryView + ReflectionEditView.
//  Maps V2 schema (0002_practice.sql:66) verbatim · audit-gap #12 verified.
//
//  Schema reality vs Phase 2.7b brief example:
//    - Column is `note_text` · NOT `note` (brief used `note` · adapted to schema)
//    - NO `note_length_chars` column · computed client-side from noteText.count
//    - `lineage_id` + `stage_index_at_time` live on JOINED public.sessions table · embed via
//      PostgREST select("..., sessions(lineage_id, stage_index_at_time)") · NOT on reflections
//    - `session_id` is UNIQUE NOT NULL (1:1 with sessions enforced) · non-optional in DTO
//
//  Same audit-gap #11 lesson applied here: trust schema · not brief example column names.
//

import Foundation

/// Single reflection row · 1:1 with sessions · joined session embed carries lineage + stage.
struct ReflectionRow: Decodable, Identifiable {
    let id: String
    let userId: String
    let sessionId: String
    let noteText: String?
    let anchorPhrase: String?
    let createdAt: Date
    let updatedAt: Date?

    /// Joined sessions row · single object (FK relationship · session_id is UNIQUE).
    /// Optional: defensive against PostgREST embed returning null (orphaned reflection ·
    /// should not happen given FK constraint but client must not crash).
    let sessions: SessionEmbed?

    struct SessionEmbed: Decodable {
        let lineageId: String?
        let stageIndexAtTime: Int?

        enum CodingKeys: String, CodingKey {
            case lineageId        = "lineage_id"
            case stageIndexAtTime = "stage_index_at_time"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, sessions
        case userId       = "user_id"
        case sessionId    = "session_id"
        case noteText     = "note_text"
        case anchorPhrase = "anchor_phrase"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    // MARK: · Convenience accessors

    /// Sugar accessor · joined sessions.lineage_id (nullable enum on sessions).
    var lineageId: String? { sessions?.lineageId }

    /// Sugar accessor · joined sessions.stage_index_at_time (1..5 · nullable on sessions).
    var stageIndex: Int? { sessions?.stageIndexAtTime }

    /// Char count computed client-side · schema has no note_length_chars column.
    /// Used for M26 reflection_edited fire-site (privacy lock: counts ONLY · never text).
    var noteLengthChars: Int { noteText?.count ?? 0 }
}
