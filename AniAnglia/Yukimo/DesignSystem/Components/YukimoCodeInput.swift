//
//  YukimoCodeInput.swift
//  Email/SMS verification code field. 6 boxes by default,
//  backed by a single hidden TextField for paste/auto-fill support.
//

import SwiftUI

struct YukimoCodeInput: View {
    var length: Int = 6
    @Binding var code: String
    var onComplete: ((String) -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: YukimoSpacing.md) {
                ForEach(0..<length, id: \.self) { idx in
                    digitBox(at: idx)
                }
            }
            // Hidden field captures input and SMS auto-fill.
            TextField("", text: Binding(
                get: { code },
                set: { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(length))
                    code = filtered
                    if filtered.count == length { onComplete?(filtered) }
                }))
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.001)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
        .onAppear { focused = true }
    }

    private func digitBox(at index: Int) -> some View {
        let char = code.count > index ? String(code[code.index(code.startIndex, offsetBy: index)]) : ""
        let isActive = code.count == index
        return Text(char.isEmpty ? "•" : char)
            .font(YukimoTypography.codeDigit)
            .foregroundStyle(char.isEmpty ? YukimoColor.textTertiary : YukimoColor.textPrimary)
            .frame(width: 48, height: 60)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isActive && focused ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isActive && focused ? 1.5 : 1)
                    .animation(YukimoMotion.fast, value: isActive))
            .scaleEffect(isActive && focused ? 1.04 : 1)
            .animation(YukimoMotion.springSoft, value: isActive)
    }
}
