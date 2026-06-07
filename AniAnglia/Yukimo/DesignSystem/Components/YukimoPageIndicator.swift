//
//  YukimoPageIndicator.swift
//

import SwiftUI

struct YukimoPageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: YukimoSpacing.sm) {
            ForEach(0..<count, id: \.self) { idx in
                Capsule()
                    .fill(idx == current ? YukimoColor.primaryCoral : YukimoColor.borderSoft)
                    .frame(width: idx == current ? 24 : 8, height: 8)
                    .animation(YukimoMotion.springSoft, value: current)
            }
        }
    }
}
