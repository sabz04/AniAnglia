//
//  EpisodeRow.swift
//  One episode row matching the design mockups: number tile, title +
//  status row (watched / progress / Не просмотрено / Филлер), coral
//  play button on the right. Resume target gets a soft pink surface +
//  an inline progress bar.
//

import SwiftUI

struct EpisodeRow: View {
    let episode: EpisodeDTO
    let displayNumber: Int
    let isWatched: Bool
    let progress: YukimoEpisodeProgress?
    let isResumeTarget: Bool
    let onTap: () -> Void
    /// Optional handler — when provided, the row gets a swipe action /
    /// context menu to toggle watched state. Pass `nil` to hide both.
    var onSetWatched: ((Bool) -> Void)? = nil

    private var progressFraction: Double {
        guard let p = progress, p.duration > 0 else { return 0 }
        return max(0, min(1, p.seconds / p.duration))
    }

    private var hasProgress: Bool {
        guard let p = progress else { return false }
        return p.seconds > 5
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: YukimoSpacing.md) {
                    numberTile

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Серия \(displayNumber)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(YukimoColor.textPrimary)
                            .lineLimit(1)

                        statusRow
                    }

                    Spacer(minLength: 8)

                    playButton
                }

                // Inline progress bar for the resume target (matches mockup).
                if isResumeTarget && progressFraction > 0 {
                    progressBar
                }
            }
            .padding(YukimoSpacing.md)
            .background(rowBackground,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(rowStroke, lineWidth: isResumeTarget ? 1 : 0.5))
        }
        .buttonStyle(YukimoCardPressStyle())
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            if let onSetWatched {
                if isWatched {
                    Button {
                        onSetWatched(false)
                    } label: {
                        Label("Убрать из просмотренных", systemImage: "eye.slash")
                    }
                } else {
                    Button {
                        onSetWatched(true)
                    } label: {
                        Label("Отметить как просмотренное", systemImage: "checkmark.circle")
                    }
                }
            }
        }
    }

    // MARK: Number tile

    private var numberTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous)
                .fill(numberTileFill)
                .frame(width: 50, height: 50)
            Text("\(displayNumber)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(numberTileText)
        }
    }

    private var numberTileFill: Color {
        if isWatched { return YukimoColor.success.opacity(0.20) }
        return YukimoColor.softPink
    }

    private var numberTileText: Color {
        if isWatched { return YukimoColor.success }
        return YukimoColor.primaryCoralDark
    }

    // MARK: Status row

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 8) {
            if episode.isFiller {
                fillerBadge
            }
            statusIndicator
        }
    }

    private var fillerBadge: some View {
        Text("Филлер")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(YukimoColor.accentLavender)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(YukimoColor.accentLavender.opacity(0.2), in: Capsule())
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if isWatched {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(YukimoColor.success)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Просмотрено")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(YukimoColor.textSecondary)
            }
        } else if hasProgress, let p = progress {
            HStack(spacing: 4) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(YukimoColor.primaryCoral)
                Text("С \(formatPlaybackTime(p.seconds))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(YukimoColor.primaryCoral)
            }
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(YukimoColor.textTertiary.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text("Не просмотрено")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(YukimoColor.textTertiary)
            }
        }
    }

    // MARK: Play button (coral filled circle on the right)

    private var playButton: some View {
        ZStack {
            Circle()
                .fill(YukimoColor.primaryCoral.opacity(0.12))
                .frame(width: 40, height: 40)
            Circle()
                .stroke(YukimoColor.primaryCoral, lineWidth: 1.5)
                .frame(width: 40, height: 40)
            Image(systemName: "play.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(YukimoColor.primaryCoral)
                .offset(x: 1)
        }
    }

    // MARK: Inline progress bar

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(YukimoColor.primaryCoral.opacity(0.18))
                Capsule()
                    .fill(YukimoColor.primaryCoral)
                    .frame(width: max(4, proxy.size.width * progressFraction))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 4)
    }

    // MARK: Background / stroke

    private var rowBackground: Color {
        isResumeTarget ? YukimoColor.softPink.opacity(0.55) : YukimoColor.surface
    }

    private var rowStroke: Color {
        isResumeTarget ? YukimoColor.primaryCoral.opacity(0.45) : YukimoColor.borderSoft
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        var parts = ["Серия \(displayNumber)"]
        if !episode.name.isEmpty { parts.append(episode.name) }
        if isWatched { parts.append("просмотрено") }
        if episode.isFiller { parts.append("филлер") }
        if let p = progress, p.seconds > 5 {
            parts.append("остановлено на \(formatPlaybackTime(p.seconds))")
        }
        return parts.joined(separator: ", ")
    }

    private var headline: String {
        episode.name.isEmpty ? "Серия \(displayNumber)" : episode.name
    }
}

/// Subtle scale-on-press for full-card buttons.
struct YukimoCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(YukimoMotion.springSoft, value: configuration.isPressed)
    }
}
