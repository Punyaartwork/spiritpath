//
//  Shadow.swift
//  SpiritPath
//
//  Created by punyapath on 14/1/2569 BE.
//

import SwiftUI

extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: .black.opacity(0.12),
            radius: 10,
            x: 0,
            y: 6
        )
    }
}


//        AppCard {
//            Text("Option")
//        }
//        .cardShadow()
