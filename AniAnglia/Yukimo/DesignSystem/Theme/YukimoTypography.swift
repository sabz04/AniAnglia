//
//  YukimoTypography.swift
//  Rounded SF font tokens. Friendly, anime-app feel.
//

import SwiftUI

enum YukimoTypography {
    static let display    = Font.system(size: 36, weight: .bold,     design: .rounded)
    static let largeTitle = Font.system(size: 30, weight: .bold,     design: .rounded)
    static let title      = Font.system(size: 26, weight: .bold,     design: .rounded)
    static let title2     = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let title3     = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let headline   = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body       = Font.system(size: 16, weight: .regular,  design: .rounded)
    static let bodyEmph   = Font.system(size: 16, weight: .medium,   design: .rounded)
    static let callout    = Font.system(size: 15, weight: .regular,  design: .rounded)
    static let subhead    = Font.system(size: 14, weight: .medium,   design: .rounded)
    static let footnote   = Font.system(size: 13, weight: .regular,  design: .rounded)
    static let caption    = Font.system(size: 12, weight: .regular,  design: .rounded)
    static let small      = Font.system(size: 11, weight: .medium,   design: .rounded)

    /// Used on big CTAs.
    static let buttonLarge = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Used on monospaced verification code field.
    static let codeDigit   = Font.system(size: 28, weight: .semibold, design: .rounded)
}
