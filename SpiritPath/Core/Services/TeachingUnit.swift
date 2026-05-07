//
//  TeachingUnit.swift
//  SpiritPath
//
//  Phase 2.2 · canonical V9 teaching_units row + per-mode body shapes.
//  Cited verbatim from supabase/migrations/0009_v31_content_depth.sql:128-145
//  (V9 INSERTs · canonical · NOT the 20260501 wiki which had 6 wrong shapes).
//
//  Audit-gap #8 corrections relative to old wiki:
//    - listen.chapters[*].t      = "MM:SS" string · NOT seconds Int
//    - understand.layers         = List<{label}> · NOT List<String>
//    - understand.concepts       = List<{term, romanized, note}> · NOT {name, definition}
//    - understand.comparison     = List<{label, v: Double}> · NOT {with, distinction}
//    - reflect.questions[*].choices = List<{label, v: Int}> · NOT List<String>
//    - reflect.questions[*].sub  = OPTIONAL · render only when non-nil + non-empty
//
//  Decoding strategy: one generic TeachingUnitRow<Body> · three concrete fetches per
//  mode in ContentRepository · the WHERE mode = ? clause guarantees body shape match.
//

import Foundation
import Supabase
import PostgREST

// MARK: · Generic row · body type narrowed at fetch time

struct TeachingUnitRow<Body: Codable>: Codable, Identifiable {
    let id: String
    let lineageId: String
    let stageIndex: Int
    let mode: String                  // "listen" | "understand" | "reflect"
    let orderIndex: Int
    let title: String
    let durationSec: Int?             // listen-only top-level mirror of body.duration_sec
    let chapters: [ListenChapter]?    // listen-only top-level mirror of body.chapters
    let body: Body
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case id, mode, title, body, published, chapters
        case lineageId = "lineage_id"
        case stageIndex = "stage_index"
        case orderIndex = "order_index"
        case durationSec = "duration_sec"
    }
}

// MARK: · listen mode body
//   V9 line 132 · {episode, narrator, duration, duration_sec, chapters: [{t, name, note}]}

struct ListenBody: Codable, Equatable {
    let episode: String
    let narrator: String
    let duration: String              // display string e.g. "04:20"
    let durationSec: Int
    let chapters: [ListenChapter]

    enum CodingKeys: String, CodingKey {
        case episode, narrator, duration, chapters
        case durationSec = "duration_sec"
    }
}

struct ListenChapter: Codable, Equatable, Identifiable {
    let t: String                     // "MM:SS" verbatim · NOT seconds (audit-gap #8)
    let name: String
    let note: String

    var id: String { "\(t)_\(name)" }
}

// MARK: · understand mode body
//   V9 line 137 · {model_title, core_label, layers: [{label}], concepts: [{term, romanized, note}],
//                  comparison: [{label, v: Double}]}

struct UnderstandBody: Codable, Equatable {
    let modelTitle: String
    let coreLabel: String
    let layers: [UnderstandLayer]
    let concepts: [UnderstandConcept]
    let comparison: [UnderstandComparison]

    enum CodingKeys: String, CodingKey {
        case layers, concepts, comparison
        case modelTitle = "model_title"
        case coreLabel = "core_label"
    }
}

struct UnderstandLayer: Codable, Equatable, Identifiable {
    let label: String
    var id: String { label }
}

struct UnderstandConcept: Codable, Equatable, Identifiable {
    let term: String                  // Pali/Thai original e.g. "นโม"
    let romanized: String             // e.g. "NAMO · THE FIRST BOW"
    let note: String
    var id: String { term }
}

struct UnderstandComparison: Codable, Equatable, Identifiable {
    let label: String
    let v: Double                     // 0.0..1.0 weight · drives bar visualization
    var id: String { label }
}

// MARK: · reflect mode body
//   V9 line 142 · {questions: [{prompt, sub?, choices: [{label, v: Int}]}],
//                  bands: [{label, title, note, suggestion}]}

struct ReflectBody: Codable, Equatable {
    let questions: [ReflectQuestion]
    let bands: [ReflectBand]
}

struct ReflectQuestion: Codable, Equatable, Identifiable {
    let prompt: String
    let sub: String?                  // OPTIONAL · render only when non-nil + non-empty
    let choices: [ReflectChoice]
    var id: String { prompt }
}

struct ReflectChoice: Codable, Equatable, Identifiable {
    let label: String
    let v: Int                        // 1..4 typical · drives band selection
    var id: String { label }
}

struct ReflectBand: Codable, Equatable, Identifiable {
    let label: String                 // ALL CAPS short e.g. "SETTING OUT"
    let title: String
    let note: String
    let suggestion: String
    var id: String { label }
}

// MARK: · ContentRepository · per-mode fetches

extension ContentRepository {
    func fetchListenUnitsForStage(lineageId: String, stageIndex: Int) async throws -> [TeachingUnitRow<ListenBody>] {
        try await supabase
            .from("teaching_units")
            .select()
            .eq("lineage_id", value: lineageId)
            .eq("stage_index", value: stageIndex)
            .eq("mode", value: "listen")
            .eq("published", value: true)
            .order("order_index")
            .execute()
            .value
    }

    func fetchUnderstandUnitsForStage(lineageId: String, stageIndex: Int) async throws -> [TeachingUnitRow<UnderstandBody>] {
        try await supabase
            .from("teaching_units")
            .select()
            .eq("lineage_id", value: lineageId)
            .eq("stage_index", value: stageIndex)
            .eq("mode", value: "understand")
            .eq("published", value: true)
            .order("order_index")
            .execute()
            .value
    }

    func fetchReflectUnitsForStage(lineageId: String, stageIndex: Int) async throws -> [TeachingUnitRow<ReflectBody>] {
        try await supabase
            .from("teaching_units")
            .select()
            .eq("lineage_id", value: lineageId)
            .eq("stage_index", value: stageIndex)
            .eq("mode", value: "reflect")
            .eq("published", value: true)
            .order("order_index")
            .execute()
            .value
    }
}
