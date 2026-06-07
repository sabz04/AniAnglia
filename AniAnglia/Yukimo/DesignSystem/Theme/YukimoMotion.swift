//
//  YukimoMotion.swift
//

import SwiftUI

enum YukimoMotion {
    static let fast       = Animation.easeOut(duration: 0.18)
    static let normal     = Animation.easeInOut(duration: 0.28)
    static let slow       = Animation.easeInOut(duration: 0.45)

    static let springSoft   = Animation.spring(response: 0.4,  dampingFraction: 0.85)
    static let springBouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
    static let springSnap   = Animation.spring(response: 0.28, dampingFraction: 0.78)

    static let pageTransition = Animation.spring(response: 0.5, dampingFraction: 0.82)
}
