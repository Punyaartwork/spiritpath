//
//  LineageDisplay.swift
//  SpiritPath
//
//  Phase 2.1 catchup slice · static display constants for the 3 spirit lineages.
//  Mirrors prototype COMPARE_LINEAGES (screen-compare.jsx:3-7) and Android
//  LineageDisplayConstants. Hue values come from prototype tokens.jsx.
//
//  Wire-value `id` MUST match Supabase enum (mun · sodh · chah).
//

import Foundation

struct LineageDisplay: Identifiable, Hashable {
    let id: String          // wire value: "mun" · "sodh" · "chah"
    let name: String        // short · "Mun" · "Sodh" · "Chah"
    let fullName: String    // teacher full name
    let tradition: String   // tradition tag
    let glyph: String       // single emoji/symbol used as fallback image
    let accentHex: String   // hue (#RRGGBB)

    static let all: [LineageDisplay] = [mun, sodh, chah]

    static let mun = LineageDisplay(
        id: "mun",
        name: "Mun",
        fullName: "Luang Pu Mun",
        tradition: "Kammaṭṭhāna",
        glyph: "🌲",
        accentHex: "#F0C870"
    )

    static let sodh = LineageDisplay(
        id: "sodh",
        name: "Sodh",
        fullName: "Luang Pu Sodh",
        tradition: "Dhammakāya",
        glyph: "💠",
        accentHex: "#C8A8F0"
    )

    static let chah = LineageDisplay(
        id: "chah",
        name: "Chah",
        fullName: "Ajahn Chah",
        tradition: "Wat Pah Pong",
        glyph: "🌳",
        accentHex: "#A8D0A0"
    )

    static func by(id: String) -> LineageDisplay {
        all.first(where: { $0.id == id }) ?? sodh
    }
}
