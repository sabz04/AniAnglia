//
//  MainPlaceholderView.swift
//  Stub for Phase 4. Auth Flow ends here; real Main shell comes next.
//

import SwiftUI

struct YukimoMainPlaceholderView: View {
    @Environment(YukimoAppState.self) private var app

    var body: some View {
        VStack(spacing: YukimoSpacing.xl) {
            Spacer()

            YukimoLogoMark()
                .frame(width: 132, height: 132)

            VStack(spacing: YukimoSpacing.sm) {
                Text("Добро пожаловать!")
                    .font(YukimoTypography.title)
                    .foregroundStyle(YukimoColor.textPrimary)
                Text("Главный экран появится в Phase 4.")
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, YukimoSpacing.lg)

            Spacer()

            Button("Выйти") {
                app.logoutToOnboarding()
            }
            .buttonStyle(.yukimoSecondary)
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.bottom, YukimoSpacing.xxl)
        }
    }
}
