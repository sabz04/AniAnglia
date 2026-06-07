//
//  HomeView.swift
//  Main feed. All data is live from libanixart.
//

import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @Environment(YukimoAppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xxl) {
                header

                Group {
                    if let hero = vm.hero {
                        NavigationLink(value: ReleaseRoute(releaseID: hero.releaseID)) {
                            HeroCard(release: hero, isLoading: false)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HeroCard(release: nil, isLoading: vm.heroIsLoading)
                    }
                }
                .padding(.horizontal, YukimoSpacing.screenPadding)

                if !vm.continueWatching.items.isEmpty || vm.continueWatching.isLoading {
                    continueWatchingSection
                }

                PosterRail(title: "Рекомендуем тебе",
                           subtitle: "Под твой вкус",
                           systemImage: "sparkles",
                           state: vm.recommendations)

                PosterRail(title: "Сейчас смотрят",
                           subtitle: "Популярное прямо сейчас",
                           systemImage: "flame.fill",
                           state: vm.currentlyWatching)

                PosterRail(title: "Обсуждают",
                           subtitle: "Свежие комментарии",
                           systemImage: "bubble.left.and.bubble.right.fill",
                           state: vm.discussing)

                Color.clear.frame(height: 80)
            }
            .padding(.top, YukimoSpacing.md)
        }
        .scrollIndicators(.hidden)
        .background(YukimoColor.background.ignoresSafeArea())
        .refreshable { await vm.loadAll() }
        .task { await vm.loadAll() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: YukimoSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greeting)
                    .font(YukimoTypography.subhead)
                    .foregroundStyle(YukimoColor.textSecondary)
                Text(vm.profile?.username ?? "в Yukimo")
                    .font(YukimoTypography.title)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            avatar
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = vm.profile?.avatarURL {
            YukimoAsyncImage(urlString: url)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(YukimoColor.primaryCoral.opacity(0.4), lineWidth: 1.5))
        } else {
            ZStack {
                Circle().fill(YukimoColor.softPink)
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(YukimoColor.primaryCoral)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: Continue Watching

    private var continueWatchingSection: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.md) {
            SectionHeader(title: "Продолжить просмотр",
                          subtitle: nil,
                          systemImage: "play.circle.fill")
            if vm.continueWatching.isLoading && vm.continueWatching.items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: YukimoSpacing.md) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
                                .fill(YukimoColor.softPink)
                                .frame(width: 280, height: 120)
                        }
                    }
                    .padding(.horizontal, YukimoSpacing.screenPadding)
                }
                .redacted(reason: .placeholder)
                .shimmering()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: YukimoSpacing.md) {
                        ForEach(vm.continueWatching.items, id: \.releaseID) { item in
                            NavigationLink(value: ReleaseRoute(releaseID: item.releaseID)) {
                                ContinueWatchingCard(release: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, YukimoSpacing.screenPadding)
                }
            }
        }
    }
}
