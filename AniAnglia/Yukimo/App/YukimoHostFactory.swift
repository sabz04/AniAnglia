//
//  YukimoHostFactory.swift
//  Obj-C-visible factory: SceneDelegate.mm uses this to construct the
//  SwiftUI root inside a UIHostingController without naming generics.
//

import UIKit
import SwiftUI

@objc(YukimoHostFactory)
public final class YukimoHostFactory: NSObject {

    @objc public static func makeRootViewController() -> UIViewController {
        let host = UIHostingController(rootView: YukimoRootView())
        host.view.backgroundColor = .clear
        return host
    }
}
