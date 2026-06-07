//
//  ContinueWatchingCard.swift
//  Wide card showing poster + last-watched episode + progress.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let release: ReleaseDTO
    var width: CGFloat = 280

    var body: some View {
        HStack(spacing: YukimoSpacing.md) {
            YukimoAsyncImage(urlString: release.imageURL)
                .aspectRatio(2.0/3.0, contentMode: .fill)
                .frame(width: 64, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(release.displayTitle)
                    .font(YukimoTypography.bodyEmph)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(2)
                if release.lastViewEpisodePosition > 0 {
                    Text(episodeLabel)
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                progressBar
            }
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(YukimoColor.primaryCoral)
                    .frame(width: 36, height: 36)
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(x: 1) // optical balance for triangle
            }
            .yukimoShadow(YukimoShadow.glow)
        }
        .padding(YukimoSpacing.md)
        .frame(width: width)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
        .yukimoShadow(YukimoShadow.soft)
    }

    private var episodeLabel: String {
        let pos = release.lastViewEpisodePosition
        if let name = release.lastViewEpisodeName, !name.isEmpty {
            return "Серия \(pos) · \(name)"
        }
        return "Серия \(pos)"
    }

    private var progressFraction: Double {
        let total = max(release.episodesTotal, release.episodesReleased)
        guard total > 0, release.lastViewEpisodePosition > 0 else { return 0 }
        return min(Double(release.lastViewEpisodePosition) / Double(total), 1)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(YukimoColor.borderSoft)
                Capsule()
                    .fill(LinearGradient(
                        colors: [YukimoColor.primaryCoralLight, YukimoColor.primaryCoral],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, proxy.size.width * progressFraction))
            }
        }
        .frame(height: 4)
    }
}
