//
//  AnimeDetailsToolbar.swift
//  Floating glass toolbar that always sits above the scroll content.
//  Background opacity tweens with scroll offset so the toolbar reveals
//  itself smoothly as the hero passes under.
//

import SwiftUI

struct AnimeDetailsToolbar: View {
    let title: String
    /// 0…1 — how visible the title text is. The view multiplies its alpha by this.
    let titleVisibility: Double
    /// 0…1 — how solid the toolbar background is.
    let surfaceOpacity: Double

    let onBack: () -> Void
    let shareURL: URL?
    let onCopyLink: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: YukimoSpacing.sm) {
            glassIcon(systemName: "chevron.left",
                      label: "Назад",
                      action: onBack)

            Spacer(minLength: 0)

            Text(title)
                .font(YukimoTypography.headline)
                .foregroundStyle(YukimoColor.textPrimary)
                .lineLimit(1)
                .opacity(titleVisibility)

            Spacer(minLength: 0)

            if let shareURL {
                ShareLink(item: shareURL,
                          subject: Text(title.isEmpty ? "Yukimo" : title),
                          message: Text("Посмотри это аниме в Yukimo")) {
                    glassIconLabel(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Поделиться")
            }

            Menu {
                Button {
                    onCopyLink()
                } label: {
                    Label("Скопировать ссылку", systemImage: "link")
                }
            } label: {
                glassIconLabel(systemName: "ellipsis")
            }
            .accessibilityLabel("Ещё")
        }
        .padding(.horizontal, YukimoSpacing.md)
        .padding(.bottom, 8)
        .padding(.top, 8)
        .background(toolbarBackground)
    }

    // MARK: Background — fades from clear to opaque material

    @ViewBuilder
    private var toolbarBackground: some View {
        ZStack {
            // Material is fully transparent at scroll=0 and gains presence
            // when surfaceOpacity > 0. We hard-clamp to keep the cap.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(surfaceOpacity)
            Rectangle()
                .fill(YukimoColor.background.opacity(surfaceOpacity * 0.55))
            Rectangle()
                .fill(YukimoColor.borderSoft.opacity(surfaceOpacity * 0.3))
                .frame(maxHeight: 0.5)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .compositingGroup()
        .ignoresSafeArea(edges: .top)
    }

    // MARK: Reusable glass control

    private func glassIcon(systemName: String,
                           label: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            glassIconLabel(systemName: systemName)
        }
        .accessibilityLabel(label)
    }

    private func glassIconLabel(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(YukimoColor.borderSoft, lineWidth: 0.5))
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(YukimoColor.textPrimary)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Scroll offset tracking

struct DetailsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
