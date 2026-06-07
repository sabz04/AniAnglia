//
//  YukimoIcon.swift
//  SF Symbol wrapper with consistent rendering / weight.
//

import SwiftUI

struct YukimoIcon: View {
    let name: String
    var size: CGFloat = 17
    var weight: Font.Weight = .semibold
    var color: Color = YukimoColor.textPrimary

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight, design: .rounded))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }
}

enum YukimoSymbol {
    // Tab bar
    static let home          = "house"
    static let homeFilled    = "house.fill"
    static let search        = "magnifyingglass"
    static let library       = "bookmark"
    static let libraryFilled = "bookmark.fill"
    static let feed          = "bubble.left.and.bubble.right"
    static let feedFilled    = "bubble.left.and.bubble.right.fill"
    static let profile       = "person"
    static let profileFilled = "person.fill"

    // Auth
    static let envelope      = "envelope.fill"
    static let lock          = "lock.fill"
    static let lockOpen      = "lock.open.fill"
    static let user          = "person.fill"
    static let eye           = "eye"
    static let eyeSlash      = "eye.slash"
    static let checkCircle   = "checkmark.circle.fill"
    static let xmark         = "xmark"
    static let arrowRight    = "arrow.right"
    static let chevronLeft   = "chevron.left"
    static let chevronRight  = "chevron.right"
    static let warning       = "exclamationmark.triangle.fill"
    static let info          = "info.circle.fill"
    static let sparkles      = "sparkles"
    static let heart         = "heart.fill"
    static let play          = "play.fill"
    static let playCircle    = "play.circle.fill"

    // Onboarding
    static let stack         = "rectangle.stack.fill"
    static let chat          = "bubble.left.and.bubble.right.fill"
    static let target        = "target"
    static let wand          = "wand.and.stars"
}
