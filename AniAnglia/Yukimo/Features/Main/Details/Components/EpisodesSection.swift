//
//  EpisodesSection.swift
//  "Серии" block: header (title + count pill with chevron), and the
//  vertical list of EpisodeRows. По умолчанию показывает первые 5
//  серий + coral "Показать все серии" кнопку. Загрузка / ошибка /
//  пустое состояние. Без summary "Озвучка / Тип" — выбор плеера и
//  озвучки делается прямо в плеере.
//

import SwiftUI

struct EpisodesSection: View {
    let episodes: [EpisodeDTO]
    let isLoading: Bool
    let errorMessage: String?
    let releaseID: Int64
    let selectedSourceID: Int64?
    let isEpisodeWatched: (EpisodeDTO) -> Bool
    let resumePosition: Int?
    let onPickEpisode: (EpisodeDTO) -> Void
    let onSetWatched: (EpisodeDTO, Bool) -> Void

    private let pageSize = 10
    @State private var visibleCount = 10

    private var displayedEpisodes: [EpisodeDTO] {
        Array(episodes.prefix(visibleCount))
    }

    private var hasMore: Bool {
        visibleCount < episodes.count
    }

    private var remaining: Int {
        max(0, episodes.count - visibleCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.md) {
            header
            content
        }
    }

    // MARK: Header — icon + label, "shown/total" count pill on the right

    private var header: some View {
        HStack(alignment: .center) {
            Label("Серии", systemImage: "play.rectangle.fill")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
            Spacer()
            if !episodes.isEmpty {
                countPill
            }
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    /// Shows "<shown>/<total>" so the user can see how much of the list
    /// is currently loaded. Non-interactive — pagination happens via the
    /// "Показать ещё" button at the bottom.
    private var countPill: some View {
        let shown = min(visibleCount, episodes.count)
        return Text("\(shown) / \(episodes.count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(YukimoColor.primaryCoralDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(YukimoColor.softPink, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(YukimoColor.primaryCoral.opacity(0.25), lineWidth: 0.5))
    }

    // MARK: Content states

    @ViewBuilder
    private var content: some View {
        if isLoading && episodes.isEmpty {
            loadingState
        } else if let err = errorMessage, episodes.isEmpty {
            errorState(err)
        } else if episodes.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 8) {
                ForEach(Array(displayedEpisodes.enumerated()), id: \.offset) { idx, ep in
                    let progress = selectedSourceID.flatMap { sid in
                        YukimoProgressStore.shared.load(
                            releaseID: releaseID, sourceID: sid, position: ep.position)
                    } ?? nil
                    EpisodeRow(
                        episode: ep,
                        displayNumber: idx + 1,
                        isWatched: isEpisodeWatched(ep),
                        progress: progress,
                        isResumeTarget: resumePosition == ep.position,
                        onTap: { onPickEpisode(ep) },
                        onSetWatched: { newValue in onSetWatched(ep, newValue) })
                }

                if hasMore {
                    loadMoreButton
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
    }

    // MARK: "Показать ещё" — adds the next page to the visible window.

    private var loadMoreButton: some View {
        // Hint how many we'd add — exactly `pageSize` until the very
        // last page, then the leftover count.
        let nextChunk = min(pageSize, remaining)
        return Button {
            visibleCount = min(episodes.count, visibleCount + pageSize)
        } label: {
            HStack(spacing: 6) {
                Text("Показать ещё \(nextChunk)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(YukimoColor.primaryCoralDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(YukimoColor.softPink,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(YukimoColor.primaryCoral.opacity(0.3), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Показать ещё \(nextChunk) серий, осталось \(remaining)")
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: YukimoSpacing.md) {
                    RoundedRectangle(cornerRadius: YukimoRadius.sm).fill(YukimoColor.softPink)
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 4).fill(YukimoColor.softPink.opacity(0.7))
                            .frame(height: 14).frame(maxWidth: 220, alignment: .leading)
                        RoundedRectangle(cornerRadius: 4).fill(YukimoColor.softPink.opacity(0.5))
                            .frame(height: 10).frame(maxWidth: 140, alignment: .leading)
                    }
                    Spacer()
                }
                .padding(YukimoSpacing.md)
                .background(YukimoColor.surface,
                            in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            }
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(YukimoColor.warning)
            Text("Не удалось загрузить серии")
                .font(YukimoTypography.bodyEmph)
                .foregroundStyle(YukimoColor.textPrimary)
            Text(message)
                .font(YukimoTypography.footnote)
                .foregroundStyle(YukimoColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(YukimoSpacing.xl)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tv.slash")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(YukimoColor.textTertiary)
            Text("Серии пока недоступны")
                .font(YukimoTypography.bodyEmph)
                .foregroundStyle(YukimoColor.textPrimary)
            Text("Мы покажем их здесь, когда они появятся.")
                .font(YukimoTypography.footnote)
                .foregroundStyle(YukimoColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(YukimoSpacing.xl)
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }
}
