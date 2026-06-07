//
//  YukimoColor.swift
//  Yukimo Design System — color tokens.
//
//  Inspired by the Yukimo app icon: coral/salmon primary on cream
//  surfaces with soft pinks. Dark mode is warm, not sooty-black.
//

import SwiftUI
import UIKit

enum YukimoColor {

    // MARK: Brand — Coral

    static let primaryCoral      = dyn(light: 0xFF6B66, dark: 0xFF8580)
    static let primaryCoralDark  = dyn(light: 0xF0525B, dark: 0xF06E6B)
    static let primaryCoralLight = dyn(light: 0xFF9A96, dark: 0xFFB0AB)

    // MARK: Brand — Pink family

    static let softPink = dyn(light: 0xFFD8DD, dark: 0x3A2A30)
    static let palePink = dyn(light: 0xFFF1F4, dark: 0x2A1E24)

    // MARK: Surfaces

    static let creamWhite      = dyn(light: 0xFFF9F7, dark: 0x21171D)
    static let surface         = dyn(light: 0xFFFFFF, dark: 0x21171D)
    static let surfaceElevated = dyn(light: 0xFFF7F8, dark: 0x2B1E26)
    static let background      = dyn(light: 0xFFF6F4, dark: 0x171014)
    static let surfaceHigh     = dyn(light: 0xFFFDFC, dark: 0x2B1E26)

    // MARK: Text

    static let textPrimary   = dyn(light: 0x2B1F24, dark: 0xFFF4F6)
    static let textSecondary = dyn(light: 0x7A5D65, dark: 0xD8B8C0)
    static let textTertiary  = dyn(light: 0xB08A94, dark: 0xA98A92)
    static let textInverted  = Color.white

    // MARK: Accents

    static let accentCherry   = dyn(light: 0xFF8AA0, dark: 0xFF8AA0)
    static let accentLavender = dyn(light: 0xD9C6FF, dark: 0xC7B0FF)
    static let accentSky      = dyn(light: 0xBDE7FF, dark: 0xA9D7F2)

    // MARK: Semantic

    static let success = dyn(light: 0x8FE3C0, dark: 0x6FCBA5)
    static let warning = dyn(light: 0xFFC98B, dark: 0xFFB979)
    static let danger  = dyn(light: 0xFF5E7A, dark: 0xFF7A8E)

    // MARK: Borders / overlays

    static let borderSoft = Color(red: 1.0, green: 107 / 255, blue: 102 / 255).opacity(0.18)
    static let shadowSoft = Color(red: 1.0, green: 107 / 255, blue: 102 / 255).opacity(0.16)
    static let glassTint  = Color.white.opacity(0.62)

    // MARK: Gradients

    static let coralGradient = LinearGradient(
        colors: [Color(hex: 0xFF8A7E), Color(hex: 0xFF5E6B)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let softPinkGradient = LinearGradient(
        colors: [Color(hex: 0xFFE7E1), Color(hex: 0xFFD0CC), Color(hex: 0xFFB6B0)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static let auroraBackground = LinearGradient(
        colors: [Color(hex: 0xFFF6F4), Color(hex: 0xFFE0DC), Color(hex: 0xFFC7C2)],
        startPoint: .top, endPoint: .bottom)

    // MARK: Helpers

    private static func dyn(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex & 0xFF0000) >> 16) / 255
        let g = Double((hex & 0x00FF00) >> 8) / 255
        let b = Double(hex & 0x0000FF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255
        let b = CGFloat(hex & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
