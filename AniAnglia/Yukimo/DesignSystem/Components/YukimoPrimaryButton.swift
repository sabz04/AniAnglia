//
//  YukimoPrimaryButton.swift
//

import SwiftUI

struct YukimoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .font(YukimoTypography.buttonLarge)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFF8A7E), Color(hex: 0xFF5E6B)],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: YukimoRadius.button, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.button, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 0.8))
        .opacity(isEnabled ? 1 : 0.45)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .yukimoShadow(configuration.isPressed ? YukimoShadow.press : YukimoShadow.soft)
        .animation(YukimoMotion.springSoft, value: configuration.isPressed)
        .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

struct YukimoSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(YukimoTypography.buttonLarge)
            .foregroundStyle(YukimoColor.primaryCoral)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                YukimoColor.softPink.opacity(configuration.isPressed ? 0.9 : 1),
                in: RoundedRectangle(cornerRadius: YukimoRadius.button, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(YukimoMotion.springSoft, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

struct YukimoGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(YukimoTypography.bodyEmph)
            .foregroundStyle(YukimoColor.primaryCoral)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(YukimoMotion.fast, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == YukimoPrimaryButtonStyle {
    static var yukimoPrimary: YukimoPrimaryButtonStyle { .init() }
    static func yukimoPrimary(loading: Bool) -> YukimoPrimaryButtonStyle {
        .init(isLoading: loading)
    }
}

extension ButtonStyle where Self == YukimoSecondaryButtonStyle {
    static var yukimoSecondary: YukimoSecondaryButtonStyle { .init() }
}

extension ButtonStyle where Self == YukimoGhostButtonStyle {
    static var yukimoGhost: YukimoGhostButtonStyle { .init() }
}
