//
//  YukimoPlayerPrefsStore.swift
//  Per-release sticky player preferences: which dubbing studio
//  (`typeID`), which player engine (`sourceID`), which episode position,
//  and which quality the user last picked. Persisted to UserDefaults so
//  reopening the same anime restores everything in one shot.
//
//  Semantics:
//   - Each release has at most one Prefs record.
//   - Writes are coalesced on a utility queue so the player thread isn't
//     blocked.
//   - `position` here is the LITERAL last position the user opened —
//     authoritative over libanixart's sticky server `lastViewEpisode`
//     and over `YukimoProgressStore` snapshots (which are by-source).
//

import Foundation

final class YukimoPlayerPrefsStore {
    static let shared = YukimoPlayerPrefsStore()

    struct Prefs: Codable {
        var sourceID: Int64?
        var typeID: Int64?
        var position: Int?
        /// Free-form quality key as exposed by `StreamVariantDTO.quality`
        /// — e.g. `"720"`, `"1080"`, `"hls"`. Stored verbatim so it
        /// survives parser changes that swap height-based labels for
        /// adaptive ones.
        var qualityKey: String?
        var updatedAt: Date
    }

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "yukimo.playerprefs", qos: .utility)

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(releaseID: Int64) -> String {
        "yukimo.playerprefs.\(releaseID)"
    }

    func load(releaseID: Int64) -> Prefs? {
        guard let data = defaults.data(forKey: key(releaseID: releaseID)) else { return nil }
        return try? JSONDecoder().decode(Prefs.self, from: data)
    }

    /// Patch-style save — only fields passed non-nil are overwritten.
    /// Pass an explicit value to update; omit to keep the previous one.
    func save(releaseID: Int64,
              sourceID: Int64? = nil,
              typeID: Int64? = nil,
              position: Int? = nil,
              qualityKey: String? = nil) {
        queue.async {
            var current = self.load(releaseID: releaseID)
                ?? Prefs(sourceID: nil, typeID: nil, position: nil,
                         qualityKey: nil, updatedAt: Date())
            if let sourceID { current.sourceID = sourceID }
            if let typeID { current.typeID = typeID }
            if let position { current.position = position }
            if let qualityKey { current.qualityKey = qualityKey }
            current.updatedAt = Date()
            guard let encoded = try? JSONEncoder().encode(current) else { return }
            self.defaults.set(encoded, forKey: self.key(releaseID: releaseID))
        }
    }
}
