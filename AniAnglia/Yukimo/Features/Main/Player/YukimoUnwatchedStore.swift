//
//  YukimoUnwatchedStore.swift
//  Persisted set of episode positions the user has explicitly removed
//  from "просмотрено". Acts as an override on top of libanixart's
//  sticky server-side `Episode.is_watched` flag — once the server says
//  an episode is watched, it sometimes never flips back, so we need a
//  local-truth layer that says "the user really meant: not watched".
//
//  Lives parallel to `YukimoWatchedStore`. The two stores are mutually
//  exclusive: writing to one always removes the same position from the
//  other so we can never end up in a contradictory state.
//

import Foundation

final class YukimoUnwatchedStore {
    static let shared = YukimoUnwatchedStore()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(releaseID: Int64) -> String {
        "yukimo.unwatched.\(releaseID)"
    }

    // MARK: Read

    func isUnwatched(releaseID: Int64, position: Int) -> Bool {
        loadPositions(releaseID: releaseID).contains(position)
    }

    func loadPositions(releaseID: Int64) -> Set<Int> {
        guard let data = defaults.data(forKey: key(releaseID: releaseID)) else { return [] }
        guard let array = try? JSONDecoder().decode([Int].self, from: data) else { return [] }
        return Set(array)
    }

    // MARK: Write

    func markUnwatched(releaseID: Int64, position: Int) {
        var positions = loadPositions(releaseID: releaseID)
        positions.insert(position)
        save(positions, for: releaseID)
    }

    func clearUnwatched(releaseID: Int64, position: Int) {
        var positions = loadPositions(releaseID: releaseID)
        positions.remove(position)
        save(positions, for: releaseID)
    }

    private func save(_ positions: Set<Int>, for releaseID: Int64) {
        guard let data = try? JSONEncoder().encode(Array(positions).sorted()) else { return }
        defaults.set(data, forKey: key(releaseID: releaseID))
    }
}
