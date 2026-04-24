//
//  DayArcView.swift
//  SpiritPath
//
//  Day-arc indicator · dashed full arc + solid morning-to-now arc + current-position dot.
//  Port of prototype screen-home.jsx DayArc SVG (320×60 viewBox).
//  Scales to container width · fixed height 50pt + 8pt label row.
//

import SwiftUI

struct DayArcView: View {
    var body: some View {
        ZStack {
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // viewBox 320×60 scale helpers
                func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                    CGPoint(x: x / 320 * w, y: y / 60 * h)
                }

                // 1 · Dashed full-day arc · M 10 50 Q 160 -10 310 50
                var fullArc = Path()
                fullArc.move(to: p(10, 50))
                fullArc.addQuadCurve(to: p(310, 50), control: p(160, -10))
                context.stroke(
                    fullArc,
                    with: .color(AppTheme.Ink.ghost),
                    style: StrokeStyle(lineWidth: 1.5, dash: [2, 3])
                )

                // 2 · Primary morning→now arc · M 10 50 Q 160 -10 160 20
                var primaryArc = Path()
                primaryArc.move(to: p(10, 50))
                primaryArc.addQuadCurve(to: p(160, 20), control: p(160, -10))
                context.stroke(
                    primaryArc,
                    with: .color(AppTheme.Accent.primary),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )

                // 3 · Current position halo · r=9 · opacity 0.2
                let dotCenter = p(160, 20)
                let rGlow = 9 * w / 320
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: dotCenter.x - rGlow,
                        y: dotCenter.y - rGlow,
                        width: rGlow * 2,
                        height: rGlow * 2
                    )),
                    with: .color(AppTheme.Accent.primary.opacity(0.2))
                )

                // 4 · Current position dot · r=5
                let rDot = 5 * w / 320
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: dotCenter.x - rDot,
                        y: dotCenter.y - rDot,
                        width: rDot * 2,
                        height: rDot * 2
                    )),
                    with: .color(AppTheme.Accent.primary)
                )
            }

            // Time labels overlay · 05:00 · 12:00 · 21:30
            GeometryReader { geo in
                let w = geo.size.width
                ZStack {
                    timeLabel("05:00")
                        .position(x: 20 / 320 * w, y: 58 / 60 * 50)
                    timeLabel("12:00")
                        .position(x: 140 / 320 * w, y: 58 / 60 * 50)
                    timeLabel("21:30")
                        .position(x: 270 / 320 * w, y: 58 / 60 * 50)
                }
            }
        }
        .frame(height: 50)
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("Manrope", size: 8))
            .tracking(1)
            .foregroundStyle(AppTheme.Ink.muted)
    }
}

#Preview {
    DayArcView()
        .padding()
        .background(AppTheme.Surface.background)
}
