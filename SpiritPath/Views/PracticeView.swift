//
//  PracticeView.swift
//  SpiritPath
//
//  Phase 1.3 · session prep · 4 preference sections + Begin button.
//  Port of prototype screen-practice.jsx · all copy locked verbatim.
//  Prefs persist via @AppStorage · read by RootTabView when creating SessionContext.
//

import SwiftUI

struct PracticeView: View {
    let onBegin: () -> Void

    @AppStorage("pref.duration") private var duration: String = "30 MINS"
    @AppStorage("pref.place")    private var place: String    = "forest"
    @AppStorage("pref.ground")   private var ground: String   = "grass"
    @AppStorage("pref.pace")     private var pace: String     = "forest"

    /// Phase 1.6 · refreshed on appear and after permission flow · drives micro-copy
    /// shown above the Begin button. Hides HKAuthorizationStatus from the view layer.
    @State private var healthState: HealthService.PermissionState = .undetermined

    private let durations = ["15 MINS", "30 MINS", "60 MINS"]

    private let grounds: [(id: String, label: String, sub: String, icon: String)] = [
        ("grass",   "Grass",   "Soft ground, more to feel", "leaf.fill"),
        ("earth",   "Earth",   "Grounding each step",        "globe"),
        ("stone",   "Stone",   "Firm and steady",            "mountain.2.fill"),
        ("indoors", "Indoors", "Quiet and subtle",           "house.fill")
    ]

    private let paces: [(id: String, label: String, sub: String, icon: String)] = [
        ("temple", "Temple Walk", "Slow, intentional breath", "building.columns.fill"),
        ("forest", "Forest Walk", "Natural rhythm",           "figure.walk"),
        ("street", "Street Walk", "Modern world awareness",   "building.2.fill")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                intro
                durationSection
                placeSection
                groundSection
                paceSection
                beginSection
                Color.clear.frame(height: 80)   // tab bar spacer
            }
        }
        .onAppear {
            healthState = HealthService.shared.permissionState
            #if DEBUG
            print("Practice .onAppear · health state: \(healthState)")
            #endif
        }
    }

    // MARK: · header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text("Practice")
                    .font(.custom("DMSerifDisplay-Italic", size: 18))
                    .foregroundStyle(AppTheme.Accent.primary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(AppTheme.Surface.selected)
                    .frame(width: 28, height: 28)
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Accent.secondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
    }

    // MARK: · intro copy

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prepare your\nHeart for the\njourney.")
                .appText(.displayLG)
            Text("Set your intention and let the path\nguide your steps today.")
                .appText(.bodySmall)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: · duration

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "How long will you walk?")
            HStack(spacing: 10) {
                ForEach(durations, id: \.self) { d in
                    let active = d == duration
                    Button {
                        duration = d
                    } label: {
                        Text(d)
                            .font(.custom("Manrope", size: 12))
                            .fontWeight(.semibold)
                            .tracking(1.4)
                            .foregroundStyle(active ? AppTheme.Accent.onPrimary : AppTheme.Ink.soft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(active ? AppTheme.Accent.primary : .clear)
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                active ? Color.clear : AppTheme.Ink.ghost,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: · place (2-col · Forest / Temple)

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Where will you walk?")
            HStack(spacing: 10) {
                placeTile(id: "forest", label: "Forest") {
                    ForestDayView()
                }
                placeTile(id: "temple", label: "Temple") {
                    TempleSceneView()
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func placeTile<Scene: View>(
        id: String,
        label: String,
        @ViewBuilder scene: () -> Scene
    ) -> some View {
        let active = id == place
        return Button {
            place = id
        } label: {
            ZStack(alignment: .bottomLeading) {
                scene()
                LinearGradient(
                    colors: [.black.opacity(0), .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                HStack {
                    Text(label)
                        .font(.custom("DMSerifDisplay-Italic", size: 17))
                        .foregroundStyle(AppTheme.Ink.primary)
                    Spacer()
                    if active {
                        ZStack {
                            Circle()
                                .fill(AppTheme.Accent.primary)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.Accent.onPrimary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        active ? AppTheme.Accent.primary : Color.clear,
                        lineWidth: 2
                    )
                    .padding(-2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: · ground (2x2 grid)

    private var groundSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "What do your feet meet?")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(grounds, id: \.id) { g in
                    groundTile(g)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func groundTile(
        _ g: (id: String, label: String, sub: String, icon: String)
    ) -> some View {
        let active = g.id == ground
        return Button {
            ground = g.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: g.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.Accent.primary)
                Text(g.label)
                    .font(.custom("DMSerifDisplay-Regular", size: 16))
                    .foregroundStyle(AppTheme.Ink.primary)
                    .padding(.top, 6)
                Text(g.sub)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? AppTheme.Surface.selected : AppTheme.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        active ? AppTheme.Accent.secondary : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: · pace mode · vertical list

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "Pace Mode")
            VStack(spacing: 10) {
                ForEach(paces, id: \.id) { p in
                    paceTile(p)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }

    private func paceTile(
        _ p: (id: String, label: String, sub: String, icon: String)
    ) -> some View {
        let active = p.id == pace
        return Button {
            pace = p.id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(active ? AppTheme.Accent.onPrimary.opacity(0.2) : AppTheme.Surface.background)
                        .frame(width: 40, height: 40)
                    Image(systemName: p.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(active ? AppTheme.Accent.onPrimary : AppTheme.Accent.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.label)
                        .font(.custom("DMSerifDisplay-Regular", size: 16))
                        .foregroundStyle(active ? AppTheme.Accent.onPrimary : AppTheme.Ink.primary)
                    Text(p.sub)
                        .font(.custom("Manrope", size: 11))
                        .foregroundStyle(active ? AppTheme.Accent.onPrimary.opacity(0.72) : AppTheme.Ink.muted)
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(
                            active ? AppTheme.Accent.onPrimary : AppTheme.Ink.faint,
                            lineWidth: 1.5
                        )
                        .frame(width: 20, height: 20)
                    if active {
                        Circle()
                            .fill(AppTheme.Accent.onPrimary)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(active ? AppTheme.Accent.primary : AppTheme.Surface.card)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: · Begin

    private var beginSection: some View {
        VStack(spacing: 14) {
            if let line = healthMicroCopy {
                Text(line)
                    .font(.custom("Manrope", size: 11))
                    .foregroundStyle(AppTheme.Ink.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Button(action: handleBegin) {
                HStack(spacing: 8) {
                    Text("Begin your walk")
                        .font(.custom("Manrope", size: 15))
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppTheme.Accent.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radii.pill)
                        .fill(AppTheme.Accent.primary)
                )
            }
            .buttonStyle(.plain)

            Text("Your presence is your only requirement.")
                .font(.custom("Manrope", size: 11))
                .italic()
                .foregroundStyle(AppTheme.Ink.muted)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 32)
    }

    /// State-aware micro-copy · only shown for non-granted states · skill-tone phrasing.
    private var healthMicroCopy: String? {
        switch healthState {
        case .undetermined: return "Health permission requested on first session."
        case .denied:       return "Health access off · sessions still walk."
        case .granted:      return nil   // success state hidden · we're tracking quietly
        case .unavailable:  return nil   // older sim / iPad · no need to draw attention
        }
    }

    /// Phase 1.6 · ask once · proceed regardless of grant outcome.
    /// Subsequent sessions skip the prompt; we still proceed to Begin either way.
    private func handleBegin() {
        if healthState == .undetermined {
            Task {
                try? await HealthService.shared.requestAuthorization()
                // status now flipped (granted or denied) · refresh + proceed either way
                healthState = HealthService.shared.permissionState
                await MainActor.run { onBegin() }
            }
        } else {
            onBegin()
        }
    }
}

#Preview {
    ZStack {
        AppBackground(style: .day)
        PracticeView(onBegin: {})
    }
}
