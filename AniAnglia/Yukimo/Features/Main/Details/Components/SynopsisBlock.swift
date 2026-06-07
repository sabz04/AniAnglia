//
//  SynopsisBlock.swift
//  Apple TV-style synopsis: 3-line clamp with a fading edge — tap anywhere
//  to expand. No explicit "Read more" button — the fade IS the affordance.
//

import SwiftUI

struct SynopsisBlock: View {
    let text: String
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
            Label("Описание", systemImage: "text.alignleft")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)

            ZStack(alignment: .bottom) {
                Text(cleaned)
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .lineLimit(expanded ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !expanded && cleaned.count > 120 {
                    LinearGradient(
                        colors: [
                            YukimoColor.background.opacity(0),
                            YukimoColor.background.opacity(0.85),
                            YukimoColor.background,
                        ],
                        startPoint: .top, endPoint: .bottom)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    expanded.toggle()
                }
            }
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    /// Very cheap HTML cleanup — Anixart descriptions sometimes contain
    /// `<br>`, `&amp;`, `&quot;`, `&nbsp;` etc.
    private var cleaned: String {
        text
            .replacingOccurrences(of: "<br/>",  with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br>",   with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;",  with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
