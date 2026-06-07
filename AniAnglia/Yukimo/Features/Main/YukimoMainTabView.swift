//
//  YukimoMainTabView.swift
//  iOS 26 tab bar shell. Each tab owns its own NavigationStack so push
//  state survives tab switches and back gestures behave naturally.
//

import SwiftUI

struct YukimoMainTabView: View {
    enum Tab: Hashable { case home, search, library, feed, profile }

    @State private var selection: Tab = .home
    @State private var homePath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var profilePath = NavigationPath()

    @Environment(YukimoAppState.self) private var app

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $homePath) {
                HomeView()
                    .navigationDestination(for: ReleaseRoute.self) { route in
                        AnimeDetailsView(releaseID: route.releaseID)
                    }
            }
            .tabItem {
                Label("Главная", systemImage: selection == .home
                      ? YukimoSymbol.homeFilled : YukimoSymbol.home)
            }
            .tag(Tab.home)

            NavigationStack(path: $searchPath) {
                SearchTabView()
                    .navigationDestination(for: ReleaseRoute.self) { route in
                        AnimeDetailsView(releaseID: route.releaseID)
                    }
            }
            .tabItem {
                Label("Поиск", systemImage: YukimoSymbol.search)
            }
            .tag(Tab.search)

            NavigationStack(path: $libraryPath) {
                LibraryTabView()
                    .navigationDestination(for: ReleaseRoute.self) { route in
                        AnimeDetailsView(releaseID: route.releaseID)
                    }
            }
            .tabItem {
                Label("Списки", systemImage: selection == .library
                      ? YukimoSymbol.libraryFilled : YukimoSymbol.library)
            }
            .tag(Tab.library)

            NavigationStack {
                PlaceholderTabView(
                    title: "Лента",
                    subtitle: "Комьюнити, посты и реакции скоро будут здесь.",
                    systemImage: YukimoSymbol.feedFilled)
                    .navigationTitle("Лента")
                    .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Label("Лента", systemImage: selection == .feed
                      ? YukimoSymbol.feedFilled : YukimoSymbol.feed)
            }
            .tag(Tab.feed)

            NavigationStack(path: $profilePath) {
                ProfileTabView()
                    .navigationDestination(for: ReleaseRoute.self) { route in
                        AnimeDetailsView(releaseID: route.releaseID)
                    }
            }
            .tabItem {
                Label("Профиль", systemImage: selection == .profile
                      ? YukimoSymbol.profileFilled : YukimoSymbol.profile)
            }
            .tag(Tab.profile)
        }
        .tint(YukimoColor.primaryCoral)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
