//
//  YukimoAppState.swift
//  Top-level observable app state. Owns route + session pointers.
//

import SwiftUI
import Observation

@Observable
final class YukimoAppState {
    var root: YukimoRootRoute = .splash

    /// Held while a sign-up or restore verification is in flight.
    /// Swift can't pass `AuthPending` through enums easily because it's an
    /// Obj-C reference type — so we keep it here and refer to the route by id.
    var activePending: AuthPending?

    @MainActor
    func bootstrap() async {
        // Splash for a beat so the logo animation reads.
        try? await Task.sleep(nanoseconds: 900_000_000)

        if SessionBridge.shared().hasActiveSession {
            withAnimation(YukimoMotion.pageTransition) {
                root = .main
            }
        } else {
            withAnimation(YukimoMotion.pageTransition) {
                root = .auth(.onboarding)
            }
        }
    }

    @MainActor
    func enter(_ route: AuthRoute) {
        withAnimation(YukimoMotion.pageTransition) {
            root = .auth(route)
        }
    }

    @MainActor
    func finishAuth(message: String = "Добро пожаловать в Yukimo") {
        withAnimation(YukimoMotion.pageTransition) {
            root = .auth(.success(message: message))
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(YukimoMotion.pageTransition) {
                    root = .main
                }
            }
        }
    }

    @MainActor
    func logoutToOnboarding() {
        AuthBridge.shared().logout()
        activePending = nil
        withAnimation(YukimoMotion.pageTransition) {
            root = .auth(.onboarding)
        }
    }
}
