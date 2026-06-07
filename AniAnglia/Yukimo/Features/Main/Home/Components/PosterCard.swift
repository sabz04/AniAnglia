//
//  PosterCard.swift
//  Anime poster card — 2:3 aspect ratio (industry standard) with
//  title underneath. Used in horizontal rails.
//

import SwiftUI

struct PosterCard: View {
    let release: ReleaseDTO
    var width: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                YukimoAsyncImage(urlString: release.imageURL)
                    .aspectRatio(2.0/3.0, contentMode: .fill)
                    .frame(width: width, height: width * 1.5)
                    .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                            .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
                    .yukimoShadow(YukimoShadow.soft)

                if release.grade > 0 {
                    ratingBadge
                        .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(release.displayTitle)
                    .font(YukimoTypography.subhead)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if !release.year.isEmpty {
                    Text(release.year)
                        .font(YukimoTypography.caption)
                        .foregroundStyle(YukimoColor.textTertiary)
                }
            }
            .frame(width: width, alignment: .leading)
        }
    }

    private var ratingBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.yellow)
            Text(String(format: "%.1f", release.grade))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.55),
                    in: Capsule())
    }
}

// `displayTitle`/`statusLabel`/`statusTint` extensions live in ReleaseRowCard.swift.
