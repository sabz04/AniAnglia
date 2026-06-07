//
//  YukimoErrorBanner.swift
//

import SwiftUI

struct YukimoErrorBanner: View {
    let message: String
    var systemImage: String = YukimoSymbol.warning

    var body: some View {
        HStack(spacing: YukimoSpacing.md) {
            YukimoIcon(name: systemImage, size: 18, weight: .semibold, color: YukimoColor.danger)
            Text(message)
                .font(YukimoTypography.subhead)
                .foregroundStyle(YukimoColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, YukimoSpacing.lg)
        .padding(.vertical, YukimoSpacing.md)
        .background(YukimoColor.danger.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.danger.opacity(0.35), lineWidth: 0.8))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
