//
//  YukimoDetailsCache.swift
//  Session-scoped cache for `AnimeDetailsView`. When the user revisits
//  the same release within a few minutes — typing in Search, tapping a
//  poster on Home, opening a related title — we hand back the snapshot
//  we already paid for instead of running the four-step fetch chain
//  (release → types → sources → episodes) all over again.
//
//  Lives in memory only; no UserDefaults backing. Released when the app
//  is torn down. TTL is short on purpose so mutations that bypass the
//  cache (server-side reactions, vote / favourite / list moves) still
//  show fresh data after a brief wait.
//

import Foundation

@MainActor
final class YukimoDetailsCache {
    static let shared = YukimoDetailsCache()

    struct Snapshot {
        let release: ReleaseDTO
        let episodeTypes: [EpisodeTypeDTO]
        let selectedTypeID: Int64?
        let episodeSources: [EpisodeSourceDTO]
        let selectedSourceID: Int64?
        let episodes: [EpisodeDTO]
        let cachedAt: Date
    }

    private let ttl: TimeInterval = 5 * 60        // 5 minutes
    private let maxEntries = 30
    private var entries: [Int64: Snapshot] = [:]

    private init() {}

    func get(_ releaseID: Int64) -> Snapshot? {
        guard let s = entries[releaseID] else { return nil }
        if Date().timeIntervalSince(s.cachedAt) > ttl {
            entries.removeValue(forKey: releaseID)
            return nil
        }
        return s
    }

    func put(_ releaseID: Int64, _ snapshot: Snapshot) {
        entries[releaseID] = snapshot
        if entries.count > maxEntries, let oldest = entries.min(by: { $0.value.cachedAt < $1.value.cachedAt })?.key {
            entries.removeValue(forKey: oldest)
        }
    }

    /// Replace just the episodes for the current (type, source) pair —
    /// used after the player closes so the new `is_watched` flags land
    /// without throwing away the rest of the snapshot.
    func updateEpisodes(_ releaseID: Int64, episodes: [EpisodeDTO]) {
        guard let existing = entries[releaseID] else { return }
        entries[releaseID] = Snapshot(
            release: existing.release,
            episodeTypes: existing.episodeTypes,
            selectedTypeID: existing.selectedTypeID,
            episodeSources: existing.episodeSources,
            selectedSourceID: existing.selectedSourceID,
            episodes: episodes,
            cachedAt: existing.cachedAt)   // keep original TTL clock
    }

    func invalidate(_ releaseID: Int64) {
        entries.removeValue(forKey: releaseID)
    }

    func invalidateAll() {
        entries.removeAll()
    }
}
