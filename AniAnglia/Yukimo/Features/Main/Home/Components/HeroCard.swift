//
//  HeroCard.swift
//  Featured release card. Backdrop image + scrim + title + CTA.
//

import SwiftUI

struct HeroCard: View {
    let release: ReleaseDTO?
    var isLoading: Bool

    var body: some View {
        // Fixed 5:4 frame regardless of loading state — no layout shift
        // between skeleton and loaded data. Taller than the old 16:11 so the
        // recommendation card has presence on Home.
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = width * 4.0 / 5.0
            ZStack(alignment: .bottomLeading) {
                backdrop
                    .frame(width: width, height: height)
                    .clipped()

                // Two-pass scrim:
                //  1. Wide vertical fade from top, gets stronger sooner so
                //     light/pastel posters don't bleach the title.
                //  2. Concentrated bottom slab anchored to the text zone —
                //     near-opaque, gives a guaranteed dark "letter box"
                //     under the CTA + title regardless of the artwork.
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .clear,                location: 0.00),
                        Gradient.Stop(color: .black.opacity(0.10),  location: 0.30),
                        Gradient.Stop(color: .black.opacity(0.45),  location: 0.55),
                        Gradient.Stop(color: .black.opacity(0.78),  location: 0.85),
                        Gradient.Stop(color: .black.opacity(0.92),  location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom)
                    .frame(width: width, height: height)

                if let release {
                    content(for: release)
                        .padding(YukimoSpacing.xl)
                        .frame(width: width, alignment: .leading)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.xl, style: .continuous)
                    .stroke(YukimoColor.borderSoft, lineWidth: 0.6))
            .yukimoShadow(YukimoShadow.elevated)
            .redacted(reason: isLoading && release == nil ? .placeholder : [])
        }
        .aspectRatio(5.0/4.0, contentMode: .fit)
    }

    @ViewBuilder
    private var backdrop: some View {
        if let url = release?.imageURL {
            YukimoAsyncImage(urlString: url)
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Color(hex: 0xFFB0AB), Color(hex: 0xFF8AA0), Color(hex: 0xD9C6FF)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func content(for release: ReleaseDTO) -> some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                Text("Рекомендуем сегодня")
                    .font(YukimoTypography.caption)
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))

            // Double-layered shadow under the title — close-radius layer
            // anchors the glyph edges to dark pixels, wider-radius layer
            // smudges the background a bit further out so the text stays
            // legible even on busy, light artwork.
            Text(release.displayTitle)
                .font(YukimoTypography.title)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.60), radius: 6, x: 0, y: 2)
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 4)

            HStack(spacing: YukimoSpacing.sm) {
                metaPill(systemImage: "star.fill",
                         text: release.grade > 0 ? String(format: "%.1f", release.grade) : "—")
                if !release.year.isEmpty {
                    metaPill(systemImage: "calendar", text: release.year)
                }
                if release.episodesReleased > 0 {
                    metaPill(systemImage: "play.rectangle",
                             text: "\(release.episodesReleased) сер.")
                }
            }

            Text("Смотреть")
                .font(YukimoTypography.headline)
                .foregroundStyle(YukimoColor.primaryCoralDark)
                .padding(.horizontal, YukimoSpacing.lg)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
                .yukimoShadow(YukimoShadow.soft)
                .padding(.top, 6)
        }
    }

    private func metaPill(systemImage: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(YukimoTypography.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.38), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.6))
        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 1)
    }
}
