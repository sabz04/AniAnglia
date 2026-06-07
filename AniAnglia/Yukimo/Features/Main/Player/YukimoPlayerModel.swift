//
//  YukimoPlayerModel.swift
//  All player state — episode tree, streams, AVPlayer, scrub time.
//

import SwiftUI
import AVFoundation
import Observation

@Observable
@MainActor
final class YukimoPlayerModel {
    // MARK: Fixed inputs

    let releaseID: Int64
    let releaseTitle: String

    /// When non-nil, `loadCurrentEpisode()` skips the libanixart fetch and
    /// plays this `file://` URL directly. Used by the offline player path
    /// after `YukimoDownloadsManager` has finished mirroring an HLS stream
    /// to disk.
    @ObservationIgnored let forcedLocalManifest: URL?

    /// All finished downloads belonging to the same anime. Non-empty puts
    /// the player into offline-list mode — the episodes sheet renders
    /// these entries instead of `episodes`, and tapping one swaps the
    /// playing manifest via `switchToOfflineEntry(_:)`.
    var offlineEntries: [YukimoDownloadsManager.Entry] = []

    var isOfflineMode: Bool { !offlineEntries.isEmpty }

    var currentOfflineEntry: YukimoDownloadsManager.Entry? {
        offlineEntries.first {
            $0.position == currentPosition && $0.sourceID == selectedSourceID
        }
    }

    // MARK: Episode tree (mutable — can change in-player)

    var episodeTypes: [EpisodeTypeDTO]
    var selectedTypeID: Int64

    var episodeSources: [EpisodeSourceDTO]
    var selectedSourceID: Int64

    var episodes: [EpisodeDTO]
    var currentPosition: Int

    // MARK: Streams

    var variants: [StreamVariantDTO] = []
    var selectedVariant: StreamVariantDTO?

    // MARK: Playback state

    var isPlaying: Bool = false
    var currentTime: Double = 0
    var duration: Double = 0
    var isScrubbing: Bool = false
    var isLoading: Bool = true
    /// Bumped whenever a row in `PlayerEpisodesSheet` toggles the
    /// `YukimoWatchedStore` state. The sheet reads this in its row
    /// builder so SwiftUI re-renders the `isWatched` indicator — the
    /// underlying UserDefaults-backed store is not itself observable.
    var watchedToggleToken: Int = 0

    /// Episodes the user explicitly UN-watched in this session. This is
    /// the only way to defeat libanixart's sticky server-side
    /// `is_watched` — `Episode::is_watched` can return true forever even
    /// after we call the unmark store, and `OR`-ing the two flags would
    /// keep the row green. An entry here means: "ignore the server flag
    /// for this position".
    var locallyUnwatchedPositions: Set<Int> = []
    var loadingMessage: String? = "Загрузка плеера…"
    /// AVPlayer is in `.waitingToPlayAtSpecifiedRate` — buffering after a
    /// seek, quality switch, or transient network stall. Distinct from
    /// `isLoading` (the initial libanixart fetch); the UI shows a smaller
    /// inline spinner for `isBuffering` while keeping all controls usable.
    var isBuffering: Bool = false
    var error: String?

    // MARK: AVPlayer

    let player: AVPlayer = AVPlayer()

    @ObservationIgnored private var timeObserverToken: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var lastProgressSave: Date = .distantPast
    @ObservationIgnored private var pendingResumeSeconds: Double? = nil
    /// `true` between calling `player.seek(...)` and its completion
    /// handler firing. While set, the periodic time observer must NOT
    /// write `currentTime` from `player.currentTime` — AVPlayer reports
    /// the *old* position until the seek physically completes, which
    /// would otherwise yank the scrubber thumb backward before snapping
    /// forward to the target a moment later.
    @ObservationIgnored private var isSeekingToTarget: Bool = false
    @ObservationIgnored private var playerKVOs: [NSKeyValueObservation] = []
    @ObservationIgnored private var itemKVOs: [NSKeyValueObservation] = []
    @ObservationIgnored private var stallNoteObs: NSObjectProtocol?
    @ObservationIgnored private var failedNoteObs: NSObjectProtocol?
    @ObservationIgnored private var errLogNoteObs: NSObjectProtocol?

    // Retry/fallback bookkeeping for AVPlayer load failures (the
    // "stuck at 00:00" symptom). One retry per variant, then move to
    // the next variant by descending height; show error only after
    // all variants have been tried.
    @ObservationIgnored private var variantRetryAttempt = 0
    @ObservationIgnored private var triedVariantQualities: Set<String> = []

    // MARK: Init

    init(releaseID: Int64,
         releaseTitle: String,
         types: [EpisodeTypeDTO],
         sources: [EpisodeSourceDTO],
         episodes: [EpisodeDTO],
         initialTypeID: Int64,
         initialSourceID: Int64,
         initialPosition: Int,
         forcedLocalManifest: URL? = nil,
         offlineEntries: [YukimoDownloadsManager.Entry] = []) {
        self.releaseID = releaseID
        self.releaseTitle = releaseTitle
        self.episodeTypes = types
        self.selectedTypeID = initialTypeID
        self.episodeSources = sources
        self.selectedSourceID = initialSourceID
        self.episodes = episodes
        self.currentPosition = initialPosition
        self.forcedLocalManifest = forcedLocalManifest
        self.offlineEntries = offlineEntries
    }

    /// Hot-swap to another downloaded episode within the same anime —
    /// invoked when the user picks one in the player's episodes sheet
    /// while in offline mode.
    func switchToOfflineEntry(_ entry: YukimoDownloadsManager.Entry) async {
        guard entry.status == .finished,
              let url = YukimoDownloadsManager.shared.localPlaybackURL(forEntry: entry.id) else { return }
        // Persist whatever we just had so the resume "С m:ss" stays right.
        if currentTime > 0 && duration > 0 {
            YukimoProgressStore.shared.save(
                releaseID: releaseID, sourceID: selectedSourceID,
                position: currentPosition,
                seconds: currentTime, duration: duration)
        }
        pause()
        selectedSourceID = entry.sourceID
        selectedTypeID   = entry.typeID
        currentPosition  = entry.position
        let v = StreamVariantDTO.make(
            quality: entry.qualityLabel.isEmpty ? "Local" : entry.qualityLabel,
            url: url.absoluteString)
        variants = [v]
        applyVariant(v, resumeFromZero: true)
    }

    func configure() {
        configureAudioSession()
        installPeriodicObserver()
        installEndObserver()
        installPlaybackDiagnostics()
        // Defensive: re-fetch the episode list. If Details passed a stale or
        // partial list (a known intermittent quirk of the parser), this gives
        // us the full set before the user opens the episodes sheet.
        Task { await refetchEpisodes() }
    }

    func refetchEpisodes() async {
        // Defence: if a "trailer" source slipped through with a single episode,
        // and the source list contains a richer one, switch to it before
        // re-fetching.
        if let currentMeta = episodeSources.first(where: { $0.sourceID == selectedSourceID }),
           let best = episodeSources.max(by: { $0.episodesCount < $1.episodesCount }),
           best.sourceID != selectedSourceID,
           best.episodesCount > currentMeta.episodesCount {
            selectedSourceID = best.sourceID
        }
        do {
            let eps: [EpisodeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodes(
                    releaseID: releaseID,
                    typeID: selectedTypeID,
                    sourceID: selectedSourceID) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.player", code: -1)) }
                    }
            }
            if !eps.isEmpty { self.episodes = eps }
        } catch {
            // Keep the inherited list; player still works.
        }
    }

    // MARK: Lifecycle

    func loadCurrentEpisode() async {
        isLoading = true
        isBuffering = false   // owned by isLoading until streams resolve
        loadingMessage = "Загрузка потоков…"
        error = nil
        // Fresh episode/source — reset variant retry bookkeeping.
        variantRetryAttempt = 0
        triedVariantQualities.removeAll()
        defer { isLoading = false }
        print("[Yukimo.player] loadCurrentEpisode start releaseID=\(releaseID) sourceID=\(selectedSourceID) source=\(selectedSourceName) typeID=\(selectedTypeID) type=\(selectedTypeName) position=\(currentPosition)")

        // Offline path — skip every network round-trip and just hand the
        // downloaded m3u8 to AVPlayer.
        if let local = forcedLocalManifest {
            let v = StreamVariantDTO.make(quality: "Local", url: local.absoluteString)
            self.variants = [v]
            print("[Yukimo.player] using local manifest \(local.absoluteString)")
            applyVariant(v, resumeFromZero: true)
            return
        }
        do {
            let list: [StreamVariantDTO] = try await withCheckedThrowingContinuation { cont in
                PlayerBridge.shared().resolveStreams(
                    releaseID: releaseID,
                    sourceID: selectedSourceID,
                    position: currentPosition) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.player", code: -1)) }
                    }
            }
            print("[Yukimo.player] resolveStreams returned \(list.count) variants: \(list.map { "\($0.quality)(\($0.height))" }.joined(separator: ","))")
            self.variants = list
            if let preferred = pickPreferred(list) {
                print("[Yukimo.player] picked variant quality=\(preferred.quality) height=\(preferred.height) url=\(preferred.url)")
                applyVariant(preferred, resumeFromZero: true)
            } else {
                print("[Yukimo.player] ERROR no preferred variant")
                self.error = "Не удалось получить варианты качества"
            }
        } catch {
            let ns = error as NSError
            print("[Yukimo.player] ERROR resolveStreams domain=\(ns.domain) code=\(ns.code) msg=\(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }

    // MARK: Mutations

    func switchToVariant(_ variant: StreamVariantDTO) {
        applyVariant(variant, resumeFromZero: false)
        YukimoPlayerPrefsStore.shared.save(
            releaseID: releaseID, qualityKey: variant.quality)
    }

    func switchSource(_ sourceID: Int64) async {
        guard sourceID != selectedSourceID else { return }
        pause()
        isLoading = true
        loadingMessage = "Меняем плеер…"
        defer { isLoading = false }
        selectedSourceID = sourceID
        YukimoPlayerPrefsStore.shared.save(
            releaseID: releaseID, sourceID: sourceID)

        do {
            // Refresh episode list for the new source.
            let eps: [EpisodeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodes(
                    releaseID: releaseID,
                    typeID: selectedTypeID,
                    sourceID: sourceID) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.player", code: -1)) }
                    }
            }
            self.episodes = eps
            // Try to preserve the same position; otherwise fall back to first.
            if let match = eps.first(where: { $0.position == currentPosition }) {
                currentPosition = match.position
            } else if let first = eps.first {
                currentPosition = first.position
            }
            await loadCurrentEpisode()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Switch the dubbing studio (EpisodeType). Reloads sources, picks the
    /// best one (max episodes count), then refreshes the episode list.
    func switchType(_ typeID: Int64) async {
        guard typeID != selectedTypeID else { return }
        pause()
        isLoading = true
        loadingMessage = "Меняем озвучку…"
        defer { isLoading = false }
        selectedTypeID = typeID
        YukimoPlayerPrefsStore.shared.save(
            releaseID: releaseID, typeID: typeID)

        do {
            // Fetch new sources for the chosen type.
            let sources: [EpisodeSourceDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodeSources(
                    releaseID: releaseID,
                    typeID: typeID) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.player", code: -1)) }
                    }
            }
            self.episodeSources = sources
            // Prefer the source with the most episodes — single-episode
            // sources are often trailers / PVs.
            if let best = sources.max(by: { $0.episodesCount < $1.episodesCount }) {
                selectedSourceID = best.sourceID
            } else if let first = sources.first {
                selectedSourceID = first.sourceID
            }

            // Refresh episode list for the new type+source.
            let eps: [EpisodeDTO] = try await withCheckedThrowingContinuation { cont in
                ReleaseDetailBridge.shared().loadEpisodes(
                    releaseID: releaseID,
                    typeID: typeID,
                    sourceID: selectedSourceID) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.player", code: -1)) }
                    }
            }
            self.episodes = eps
            if let match = eps.first(where: { $0.position == currentPosition }) {
                currentPosition = match.position
            } else if let first = eps.first {
                currentPosition = first.position
            }
            await loadCurrentEpisode()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func playEpisode(at position: Int) async {
        guard position != currentPosition else { return }
        // Persist where the user is leaving off before we switch episodes.
        if currentTime > 0 && duration > 0 {
            YukimoProgressStore.shared.save(
                releaseID: releaseID, sourceID: selectedSourceID,
                position: currentPosition, seconds: currentTime, duration: duration)
        }
        pause()
        currentPosition = position
        YukimoPlayerPrefsStore.shared.save(
            releaseID: releaseID, position: position)
        await loadCurrentEpisode()
    }

    func nextEpisode() async {
        guard let i = episodes.firstIndex(where: { $0.position == currentPosition }),
              i + 1 < episodes.count else { return }
        await playEpisode(at: episodes[i + 1].position)
    }

    func previousEpisode() async {
        guard let i = episodes.firstIndex(where: { $0.position == currentPosition }),
              i - 1 >= 0 else { return }
        await playEpisode(at: episodes[i - 1].position)
    }

    var hasNextEpisode: Bool {
        guard let i = episodes.firstIndex(where: { $0.position == currentPosition }) else { return false }
        return i + 1 < episodes.count
    }

    var hasPreviousEpisode: Bool {
        guard let i = episodes.firstIndex(where: { $0.position == currentPosition }) else { return false }
        return i - 1 >= 0
    }

    var currentEpisode: EpisodeDTO? {
        episodes.first(where: { $0.position == currentPosition })
    }

    var selectedSourceName: String {
        // Note: in libanixart "source" = the player engine (Kodik / Sibnet /
        // AniLibria-сайт), and "type" = the dubbing studio. The UI uses
        // "Плеер" for source and "Озвучка" for type.
        if let e = currentOfflineEntry, !e.sourceName.isEmpty { return e.sourceName }
        return episodeSources.first(where: { $0.sourceID == selectedSourceID })?.name ?? "Плеер"
    }

    var selectedTypeName: String {
        if let e = currentOfflineEntry, !e.typeName.isEmpty { return e.typeName }
        return episodeTypes.first(where: { $0.typeID == selectedTypeID })?.name ?? "Озвучка"
    }

    var selectedQualityLabel: String {
        if let e = currentOfflineEntry, !e.qualityLabel.isEmpty { return e.qualityLabel }
        guard let v = selectedVariant else { return "Auto" }
        return v.height > 0 ? "\(v.height)p" : v.quality
    }

    // MARK: Playback ops

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        let target = max(0, min(duration, fraction * duration))
        seek(toSeconds: target)
    }

    func seek(toSeconds seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        // Show the target immediately so the scrubber stays at the spot
        // the user released, then suppress periodic-observer overwrites
        // until AVPlayer's seek has actually completed.
        currentTime = seconds
        isSeekingToTarget = true
        player.seek(to: target,
                    toleranceBefore: .zero,
                    toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isSeekingToTarget = false
            }
        }
    }

    func skip(by deltaSeconds: Double) {
        let target = max(0, min(max(duration - 0.1, 0), currentTime + deltaSeconds))
        seek(toSeconds: target)
    }

    // MARK: Watched + cleanup

    /// Set when the user unmarks the currently-playing episode — the
    /// view observes this and dismisses the fullScreenCover so the
    /// freshly-unwatched episode doesn't keep playing in the background.
    var shouldDismissPlayer: Bool = false

    /// Toggle watched flag for a specific episode position. Used by the
    /// player's episodes sheet long-press menu.
    func setWatched(_ watched: Bool, position: Int) {
        if watched {
            locallyUnwatchedPositions.remove(position)
            YukimoUnwatchedStore.shared.clearUnwatched(
                releaseID: releaseID, position: position)
            YukimoWatchedStore.shared.markWatched(
                releaseID: releaseID, position: position)
        } else {
            locallyUnwatchedPositions.insert(position)
            // Persist override so other VMs (e.g. AnimeDetailsViewModel
            // after the player dismisses) pick it up too.
            YukimoUnwatchedStore.shared.markUnwatched(
                releaseID: releaseID, position: position)
            YukimoWatchedStore.shared.unmarkWatched(
                releaseID: releaseID, position: position)
            clearProgress(forPosition: position)
            if position == currentPosition {
                shouldDismissPlayer = true
            }
        }
        watchedToggleToken &+= 1
        print("[Yukimo.watched] player setWatched=\(watched) position=\(position) locallyUnwatched=\(locallyUnwatchedPositions) dismiss=\(shouldDismissPlayer)")
    }

    private func clearProgress(forPosition position: Int) {
        // Clear every source we know about — the user may have watched
        // this episode via a different дубляж, and that progress should
        // be wiped too.
        var sourceIDs = episodeSources.map(\.sourceID)
        if !sourceIDs.contains(selectedSourceID) {
            sourceIDs.append(selectedSourceID)
        }
        for sid in sourceIDs {
            YukimoProgressStore.shared.clear(
                releaseID: releaseID, sourceID: sid, position: position)
        }
    }

    /// Position to centre on when the user opens the "Серии" sheet.
    ///
    /// Why this isn't just `currentPosition`: `currentPosition` may have
    /// been set from `Episode.lastViewEpisodePosition` (a server-side
    /// sticky flag that records the *last* episode the user opened —
    /// even by accident). Anchor logic instead trusts the *local*
    /// watched store, which only contains episodes the user marked
    /// (manually or by completing playback). Fallback chain:
    ///   1. Local progress > 5 s, ignoring un-watched overrides.
    ///   2. Highest position in `YukimoWatchedStore` minus `YukimoUnwatchedStore`.
    ///      Prefer `max + 1` (the next ep) if it exists.
    ///   3. `currentPosition` (what AVPlayer is actually playing).
    ///   4. First episode in the list.
    func anchorPositionForSheet() -> Int {
        // 1. `currentPosition` wins. The player only opens on a position
        //    the user explicitly picked (CTA "Продолжить", "Смотреть",
        //    a row tap, or an offline-list pick) — that's the most
        //    trustworthy signal of "where am I now". Stale `s ≥ 5`
        //    entries in `YukimoProgressStore` from accidental taps long
        //    ago must never override this.
        if episodes.contains(where: { $0.position == currentPosition }) {
            return currentPosition
        }

        let storedWatched = YukimoWatchedStore.shared.loadPositions(releaseID: releaseID)
        let unwatched = YukimoUnwatchedStore.shared.loadPositions(releaseID: releaseID)
            .union(locallyUnwatchedPositions)
        let effectiveWatched = storedWatched.subtracting(unwatched)

        // 2. Highest "really watched". Prefer the next episode after it.
        if let maxWatched = effectiveWatched.max() {
            if episodes.contains(where: { $0.position == maxWatched + 1 }) {
                return maxWatched + 1
            }
            if episodes.contains(where: { $0.position == maxWatched }) {
                return maxWatched
            }
        }

        // 3. First episode.
        return episodes.first?.position ?? currentPosition
    }

    /// Single source of truth for the row indicator inside the player.
    /// Resolution order:
    ///   1. Persisted UN-watched store / in-memory override → false
    ///   2. Persisted watched store → true
    ///   3. libanixart's `Episode.is_watched` server flag → its value
    func isEpisodeWatchedInPlayer(_ ep: EpisodeDTO) -> Bool {
        if locallyUnwatchedPositions.contains(ep.position)
            || YukimoUnwatchedStore.shared.isUnwatched(
                releaseID: releaseID, position: ep.position) {
            return false
        }
        if YukimoWatchedStore.shared.isWatched(
            releaseID: releaseID, position: ep.position) { return true }
        return ep.isWatched
    }

    func markCurrentWatched() {
        // Server: best-effort, no retry — Anixart eventually accepts it.
        PlayerBridge.shared().markWatched(
            releaseID: releaseID,
            sourceID: selectedSourceID,
            position: currentPosition,
            completion: nil)
        // Local: synchronous, immediately readable on player dismiss so
        // AnimeDetails can re-evaluate `resumeEpisode` / `watchContext`.
        YukimoWatchedStore.shared.markWatched(
            releaseID: releaseID,
            position: currentPosition)
    }

    func teardown() {
        // Persist exactly where the user left off — survives across app restarts.
        if currentTime > 0 && duration > 0 {
            YukimoProgressStore.shared.save(
                releaseID: releaseID,
                sourceID: selectedSourceID,
                position: currentPosition,
                seconds: currentTime,
                duration: duration)
        }
        player.pause()
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        playerKVOs.forEach { $0.invalidate() }
        playerKVOs.removeAll()
        itemKVOs.forEach { $0.invalidate() }
        itemKVOs.removeAll()
        for note in [stallNoteObs, failedNoteObs, errLogNoteObs].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(note)
        }
        stallNoteObs = nil
        failedNoteObs = nil
        errLogNoteObs = nil
        markCurrentWatched()
    }

    // MARK: Internals

    private func applyVariant(_ variant: StreamVariantDTO, resumeFromZero: Bool) {
        guard let url = URL(string: variant.url) else {
            print("[Yukimo.player] ERROR bad URL string: \(variant.url)")
            error = "Битая ссылка на видео"
            return
        }
        print("[Yukimo.player] applyVariant url=\(url.absoluteString) resumeFromZero=\(resumeFromZero)")
        let previousTime = resumeFromZero ? .zero : player.currentTime()
        let wasPlaying = !resumeFromZero && isPlaying
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if !resumeFromZero {
            // Quality switch — preserve current time.
            player.seek(to: previousTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            // New episode — consult the local progress store for a resume point.
            if let resume = YukimoProgressStore.shared.resumeSeconds(
                releaseID: releaseID,
                sourceID: selectedSourceID,
                position: currentPosition) {
                // Item may not be ready yet — stash and replay once duration arrives.
                pendingResumeSeconds = resume
            } else {
                pendingResumeSeconds = nil
            }
        }
        selectedVariant = variant
        attachItemKVOs(to: item)
        if resumeFromZero || wasPlaying {
            play()
        } else {
            isPlaying = false
        }
        // Reset duration; it will be updated by the periodic observer once
        // AVPlayerItem reports a valid value.
        duration = 0
    }

    // MARK: Playback diagnostics — log AVPlayer state transitions so we
    // can tell whether a "stuck at 00:00" symptom is a CDN 403, a stalled
    // network, an HLS parse failure, or just slow buffering.

    private func installPlaybackDiagnostics() {
        playerKVOs.forEach { $0.invalidate() }
        playerKVOs.removeAll()

        playerKVOs.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            let reason = p.reasonForWaitingToPlay?.rawValue ?? "nil"
            print("[Yukimo.av] timeControlStatus=\(p.timeControlStatus.rawValue) waitingReason=\(reason) rate=\(p.rate)")
            // Drive `isBuffering` for the UI. Treat the "no item" wait
            // state as not-buffering (it's a transient between item swaps,
            // already covered by `isLoading`).
            let waiting = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
            let noItem  = p.reasonForWaitingToPlay == .noItemToPlay
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isBuffering = waiting && !noItem && !self.isLoading
            }
        })
        playerKVOs.append(player.observe(\.reasonForWaitingToPlay, options: [.new]) { _, change in
            let reason = (change.newValue ?? nil)?.rawValue ?? "nil"
            print("[Yukimo.av] reasonForWaitingToPlay=\(reason)")
        })
        playerKVOs.append(player.observe(\.rate, options: [.new]) { p, _ in
            print("[Yukimo.av] rate=\(p.rate)")
        })

        stallNoteObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.playbackStalledNotification, object: nil, queue: .main
        ) { _ in
            print("[Yukimo.av] STALLED")
        }
        failedNoteObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil, queue: .main
        ) { note in
            let err = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            print("[Yukimo.av] failedToPlayToEnd: \(String(describing: err))")
        }
        errLogNoteObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.newErrorLogEntryNotification, object: nil, queue: .main
        ) { note in
            guard let item = note.object as? AVPlayerItem,
                  let log = item.errorLog(),
                  let last = log.events.last else { return }
            print("[Yukimo.av] errorLog code=\(last.errorStatusCode) domain=\(last.errorDomain) reason=\(last.errorComment ?? "nil") uri=\(last.uri ?? "nil") serverAddr=\(last.serverAddress ?? "nil")")
        }
    }

    private func attachItemKVOs(to item: AVPlayerItem) {
        itemKVOs.forEach { $0.invalidate() }
        itemKVOs.removeAll()

        itemKVOs.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let errDesc = item.error?.localizedDescription ?? "nil"
            print("[Yukimo.av] item.status=\(item.status.rawValue) error=\(errDesc)")
            if item.status == .failed, let nsErr = item.error as NSError? {
                print("[Yukimo.av] item.error domain=\(nsErr.domain) code=\(nsErr.code) userInfo=\(nsErr.userInfo)")
                Task { @MainActor [weak self] in
                    self?.handleItemFailure(error: nsErr)
                }
            }
        })
        itemKVOs.append(item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { item, _ in
            print("[Yukimo.av] isPlaybackLikelyToKeepUp=\(item.isPlaybackLikelyToKeepUp)")
        })
        itemKVOs.append(item.observe(\.isPlaybackBufferEmpty, options: [.new]) { item, _ in
            print("[Yukimo.av] isPlaybackBufferEmpty=\(item.isPlaybackBufferEmpty)")
        })
        itemKVOs.append(item.observe(\.loadedTimeRanges, options: [.new]) { item, _ in
            let ranges = item.loadedTimeRanges.map { tv -> String in
                let r = tv.timeRangeValue
                return "[\(r.start.seconds.rounded())..\(r.end.seconds.rounded())]"
            }.joined(separator: ",")
            if !ranges.isEmpty {
                print("[Yukimo.av] loadedTimeRanges=\(ranges)")
            }
        })
    }

    /// Called when AVPlayer reports `item.status = .failed`. Strategy:
    /// 1. If we haven't retried *this* variant yet, replay the same URL
    ///    once — the underlying NSURLSession occasionally fails on a
    ///    first connect to a CDN edge and succeeds on retry.
    /// 2. Otherwise look for an untried variant with the next-lower
    ///    height and switch to it (its URL is different, so a CDN /
    ///    edge issue on one quality may not affect another).
    /// 3. When everything is exhausted, surface the failure to the UI.
    @MainActor
    private func handleItemFailure(error nsErr: NSError) {
        guard let current = selectedVariant else {
            self.error = nsErr.localizedDescription
            return
        }

        if variantRetryAttempt == 0 {
            variantRetryAttempt += 1
            print("[Yukimo.av] auto-retry same variant quality=\(current.quality)")
            applyVariant(current, resumeFromZero: false)
            return
        }

        // Same variant failed twice. Mark it tried and look for a
        // fallback variant.
        triedVariantQualities.insert(current.quality)

        let untried = variants.filter { !triedVariantQualities.contains($0.quality) }
        // Prefer untried variants closest to (but below) the current
        // height first. Tie-break by descending height.
        let sortedFallbacks = untried.sorted { a, b in
            let ah = a.height == 0 ? -1 : a.height
            let bh = b.height == 0 ? -1 : b.height
            return ah > bh
        }

        if let fallback = sortedFallbacks.first {
            variantRetryAttempt = 0
            print("[Yukimo.av] falling back from quality=\(current.quality) to quality=\(fallback.quality)")
            applyVariant(fallback, resumeFromZero: false)
            return
        }

        // Truly exhausted.
        print("[Yukimo.av] all variants failed; surfacing error to UI")
        self.error = "\(nsErr.localizedDescription) — попробуйте перезайти в плеер или сменить озвучку."
    }

    private func pickPreferred(_ list: [StreamVariantDTO]) -> StreamVariantDTO? {
        // Per-release sticky pref wins — match by `quality` string so it
        // survives parser changes that swap height-based labels.
        if let prefs = YukimoPlayerPrefsStore.shared.load(releaseID: releaseID),
           let key = prefs.qualityKey,
           let match = list.first(where: { $0.quality == key }) {
            return match
        }
        // User-set default; 0 means "Auto" → just take the highest available.
        let target = Int(SettingsBridge.shared().defaultQualityHeight)
        if target > 0,
           let exact = list.first(where: { $0.height == target }) {
            return exact
        }
        if target > 0,
           let lowerOrEqual = list
               .filter({ $0.height > 0 && $0.height <= target })
               .max(by: { $0.height < $1.height }) {
            return lowerOrEqual
        }
        if let highest = list
            .filter({ $0.height > 0 })
            .max(by: { $0.height < $1.height }) {
            return highest
        }
        return list.first
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Best-effort.
        }
    }

    private func installPeriodicObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            guard let self else { return }
            if !self.isScrubbing && !self.isSeekingToTarget {
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
            }
            if let item = self.player.currentItem {
                let dur = item.duration.seconds
                if dur.isFinite && dur > 0 && abs(self.duration - dur) > 0.5 {
                    self.duration = dur
                    // Item reported real duration — apply any pending resume seek now.
                    if let resume = self.pendingResumeSeconds, resume > 0, resume < dur - 5 {
                        let target = CMTime(seconds: resume, preferredTimescale: 600)
                        self.player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
                        self.pendingResumeSeconds = nil
                    }
                }
            }
            self.isPlaying = self.player.rate > 0

            // Persist progress every ~5s of real playback.
            if self.isPlaying, !self.isScrubbing,
               Date().timeIntervalSince(self.lastProgressSave) > 5,
               self.currentTime > 0 {
                YukimoProgressStore.shared.save(
                    releaseID: self.releaseID,
                    sourceID: self.selectedSourceID,
                    position: self.currentPosition,
                    seconds: self.currentTime,
                    duration: self.duration)
                self.lastProgressSave = Date()
            }
        }
    }

    private func installEndObserver() {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.markCurrentWatched()
                YukimoProgressStore.shared.clear(
                    releaseID: self.releaseID,
                    sourceID: self.selectedSourceID,
                    position: self.currentPosition)
                if self.hasNextEpisode {
                    await self.nextEpisode()
                }
            }
        }
    }
}
