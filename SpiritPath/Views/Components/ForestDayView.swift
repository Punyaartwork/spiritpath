//
//  ForestDayView.swift
//  SpiritPath
//
//  Place picker tile · forest variant · 160×140 viewBox · Canvas port of prototype
//  screen-practice.jsx ForestDay SVG.
//  Illustration-specific hex locked to prototype palette (exception documented in spec).
//

import SwiftUI

struct ForestDayView: View {
    // Illustration hex · not tokenized
    private static let skyTop   = Color(hex: "#3560a0")
    private static let skyBase  = Color(hex: "#1e3a6f")
    private static let moon     = Color(hex: "#f5d17a")
    private static let riverOuter = Color(hex: "#6ba3d6")
    private static let riverInner = Color(hex: "#9dc4e8")

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 160
            let sy = size.height / 140
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            // Sky gradient
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Self.skyTop, Self.skyBase]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            // Moon glow · r=28 · opacity 0.25
            let moonCenter = p(80, 50)
            let glowR = 28 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moonCenter.x - glowR, y: moonCenter.y - glowR,
                    width: glowR * 2, height: glowR * 2
                )),
                with: .color(Self.moon.opacity(0.25))
            )

            // Moon body · r=18
            let moonR = 18 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moonCenter.x - moonR, y: moonCenter.y - moonR,
                    width: moonR * 2, height: moonR * 2
                )),
                with: .color(Self.moon)
            )

            // River · single curve · outer + inner stroke
            var river = Path()
            river.move(to: p(70, 140))
            river.addCurve(
                to: p(80, 65),
                control1: p(60, 110),
                control2: p(100, 90)
            )
            context.stroke(
                river,
                with: .color(Self.riverOuter.opacity(0.9)),
                style: StrokeStyle(lineWidth: 12 * sx, lineCap: .round)
            )
            context.stroke(
                river,
                with: .color(Self.riverInner.opacity(0.7)),
                style: StrokeStyle(lineWidth: 5 * sx, lineCap: .round)
            )
        }
    }
}

#Preview {
    ForestDayView()
        .frame(width: 160, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
        .background(AppTheme.Surface.background)
}
