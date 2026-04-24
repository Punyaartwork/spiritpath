//
//  TempleSceneView.swift
//  SpiritPath
//
//  Place picker tile · temple variant · 160×140 viewBox · Canvas port of prototype
//  screen-practice.jsx TempleScene SVG.
//  Illustration-specific hex locked to prototype palette.
//

import SwiftUI

struct TempleSceneView: View {
    // Illustration hex
    private static let skyTop    = Color(hex: "#122952")
    private static let skyBase   = Color(hex: "#1e3a6f")
    private static let spireGold = Color(hex: "#f5d17a")
    private static let plinth    = Color(hex: "#d9a94a")
    private static let water     = Color(hex: "#0a1628")
    private static let moonCream = Color(hex: "#fef4d6")

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 160
            let sy = size.height / 140
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
                Path(CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy))
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

            // Main spire · triangle 80,20 → 74,55 → 86,55
            var mainSpire = Path()
            mainSpire.move(to: p(80, 20))
            mainSpire.addLine(to: p(74, 55))
            mainSpire.addLine(to: p(86, 55))
            mainSpire.closeSubpath()
            context.fill(mainSpire, with: .color(Self.spireGold))
            context.fill(rect(70, 55, 20, 28), with: .color(Self.spireGold))

            // Left spire · 60,45 → 54,70 → 66,70
            var leftSpire = Path()
            leftSpire.move(to: p(60, 45))
            leftSpire.addLine(to: p(54, 70))
            leftSpire.addLine(to: p(66, 70))
            leftSpire.closeSubpath()
            context.fill(leftSpire, with: .color(Self.spireGold))
            context.fill(rect(52, 70, 14, 20), with: .color(Self.spireGold))

            // Right spire · 100,45 → 94,70 → 106,70
            var rightSpire = Path()
            rightSpire.move(to: p(100, 45))
            rightSpire.addLine(to: p(94, 70))
            rightSpire.addLine(to: p(106, 70))
            rightSpire.closeSubpath()
            context.fill(rightSpire, with: .color(Self.spireGold))
            context.fill(rect(94, 70, 14, 20), with: .color(Self.spireGold))

            // Plinth
            context.fill(rect(40, 90, 80, 22), with: .color(Self.plinth))

            // Water (reflection base)
            context.fill(rect(0, 115, 160, 25), with: .color(Self.water.opacity(0.85)))

            // Reflection · faint inverted main spire
            var reflectTri = Path()
            reflectTri.move(to: p(80, 140))
            reflectTri.addLine(to: p(74, 115))
            reflectTri.addLine(to: p(86, 115))
            reflectTri.closeSubpath()
            context.fill(reflectTri, with: .color(Self.spireGold.opacity(0.25)))
            context.fill(rect(70, 115, 20, 20), with: .color(Self.spireGold.opacity(0.25)))

            // Moon · r=8 + glow r=14
            let moon = p(135, 28)
            let glowR = 14 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moon.x - glowR, y: moon.y - glowR,
                    width: glowR * 2, height: glowR * 2
                )),
                with: .color(Self.moonCream.opacity(0.2))
            )
            let moonR = 8 * min(sx, sy)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: moon.x - moonR, y: moon.y - moonR,
                    width: moonR * 2, height: moonR * 2
                )),
                with: .color(Self.moonCream)
            )
        }
    }
}

#Preview {
    TempleSceneView()
        .frame(width: 160, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
        .background(AppTheme.Surface.background)
}
