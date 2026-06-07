//
//  PosterRail.swift
//  Generic horizontal carousel + section header.
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: YukimoSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(YukimoColor.primaryCoral)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(YukimoTypography.title3)
                    .foregroundStyle(YukimoColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                }
            }
            Spacer(minLength: 0)
            if let onSeeAll {
                Button(action: onSeeAll) {
                    HStack(spacing: 2) {
                        Text("Все")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .buttonStyle(.yukimoGhost)
            }
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }
}

struct PosterRail: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let state: HomeViewModel.SectionState<ReleaseDTO>
    var posterWidth: CGFloat = 130

    var body: some View {
        // Don't render anything when the section is empty AND not loading —
        // the user explicitly didn't want empty-state placeholders cluttering
        // Home (recommendations, etc.).
        if state.items.isEmpty && !state.isLoading {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: YukimoSpacing.md) {
                SectionHeader(title: title, subtitle: subtitle, systemImage: systemImage)

                if state.isLoading && state.items.isEmpty {
                    loadingRow
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: YukimoSpacing.md) {
                            ForEach(state.items, id: \.releaseID) { item in
                                NavigationLink(value: ReleaseRoute(releaseID: item.releaseID)) {
                                    PosterCard(release: item, width: posterWidth)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, YukimoSpacing.screenPadding)
                    }
                }
            }
        }
    }

    private var loadingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: YukimoSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: YukimoSpacing.sm) {
                        RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                            .fill(YukimoColor.softPink)
                            .frame(width: posterWidth, height: posterWidth * 1.5)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(YukimoColor.softPink.opacity(0.7))
                            .frame(width: posterWidth, height: 12)
                    }
                }
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private var emptyRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(YukimoColor.textTertiary)
                Text(state.error ?? "Пока пусто")
                    .font(YukimoTypography.footnote)
                    .foregroundStyle(YukimoColor.textTertiary)
            }
            .padding(.vertical, YukimoSpacing.xl)
            Spacer()
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }
}

// Tiny shimmer modifier — sweeps a translucent highlight across redacted content.
private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1.2

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                let w = proxy.size.width
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)],
                    startPoint: .leading, endPoint: .trailing)
                    .frame(width: w * 0.4)
                    .offset(x: phase * w)
            }
            .mask(content)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
        )
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}
