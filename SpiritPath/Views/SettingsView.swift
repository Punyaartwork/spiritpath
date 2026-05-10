//
//  SettingsView.swift
//  SpiritPath
//
//  Phase 2.7c · iOS-side mirror of Android Phase 2.7c SettingsScreen.
//  6 sections (in render order):
//    A · Profile          · read-only · name · email · spirit master · member since
//    B · Practice prefs   · lineage picker · place · ground · pace defaults
//    C · Notifications    · push toggle (Phase 3 placeholder · disabled) · "When to practice" hours
//    D · Privacy          · tracking opt-out · health link · data export · account deletion
//    E · Night Log        · M23 verbatim copy · entry count
//    F · About            · version · privacy policy · terms · credits · support
//
//  Reachable from gear icons in StillnessView + JourneyView headers (Phase 2.7c routing).
//
//  Required for App Store submission per Phase 3 prep · CCPA right-to-know +
//  right-to-delete satisfied by data export + 30-day grace deletion request flows.
//
//  Copy locks (cross-platform identical · ห้ามแก้):
//    · M23 Night Log copy · `0007_night_log.sql:65-69`
//    · Account deletion warning · "This cannot be undone. 30 days from now your data is permanently removed."
//    · Privacy toggle label · "Send anonymous usage data"
//    · Practice window header · "When to practice"
//

import SwiftUI
import Supabase

// MARK: · ViewModel · @Observable (iOS 17+ Observation framework)

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: · UI state · driven by @Bindable in SettingsView

    /// Profile read · loaded once via `.task { await load() }`. nil during initial fetch.
    var profile: ProfileSnapshot?

    /// Lineage selected in Practice prefs · mirrors profiles.selected_lineage_id.
    /// Default sodh matches the canonical fallback (CLAUDE.md row 7).
    var lineageId: String = UserDefaults.standard.string(forKey: "selected_lineage_id") ?? "sodh"
    var lineagePickerPresented: Bool = false

    /// Practice defaults · @AppStorage-mirrored so PracticeView keeps reading the same value.
    var defaultPlace: String  = UserDefaults.standard.string(forKey: "pref.place")  ?? "forest"
    var defaultGround: String = UserDefaults.standard.string(forKey: "pref.ground") ?? "grass"
    var defaultPace: String   = UserDefaults.standard.string(forKey: "pref.pace")   ?? "forest"

    /// Notifications · push toggle disabled in Phase 2.7c (real APNS lands Phase 3).
    var pushEnabled: Bool = false

    /// "When to practice" · hour range 0..23 inclusive.
    var practiceStartHour: Double = 6
    var practiceEndHour: Double = 22
    var weekdaysOnly: Bool = false

    /// Privacy · M5 lock state · profiles.tracking_opt_out source-of-truth.
    /// Toggle label reads "Send anonymous usage data" → unchecked = opt-out.
    var sendAnonymousUsageData: Bool = true

    /// Night log · entry count · optional · loaded best-effort.
    var nightLogEntryCount: Int = 0

    /// Account deletion confirmation dialog state.
    var showDeletionConfirm: Bool = false
    var deletionRequested: Bool = false

    /// Data export request feedback · single-line confirmation banner.
    var exportRequested: Bool = false

    /// Generic error banner shown if an action fails (network · not authenticated).
    var errorMessage: String?

    // MARK: · Snapshot read into the screen

    struct ProfileSnapshot: Equatable {
        let displayName: String?
        let email: String?
        let lineageId: String?
        let memberSince: Date?
    }

    // MARK: · Lifecycle

    /// One-shot load · fetches the profile row + night log entry count.
    /// Best-effort · failures fall back to nil display values.
    func load() async {
        await loadProfile()
        await loadNightLogCount()
    }

    private func loadProfile() async {
        guard let userId = supabase.auth.currentUser?.id else {
            // Auth not wired (Phase 1.7a parked) · render placeholder values.
            profile = ProfileSnapshot(
                displayName: nil,
                email: supabase.auth.currentUser?.email,
                lineageId: lineageId,
                memberSince: nil
            )
            return
        }

        struct ProfileRow: Decodable {
            let display_name: String?
            let selected_lineage_id: String?
            let tracking_opt_out: Bool?
            let created_at: Date?
        }

        do {
            let row: ProfileRow = try await supabase
                .from("profiles")
                .select("display_name,selected_lineage_id,tracking_opt_out,created_at")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value

            profile = ProfileSnapshot(
                displayName: row.display_name,
                email: supabase.auth.currentUser?.email,
                lineageId: row.selected_lineage_id ?? lineageId,
                memberSince: row.created_at
            )
            if let serverLineage = row.selected_lineage_id {
                lineageId = serverLineage
            }
            if let optOut = row.tracking_opt_out {
                // Toggle reads as "send" so invert the opt-out wire value.
                sendAnonymousUsageData = !optOut
            }
        } catch {
            profile = ProfileSnapshot(
                displayName: nil,
                email: supabase.auth.currentUser?.email,
                lineageId: lineageId,
                memberSince: nil
            )
        }
    }

    private func loadNightLogCount() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        struct CountRow: Decodable { let id: String }
        do {
            let rows: [CountRow] = try await supabase
                .from("night_log_entries")
                .select("id")
                .eq("user_id", value: userId.uuidString)
                .is("deleted_at", value: nil)
                .execute()
                .value
            nightLogEntryCount = rows.count
        } catch {
            nightLogEntryCount = 0
        }
    }

    // MARK: · Actions · Practice prefs

    func onLineageSelected(_ newLineageId: String) async {
        guard newLineageId != lineageId else { return }
        let from = lineageId
        do {
            try await ProfileRepository.shared.updateLineage(newLineageId)
            UserDefaults.standard.set(newLineageId, forKey: "selected_lineage_id")
            Analytics.track(.lineageChanged(
                fromLineageId: from,
                toLineageId: newLineageId,
                currentStage: 1
            ))
            lineageId = newLineageId
        } catch ProfileRepositoryError.notAuthenticated {
            // Phase 1.7a not wired · keep local state in sync.
            UserDefaults.standard.set(newLineageId, forKey: "selected_lineage_id")
            lineageId = newLineageId
        } catch {
            errorMessage = "Could not save your lineage. Please try again."
        }
    }

    func onPlaceChanged(_ value: String) {
        defaultPlace = value
        UserDefaults.standard.set(value, forKey: "pref.place")
    }

    func onGroundChanged(_ value: String) {
        defaultGround = value
        UserDefaults.standard.set(value, forKey: "pref.ground")
    }

    func onPaceChanged(_ value: String) {
        defaultPace = value
        UserDefaults.standard.set(value, forKey: "pref.pace")
    }

    // MARK: · Actions · Notifications + practice window

    func savePracticeWindow() async {
        do {
            try await SettingsRepository.shared.updatePracticeWindow(
                startHour: Int(practiceStartHour),
                endHour: Int(practiceEndHour),
                weekdaysOnly: weekdaysOnly
            )
        } catch SettingsRepository.RepositoryError.notAuthenticated {
            // Auth not wired · keep local state.
        } catch {
            errorMessage = "Could not save your practice window."
        }
    }

    // MARK: · Actions · Privacy

    func onSendAnonymousUsageDataChanged(_ send: Bool) async {
        sendAnonymousUsageData = send
        do {
            try await SettingsRepository.shared.updateTrackingOptOut(!send)
        } catch SettingsRepository.RepositoryError.notAuthenticated {
            // Auth not wired · still mirror into Mixpanel SDK locally.
            Analytics.setOptOut(!send)
        } catch {
            errorMessage = "Could not update your privacy choice."
        }
    }

    func requestDataExport() async {
        do {
            try await SettingsRepository.shared.requestDataExport()
            exportRequested = true
        } catch SettingsRepository.RepositoryError.notAuthenticated {
            errorMessage = "Sign in to request your data."
        } catch {
            errorMessage = "Could not start your export. Please try again."
        }
    }

    // MARK: · Actions · Account deletion

    func confirmDeletion() async {
        do {
            try await SettingsRepository.shared.requestAccountDeletion()
            deletionRequested = true
        } catch SettingsRepository.RepositoryError.notAuthenticated {
            errorMessage = "Sign in to delete your account."
        } catch {
            errorMessage = "Could not submit deletion. Please try again."
        }
    }
}

// MARK: · View

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                profileSection
                practicePreferencesSection
                notificationsSection
                privacySection
                nightLogSection
                aboutSection
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .background(AppBackground(style: .day))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .sheet(isPresented: $viewModel.lineagePickerPresented) {
            LineagePickerSheet(
                currentLineageId: viewModel.lineageId,
                onSelect: { newId in
                    Task { await viewModel.onLineageSelected(newId) }
                },
                isPresented: $viewModel.lineagePickerPresented
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Delete account",
            isPresented: $viewModel.showDeletionConfirm,
            titleVisibility: .visible
        ) {
            Button("Confirm deletion", role: .destructive) {
                Task { await viewModel.confirmDeletion() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. 30 days from now your data is permanently removed.")
        }
    }

    // MARK: · Section A · Profile (read-only)

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Profile")

            sectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    profileRow(
                        label: "Name",
                        value: viewModel.profile?.displayName ?? "—"
                    )
                    Divider().background(AppTheme.Ink.ghost)

                    profileRow(
                        label: "Email",
                        value: viewModel.profile?.email ?? "—"
                    )
                    Divider().background(AppTheme.Ink.ghost)

                    profileRow(
                        label: "Spirit Master",
                        value: spiritMasterDisplayName
                    )
                    Divider().background(AppTheme.Ink.ghost)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Member since")
                            .font(.custom("Manrope", size: 13))
                            .foregroundStyle(AppTheme.Ink.muted)
                        Spacer()
                        Text(memberSinceDisplay)
                            .font(.custom("DMSerifDisplay-Italic", size: 15))
                            .foregroundStyle(AppTheme.Ink.primary)
                    }
                }
            }
        }
    }

    private var spiritMasterDisplayName: String {
        let id = viewModel.profile?.lineageId ?? viewModel.lineageId
        return LineagePickerOptions.options.first(where: { $0.id == id })?.displayName ?? "—"
    }

    private var memberSinceDisplay: String {
        guard let date = viewModel.profile?.memberSince else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return "Member since \(formatter.string(from: date))"
    }

    private func profileRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.muted)
            Spacer()
            Text(value)
                .font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Ink.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    // MARK: · Section B · Practice preferences

    private var practicePreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Practice preferences")

            sectionCard {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        viewModel.lineagePickerPresented = true
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lineage")
                                    .font(.custom("Manrope", size: 13))
                                    .foregroundStyle(AppTheme.Ink.muted)
                                Text(spiritMasterDisplayName)
                                    .font(.custom("DMSerifDisplay-Italic", size: 16))
                                    .foregroundStyle(AppTheme.Accent.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppTheme.Ink.soft)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)

                    choiceRow(
                        label: "Default place",
                        options: ["forest", "temple", "city"],
                        current: viewModel.defaultPlace,
                        onChange: { viewModel.onPlaceChanged($0) }
                    )

                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)

                    choiceRow(
                        label: "Default ground",
                        options: ["grass", "wood", "stone"],
                        current: viewModel.defaultGround,
                        onChange: { viewModel.onGroundChanged($0) }
                    )

                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)

                    choiceRow(
                        label: "Default pace",
                        options: ["forest", "temple", "city"],
                        current: viewModel.defaultPace,
                        onChange: { viewModel.onPaceChanged($0) }
                    )
                }
            }
        }
    }

    private func choiceRow(
        label: String,
        options: [String],
        current: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("Manrope", size: 13))
                .foregroundStyle(AppTheme.Ink.muted)

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let active = option == current
                    Button {
                        onChange(option)
                    } label: {
                        Text(option.capitalized)
                            .font(.custom("Manrope", size: 12))
                            .fontWeight(.medium)
                            .foregroundStyle(
                                active ? AppTheme.Accent.onPrimary : AppTheme.Ink.soft
                            )
                            .padding(.horizontal, 12)
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
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: · Section C · Notifications + practice window

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Notifications")

            sectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Practice reminders")
                                .font(.custom("Manrope", size: 14))
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.Ink.primary)
                            Text("Available in a future update")
                                .font(.custom("Manrope", size: 11))
                                .foregroundStyle(AppTheme.Ink.muted)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.pushEnabled)
                            .labelsHidden()
                            .disabled(true)
                            .tint(AppTheme.Accent.primary)
                    }

                    Divider().background(AppTheme.Ink.ghost)

                    practiceWindowBlock
                }
            }
        }
    }

    private var practiceWindowBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("When to practice")
                .font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Ink.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(AppTheme.Ink.muted)
                    Spacer()
                    Text(hourLabel(viewModel.practiceStartHour))
                        .font(.custom("JetBrainsMono-Regular", size: 12))
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                Slider(
                    value: $viewModel.practiceStartHour,
                    in: 0...23,
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing { Task { await viewModel.savePracticeWindow() } }
                    }
                )
                .tint(AppTheme.Accent.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("End")
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(AppTheme.Ink.muted)
                    Spacer()
                    Text(hourLabel(viewModel.practiceEndHour))
                        .font(.custom("JetBrainsMono-Regular", size: 12))
                        .foregroundStyle(AppTheme.Ink.primary)
                }
                Slider(
                    value: $viewModel.practiceEndHour,
                    in: 0...23,
                    step: 1,
                    onEditingChanged: { editing in
                        if !editing { Task { await viewModel.savePracticeWindow() } }
                    }
                )
                .tint(AppTheme.Accent.primary)
            }

            Toggle(isOn: $viewModel.weekdaysOnly) {
                Text("Weekdays only")
                    .font(.custom("Manrope", size: 13))
                    .foregroundStyle(AppTheme.Ink.primary)
            }
            .tint(AppTheme.Accent.primary)
            .onChange(of: viewModel.weekdaysOnly) { _, _ in
                Task { await viewModel.savePracticeWindow() }
            }
        }
    }

    private func hourLabel(_ hour: Double) -> String {
        let h = Int(hour)
        return String(format: "%02d:00", h)
    }

    // MARK: · Section D · Privacy

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Privacy")

            sectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: Binding(
                        get: { viewModel.sendAnonymousUsageData },
                        set: { newValue in
                            Task { await viewModel.onSendAnonymousUsageDataChanged(newValue) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Send anonymous usage data")
                                .font(.custom("Manrope", size: 14))
                                .fontWeight(.medium)
                                .foregroundStyle(AppTheme.Ink.primary)
                            Text("Helps us understand how the app is used.")
                                .font(.custom("Manrope", size: 11))
                                .foregroundStyle(AppTheme.Ink.muted)
                        }
                    }
                    .tint(AppTheme.Accent.primary)

                    Divider().background(AppTheme.Ink.ghost)

                    healthLinkRow

                    Divider().background(AppTheme.Ink.ghost)

                    Button {
                        Task { await viewModel.requestDataExport() }
                    } label: {
                        actionRow(
                            label: "Export your data",
                            hint: viewModel.exportRequested
                                ? "Export requested · we'll email a download link."
                                : "We'll prepare a copy of your practice history."
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().background(AppTheme.Ink.ghost)

                    Button {
                        viewModel.showDeletionConfirm = true
                    } label: {
                        actionRow(
                            label: "Delete account",
                            hint: viewModel.deletionRequested
                                ? "Deletion requested · sign in within 30 days to cancel."
                                : "Removes your data after 30 days.",
                            destructive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.custom("Manrope", size: 12))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .padding(.top, 4)
            }
        }
    }

    private var healthLinkRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Health")
                    .font(.custom("Manrope", size: 14))
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.Ink.primary)
                Text(healthHintCopy)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            Spacer()
            Image(systemName: healthIconName)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.Ink.soft)
        }
    }

    /// M19 state-aware Health copy.
    private var healthHintCopy: String {
        switch HealthService.shared.permissionState {
        case .undetermined: return "Will ask on your first walking session."
        case .granted:      return "Mindful sessions are saved to Apple Health."
        case .denied:       return "Manage access in Settings → Privacy → Health."
        case .unavailable:  return "Not available on this device."
        }
    }

    private var healthIconName: String {
        switch HealthService.shared.permissionState {
        case .granted: return "checkmark.circle"
        default:       return "info.circle"
        }
    }

    private func actionRow(
        label: String,
        hint: String,
        destructive: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.custom("Manrope", size: 14))
                    .fontWeight(.medium)
                    .foregroundStyle(
                        destructive ? AppTheme.Accent.primary : AppTheme.Ink.primary
                    )
                Text(hint)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.Ink.soft)
        }
    }

    // MARK: · Section E · Night Log (M23 verbatim)

    private var nightLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Night Log")

            sectionCard {
                VStack(alignment: .leading, spacing: 12) {
                    // M23 verbatim · single-source-of-truth in NightLogCopy.M23.body
                    // (mirrors 0007_night_log.sql:65-69 · cross-platform locked).
                    Text(NightLogCopy.M23.body)
                        .font(.custom("Manrope", size: 13))
                        .foregroundStyle(AppTheme.Ink.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.nightLogEntryCount > 0 {
                        Text("\(viewModel.nightLogEntryCount) \(viewModel.nightLogEntryCount == 1 ? "entry" : "entries") on this device")
                            .font(.custom("Manrope", size: 11))
                            .foregroundStyle(AppTheme.Ink.faint)
                    }
                }
            }
        }
    }

    // MARK: · Section F · About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "About")

            sectionCard {
                VStack(alignment: .leading, spacing: 0) {
                    aboutRow(label: "Version", value: appVersion, showChevron: false)
                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)
                    Link(destination: SettingsLinks.privacyPolicy) {
                        aboutRow(label: "Privacy policy", value: nil, showChevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)
                    Link(destination: SettingsLinks.termsOfService) {
                        aboutRow(label: "Terms of service", value: nil, showChevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)
                    aboutRow(label: "Credits", value: nil, showChevron: true)
                    Divider().background(AppTheme.Ink.ghost).padding(.vertical, 10)
                    aboutRow(label: "Support", value: nil, showChevron: true)
                }
            }
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func aboutRow(label: String, value: String?, showChevron: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.custom("Manrope", size: 14))
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Ink.primary)
            Spacer()
            if let value {
                Text(value)
                    .font(.custom("JetBrainsMono-Regular", size: 12))
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.Ink.soft)
            }
        }
    }

    // MARK: · Reusable card chrome

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                    .fill(AppTheme.Surface.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radii.card)
                            .strokeBorder(AppTheme.Ink.ghost, lineWidth: 1)
                    )
            )
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel())
    }
}
