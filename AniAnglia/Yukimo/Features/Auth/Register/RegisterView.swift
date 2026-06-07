//
//  RegisterView.swift
//

import SwiftUI

struct RegisterView: View {
    @Environment(YukimoAppState.self) private var app
    @State private var vm = RegisterViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                AuthHeader(
                    title: "Добро пожаловать",
                    subtitle: "Создайте аккаунт, чтобы начать"
                )

                if let bannerError = vm.bannerError {
                    YukimoErrorBanner(message: bannerError)
                        .animation(YukimoMotion.springSoft, value: vm.bannerError)
                }

                YukimoSurfaceCard {
                    VStack(spacing: YukimoSpacing.lg) {
                        YukimoTextField(
                            title: "Логин",
                            systemImage: YukimoSymbol.user,
                            text: $vm.login,
                            textContentType: .username,
                            errorMessage: vm.loginError)

                        YukimoTextField(
                            title: "Email",
                            systemImage: YukimoSymbol.envelope,
                            text: $vm.email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            errorMessage: vm.emailError)

                        YukimoSecureField(
                            title: "Пароль",
                            systemImage: YukimoSymbol.lock,
                            text: $vm.password,
                            textContentType: .newPassword,
                            errorMessage: vm.passwordError)

                        YukimoSecureField(
                            title: "Подтвердите пароль",
                            systemImage: YukimoSymbol.lock,
                            text: $vm.confirm,
                            textContentType: .newPassword,
                            errorMessage: vm.confirmError,
                            onSubmit: { Task { await submit() } })
                    }
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text("Создать аккаунт")
                }
                .buttonStyle(.yukimoPrimary(loading: vm.isSubmitting))
                .disabled(!vm.canSubmit)

                AuthSwitchFooter(question: "Уже есть аккаунт?",
                                 actionTitle: "Войти") { app.enter(.login) }

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
        await vm.submit { pending in
            app.activePending = pending
            app.enter(.verifySignUp(pendingId: ObjectIdentifier(pending), email: vm.email))
        }
    }
}
