//
//  DetailsBadge.swift
//  Small pill badge used on top of the hero header (category + status).
//

import SwiftUI

struct DetailsBadge: View {
    enum Scheme { case onLight, onDark }

    let icon: String
    let label: String
    var tint: Color = YukimoColor.primaryCoral
    var scheme: Scheme = .onDark

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .lineLimit(1)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundShape, in: Capsule())
        .overlay(Capsule().stroke(strokeColor, lineWidth: 0.6))
    }

    private var foregroundColor: Color {
        switch scheme {
        case .onLight: return tint
        case .onDark:  return .white
        }
    }

    private var backgroundShape: AnyShapeStyle {
        switch scheme {
        case .onLight: return AnyShapeStyle(YukimoColor.softPink)
        case .onDark:  return AnyShapeStyle(Color.white.opacity(0.18))
        }
    }

    private var strokeColor: Color {
        switch scheme {
        case .onLight: return tint.opacity(0.3)
        case .onDark:  return .white.opacity(0.22)
        }
    }
}
