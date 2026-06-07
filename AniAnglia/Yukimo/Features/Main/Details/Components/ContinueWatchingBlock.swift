//
//  ContinueWatchingBlock.swift
//  "Продолжить просмотр" card matching the design mockup: poster
//  thumbnail on the left, label + episode line, full-width coral
//  progress bar with a bold percentage label aligned right.
//

import SwiftUI

struct ContinueWatchingBlock: View {
    let release: ReleaseDTO
    let episodeDisplayNumber: Int       // 1-based display order
    let episodeName: String?
    let progress: YukimoEpisodeProgress?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            cardBody
        }
        .buttonStyle(YukimoCardPressStyle())
        .padding(.horizontal, YukimoSpacing.screenPadding)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardBody: some View {
        HStack(alignment: .center, spacing: YukimoSpacing.md) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text("Продолжить просмотр")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.9)
                    .foregroundStyle(YukimoColor.textTertiary)

                Text(headline)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if let fraction = progressFraction {
                    progressRow(fraction)
                        .padding(.top, 2)
                } else {
                    Text(remainingSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(YukimoColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)
        }
        .padding(YukimoSpacing.md)
        .frame(maxWidth: .infinity)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
        .yukimoShadow(YukimoShadow.soft)
    }

    // MARK: Thumbnail (square 60×60 with play disc)

    private var thumbnail: some View {
        YukimoAsyncImage(urlString: release.imageURL)
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
            .overlay(
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.45))
                        .frame(width: 26, height: 26)
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 0.5)
                })
    }

    // MARK: Progress row — bar + bold % aligned right

    @ViewBuilder
    private func progressRow(_ fraction: Double) -> some View {
        let percent = Int((fraction * 100).rounded())
        HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(YukimoColor.primaryCoral.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [YukimoColor.primaryCoralLight, YukimoColor.primaryCoral],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * fraction))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            Text("\(percent)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(YukimoColor.primaryCoral)
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)
        }
    }

    // MARK: Strings

    private var headline: String {
        if let episodeName, !episodeName.isEmpty {
            return "Серия \(episodeDisplayNumber) · \(episodeName)"
        }
        return "Серия \(episodeDisplayNumber)"
    }

    private var remainingSubtitle: String {
        guard let progress, progress.duration > 0 else { return "Готово к просмотру" }
        let remaining = max(0, progress.duration - progress.seconds)
        return "\(format(remaining)) осталось"
    }

    private var progressFraction: Double? {
        guard let progress, progress.duration > 0 else { return nil }
        return max(0, min(1, progress.seconds / progress.duration))
    }

    private func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }

    private var accessibilityLabel: String {
        if let fraction = progressFraction {
            return "Продолжить просмотр серии \(episodeDisplayNumber), \(Int((fraction * 100).rounded())) процентов"
        }
        return "Продолжить просмотр серии \(episodeDisplayNumber)"
    }
}
