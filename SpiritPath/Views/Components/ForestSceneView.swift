//
//  ForestSceneView.swift
//  SpiritPath
//
//  Moonlit forest illustration · Canvas API port of prototype screen-home.jsx ForestScene SVG.
//  Coordinates mirror the 360×170 viewBox · scales proportionally to any container size.
//  Illustration-only hex values inlined per Phase 1.2 spec (exceptions documented).
//

import SwiftUI

struct ForestSceneView: View {
    // Illustration-only colors · locked to prototype exact hex · NOT tokenized
    private static let skyTop    = Color(hex: "#1e3a6f")
    private static let skyBottom = Color(hex: "#0a1628")
    private static let moonGlow  = Color(hex: "#6ba3d6")  // + 0.25 opacity
    private static let moonOuter = Color(hex: "#fff0c8")  // + 0.5 opacity
    private static let moonInner = Color(hex: "#f5d17a")
    private static let riverOuter = Color(hex: "#6ba3d6")
    private static let riverInner = Color(hex: "#9dc4e8")
    private static let starWhite  = Color(hex: "#fef4d6")

    var body: some View {
        Canvas { context, size in
            // viewBox 360 × 170 · scale helpers
            let sx = size.width / 360.0
            let sy = size.height / 170.0
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            // 1 · Sky gradient
            let skyRect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(skyRect),
                with: .linearGradient(
                    Gradient(colors: [Self.skyTop, Self.skyBottom]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height)
                )
            )

            // 2 · Moon glow · r=70 · opacity 0.25
            let moonCenter = point(180, 62)
            let glowR = 70 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moonCenter.x - glowR,
                    y: moonCenter.y - glowR,
                    width: glowR * 2,
                    height: glowR * 2
                )),
                with: .color(Self.moonGlow.opacity(0.25))
            )

            // 3 · Moon outer halo · r=50 · opacity 0.5
            let outerR = 50 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moonCenter.x - outerR,
                    y: moonCenter.y - outerR,
                    width: outerR * 2,
                    height: outerR * 2
                )),
                with: .color(Self.moonOuter.opacity(0.5))
            )

            // 4 · Moon body · r=28
            let innerR = 28 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moonCenter.x - innerR,
                    y: moonCenter.y - innerR,
                    width: innerR * 2,
                    height: innerR * 2
                )),
                with: .color(Self.moonInner)
            )

            // 5 · Winding river · 2 strokes wide + narrow
            var river = Path()
            river.move(to: point(150, 170))
            river.addCurve(
                to: point(180, 100),
                control1: point(130, 140),
                control2: point(200, 130)
            )
            river.addCurve(
                to: point(180, 55),
                control1: point(160, 80),
                control2: point(200, 70)
            )
            context.stroke(
                river,
                with: .color(Self.riverOuter.opacity(0.9)),
                style: StrokeStyle(lineWidth: 18 * sx, lineCap: .round)
            )
            context.stroke(
                river,
                with: .color(Self.riverInner.opacity(0.7)),
                style: StrokeStyle(lineWidth: 8 * sx, lineCap: .round)
            )

            // 6 · Stars · 20 deterministic positions · formula from prototype
            for i in 0..<20 {
                let x = CGFloat((i * 53 + 11) % 360) * sx
                let y = CGFloat((i * 17 + 5) % 60) * sy
                let r = (i % 3 == 0) ? 1.3 : 0.7
                let op = 0.6 + Double(i % 3) * 0.15
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x - r,
                        y: y - r,
                        width: r * 2,
                        height: r * 2
                    )),
                    with: .color(Self.starWhite.opacity(op))
                )
            }
        }
    }
}

#Preview {
    ForestSceneView()
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding()
        .background(AppTheme.Surface.background)
}
