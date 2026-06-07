//
//  GlassBackground.swift
//  Liquid Glass on iOS 26 with material fallback for older systems
//  and a solid surface fallback when Reduce Transparency is on.
//

import SwiftUI

struct YukimoGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(YukimoColor.surfaceElevated, in: shape)
                .overlay(shape.stroke(YukimoColor.borderSoft, lineWidth: 0.5))
        } else {
            content.background {
                if #available(iOS 26.0, *) {
                    // iOS 26 Liquid Glass
                    Color.clear
                        .modifier(LiquidGlassModifier(shape: shape, tint: tint, interactive: interactive))
                } else {
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay(shape.fill(YukimoColor.glassTint.opacity(0.35)))
                        .overlay(shape.stroke(YukimoColor.borderSoft, lineWidth: 0.5))
                }
            }
        }
    }
}

@available(iOS 26.0, *)
private struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        // Apple's Glass APIs in iOS 26. Guarded by availability so older toolchains
        // still compile; on devices below 26 we never reach this branch.
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        }
    }
}

extension View {
    /// Apply Yukimo glass background. Auto-falls back on iOS < 26 or with Reduce Transparency.
    func yukimoGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(YukimoGlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Convenience: rounded rect of given radius.
    func yukimoGlass(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false) -> some View {
        yukimoGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                    tint: tint, interactive: interactive)
    }
}
