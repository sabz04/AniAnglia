//
//  DetailsActionRow.swift
//  Primary CTA + secondary icon row. Bookmark and Rate reflect the
//  *optimistic* values passed by the view-model so the UI updates the
//  instant the user taps, without waiting for the server reload.
//

import SwiftUI

struct DetailsActionRow: View {
    let release: ReleaseDTO
    let currentListStatus: Int        // 0..5
    let currentVote: Int              // 0..5
    let watchTitle: String
    let watchDisabled: Bool
    let onWatch: () -> Void
    let onPickList: (YukimoListStatus) -> Void
    let onToggleFavorite: () -> Void
    let onRate: () -> Void

    private var inList: Bool { currentListStatus != 0 }

    private var listLabel: String {
        switch currentListStatus {
        case 1: return "Смотрю"
        case 2: return "В планах"
        case 3: return "Просмотрено"
        case 4: return "Отложено"
        case 5: return "Брошено"
        default: return "В список"
        }
    }

    private var listIcon: String {
        switch currentListStatus {
        case 1: return "play.fill"
        case 2: return "bookmark.fill"
        case 3: return "checkmark.circle.fill"
        case 4: return "pause.circle.fill"
        case 5: return "xmark.circle.fill"
        default: return "bookmark"
        }
    }

    var body: some View {
        VStack(spacing: YukimoSpacing.md) {
            Button(action: onWatch) {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(watchTitle)
                }
            }
            .buttonStyle(.yukimoPrimary)
            .disabled(watchDisabled)

            HStack(spacing: YukimoSpacing.md) {
                Menu {
                    Section("В список") {
                        Button(action: { onPickList(.watching) }) {
                            Label("Смотрю", systemImage: currentListStatus == 1 ? "checkmark" : "play.fill")
                        }
                        Button(action: { onPickList(.plan) }) {
                            Label("В планах", systemImage: currentListStatus == 2 ? "checkmark" : "bookmark.fill")
                        }
                        Button(action: { onPickList(.watched) }) {
                            Label("Просмотрено", systemImage: currentListStatus == 3 ? "checkmark" : "checkmark.circle.fill")
                        }
                        Button(action: { onPickList(.holdOn) }) {
                            Label("Отложено", systemImage: currentListStatus == 4 ? "checkmark" : "pause.circle.fill")
                        }
                        Button(action: { onPickList(.dropped) }) {
                            Label("Брошено", systemImage: currentListStatus == 5 ? "checkmark" : "xmark.circle.fill")
                        }
                    }
                    if inList {
                        Section {
                            Button("Удалить из списка", role: .destructive) {
                                onPickList(.none)
                            }
                        }
                    }
                } label: {
                    iconLabel(
                        systemImage: listIcon,
                        label: listLabel,
                        active: inList)
                }
                .menuStyle(.button)

                Button(action: onRate) {
                    iconLabel(
                        systemImage: currentVote > 0 ? "star.fill" : "star",
                        label: currentVote > 0 ? "★ \(currentVote)/5" : "Оценить",
                        active: currentVote > 0,
                        accent: currentVote > 0 ? .orange : nil)
                }
                .buttonStyle(.plain)

                Button(action: onToggleFavorite) {
                    iconLabel(
                        systemImage: release.isFavorite ? "heart.fill" : "heart",
                        label: release.isFavorite ? "В избранном" : "Любимое",
                        active: release.isFavorite)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    /// Three-cell secondary action button — icon + caption inside a
    /// rounded chip. `accent` overrides the default coral tint (used to
    /// switch the Rate cell to yellow when the user has voted).
    private func iconLabel(systemImage: String,
                           label: String,
                           active: Bool,
                           accent: Color? = nil) -> some View {
        let tint: Color = accent ?? YukimoColor.primaryCoral
        let bg: Color = active
            ? (accent != nil ? tint.opacity(0.18) : YukimoColor.softPink)
            : YukimoColor.surface
        let strokeColor: Color = active ? tint.opacity(0.45) : YukimoColor.borderSoft

        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(bg)
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(active ? tint : YukimoColor.textPrimary)
                    .symbolEffect(.bounce, value: active)
            }
            .frame(height: 48)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(strokeColor, lineWidth: active ? 1 : 0.5))

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(active ? tint : YukimoColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
