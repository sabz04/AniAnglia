//
//  YukimoRootView.swift
//  Top-level switching between Splash / Auth / Main.
//

import SwiftUI

struct YukimoRootView: View {
    @State private var app = YukimoAppState()

    var body: some View {
        ZStack {
            YukimoGradientBackground()

            Group {
                switch app.root {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                case .auth(let route):
                    AuthRouterView(route: route)
                        .environment(app)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal:   .opacity.combined(with: .move(edge: .leading))))
                case .main:
                    YukimoMainTabView()
                        .environment(app)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .environment(app)
        .task { await app.bootstrap() }
        .preferredColorScheme(nil) // honour system; theme bridge wires user override later.
        .animation(YukimoMotion.pageTransition, value: app.root)
    }
}

struct AuthRouterView: View {
    let route: AuthRoute

    var body: some View {
        switch route {
        case .onboarding:
            OnboardingView()
        case .login:
            LoginView()
        case .register:
            RegisterView()
        case .forgotPassword:
            ForgotPasswordView()
        case .verifySignUp(_, let email):
            VerificationView(mode: .signUp, target: email)
        case .verifyRestore(_, let loginOrEmail):
            VerificationView(mode: .restore, target: loginOrEmail)
        case .success(let message):
            AuthSuccessView(message: message)
        }
    }
}
