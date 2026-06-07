//
//  YukimoShadow.swift
//

import SwiftUI

struct YukimoShadowSpec {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum YukimoShadow {
    static let soft     = YukimoShadowSpec(color: YukimoColor.shadowSoft,                  radius: 16, x: 0, y: 6)
    static let elevated = YukimoShadowSpec(color: YukimoColor.shadowSoft.opacity(0.5),     radius: 24, x: 0, y: 12)
    static let press    = YukimoShadowSpec(color: YukimoColor.shadowSoft.opacity(0.4),     radius: 8,  x: 0, y: 2)
    static let glow     = YukimoShadowSpec(color: Color(hex: 0xFF6B66).opacity(0.45),      radius: 24, x: 0, y: 0)
}

extension View {
    func yukimoShadow(_ spec: YukimoShadowSpec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
