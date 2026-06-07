//
//  YukimoTextField.swift
//  Native TextField with soft pink card chrome, leading SF icon,
//  focus glow, validation state, and accessibility.
//

import SwiftUI

struct YukimoTextField: View {
    let title: String
    let systemImage: String?
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .never
    var errorMessage: String? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: YukimoSpacing.md) {
                if let systemImage {
                    YukimoIcon(name: systemImage,
                               size: 16,
                               weight: .semibold,
                               color: focused ? YukimoColor.primaryCoral : YukimoColor.textTertiary)
                        .animation(YukimoMotion.fast, value: focused)
                }
                TextField(title, text: $text, prompt: Text(title).foregroundStyle(YukimoColor.textTertiary))
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .submitLabel(submitLabel)
                    .onSubmit { onSubmit?() }
                    .focused($focused)
            }
            .padding(.horizontal, YukimoSpacing.lg)
            .frame(height: 56)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous)
                    .stroke(borderColor, lineWidth: focused || errorMessage != nil ? 1.5 : 1)
                    .animation(YukimoMotion.fast, value: focused)
                    .animation(YukimoMotion.fast, value: errorMessage)
            )

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(YukimoTypography.footnote)
                    .foregroundStyle(YukimoColor.danger)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return YukimoColor.danger }
        if focused { return YukimoColor.primaryCoral }
        return YukimoColor.borderSoft
    }
}

struct YukimoSecureField: View {
    let title: String
    let systemImage: String?
    @Binding var text: String
    var textContentType: UITextContentType? = .password
    var errorMessage: String? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool
    @State private var revealed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: YukimoSpacing.md) {
                if let systemImage {
                    YukimoIcon(name: systemImage,
                               size: 16,
                               weight: .semibold,
                               color: focused ? YukimoColor.primaryCoral : YukimoColor.textTertiary)
                        .animation(YukimoMotion.fast, value: focused)
                }
                Group {
                    if revealed {
                        TextField(title, text: $text, prompt: Text(title).foregroundStyle(YukimoColor.textTertiary))
                    } else {
                        SecureField(title, text: $text, prompt: Text(title).foregroundStyle(YukimoColor.textTertiary))
                    }
                }
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textPrimary)
                .textContentType(textContentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                .focused($focused)

                Button {
                    revealed.toggle()
                } label: {
                    YukimoIcon(name: revealed ? YukimoSymbol.eyeSlash : YukimoSymbol.eye,
                               size: 16, weight: .regular,
                               color: YukimoColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? "Скрыть пароль" : "Показать пароль")
            }
            .padding(.horizontal, YukimoSpacing.lg)
            .frame(height: 56)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous)
                    .stroke(borderColor, lineWidth: focused || errorMessage != nil ? 1.5 : 1)
                    .animation(YukimoMotion.fast, value: focused)
                    .animation(YukimoMotion.fast, value: errorMessage)
            )

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(YukimoTypography.footnote)
                    .foregroundStyle(YukimoColor.danger)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return YukimoColor.danger }
        if focused { return YukimoColor.primaryCoral }
        return YukimoColor.borderSoft
    }
}
