//
//  LoginView.swift
//

import SwiftUI

struct LoginView: View {
    @Environment(YukimoAppState.self) private var app
    @State private var vm = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                AuthHeader(
                    title: "С возвращением",
                    subtitle: "Войдите, чтобы продолжить смотреть"
                )

                if let bannerError = vm.bannerError {
                    YukimoErrorBanner(message: bannerError)
                        .animation(YukimoMotion.springSoft, value: vm.bannerError)
                }

                YukimoSurfaceCard {
                    VStack(spacing: YukimoSpacing.lg) {
                        YukimoTextField(
                            title: "Логин или email",
                            systemImage: YukimoSymbol.user,
                            text: $vm.login,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            errorMessage: vm.loginError)

                        YukimoSecureField(
                            title: "Пароль",
                            systemImage: YukimoSymbol.lock,
                            text: $vm.password,
                            textContentType: .password,
                            errorMessage: vm.passwordError,
                            onSubmit: { Task { await submit() } })

                        HStack {
                            Spacer()
                            Button("Забыли пароль?") {
                                app.enter(.forgotPassword)
                            }
                            .buttonStyle(.yukimoGhost)
                        }
                    }
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text("Войти")
                }
                .buttonStyle(.yukimoPrimary(loading: vm.isSubmitting))
                .disabled(!vm.canSubmit)

                AuthSwitchFooter(question: "Нет аккаунта?",
                                 actionTitle: "Создать") { app.enter(.register) }

                Spacer(minLength: YukimoSpacing.huge)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.top, YukimoSpacing.huge)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .topLeading) {
            BackButton { app.enter(.onboarding) }
                .padding(.horizontal, YukimoSpacing.screenPadding)
                .padding(.top, YukimoSpacing.lg)
        }
    }

    private func submit() async {
        await vm.submit { app.finishAuth(message: "С возвращением!") }
    }
}

struct AuthHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: YukimoSpacing.sm) {
            YukimoLogoMark()
                .frame(width: 72, height: 72)
                .padding(.bottom, YukimoSpacing.md)

            Text(title)
                .font(YukimoTypography.title)
                .foregroundStyle(YukimoColor.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct AuthSwitchFooter: View {
    let question: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: YukimoSpacing.xs) {
            Text(question)
                .font(YukimoTypography.subhead)
                .foregroundStyle(YukimoColor.textSecondary)
            Button(actionTitle, action: action)
                .buttonStyle(.yukimoGhost)
        }
    }
}

struct BackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                YukimoIcon(name: YukimoSymbol.chevronLeft, size: 14, weight: .bold,
                           color: YukimoColor.textPrimary)
                Text("Назад")
                    .font(YukimoTypography.subhead)
                    .foregroundStyle(YukimoColor.textPrimary)
            }
            .padding(.horizontal, YukimoSpacing.md)
            .padding(.vertical, YukimoSpacing.sm)
            .yukimoGlass(cornerRadius: YukimoRadius.pill)
        }
        .buttonStyle(.plain)
    }
}
