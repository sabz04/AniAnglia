import SwiftUI

//
//  YukimoHistoryStore.swift
//  Local viewing-history cache. The libanixart server endpoints
//  (`get_history`, `history_search`) intermittently return 0 items even
//  on accounts with active watch sessions; this store gives a robust
//  client-side history that the Library "История" tab can fall back on
//  (and merge with) regardless of server behaviour.
//
//  Records:
//   - `releaseID`
//   - timestamp of last "Смотреть" / episode play
//   - lightweight metadata snapshot (title, poster URL, year, grade,
//     episode counts, status, genres) so the row card can render even
//     when the user is offline or the server forgot the title.
//

import Foundation

@MainActor
final class YukimoHistoryStore {
    static let shared = YukimoHistoryStore()

    struct Entry: Codable, Equatable {
        let releaseID: Int64
        var timestamp: Date
        var titleRu: String
        var titleOriginal: String
        var imageURL: String
        var grade: Double
        var voteCount: Int
        var year: String
        var episodesReleased: Int
        var episodesTotal: Int
        var genres: String
        var status: Int           // YukimoReleaseStatus rawValue
        var category: Int         // YukimoReleaseCategory rawValue
        var descriptionText: String
    }

    private let defaultsKey = "yukimo.history.v1"
    /// Bound on the local list so UserDefaults doesn't grow unbounded.
    private let maxEntries = 200
    private let writeQueue = DispatchQueue(label: "yukimo.history.write", qos: .utility)

    private init() {}

    func record(_ release: ReleaseDTO) {
        let entry = Entry(
            releaseID: release.releaseID,
            timestamp: Date(),
            titleRu: release.titleRu,
            titleOriginal: release.titleOriginal,
            imageURL: release.imageURL ?? "",
            grade: release.grade,
            voteCount: release.voteCount,
            year: release.year,
            episodesReleased: release.episodesReleased,
            episodesTotal: release.episodesTotal,
            genres: release.genres,
            status: release.status.rawValue,
            category: release.category.rawValue,
            descriptionText: release.description_ ?? "")
        var current = load()
        current.removeAll { $0.releaseID == entry.releaseID }
        current.insert(entry, at: 0)
        if current.count > maxEntries {
            current = Array(current.prefix(maxEntries))
        }
        persist(current)
    }

    /// All entries, newest first.
    func all() -> [Entry] {
        load().sorted { $0.timestamp > $1.timestamp }
    }

    func remove(releaseID: Int64) {
        var current = load()
        current.removeAll { $0.releaseID == releaseID }
        persist(current)
    }

    func clear() {
        persist([])
    }

    // MARK: Storage

    private func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    private func persist(_ entries: [Entry]) {
        let key = defaultsKey
        writeQueue.async {
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

// MARK: - Display

extension YukimoHistoryStore.Entry: Identifiable {
    var id: Int64 { releaseID }

    var displayTitle: String {
        titleRu.isEmpty ? titleOriginal : titleRu
    }
}

/// Row visually matching `ReleaseRowCard` but driven by a
/// `YukimoHistoryStore.Entry` (so we don't have to construct a synthetic
/// `ReleaseDTO` from cached data).
struct HistoryEntryRowCard: View {
    let entry: YukimoHistoryStore.Entry

    var body: some View {
        HStack(alignment: .top, spacing: YukimoSpacing.md) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.displayTitle)
                    .font(YukimoTypography.bodyEmph)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if entry.grade > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.orange)
                            Text(String(format: "%.1f", entry.grade))
                                .font(YukimoTypography.subhead)
                                .foregroundStyle(YukimoColor.textPrimary)
                        }
                    }
                    Text(timestampLabel)
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textTertiary)
                }

                if let snippet = descriptionSnippet {
                    Text(snippet)
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(YukimoSpacing.md)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
    }

    private var poster: some View {
        YukimoAsyncImage(urlString: entry.imageURL.isEmpty ? nil : entry.imageURL)
            .aspectRatio(2.0/3.0, contentMode: .fill)
            .frame(width: 64, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous))
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.unitsStyle = .full
        return f
    }()

    private var timestampLabel: String {
        Self.relativeFormatter.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    private var descriptionSnippet: String? {
        let raw = entry.descriptionText
        if raw.isEmpty { return nil }
        let stripped = raw
            .replacingOccurrences(of: "<br>",   with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>",  with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;",  with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}
