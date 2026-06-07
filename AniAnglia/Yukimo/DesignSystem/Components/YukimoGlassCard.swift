//
//  YukimoGlassCard.swift
//

import SwiftUI

struct YukimoGlassCard<Content: View>: View {
    var padding: CGFloat = YukimoSpacing.xxl
    var corner: CGFloat = YukimoRadius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .yukimoGlass(cornerRadius: corner)
            .yukimoShadow(YukimoShadow.soft)
    }
}

struct YukimoSurfaceCard<Content: View>: View {
    var padding: CGFloat = YukimoSpacing.xxl
    var corner: CGFloat = YukimoRadius.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
            .yukimoShadow(YukimoShadow.soft)
    }
}
