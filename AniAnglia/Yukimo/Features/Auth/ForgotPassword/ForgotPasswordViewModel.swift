//
//  ForgotPasswordViewModel.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ForgotPasswordViewModel {
    var loginOrEmail: String = ""
    var newPassword: String = ""
    var confirm: String = ""

    var loginError: String?
    var passwordError: String?
    var confirmError: String?
    var bannerError: String?

    var isSubmitting: Bool = false

    var canSubmit: Bool {
        !loginOrEmail.isEmpty && !newPassword.isEmpty && !confirm.isEmpty && !isSubmitting
    }

    func validate() -> Bool {
        loginError = AuthValidator.checkLoginOrEmail(loginOrEmail).message
        passwordError = AuthValidator.checkPassword(newPassword).message
        if confirm.isEmpty {
            confirmError = "Подтвердите пароль"
        } else if confirm != newPassword {
            confirmError = "Пароли не совпадают"
        } else {
            confirmError = nil
        }
        return loginError == nil && passwordError == nil && confirmError == nil
    }

    func submit(onPending: @escaping (AuthPending) -> Void) async {
        bannerError = nil
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let pending: AuthPending = try await withCheckedThrowingContinuation { cont in
                AuthBridge.shared().restorePassword(
                    loginOrEmail: loginOrEmail, newPassword: newPassword
                ) { p, err in
                    if let p {
                        cont.resume(returning: p)
                    } else {
                        cont.resume(throwing: err ?? NSError(domain: YukimoAuthErrorDomain, code: 0))
                    }
                }
            }
            onPending(pending)
        } catch {
            bannerError = AuthErrorMessage.from(error)
        }
    }
}
