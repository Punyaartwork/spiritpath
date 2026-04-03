//
//  AppTheme.swift
//  SpiritPath
//
//  Created by punyapath on 14/1/2569 BE.
//

import SwiftUI

struct AppTheme {
    static let background = Color.bgPrimary
    static let card = Color.surfaceCard
    static let primaryAction = Color.accentGold
}


enum AppBackgroundStyle {
    case solidPrimary      // สีเปล่า
    case solidSecondary    // สีเปล่า
    case gradientCalm      // gradient
    case gradientDepth     // gradient
    case imageForest       // ภาพ
}


struct AppBackground: View {

    let style: AppBackgroundStyle

    var body: some View {
        backgroundView
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {

        case .solidPrimary:
            Color.bgPrimary

        case .solidSecondary:
            Color.bgSecondary

        case .gradientCalm:
            LinearGradient(
                colors: [.accentBlue.opacity(0.5), .bgSecondary],
                startPoint: .top,
                endPoint: .bottom
            )

        case .gradientDepth:
            LinearGradient(
                colors: [.accentBlue.opacity(0.7), .bgPrimary],
                startPoint: .top,
                endPoint: .bottom
            )

        case .imageForest:
            Image("bg_forest")
                .resizable()
                .scaledToFill()
                .overlay(
                    Color.bgPrimary.opacity(0.4) // คุม mood
                )
        }
    }
}



//        struct IntroductionView: View {
//            var body: some View {
//                ZStack {
//                    AppBackground(style: .gradientCalm)
//                    content
//                }
//            }
//        }
