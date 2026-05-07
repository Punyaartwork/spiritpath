//
//  StageRow.swift
//  SpiritPath
//
//  Phase 2.1 catchup slice for Phase 2.6 · Decodable mirror of public.stages
//  (V3 schema · V9 backfill of subtitle / anchor_phrase / trap_warning).
//  Cross-platform contract · matches Android StageRow DTO.
//

import Foundation

struct StageRow: Decodable, Identifiable, Hashable {
    let lineageId: String
    let stageIndex: Int
    let title: String
    let subtitle: String?
    let keyImageRef: String?
    let trapWarning: String?
    let anchorPhrase: String?

    var id: String { "\(lineageId)_\(stageIndex)" }

    enum CodingKeys: String, CodingKey {
        case lineageId    = "lineage_id"
        case stageIndex   = "stage_index"
        case title
        case subtitle
        case keyImageRef  = "key_image_ref"
        case trapWarning  = "trap_warning"
        case anchorPhrase = "anchor_phrase"
    }
}
