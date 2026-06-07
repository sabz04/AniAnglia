//
//  VerificationViewModel.swift
//

import SwiftUI
import Observation

enum VerificationMode {
    case signUp
    case restore
}

@Observable
@MainActor
final class VerificationViewModel {
    let mode: VerificationMode
    var code: String = ""
    var bannerError: String?
    var isSubmitting: Bool = false
    var secondsUntilResend: Int = 60

    private var timerTask: Task<Void, Never>?

    init(mode: VerificationMode) {
        self.mode = mode
    }

    // No explicit deinit cancellation: the timer loop checks `self?` weakly and
    // terminates when the view model is deallocated. Mutating @MainActor state
    // from a nonisolated deinit is not allowed.

    var canSubmit: Bool { code.count == 6 && !isSubmitting }
    var canResend: Bool { secondsUntilResend == 0 && !isSubmitting }

    func startResendTimer() {
        timerTask?.cancel()
        secondsUntilResend = 60
        timerTask = Task { [weak self] in
            while let s = self?.secondsUntilResend, s > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    if let value = self?.secondsUntilResend, value > 0 {
                        self?.secondsUntilResend = value - 1
                    }
                }
            }
        }
    }

    func resend() {
        // The current libanixart auth pending object doesn't expose a "resend"
        // method directly — restart the timer so the user can re-trigger via
        // their email client. When the API gains a resend endpoint we'll hook it.
        startResendTimer()
    }

    func submit(pending: AuthPending?, onSuccess: @escaping () -> Void) async {
        bannerError = nil
        guard let pending else {
            bannerError = "Сессия истекла, попробуйте снова."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                switch mode {
                case .signUp:
                    AuthBridge.shared().verifySignUp(pending: pending, code: code) { ok, err in
                        if ok { cont.resume() }
                        else { cont.resume(throwing: err ?? NSError(domain: YukimoAuthErrorDomain, code: 0)) }
                    }
                case .restore:
                    AuthBridge.shared().verifyRestore(pending: pending, code: code) { ok, err in
                        if ok { cont.resume() }
                        else { cont.resume(throwing: err ?? NSError(domain: YukimoAuthErrorDomain, code: 0)) }
                    }
                }
            }
            onSuccess()
        } catch {
            bannerError = AuthErrorMessage.from(error)
        }
    }
}
