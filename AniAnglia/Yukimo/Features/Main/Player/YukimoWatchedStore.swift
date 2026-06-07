//
//  YukimoWatchedStore.swift
//  Persisted set of watched episode positions per release. Independent
//  of source — once an episode is watched in ANY дубляже, the UI shows
//  it as watched everywhere.
//

import Foundation

final class YukimoWatchedStore {
    static let shared = YukimoWatchedStore()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.yukimo.watched", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(releaseID: Int64) -> String {
        "yukimo.watched.\(releaseID)"
    }

    // MARK: Read

    func isWatched(releaseID: Int64, position: Int) -> Bool {
        loadPositions(releaseID: releaseID).contains(position)
    }

    func loadPositions(releaseID: Int64) -> Set<Int> {
        guard let data = defaults.data(forKey: key(releaseID: releaseID)) else { return [] }
        guard let array = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        return Set(array)
    }

    // MARK: Write
    //
    // Synchronous: UserDefaults writes are cheap, and callers (the
    // player on episode-end + the details VM on player dismiss) depend
    // on the write being readable *immediately* afterwards so the
    // "Watch" CTA can recompute. Doing this on a background queue
    // introduced a race where the CTA re-rendered before the watched
    // set had been persisted, leaving the user staring at the old
    // episode label.

    func markWatched(releaseID: Int64, position: Int) {
        var positions = loadPositions(releaseID: releaseID)
        positions.insert(position)
        save(positions, for: releaseID)
    }

    func unmarkWatched(releaseID: Int64, position: Int) {
        var positions = loadPositions(releaseID: releaseID)
        positions.remove(position)
        save(positions, for: releaseID)
    }

    private func save(_ positions: Set<Int>, for releaseID: Int64) {
        guard let data = try? JSONEncoder().encode(Array(positions).sorted()) else { return }
        defaults.set(data, forKey: key(releaseID: releaseID))
    }
}
