//
//  PrimaryActionButton.swift
//  SpiritPath
//
//  Created by punyapath on 27/1/2569 BE.
//

import SwiftUI

struct PrimaryActionButton: View {

    enum Style {
        case primary
        case secondary
        case premium
    }

    let title: String
    var style: Style = .primary
    let action: () -> Void

    private var backgroundColor: Color {
        switch style {
        case .primary: return Color.yellow
        case .secondary: return Color.blue
        case .premium: return Color.white
        }
    }

    private var textColor: Color {
        switch style {
        case .premium: return .black
        default: return .white
        }
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(backgroundColor)
                .cornerRadius(18)
        }
    }
}
