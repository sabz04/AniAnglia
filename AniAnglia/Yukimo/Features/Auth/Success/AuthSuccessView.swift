//
//  AuthSuccessView.swift
//

import SwiftUI

struct AuthSuccessView: View {
    let message: String

    @State private var checkScale: CGFloat = 0.4
    @State private var glow: Double = 0

    var body: some View {
        VStack(spacing: YukimoSpacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(YukimoColor.success.opacity(0.20))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(YukimoColor.success.opacity(0.35))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(YukimoColor.success)
                    .symbolRenderingMode(.hierarchical)
                    .scaleEffect(checkScale)
                    .opacity(glow)
            }
            Text(message)
                .font(YukimoTypography.title2)
                .foregroundStyle(YukimoColor.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(glow)

            Spacer()
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkScale = 1
                glow = 1
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
