//
//  YukimoProgressStore.swift
//  Local persistence of playback progress per (release, source, episode position).
//  Backed by UserDefaults — small, atomic, survives app restarts.
//

import Foundation

struct YukimoEpisodeProgress: Codable {
    let seconds: Double
    let duration: Double
    let savedAt: Date
}

final class YukimoProgressStore {
    static let shared = YukimoProgressStore()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "com.yukimo.progress", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Keys

    private func key(releaseID: Int64, sourceID: Int64, position: Int) -> String {
        "yukimo.progress.\(releaseID).\(sourceID).\(position)"
    }

    // MARK: Read

    /// Returns saved time in seconds. `nil` if no useful resume point.
    /// Considers progress useful only when 5s ≤ saved ≤ duration − 15s.
    func resumeSeconds(releaseID: Int64, sourceID: Int64, position: Int) -> Double? {
        guard let p = load(releaseID: releaseID, sourceID: sourceID, position: position) else { return nil }
        guard p.seconds > 5 else { return nil }
        if p.duration > 0 && p.seconds > p.duration - 15 { return nil }
        return p.seconds
    }

    func load(releaseID: Int64, sourceID: Int64, position: Int) -> YukimoEpisodeProgress? {
        let k = key(releaseID: releaseID, sourceID: sourceID, position: position)
        guard let data = defaults.data(forKey: k) else { return nil }
        return try? JSONDecoder().decode(YukimoEpisodeProgress.self, from: data)
    }

    // MARK: Write

    func save(releaseID: Int64, sourceID: Int64, position: Int,
              seconds: Double, duration: Double) {
        let k = key(releaseID: releaseID, sourceID: sourceID, position: position)
        let progress = YukimoEpisodeProgress(seconds: seconds, duration: duration, savedAt: Date())
        queue.async { [weak self] in
            guard let data = try? JSONEncoder().encode(progress) else { return }
            self?.defaults.set(data, forKey: k)
        }
    }

    /// Called when an episode plays through to the end — clears the
    /// resume point so next open starts fresh.
    func clear(releaseID: Int64, sourceID: Int64, position: Int) {
        let k = key(releaseID: releaseID, sourceID: sourceID, position: position)
        queue.async { [weak self] in
            self?.defaults.removeObject(forKey: k)
        }
    }
}
