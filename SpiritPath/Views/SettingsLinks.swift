//
//  SettingsLinks.swift
//  SpiritPath
//
//  Phase 2.7b/c reconcile · External URLs surfaced from Settings → About section.
//  Placeholder URLs until real hosted pages are supplied before App Store submission.
//  One-line swap pre-Phase-3 so the rest of the codebase doesn't need to change.
//

import Foundation

/// External URLs referenced from SettingsView. Replace placeholders before App Store submission.
enum SettingsLinks {
    /// Privacy policy · App Store metadata also references this URL.
    static let privacyPolicy: URL = URL(string: "https://spiritpath.app/privacy")
        ?? URL(string: "https://example.com")!

    /// Terms of service · App Store metadata also references this URL.
    static let termsOfService: URL = URL(string: "https://spiritpath.app/terms")
        ?? URL(string: "https://example.com")!
}
