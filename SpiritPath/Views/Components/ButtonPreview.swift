//
//  Untitled.swift
//  SpiritPath
//
//  Created by punyapath on 27/1/2569 BE.
//

import SwiftUI

struct ButtonPreview: View {

    @State private var selected = 0

    var body: some View {
        VStack(spacing: 16) {

            PrimaryActionButton(title: "START") { }
            PrimaryActionButton(title: "CONTINUE", style: .secondary) { }
            PrimaryActionButton(title: "Try it free", style: .premium) { }

            ChoiceButton(
                title: "I'm just getting started",
                isSelected: selected == 0
            ) { selected = 0 }

            ChoiceButton(
                title: "I have some experience",
                isSelected: selected == 1
            ) { selected = 1 }

            ListActionButton(
                title: "Clear your mind instantly",
                subtitle: "with mindful walking sessions",
                image: Image(systemName: "leaf")
            ) { }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

#Preview {
    ButtonPreview()
}
