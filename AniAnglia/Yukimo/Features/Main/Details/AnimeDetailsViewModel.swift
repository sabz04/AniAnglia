//
//  AnimeDetailsViewModel.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AnimeDetailsViewModel {
    let releaseID: Int64

    var release: ReleaseDTO?
    var isLoadingRelease: Bool = true
    var releaseError: String?

    var episodeTypes: [EpisodeTypeDTO] = []
    var selectedTypeID: Int64?
    var episodeSources: [EpisodeSourceDTO] = []
    var selectedSourceID: Int64?
    var episodes: [EpisodeDTO] = []
    var isLoadingEpisodes: Bool = false
    var episodesError: String?

    var bannerError: String?

    var pendingFavoriteMutation: Bool = false
    var pendingListMutation: Bool = false
    var pendingVoteMutation: Bool = false

    /// Optimistic overrides. The server occasionally returns 0 for
    /// `profile_list_status` / `my_vote` on the very next read after a
    /// mutation, so we keep the user's chosen value locally as the source
    /// of truth for the UI within this screen's lifetime.
    var localListStatus: Int? = nil
    var localMyVote: Int? = nil
    var localIsFavorite: Bool? = nil

    /// Set true the first time `load()` finishes — guards against repeat
    /// fetches when SwiftUI re-runs `.task` on a re-appearance (e.g. user
    /// pops back from a related title).
    @ObservationIgnored private var didInitialLoad = false

    func effectiveListStatus() -> Int {
        localListStatus ?? Int(release?.listStatus ?? 0)
    }

    func effectiveMyVote() -> Int {
        localMyVote ?? Int(release?.myVote ?? 0)
    }

    func effectiveIsFavorite() -> Bool {
        localIsFavorite ?? (release?.isFavorite ?? false)
    }

    /// 1-based display number for an episode position (matches what the
    /// episodes list shows the user). Returns nil if the episode isn't in
    /// the currently loaded source list.
    func displayNumber(forPosition position: Int) -> Int? {
        if let idx = episodes.firstIndex(where: { $0.position == position }) {
            return idx + 1
        }
        return nil
    }

    /// Episode the user should land on when they tap "Watch". Resolution
    /// order:
    ///   1. Server's `last_view_episode_position` (if it's in the current
    ///      source's list).
    ///   2. Local mid-watch progress on the highest position (any source).
    ///   3. Episode after the highest locally-watched one (next unseen).
    ///   4. Highest locally-watched episode itself (rewatch fallback).
    ///   5. First episode.
    var resumeEpisode: EpisodeDTO? {
        let allWatched = YukimoWatchedStore.shared.loadPositions(releaseID: releaseID)
            .union(locallyWatchedPositions)
        let allUnwatched = YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID)
            .union(locallyUnwatchedPositions)
        let effective = allWatched.subtracting(allUnwatched)

        // 1. Per-release player prefs — the LITERAL last position the
        //    user opened in this app. Authoritative over server pointer,
        //    progress store, and watched-set heuristics.
        if let prefs = YukimoPlayerPrefsStore.shared.load(releaseID: releaseID),
           let pos = prefs.position,
           !allUnwatched.contains(pos),
           let match = episodes.first(where: { $0.position == pos }) {
            return match
        }

        // 2. Server's `last_view_episode_position` — sticky and easy to
        //    poison (accidental tap records permanently). Treat as
        //    authoritative ONLY if it's consistent with what the user
        //    locally watched.
        let serverPos = release?.lastViewEpisodePosition ?? 0
        let serverConsistent = effective.isEmpty || effective.contains(serverPos)
        if serverPos > 0,
           !allUnwatched.contains(serverPos),
           serverConsistent,
           let match = episodes.first(where: { $0.position == serverPos }) {
            return match
        }
        if let pos = localInProgressPosition,
           let match = episodes.first(where: { $0.position == pos }) {
            return match
        }
        if let lastWatched = localHighestWatchedPosition {
            if let nextEp = episodes.first(where: { $0.position == lastWatched + 1 }) {
                return nextEp
            }
            if let match = episodes.first(where: { $0.position == lastWatched }) {
                return match
            }
        }
        return episodes.first
    }

    /// True when the resume episode is something other than the very first
    /// one — i.e. the CTA should read "Продолжить" rather than "Смотреть".
    var hasResumeProgress: Bool {
        let allWatched = YukimoWatchedStore.shared.loadPositions(releaseID: releaseID)
            .union(locallyWatchedPositions)
        let allUnwatched = YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID)
            .union(locallyUnwatchedPositions)
        let effective = allWatched.subtracting(allUnwatched)

        // Mirror `resumeEpisode`'s prefs check first.
        if let prefs = YukimoPlayerPrefsStore.shared.load(releaseID: releaseID),
           let pos = prefs.position,
           !allUnwatched.contains(pos),
           episodes.contains(where: { $0.position == pos }) {
            return true
        }

        let serverPos = release?.lastViewEpisodePosition ?? 0
        let serverConsistent = effective.isEmpty || effective.contains(serverPos)
        if serverPos > 0,
           !allUnwatched.contains(serverPos),
           serverConsistent,
           episodes.contains(where: { $0.position == serverPos }) {
            return true
        }
        return localInProgressPosition != nil
            || localHighestWatchedPosition != nil
    }

    /// Highest episode position that has saved playback progress beyond
    /// the resume threshold but isn't fully watched yet. Checks every
    /// source we know about (sources might be switched in-player after
    /// progress was recorded).
    private var localInProgressPosition: Int? {
        guard !episodes.isEmpty else { return nil }
        let sourceIDs = episodeSources.map(\.sourceID) + [selectedSourceID].compactMap { $0 }
        let persistedUnwatched = YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID)
        for ep in episodes.reversed() {
            if locallyUnwatchedPositions.contains(ep.position)
                || persistedUnwatched.contains(ep.position) { continue }
            for sid in sourceIDs {
                guard let p = YukimoProgressStore.shared.load(
                    releaseID: releaseID, sourceID: sid, position: ep.position) else { continue }
                guard p.seconds > 5 else { continue }
                if p.duration > 0 && p.seconds >= p.duration * 0.98 { continue }
                return ep.position
            }
        }
        return nil
    }

    /// Highest position the local watched store knows about — covers the
    /// case where the player auto-marked watched but the server hasn't
    /// caught up yet, OR the server endpoint just didn't return it.
    ///
    /// Union of the persistent `YukimoWatchedStore` and the VM-local
    /// `locallyWatchedPositions` (the latter is mutated synchronously
    /// when the player dismisses, so the CTA can re-evaluate without
    /// waiting on the disk write).
    private var localHighestWatchedPosition: Int? {
        var watched = YukimoWatchedStore.shared.loadPositions(releaseID: releaseID)
        watched.formUnion(locallyWatchedPositions)
        // Anything the user explicitly un-watched (in-memory OR persisted)
        // is dropped — otherwise the resume target would still point at
        // an episode the user said they hadn't watched.
        watched.subtract(locallyUnwatchedPositions)
        watched.subtract(YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID))
        guard !watched.isEmpty else { return nil }
        let validPositions = Set(episodes.map(\.position))
        let intersected = watched.intersection(validPositions)
        return intersected.max() ?? watched.max()
    }

    /// Called by the view after the player dismisses. Syncs both the
    /// watched AND un-watched persistent stores into the VM-local sets
    /// so SwiftUI sees observable mutations and the Watch CTA / episode
    /// rows re-render with the fresh state the user established inside
    /// the player.
    func syncWatchedAfterPlayer() {
        let stored = YukimoWatchedStore.shared.loadPositions(releaseID: releaseID)
        let unwatched = YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID)
        // Items the user un-watched in the player should drop from the
        // local watched set too, even if they were added earlier.
        locallyWatchedPositions.formUnion(stored)
        locallyWatchedPositions.subtract(unwatched)
        locallyUnwatchedPositions.formUnion(unwatched)
    }

    /// Rich context for the primary CTA.
    var watchContext: AnimeWatchContext {
        if episodes.isEmpty {
            return isLoadingEpisodes ? .loading : .unavailable(reason: "Серии недоступны")
        }
        guard let ep = resumeEpisode else {
            return .unavailable(reason: "Серии недоступны")
        }
        let displayNumber = self.displayNumber(forPosition: ep.position) ?? 1
        if hasResumeProgress {
            // Find progress for this resume target across all known
            // sources (user could've watched it via a different дубляж).
            let resumeSeconds: Double? = {
                let sourceIDs = episodeSources.map(\.sourceID)
                    + [selectedSourceID].compactMap { $0 }
                for sid in sourceIDs {
                    if let p = YukimoProgressStore.shared.load(
                        releaseID: releaseID, sourceID: sid, position: ep.position),
                       p.seconds > 5 {
                        return p.seconds
                    }
                }
                return nil
            }()
            return .resume(
                displayNumber: displayNumber,
                episodeName: ep.name.isEmpty ? nil : ep.name,
                resumeSeconds: resumeSeconds)
        }
        return .startFresh(totalEpisodes: episodes.count)
    }

    /// Progress for the current resume episode — used by the
    /// ContinueWatchingBlock to draw a visual bar. Returns nil if there
    /// is no meaningful local progress.
    var resumeProgress: YukimoEpisodeProgress? {
        guard let ep = resumeEpisode, hasResumeProgress,
              let sid = selectedSourceID else { return nil }
        return YukimoProgressStore.shared.load(
            releaseID: releaseID, sourceID: sid, position: ep.position)
    }

    /// Type currently selected on screen (for episodes section summary).
    var currentTypeName: String? {
        episodeTypes.first(where: { $0.typeID == selectedTypeID })?.name
    }

    var currentTypeWorkers: String? {
        let workers = episodeTypes.first(where: { $0.typeID == selectedTypeID })?.workers
        return (workers?.isEmpty == false) ? workers : nil
    }

    var currentSourceName: String {
        episodeSources.first(where: { $0.sourceID == selectedSourceID })?.name ?? "Источник"
    }

    var currentSourceEpisodeCount: Int {
        episodeSources.first(where: { $0.sourceID == selectedSourceID })?.episodesCount
            ?? episodes.count
    }

    func voteRelease(_ stars: Int) async {
        pendingVoteMutation = true
        localMyVote = stars  // optimistic
        defer { pendingVoteMutation = false }
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ReleaseDetailBridge.shared().vote(releaseID: releaseID, stars: stars) { ok, err in
                    if ok { cont.resume() }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            YukimoDetailsCache.shared.invalidate(releaseID)
        } catch {
            self.bannerError = error.localizedDescription
        }
    }

    /// Episodes the user just watched in this session — used to show the
    /// "Просмотрено" marker immediately when they return from the player,
    /// without waiting for a server round-trip.
    var locallyWatchedPositions: Set<Int> = []

    /// Episodes the user explicitly UN-watched. Required because
    /// libanixart's `Episode.is_watched` server flag is sticky — without
    /// this override the row would stay green forever after unmark.
    var locallyUnwatchedPositions: Set<Int> = []

    func isEpisodeWatched(_ ep: EpisodeDTO) -> Bool {
        // UN-watched wins over everything — server's is_watched, the
        // local watched set, and the watched store. Otherwise unmarking
        // would never visually take effect.
        if locallyUnwatchedPositions.contains(ep.position)
            || YukimoUnwatchedStore.shared.isUnwatched(
                releaseID: releaseID, position: ep.position) {
            return false
        }
        if locallyWatchedPositions.contains(ep.position) { return true }
        if YukimoWatchedStore.shared.isWatched(
            releaseID: releaseID, position: ep.position) { return true }
        return ep.isWatched
    }

    func markEpisodeWatched(at position: Int) {
        locallyWatchedPositions.insert(position)
    }

    /// Toggle watched flag for a specific episode. Clears both the
    /// in-memory session set and the cross-source persistent store so the
    /// row immediately reflects the change. Server-side `is_watched` is
    /// independent — the server will re-flip on next refresh, but local
    /// store wins via `isEpisodeWatched(_:)` because we also exclude.
    func setEpisodeWatched(_ watched: Bool, at position: Int) {
        if watched {
            locallyUnwatchedPositions.remove(position)
            locallyWatchedPositions.insert(position)
            YukimoUnwatchedStore.shared.clearUnwatched(releaseID: releaseID, position: position)
            YukimoWatchedStore.shared.markWatched(releaseID: releaseID, position: position)
        } else {
            locallyWatchedPositions.remove(position)
            locallyUnwatchedPositions.insert(position)
            // Persist so the player VM and any future Details VM sees the
            // override too (server's `is_watched` is sticky).
            YukimoUnwatchedStore.shared.markUnwatched(releaseID: releaseID, position: position)
            YukimoWatchedStore.shared.unmarkWatched(releaseID: releaseID, position: position)
            clearProgressForPosition(position)
        }
        print("[Yukimo.watched] details setWatched=\(watched) position=\(position) locallyUnwatched=\(locallyUnwatchedPositions) locallyWatched=\(locallyWatchedPositions)")
    }

    private func clearProgressForPosition(_ position: Int) {
        var sourceIDs = episodeSources.map(\.sourceID)
        if let sid = selectedSourceID, !sourceIDs.contains(sid) {
            sourceIDs.append(sid)
        }
        for sid in sourceIDs {
            YukimoProgressStore.shared.clear(
                releaseID: releaseID, sourceID: sid, position: position)
        }
    }

    /// Re-fetch episodes for the current source after the player closes — picks
    /// up server-side watched status updates.
    func refreshAfterPlayer() async {
        guard let typeID = selectedTypeID, let sourceID = selectedSourceID else { return }
        do {
            let items: [EpisodeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodes(
                    releaseID: releaseID, typeID: typeID, sourceID: sourceID) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                    }
            }
            self.episodes = items
            YukimoDetailsCache.shared.updateEpisodes(releaseID, episodes: items)
        } catch {
            // Keep locally-watched markers in place.
        }
    }

    init(releaseID: Int64) {
        self.releaseID = releaseID
    }

    // MARK: Load

    func load() async {
        if didInitialLoad { return }
        didInitialLoad = true

        // Session cache short-circuit — same release opened minutes ago?
        // Reuse its snapshot instead of running the 4-step API chain.
        if let cached = YukimoDetailsCache.shared.get(releaseID) {
            self.release          = cached.release
            self.episodeTypes     = cached.episodeTypes
            self.selectedTypeID   = cached.selectedTypeID
            self.episodeSources   = cached.episodeSources
            self.selectedSourceID = cached.selectedSourceID
            self.episodes         = cached.episodes
            self.isLoadingRelease  = false
            self.isLoadingEpisodes = false
            return
        }

        await loadRelease()
        await loadEpisodeTypes()
        savePartialSnapshot()
    }

    /// Force a fresh fetch — for the error retry button.
    func reload() async {
        didInitialLoad = false
        YukimoDetailsCache.shared.invalidate(releaseID)
        await load()
    }

    private func savePartialSnapshot() {
        guard let release else { return }
        YukimoDetailsCache.shared.put(releaseID, .init(
            release: release,
            episodeTypes: episodeTypes,
            selectedTypeID: selectedTypeID,
            episodeSources: episodeSources,
            selectedSourceID: selectedSourceID,
            episodes: episodes,
            cachedAt: Date()))
    }

    func loadRelease() async {
        isLoadingRelease = true
        releaseError = nil
        defer { isLoadingRelease = false }
        do {
            self.release = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadRelease(id: releaseID) { r, err in
                    if let r { cont.resume(returning: r) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
        } catch {
            self.releaseError = error.localizedDescription
        }
    }

    func loadEpisodeTypes() async {
        do {
            let types: [EpisodeTypeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodeTypes(releaseID: releaseID) { items, err in
                    if let items { cont.resume(returning: items) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            self.episodeTypes = types
            // Pick the type with the most episodes (NOT just the first one).
            // Some releases list a "trailer" / "PV" type first which contains
            // a single episode — that caused the screen to load 1 episode for
            // shows that have 25.
            if let primary = preferredType(types) {
                await selectType(primary.typeID)
            }
        } catch {
            self.episodesError = error.localizedDescription
        }
    }

    func selectType(_ typeID: Int64) async {
        selectedTypeID = typeID
        episodes = []
        episodeSources = []
        selectedSourceID = nil
        do {
            let sources: [EpisodeSourceDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodeSources(releaseID: releaseID, typeID: typeID) { items, err in
                    if let items { cont.resume(returning: items) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            self.episodeSources = sources
            // Same logic for sources: pick the dub with the most episodes
            // available — usually the canonical one (AniLibria, etc.).
            if let primary = preferredSource(sources) {
                await selectSource(primary.sourceID)
            }
        } catch {
            self.episodesError = error.localizedDescription
        }
    }

    /// Per-release player prefs win over the heuristics — if the user
    /// last opened the player with a specific дубляж, restore it on
    /// next entry. Falls back to "most episodes" otherwise (single-
    /// episode trailer types would otherwise win first place).
    private func preferredType(_ list: [EpisodeTypeDTO]) -> EpisodeTypeDTO? {
        if list.isEmpty { return nil }
        if let prefs = YukimoPlayerPrefsStore.shared.load(releaseID: releaseID),
           let typeID = prefs.typeID,
           let match = list.first(where: { $0.typeID == typeID }) {
            return match
        }
        return list.max { lhs, rhs in lhs.episodesCount < rhs.episodesCount }
    }

    private func preferredSource(_ list: [EpisodeSourceDTO]) -> EpisodeSourceDTO? {
        if list.isEmpty { return nil }
        if let prefs = YukimoPlayerPrefsStore.shared.load(releaseID: releaseID),
           let sourceID = prefs.sourceID,
           let match = list.first(where: { $0.sourceID == sourceID }) {
            return match
        }
        return list.max { lhs, rhs in lhs.episodesCount < rhs.episodesCount }
    }

    func selectSource(_ sourceID: Int64) async {
        selectedSourceID = sourceID
        guard let typeID = selectedTypeID else { return }
        isLoadingEpisodes = true
        episodesError = nil
        defer { isLoadingEpisodes = false }
        do {
            let items: [EpisodeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodes(releaseID: releaseID, typeID: typeID, sourceID: sourceID) { items, err in
                    if let items { cont.resume(returning: items) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            self.episodes = items
            savePartialSnapshot()
        } catch {
            self.episodesError = error.localizedDescription
        }
    }

    // MARK: Mutations

    func toggleFavorite() async {
        guard let release else { return }
        pendingFavoriteMutation = true
        defer { pendingFavoriteMutation = false }
        let newValue = !effectiveIsFavorite()
        localIsFavorite = newValue        // optimistic, no round-trip
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ReleaseDetailBridge.shared().setFavorite(newValue, releaseID: releaseID) { ok, err in
                    if ok { cont.resume() }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            // Cache is now stale — next fresh open should re-fetch.
            YukimoDetailsCache.shared.invalidate(releaseID)
        } catch {
            // Revert the optimistic value on failure.
            localIsFavorite = release.isFavorite
            self.bannerError = error.localizedDescription
        }
    }

    func setListStatus(_ status: YukimoListStatus) async {
        pendingListMutation = true
        // Optimistic update: map YukimoListStatus to the int we use elsewhere.
        switch status {
        case .none:     localListStatus = 0
        case .watching: localListStatus = 1
        case .plan:     localListStatus = 2
        case .watched:  localListStatus = 3
        case .holdOn:   localListStatus = 4
        case .dropped:  localListStatus = 5
        case .favorite: break // not a real list status — ignore
        @unknown default: break
        }
        defer { pendingListMutation = false }
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ReleaseDetailBridge.shared().setListStatus(status, releaseID: releaseID) { ok, err in
                    if ok { cont.resume() }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.details", code: -1)) }
                }
            }
            YukimoDetailsCache.shared.invalidate(releaseID)
        } catch {
            self.bannerError = error.localizedDescription
        }
    }
}
