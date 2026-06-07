//
//  YukimoRoute.swift
//

import Foundation

enum YukimoRootRoute: Equatable {
    case splash
    case auth(AuthRoute)
    case main
}

enum AuthRoute: Equatable {
    case onboarding
    case login
    case register
    case forgotPassword
    case verifySignUp(pendingId: ObjectIdentifier, email: String)
    case verifyRestore(pendingId: ObjectIdentifier, loginOrEmail: String)
    case success(message: String)
}

/// Stable hashable navigation value for pushing AnimeDetailsView.
struct ReleaseRoute: Hashable {
    let releaseID: Int64
}
