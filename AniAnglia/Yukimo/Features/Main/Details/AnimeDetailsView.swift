//
//  AnimeDetailsView.swift
//  Premium anime details screen — collapsing hero, primary action panel,
//  continue-watching, info strip, genres, synopsis, episodes section,
//  screenshots. Floating glass toolbar overlays the scroll.
//

import SwiftUI

struct AnimeDetailsView: View {
    let releaseID: Int64

    @State private var vm: AnimeDetailsViewModel
    @State private var descriptionExpanded = false
    @State private var ratingSheetVisible = false
    @State private var scrollOffset: CGFloat = 0
    @State private var playerSession: PlayerSession?
    @Environment(\.dismiss) private var dismiss

    init(releaseID: Int64) {
        self.releaseID = releaseID
        self._vm = State(initialValue: AnimeDetailsViewModel(releaseID: releaseID))
    }

    var body: some View {
        ZStack(alignment: .top) {
            scrollContent

            AnimeDetailsToolbar(
                title: vm.release?.displayTitle ?? "",
                titleVisibility: titleVisibility,
                surfaceOpacity: toolbarMaterialOpacity,
                onBack: { dismiss() },
                shareURL: shareURL,
                onCopyLink: copyLink)
            .animation(.easeOut(duration: 0.18), value: toolbarMaterialOpacity)
            .animation(.easeOut(duration: 0.18), value: titleVisibility)
        }
        .background(YukimoColor.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $playerSession,
                         onDismiss: { onPlayerDismissed() }) { session in
            if let release = vm.release,
               let sourceID = vm.selectedSourceID,
               let typeID = vm.selectedTypeID {
                YukimoPlayerView(
                    releaseID: releaseID,
                    releaseTitle: release.displayTitle,
                    initialTypeID: typeID,
                    initialSourceID: sourceID,
                    initialPosition: session.position,
                    initialEpisodes: vm.episodes,
                    initialTypes: vm.episodeTypes,
                    initialSources: vm.episodeSources)
            }
        }
        .sheet(isPresented: $ratingSheetVisible) {
            if let release = vm.release {
                RatingSheet(
                    currentVote: vm.effectiveMyVote(),
                    aggregate: release.grade,
                    aggregateCount: release.voteCount,
                    onRate: { newStars in
                        await vm.voteRelease(newStars)
                    })
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden)
            }
        }
        .task { await vm.load() }
    }

    // MARK: Scroll content

    private var scrollContent: some View {
        ScrollView {
            if let release = vm.release {
                VStack(spacing: 0) {
                    // Hero sizes to its content via .background() —
                    // no fixed frame, no Spacer push-down tricks.
                    AnimeHeroHeader(release: release)

                    contentBelowHero(for: release)
                        .padding(.top, YukimoSpacing.lg)

                    Color.clear.frame(height: 80)
                }
                .background(scrollOffsetReader)
            } else if vm.isLoadingRelease {
                loadingSkeleton
                    .padding(.top, YukimoSpacing.huge)
            } else if let err = vm.releaseError {
                LoadFailureState(message: err) {
                    Task { await vm.reload() }
                }
                .padding(.top, YukimoSpacing.huge)
            }
        }
        .coordinateSpace(name: "detailsScroll")
        .ignoresSafeArea(.container, edges: .top)
        .onPreferenceChange(DetailsScrollOffsetKey.self) { scrollOffset = $0 }
    }

    // MARK: Layout below hero

    @ViewBuilder
    private func contentBelowHero(for release: ReleaseDTO) -> some View {
        VStack(spacing: YukimoSpacing.xl) {
            // 1. Primary action panel — Watch CTA + List / Rate / Favorite.
            VStack(spacing: YukimoSpacing.md) {
                AnimeWatchButton(context: vm.watchContext) {
                    if let ep = vm.resumeEpisode { openPlayer(for: ep) }
                }
                .padding(.horizontal, YukimoSpacing.screenPadding)

                AnimeSecondaryActionsRow(
                    release: release,
                    currentListStatus: vm.effectiveListStatus(),
                    currentVote: vm.effectiveMyVote(),
                    currentIsFavorite: vm.effectiveIsFavorite(),
                    onPickList: { status in Task { await vm.setListStatus(status) } },
                    onToggleFavorite: { Task { await vm.toggleFavorite() } },
                    onRate: { ratingSheetVisible = true })
            }

            // 2. Continue Watching card — only when there's real resume data.
            if vm.hasResumeProgress,
               let ep = vm.resumeEpisode,
               let displayNumber = vm.displayNumber(forPosition: ep.position) {
                ContinueWatchingBlock(
                    release: release,
                    episodeDisplayNumber: displayNumber,
                    episodeName: ep.name.isEmpty ? nil : ep.name,
                    progress: vm.resumeProgress,
                    onTap: { openPlayer(for: ep) })
            }

            // 3. Genres
            if !release.genres.isEmpty {
                GenresSection(raw: release.genres)
            }

            // 4. Synopsis — collapses with gradient fade.
            if let desc = release.description_, !desc.isEmpty {
                SynopsisBlock(text: desc, expanded: $descriptionExpanded)
            } else {
                emptyDescription
            }

            // 5. Screenshots (above Episodes — visual content first).
            ScreenshotsBlock(urls: release.screenshotURLs)

            // 6. Episodes — list only, без summary с озвучкой/плеером.
            // Озвучка и плеер выбираются прямо в плеере.
            EpisodesSection(
                episodes: vm.episodes,
                isLoading: vm.isLoadingEpisodes,
                errorMessage: vm.episodesError,
                releaseID: releaseID,
                selectedSourceID: vm.selectedSourceID,
                isEpisodeWatched: { vm.isEpisodeWatched($0) },
                resumePosition: vm.hasResumeProgress ? vm.resumeEpisode?.position : nil,
                onPickEpisode: { openPlayer(for: $0) },
                onSetWatched: { ep, watched in
                    vm.setEpisodeWatched(watched, at: ep.position)
                })

            if let banner = vm.bannerError {
                YukimoErrorBanner(message: banner)
                    .padding(.horizontal, YukimoSpacing.screenPadding)
            }
        }
    }

    // MARK: Loading skeleton (full screen)

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.xl) {
            // Hero mock
            VStack(spacing: YukimoSpacing.md) {
                RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
                    .fill(YukimoColor.softPink)
                    .frame(width: 140, height: 210)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(YukimoColor.softPink.opacity(0.7))
                    .frame(width: 220, height: 22)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(YukimoColor.softPink.opacity(0.5))
                    .frame(width: 160, height: 14)
            }
            .frame(maxWidth: .infinity)

            // CTA mock
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(YukimoColor.primaryCoralLight.opacity(0.55))
                .frame(height: 60)
                .padding(.horizontal, YukimoSpacing.screenPadding)

            // Secondary row mock
            HStack(spacing: YukimoSpacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(height: 64)
                }
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)

            // Info strip mock
            HStack(spacing: YukimoSpacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                        .fill(YukimoColor.softPink.opacity(0.7))
                        .frame(height: 76)
                }
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private var emptyDescription: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
            Label("Описание", systemImage: "text.alignleft")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
            Text("Описание пока не добавлено")
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: DetailsScrollOffsetKey.self,
                            value: -proxy.frame(in: .named("detailsScroll")).minY)
        }
    }

    // MARK: Toolbar driver

    private var titleVisibility: Double {
        let start: CGFloat = 280
        let span: CGFloat = 70
        return min(1, max(0, Double((scrollOffset - start) / span)))
    }

    private var toolbarMaterialOpacity: Double {
        let start: CGFloat = 60
        let span: CGFloat = 120
        return min(1, max(0, Double((scrollOffset - start) / span)))
    }

    // MARK: Player + actions

    private func openPlayer(for ep: EpisodeDTO) {
        guard vm.selectedSourceID != nil, vm.selectedTypeID != nil else { return }
        // Local viewing-history record. Server endpoints (`get_history`,
        // `history_search`) intermittently return 0 items even for
        // accounts with active watch sessions, so the "История" tab in
        // Library is driven entirely off this local store.
        if let release = vm.release {
            YukimoHistoryStore.shared.record(release)
        }
        playerSession = PlayerSession(position: ep.position)
    }

    private func onPlayerDismissed() {
        if let last = playerSession?.position {
            vm.markEpisodeWatched(at: last)
        }
        // Pull anything the player wrote to the persistent watched store
        // (auto-next episodes, end-of-item completions) into the VM so
        // the Watch CTA recomputes immediately with the freshest resume
        // target, without waiting on the server `refreshAfterPlayer`.
        vm.syncWatchedAfterPlayer()
        Task { await vm.refreshAfterPlayer() }
    }

    private var shareURL: URL? {
        URL(string: "https://anixart.tv/release/\(releaseID)")
    }

    private func copyLink() {
        guard let shareURL else { return }
        UIPasteboard.general.string = shareURL.absoluteString
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: Player session value

struct PlayerSession: Identifiable {
    let position: Int
    var id: Int { position }
}
