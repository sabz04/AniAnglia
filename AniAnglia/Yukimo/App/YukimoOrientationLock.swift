//
//  YukimoOrientationLock.swift
//  Global interface-orientation gatekeeper. AppDelegate reads `allowed`
//  in its `supportedInterfaceOrientationsForWindow:` callback. SwiftUI
//  views flip the lock via `setPortrait` / `setLandscape` in onAppear /
//  onDisappear pairs.
//

import Foundation
import UIKit

@objc(YukimoOrientationLock)
public final class YukimoOrientationLock: NSObject {
    @objc public static let shared = YukimoOrientationLock()

    private override init() {
        super.init()
    }

    /// What UIKit is allowed to rotate to right now.
    @objc public var allowed: UIInterfaceOrientationMask = .portrait

    @objc public func setPortrait() {
        allowed = .portrait
        requestGeometry(.portrait)
    }

    @objc public func setLandscape() {
        // Allow both .landscapeLeft and .landscapeRight — but request the
        // current physical orientation if it's already landscape, otherwise
        // request landscapeRight as a sensible default.
        allowed = .landscape
        requestGeometry(.landscapeRight)
    }

    private func requestGeometry(_ orientations: UIInterfaceOrientationMask) {
        if #available(iOS 16.0, *) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .forEach { scene in
                    scene.requestGeometryUpdate(
                        .iOS(interfaceOrientations: orientations)
                    ) { _ in }
                    scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
        } else {
            // Pre-iOS 16 fallback — `attemptRotationToDeviceOrientation` reads
            // VC's `supportedInterfaceOrientations` and rotates accordingly.
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}
