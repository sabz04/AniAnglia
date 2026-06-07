//
//  AnimeSecondaryActionsRow.swift
//  Three pill-style cards in a row: List · Rate · Favorite. Each is a
//  white rounded card with a coral (or orange when rating) icon on the
//  left and the label on the right. Matches the design mockups.
//

import SwiftUI

struct AnimeSecondaryActionsRow: View {
    let release: ReleaseDTO
    let currentListStatus: Int        // 0..5
    let currentVote: Int              // 0..5
    let currentIsFavorite: Bool       // optimistic value (effectiveIsFavorite)
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
        HStack(spacing: YukimoSpacing.sm) {
            Menu {
                Section("В список") {
                    listMenuButton(.watching, "Смотрю",      "play.fill",            1)
                    listMenuButton(.plan,     "В планах",     "bookmark.fill",        2)
                    listMenuButton(.watched,  "Просмотрено",  "checkmark.circle.fill", 3)
                    listMenuButton(.holdOn,   "Отложено",     "pause.circle.fill",    4)
                    listMenuButton(.dropped,  "Брошено",      "xmark.circle.fill",    5)
                }
                if inList {
                    Section {
                        Button("Удалить из списка", role: .destructive) {
                            onPickList(.none)
                        }
                    }
                }
            } label: {
                cell(icon: listIcon,
                     label: listLabel,
                     active: inList,
                     accent: YukimoColor.primaryCoral)
            }
            .menuStyle(.button)
            .accessibilityLabel(accessibilityLabel(forList: currentListStatus))

            Button(action: onRate) {
                cell(icon: currentVote > 0 ? "star.fill" : "star",
                     label: currentVote > 0 ? "\(currentVote)/5" : "Оценить",
                     active: currentVote > 0,
                     accent: .orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(forVote: currentVote))

            Button(action: onToggleFavorite) {
                cell(icon: currentIsFavorite ? "heart.fill" : "heart",
                     label: "Любимое",
                     active: currentIsFavorite,
                     accent: YukimoColor.danger)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentIsFavorite ? "Убрать из избранного" : "Добавить в избранное")
        }
        .padding(.horizontal, YukimoSpacing.screenPadding)
    }

    // MARK: Menu row helper

    private func listMenuButton(_ status: YukimoListStatus,
                                _ label: String,
                                _ fallbackIcon: String,
                                _ marker: Int) -> some View {
        Button(action: { onPickList(status) }) {
            Label(label,
                  systemImage: currentListStatus == marker ? "checkmark" : fallbackIcon)
        }
    }

    // MARK: Horizontal cell (icon + label inline)

    private func cell(icon: String,
                      label: String,
                      active: Bool,
                      accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? accent : YukimoColor.textPrimary)
                .symbolEffect(.bounce, value: active)
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(YukimoColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 10)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(active ? accent.opacity(0.35) : YukimoColor.borderSoft,
                        lineWidth: active ? 1 : 0.6))
    }

    private func accessibilityLabel(forList status: Int) -> String {
        switch status {
        case 1: return "В списке: Смотрю"
        case 2: return "В списке: В планах"
        case 3: return "В списке: Просмотрено"
        case 4: return "В списке: Отложено"
        case 5: return "В списке: Брошено"
        default: return "Добавить в список"
        }
    }

    private func accessibilityLabel(forVote vote: Int) -> String {
        vote > 0 ? "Моя оценка \(vote) из 5. Изменить." : "Оценить аниме"
    }
}
