//
//  LoadFailureState.swift
//  Centered "couldn't load this" view with retry. Used when libanixart
//  hands back a `Generic Release Error` (typical when the site is having
//  a moment) so the user has a clear action instead of a vague banner.
//

import SwiftUI

struct LoadFailureState: View {
    var title: String = "Не удалось загрузить"
    let message: String
    let onRetry: (() -> Void)?

    init(title: String = "Не удалось загрузить",
         message: String,
         onRetry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: YukimoSpacing.lg) {
            ZStack {
                Circle()
                    .fill(YukimoColor.softPink.opacity(0.7))
                    .frame(width: 96, height: 96)
                Image(systemName: "exclamationmark.icloud")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(YukimoColor.primaryCoral)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(YukimoTypography.title2)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(friendlyMessage)
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, YukimoSpacing.xxl)
            }

            if let onRetry {
                Button("Попробовать снова", action: onRetry)
                    .buttonStyle(.yukimoPrimary)
                    .frame(maxWidth: 280)
            }
        }
        .padding(.horizontal, YukimoSpacing.xxl)
        .padding(.vertical, YukimoSpacing.huge)
        .frame(maxWidth: .infinity)
    }

    /// Strip the noisy `libanixart` prefix from generic exceptions so the
    /// user sees something they can act on, not a debug stack.
    private var friendlyMessage: String {
        let cleaned = message
            .replacingOccurrences(of: "libanixart::", with: "")
            .replacingOccurrences(of: "anixart::", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.lowercased().contains("generic")
            || cleaned.lowercased().contains("release error") {
            return "Сервер вернул ошибку. Это бывает, когда у Anixart проблемы — попробуйте ещё раз через минуту."
        }
        if cleaned.isEmpty { return "Что-то пошло не так." }
        return cleaned
    }
}
