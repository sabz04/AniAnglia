//
//  ForgotPasswordView.swift
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(YukimoAppState.self) private var app
    @State private var vm = ForgotPasswordViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                AuthHeader(
                    title: "Восстановление",
                    subtitle: "Введите email или логин — отправим код подтверждения"
                )

                if let bannerError = vm.bannerError {
                    YukimoErrorBanner(message: bannerError)
                        .animation(YukimoMotion.springSoft, value: vm.bannerError)
                }

                YukimoSurfaceCard {
                    VStack(spacing: YukimoSpacing.lg) {
                        YukimoTextField(
                            title: "Логин или email",
                            systemImage: YukimoSymbol.envelope,
                            text: $vm.loginOrEmail,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            errorMessage: vm.loginError)

                        YukimoSecureField(
                            title: "Новый пароль",
                            systemImage: YukimoSymbol.lock,
                            text: $vm.newPassword,
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
                    Text("Отправить код")
                }
                .buttonStyle(.yukimoPrimary(loading: vm.isSubmitting))
                .disabled(!vm.canSubmit)

                AuthSwitchFooter(question: "Вспомнили пароль?",
                                 actionTitle: "Войти") { app.enter(.login) }

                Spacer(minLength: YukimoSpacing.huge)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.top, YukimoSpacing.huge)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .topLeading) {
            BackButton { app.enter(.login) }
                .padding(.horizontal, YukimoSpacing.screenPadding)
                .padding(.top, YukimoSpacing.lg)
        }
    }

    private func submit() async {
        await vm.submit { pending in
            app.activePending = pending
            app.enter(.verifyRestore(pendingId: ObjectIdentifier(pending),
                                     loginOrEmail: vm.loginOrEmail))
        }
    }
}
