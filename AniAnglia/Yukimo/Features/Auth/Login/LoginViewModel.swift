//
//  LoginViewModel.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var login: String = ""
    var password: String = ""

    var loginError: String?
    var passwordError: String?
    var bannerError: String?

    var isSubmitting: Bool = false

    var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !isSubmitting
    }

    func validate() -> Bool {
        loginError = AuthValidator.checkLoginOrEmail(login).message
        passwordError = AuthValidator.checkPassword(password).message
        return loginError == nil && passwordError == nil
    }

    func submit(onSuccess: @escaping () -> Void) async {
        bannerError = nil
        guard validate() else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                AuthBridge.shared().signIn(login: login, password: password) { ok, err in
                    if ok { cont.resume() }
                    else { cont.resume(throwing: err ?? NSError(domain: YukimoAuthErrorDomain, code: 0)) }
                }
            }
            onSuccess()
        } catch {
            bannerError = AuthErrorMessage.from(error)
        }
    }
}
