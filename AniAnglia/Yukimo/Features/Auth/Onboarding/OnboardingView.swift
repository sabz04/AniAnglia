//
//  OnboardingView.swift
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
}

struct OnboardingView: View {
    @Environment(YukimoAppState.self) private var app
    @State private var index: Int = 0

    private let pages: [OnboardingPage] = [
        .init(symbol: "play.circle.fill",
              symbolColor: Color(hex: 0xFF6B66),
              title: "Смотри любимое аниме",
              subtitle: "Каталог тысяч тайтлов с озвучками и субтитрами."),
        .init(symbol: "bookmark.fill",
              symbolColor: Color(hex: 0xFF8AA0),
              title: "Собирай списки",
              subtitle: "Отслеживай прогресс и продолжай с того же места."),
        .init(symbol: "bubble.left.and.bubble.right.fill",
              symbolColor: Color(hex: 0xD9C6FF),
              title: "Общайся с комьюнити",
              subtitle: "Комментарии, реакции и обсуждения серий."),
        .init(symbol: "sparkles",
              symbolColor: Color(hex: 0xFFC98B),
              title: "Получай рекомендации",
              subtitle: "Подборки под твой вкус, обновляются каждый день."),
    ]

    var body: some View {
        VStack(spacing: YukimoSpacing.xl) {
            HStack {
                Spacer()
                Button("Пропустить") {
                    app.enter(.login)
                }
                .buttonStyle(.yukimoGhost)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)

            TabView(selection: $index) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { idx, page in
                    OnboardingPageView(page: page)
                        .tag(idx)
                        .padding(.horizontal, YukimoSpacing.screenPadding)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(YukimoMotion.pageTransition, value: index)

            YukimoPageIndicator(count: pages.count, current: index)

            VStack(spacing: YukimoSpacing.md) {
                Button {
                    if index < pages.count - 1 {
                        withAnimation(YukimoMotion.pageTransition) { index += 1 }
                    } else {
                        app.enter(.register)
                    }
                } label: {
                    HStack(spacing: YukimoSpacing.sm) {
                        Text(index == pages.count - 1 ? "Начать" : "Далее")
                        YukimoIcon(name: YukimoSymbol.arrowRight, size: 14, weight: .bold, color: .white)
                    }
                }
                .buttonStyle(.yukimoPrimary)

                Button("У меня уже есть аккаунт") {
                    app.enter(.login)
                }
                .buttonStyle(.yukimoGhost)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .padding(.bottom, YukimoSpacing.xxl)
        }
        .padding(.top, YukimoSpacing.lg)
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: YukimoSpacing.xxl) {
            ZStack {
                Circle()
                    .fill(page.symbolColor.opacity(0.18))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(page.symbolColor.opacity(0.28))
                    .frame(width: 140, height: 140)
                Image(systemName: page.symbol)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(page.symbolColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, YukimoSpacing.lg)

            VStack(spacing: YukimoSpacing.md) {
                Text(page.title)
                    .font(YukimoTypography.title)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, YukimoSpacing.md)
            }

            Spacer(minLength: 0)
        }
    }
}
