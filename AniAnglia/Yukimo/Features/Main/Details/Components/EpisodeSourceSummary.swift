//
//  EpisodeSourceSummary.swift
//  Tappable summary card placed above the episode list. Shows which
//  source (озвучка) the user is currently viewing + episode count.
//  Tapping opens the source picker sheet. If there are multiple types,
//  a second compact row underneath surfaces the type as well.
//

import SwiftUI

struct EpisodeSourceSummary: View {
    let typeName: String?
    let typeWorkers: String?
    let sourceName: String
    let sourceEpisodeCount: Int
    let canChangeSource: Bool
    let canChangeType: Bool
    let onTapSource: () -> Void
    let onTapType: () -> Void

    var body: some View {
        VStack(spacing: YukimoSpacing.sm) {
            Button(action: onTapSource) {
                HStack(spacing: YukimoSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(YukimoColor.softPink)
                            .frame(width: 38, height: 38)
                        Image(systemName: "waveform")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(YukimoColor.primaryCoralDark)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Озвучка")
                            .font(YukimoTypography.caption)
                            .foregroundStyle(YukimoColor.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.7)
                        Text(sourceName)
                            .font(YukimoTypography.bodyEmph)
                            .foregroundStyle(YukimoColor.textPrimary)
                            .lineLimit(1)
                        Text("\(sourceEpisodeCount) серий")
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if canChangeSource {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(YukimoColor.textTertiary)
                    }
                }
                .padding(YukimoSpacing.md)
                .background(YukimoColor.surface,
                            in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                        .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(!canChangeSource)
            .accessibilityLabel("Выбрать озвучку. Сейчас \(sourceName).")

            if let typeName, canChangeType {
                Button(action: onTapType) {
                    HStack(spacing: YukimoSpacing.sm) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(YukimoColor.primaryCoral)
                        Text("Тип: ")
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textTertiary)
                        + Text(typeName)
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textPrimary)
                        if let workers = typeWorkers, !workers.isEmpty {
                            Text("·")
                                .font(YukimoTypography.footnote)
                                .foregroundStyle(YukimoColor.textTertiary)
                            Text(workers)
                                .font(YukimoTypography.footnote)
                                .foregroundStyle(YukimoColor.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(YukimoColor.textTertiary)
                    }
                    .padding(.horizontal, YukimoSpacing.md)
                    .padding(.vertical, 8)
                    .background(YukimoColor.softPink.opacity(0.5),
                                in: RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выбрать тип. Сейчас \(typeName).")
            }
        }
    }
}
