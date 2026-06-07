//
//  AnimeHeroHeader.swift
//  Hero block with a natural intrinsic height — sizes to content,
//  никакого `frame(height:)` + `Spacer(minLength:)`/`ZStack(.bottom)`
//  трюков. Backdrop рисуется через `.background()`, поэтому всегда
//  занимает ровно столько же, сколько и контент. Это устойчиво к
//  длинным названиям, длинному списку мета-токенов и т.п.
//

import SwiftUI

struct AnimeHeroHeader: View {
    let release: ReleaseDTO

    @State private var showFullTitle = false

    /// Top breathing room for the floating glass toolbar (back / share /
    /// more buttons live in the navigation safe area above this).
    private let topInset: CGFloat = 72

    var body: some View {
        VStack(spacing: YukimoSpacing.md) {
            // Safe-area + toolbar headroom. A simple sized clear view
            // is more predictable than `Spacer(minLength:)`, which can
            // both stretch and overflow.
            Color.clear
                .frame(height: topInset)

            poster
                .accessibilityHidden(true)

            if let category = release.categoryLabel {
                DetailsBadge(icon: release.categoryIcon,
                             label: category,
                             tint: .white,
                             scheme: .onDark)
            }

            titleBlock
                .onTapGesture { showFullTitle = true }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Открыть полное название")

            if metaTokens.isEmpty == false {
                metaRow
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, YukimoSpacing.xl)
        .padding(.horizontal, YukimoSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(backdrop)
        .sheet(isPresented: $showFullTitle) {
            FullTitleSheet(titleRu: release.titleRu,
                           titleOriginal: release.titleOriginal)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Backdrop — drawn behind the entire VStack via .background()

    private var backdrop: some View {
        ZStack {
            YukimoColor.background
            YukimoAsyncImage(urlString: release.imageURL)
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .blur(radius: 42, opaque: true)
                .scaleEffect(1.18)
                .saturation(1.10)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white,            location: 0.0),
                            .init(color: .white,            location: 0.65),
                            .init(color: .white.opacity(0), location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom))
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0.0),
                    .init(color: .black.opacity(0.20), location: 0.55),
                    .init(color: .black.opacity(0.0),  location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom)
        }
        .clipped()
    }

    // MARK: Poster — 140×210 + status pill hanging off bottom-right

    private var poster: some View {
        ZStack(alignment: .bottomTrailing) {
            YukimoAsyncImage(urlString: release.imageURL)
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 1))
                .shadow(color: .black.opacity(0.45), radius: 22, x: 0, y: 12)

            if let statusText = posterStatusText {
                posterStatusPill(statusText, dot: posterStatusDotColor)
                    .offset(x: 14, y: 6)  // hangs off the corner
            }
        }
        .frame(width: 140, height: 210)
    }

    private var posterStatusText: String? {
        switch release.status {
        case .ongoing:  return "Онгоинг"
        case .finished: return "Завершено"
        case .upcoming: return "Анонс"
        default:        return nil
        }
    }

    private var posterStatusDotColor: Color {
        switch release.status {
        case .ongoing:  return YukimoColor.danger
        case .finished: return Color.white.opacity(0.85)
        case .upcoming: return YukimoColor.accentLavender
        default:        return YukimoColor.textTertiary
        }
    }

    private func posterStatusPill(_ text: String, dot: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dot)
                .frame(width: 6, height: 6)
                .shadow(color: dot.opacity(0.55), radius: 3)
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.55), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
        .accessibilityLabel("Статус: \(text)")
    }

    // MARK: Title

    @ViewBuilder
    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(release.displayTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 2)
            if !release.titleOriginal.isEmpty
                && release.titleOriginal != release.titleRu {
                Text(release.titleOriginal)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: Meta row — ★ rating | 2024 | 8/12 (with vertical bar separators)

    private struct MetaToken {
        let icon: String
        let value: String
        let tint: Color
    }

    private var metaTokens: [MetaToken] {
        var out: [MetaToken] = []
        if release.grade > 0 {
            out.append(.init(icon: "star.fill",
                             value: String(format: "%.1f", release.grade),
                             tint: .orange))
        }
        if !release.year.isEmpty {
            out.append(.init(icon: "calendar",
                             value: release.year,
                             tint: YukimoColor.primaryCoralLight))
        }
        if let episodes = episodesValue {
            out.append(.init(icon: "tv",
                             value: episodes,
                             tint: YukimoColor.primaryCoralLight))
        }
        return out
    }

    private var episodesValue: String? {
        if release.episodesTotal > 0 && release.episodesReleased > 0 {
            return "\(release.episodesReleased)/\(release.episodesTotal)"
        }
        if release.episodesReleased > 0 { return "\(release.episodesReleased)" }
        if release.episodesTotal > 0 { return "\(release.episodesTotal)" }
        return nil
    }

    private var metaRow: some View {
        HStack(spacing: 14) {
            ForEach(Array(metaTokens.enumerated()), id: \.offset) { idx, token in
                metaTokenView(token)
                if idx < metaTokens.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.28))
                        .frame(width: 1, height: 18)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metaTokenView(_ token: MetaToken) -> some View {
        HStack(spacing: 5) {
            Image(systemName: token.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(token.tint)
            Text(token.value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
    }
}
