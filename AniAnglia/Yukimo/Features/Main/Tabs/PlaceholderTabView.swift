//
//  PlaceholderTabView.swift
//  Soft, branded "coming soon" for tabs not yet implemented.
//

import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        ZStack {
            YukimoColor.background.ignoresSafeArea()
            VStack(spacing: YukimoSpacing.xl) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(YukimoColor.softPink.opacity(0.5))
                        .frame(width: 160, height: 160)
                    Image(systemName: systemImage)
                        .font(.system(size: 64, weight: .regular))
                        .foregroundStyle(YukimoColor.primaryCoral)
                        .symbolRenderingMode(.hierarchical)
                }
                VStack(spacing: YukimoSpacing.sm) {
                    Text(title)
                        .font(YukimoTypography.title2)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text(subtitle)
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, YukimoSpacing.xxl)
                }
                Spacer()
            }
        }
    }
}
