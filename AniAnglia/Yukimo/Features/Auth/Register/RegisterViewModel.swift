//
//  RegisterViewModel.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class RegisterViewModel {
    var login: String = ""
    var email: String = ""
    var password: String = ""
    var confirm: String = ""

    var loginError: String?
    var emailError: String?
    var passwordError: String?
    var confirmError: String?
    var bannerError: String?

    var isSubmitting: Bool = false

    var canSubmit: Bool {
        !login.isEmpty && !email.isEmpty && !password.isEmpty && !confirm.isEmpty && !isSubmitting
    }

    func validate() -> Bool {
        loginError    = AuthValidator.checkUsername(login).message
        emailError    = AuthValidator.checkEmail(email).message
        passwordError = AuthValidator.checkPassword(password).message

        if confirm.isEmpty {
            confirmError = "Подтвердите пароль"
        } else if confirm != password {
            confirmError = "Пароли не совпадают"
        } else {
            confirmError = nil
        }

        return loginError == nil && emailError == nil
            && passwordError == nil && confirmError == nil
    }

    func submit(onPending: @escaping (AuthPending) -> Void) async {
        bannerError = nil
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let pending: AuthPending = try await withCheckedThrowingContinuation { cont in
                AuthBridge.shared().signUp(login: login, email: email, password: password) { p, err in
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
