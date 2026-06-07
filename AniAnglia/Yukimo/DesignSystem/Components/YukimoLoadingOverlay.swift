//
//  YukimoLoadingOverlay.swift
//

import SwiftUI

struct YukimoLoadingOverlay: View {
    let message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            VStack(spacing: YukimoSpacing.md) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(YukimoColor.primaryCoral)
                    .scaleEffect(1.2)
                if let message {
                    Text(message)
                        .font(YukimoTypography.callout)
                        .foregroundStyle(YukimoColor.textPrimary)
                }
            }
            .padding(.horizontal, YukimoSpacing.xxl)
            .padding(.vertical, YukimoSpacing.xl)
            .yukimoGlass(cornerRadius: YukimoRadius.lg)
            .yukimoShadow(YukimoShadow.elevated)
        }
        .transition(.opacity)
    }
}
