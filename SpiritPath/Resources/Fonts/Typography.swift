//
//  Typography.swift
//  SpiritPath
//
//  Created by punyapath on 14/1/2569 BE.
//

import SwiftUI

enum AppTextStyle {
    case pageTitle
    case question
    case option
    case body
    case caption
}

extension Text {
    func appText(_ style: AppTextStyle) -> some View {
        switch style {

        case .pageTitle:
            return self
                .font(.custom("Sarabun-Bold", size: 26))
                .foregroundColor(.textPrimary)

        case .question:
            return self
                .font(.custom("Sarabun-SemiBold", size: 20))
                .foregroundColor(.textPrimary)

        case .option:
            return self
                .font(.custom("Sarabun-Regular", size: 16))
                .foregroundColor(.textPrimary)

        case .body:
            return self
                .font(.custom("Sarabun-Regular", size: 14))
                .foregroundColor(.textSecondary)

        case .caption:
            return self
                .font(.custom("Sarabun-Regular", size: 12))
                .foregroundColor(.textSecondary)
        }
    }
}
