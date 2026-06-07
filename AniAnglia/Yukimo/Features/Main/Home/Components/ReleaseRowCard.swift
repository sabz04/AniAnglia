//
//  ReleaseRowCard.swift
//  Compact horizontal card: poster + title + rating + short description.
//  Used in Search and Library vertical lists.
//

import SwiftUI

struct ReleaseRowCard: View {
    let release: ReleaseDTO

    var body: some View {
        HStack(alignment: .top, spacing: YukimoSpacing.md) {
            poster

            VStack(alignment: .leading, spacing: 6) {
                Text(release.displayTitle)
                    .font(YukimoTypography.bodyEmph)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if release.grade > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", release.grade))
                            .font(YukimoTypography.subhead)
                            .foregroundStyle(YukimoColor.textPrimary)
                    }
                }

                if let snippet = descriptionSnippet {
                    Text(snippet)
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(YukimoSpacing.md)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
    }

    private var poster: some View {
        YukimoAsyncImage(urlString: release.imageURL)
            .aspectRatio(2.0/3.0, contentMode: .fill)
            .frame(width: 64, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous))
    }

    private var descriptionSnippet: String? {
        guard let raw = release.description_ else { return nil }
        let stripped = raw
            .replacingOccurrences(of: "<br>", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br/>", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "<br />", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&nbsp;", with: " ", options: .caseInsensitive)
            .replacingOccurrences(of: "&amp;", with: "&", options: .caseInsensitive)
            .replacingOccurrences(of: "&quot;", with: "\"", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}

extension ReleaseDTO {
    var displayTitle: String {
        if !titleRu.isEmpty { return titleRu }
        return titleOriginal
    }

    var statusLabel: String? {
        switch status {
        case .ongoing:  return "Онгоинг"
        case .finished: return "Завершено"
        case .upcoming: return "Анонс"
        default:        return nil
        }
    }

    var statusTint: Color {
        switch status {
        case .ongoing:  return YukimoColor.success
        case .finished: return YukimoColor.textTertiary
        case .upcoming: return YukimoColor.accentLavender
        default:        return YukimoColor.textTertiary
        }
    }

    var categoryLabel: String? {
        switch category {
        case .series:   return "ТВ Сериал"
        case .movies:   return "Фильм"
        case .ova:      return "OVA"
        default:        return nil
        }
    }

    var categoryIcon: String {
        switch category {
        case .series:   return "tv"
        case .movies:   return "film.fill"
        case .ova:      return "play.tv"
        default:        return "questionmark"
        }
    }

    /// Pretty Russian label for `listStatus` (the int stored on the DTO maps
    /// 1..5 to Watching..Dropped; 0 means not in any list).
    var listStatusLabel: String? {
        switch listStatus {
        case 1: return "Смотрю"
        case 2: return "В планах"
        case 3: return "Просмотрено"
        case 4: return "Отложено"
        case 5: return "Брошено"
        default: return nil
        }
    }

    var listStatusIcon: String {
        switch listStatus {
        case 1: return "play.fill"
        case 2: return "bookmark.fill"
        case 3: return "checkmark.circle.fill"
        case 4: return "pause.circle.fill"
        case 5: return "xmark.circle.fill"
        default: return "bookmark"
        }
    }
}
