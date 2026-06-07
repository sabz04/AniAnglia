//
//  VerificationView.swift
//

import SwiftUI

struct VerificationView: View {
    @Environment(YukimoAppState.self) private var app
    let mode: VerificationMode
    let target: String

    @State private var vm: VerificationViewModel

    init(mode: VerificationMode, target: String) {
        self.mode = mode
        self.target = target
        self._vm = State(initialValue: VerificationViewModel(mode: mode))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                AuthHeader(
                    title: "Подтверждение",
                    subtitle: subtitleText
                )

                if let bannerError = vm.bannerError {
                    YukimoErrorBanner(message: bannerError)
                        .animation(YukimoMotion.springSoft, value: vm.bannerError)
                }

                YukimoSurfaceCard {
                    VStack(spacing: YukimoSpacing.xl) {
                        YukimoCodeInput(length: 6, code: $vm.code) { _ in
                            Task { await submit() }
                        }

                        VStack(spacing: 6) {
                            Text("Не получили код?")
                                .font(YukimoTypography.subhead)
                                .foregroundStyle(YukimoColor.textSecondary)
                            if vm.canResend {
                                Button("Отправить повторно") {
                                    vm.resend()
                                }
                                .buttonStyle(.yukimoGhost)
                            } else {
                                Text("Повторно через \(vm.secondsUntilResend) с")
                                    .font(YukimoTypography.subhead)
                                    .foregroundStyle(YukimoColor.textTertiary)
                            }
                        }
                    }
                }

                Button {
                    Task { await submit() }
                } label: {
                    Text("Подтвердить")
                }
                .buttonStyle(.yukimoPrimary(loading: vm.isSubmitting))
                .disabled(!vm.canSubmit)

                Spacer(minLength: YukimoSpacing.huge)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.top, YukimoSpacing.huge)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay(alignment: .topLeading) {
            BackButton {
                app.activePending = nil
                app.enter(mode == .signUp ? .register : .forgotPassword)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.top, YukimoSpacing.lg)
        }
        .onAppear { vm.startResendTimer() }
    }

    private var subtitleText: String {
        switch mode {
        case .signUp:  return "Введите код из письма на \(target)"
        case .restore: return "Введите код подтверждения для \(target)"
        }
    }

    private func submit() async {
        await vm.submit(pending: app.activePending) {
            app.activePending = nil
            app.finishAuth(message: mode == .signUp
                           ? "Добро пожаловать в Yukimo"
                           : "Пароль обновлён")
        }
    }
}
