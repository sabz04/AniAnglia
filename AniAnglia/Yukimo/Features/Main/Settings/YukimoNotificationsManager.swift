//
//  YukimoNotificationsManager.swift
//  iOS-side notification permission state. Doesn't subscribe to anything
//  on the Anixart backend — libanixart only exposes channel/article
//  subscriptions, not per-release new-episode alerts. The toggle here
//  just gates whether the app is allowed to deliver any future local
//  notifications we decide to schedule client-side.
//

import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
final class YukimoNotificationsManager {
    static let shared = YukimoNotificationsManager()

    enum AuthState: Equatable {
        case unknown        // never asked
        case allowed
        case denied
        case provisional
        case ephemeral

        var isAllowed: Bool { self == .allowed || self == .provisional }
    }

    private(set) var state: AuthState = .unknown

    private init() {}

    /// Reads the current system state; safe to call repeatedly.
    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:    state = .allowed
        case .denied:        state = .denied
        case .provisional:   state = .provisional
        case .ephemeral:     state = .ephemeral
        case .notDetermined: state = .unknown
        @unknown default:    state = .unknown
        }
    }

    /// Pops the iOS permission alert if we haven't asked yet. No-op if
    /// the user has already decided one way or the other.
    func requestIfNeeded() async {
        await refresh()
        guard state == .unknown else { return }
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            state = granted ? .allowed : .denied
        } catch {
            state = .denied
        }
    }
}
