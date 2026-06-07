//
//  InfoStrip.swift
//  Four equal-width stat tiles below the action panel. Rating uses
//  orange accent on a light surface (NOT the old orange-tinted bg).
//  Larger values to match the design mockup.
//

import SwiftUI

struct InfoStrip: View {
    let release: ReleaseDTO

    // LazyVGrid с 4 одинаково flexible колонками гарантирует, что
    // длинный текст ("Завершено") не растянет свой тайл шире соседей.
    // В HStack(spacing:) распределение шло по intrinsic width, поэтому
    // тайл со словом "Завершено" получался шире "4.3" / "2008" / "13/13".
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: YukimoSpacing.sm),
              count: 4)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ratingTile
            yearTile
            episodesTile
            statusTile
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    // MARK: Tiles

    private var ratingTile: some View {
        statTile(
            icon: "star.fill",
            iconTint: .orange,
            value: release.grade > 0 ? String(format: "%.1f", release.grade) : "—",
            valueTint: .orange,
            label: "Рейтинг")
    }

    private var yearTile: some View {
        statTile(
            icon: "calendar",
            iconTint: YukimoColor.primaryCoral,
            value: release.year.isEmpty ? "—" : release.year,
            valueTint: YukimoColor.textPrimary,
            label: "Год выхода")
    }

    private var episodesTile: some View {
        statTile(
            icon: "tv",
            iconTint: YukimoColor.primaryCoral,
            value: episodesValue,
            valueTint: YukimoColor.textPrimary,
            label: "Серий")
    }

    private var episodesValue: String {
        if release.episodesTotal > 0 && release.episodesReleased > 0 {
            return "\(release.episodesReleased)/\(release.episodesTotal)"
        }
        if release.episodesReleased > 0 { return "\(release.episodesReleased)" }
        if release.episodesTotal > 0 { return "\(release.episodesTotal)" }
        return "—"
    }

    private var statusTile: some View {
        VStack(spacing: 6) {
            // Status dot replaces icon for the status tile so the user
            // immediately sees the color.
            Circle()
                .fill(release.statusTint)
                .frame(width: 12, height: 12)
                .shadow(color: release.statusTint.opacity(0.5), radius: 4)
            Text(release.statusLabel ?? "—")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(YukimoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Статус")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(YukimoColor.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
    }

    // MARK: Tile builder

    private func statTile(icon: String,
                          iconTint: Color,
                          value: String,
                          valueTint: Color,
                          label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconTint)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(valueTint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(YukimoColor.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
    }
}

/// Standalone "Жанры" block — labeled header + wrap of bigger coral chips.
struct GenresSection: View {
    let raw: String

    var body: some View {
        let chips = raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if chips.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
                Label("Жанры", systemImage: "tag.fill")
                    .font(YukimoTypography.title3)
                    .foregroundStyle(YukimoColor.textPrimary)

                YukimoFlowLayout(hSpacing: 8, vSpacing: 10) {
                    ForEach(chips, id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(YukimoColor.primaryCoralDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(YukimoColor.softPink, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(YukimoColor.primaryCoral.opacity(0.25), lineWidth: 0.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
    }
}
