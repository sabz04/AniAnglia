//
//  SourcePickerRow.swift
//  Replaces the cramped horizontal scroll of source/type pills with a
//  labeled "row" that shows the active selection and opens a sheet
//  with the full list (and any metadata: episode count, workers).
//

import SwiftUI

struct PickerRow: View {
    let label: String
    let systemImage: String
    let valueTitle: String
    let valueSubtitle: String?
    var disabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 36, height: 36)
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(YukimoTypography.caption)
                        .foregroundStyle(YukimoColor.textTertiary)
                    Text(valueTitle)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                        .lineLimit(1)
                    if let subtitle = valueSubtitle {
                        Text(subtitle)
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(YukimoColor.textTertiary)
            }
            .padding(.horizontal, YukimoSpacing.md)
            .padding(.vertical, YukimoSpacing.md)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

struct TypePickerSheet: View {
    let types: [EpisodeTypeDTO]
    let selectedID: Int64?
    let onSelect: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    ForEach(types, id: \.typeID) { t in
                        let isSelected = t.typeID == selectedID
                        Button {
                            onSelect(t.typeID)
                            dismiss()
                        } label: {
                            HStack(spacing: YukimoSpacing.md) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t.name)
                                        .font(YukimoTypography.bodyEmph)
                                        .foregroundStyle(YukimoColor.textPrimary)
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.rectangle")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("\(t.episodesCount) серий")
                                    }
                                    .font(YukimoTypography.footnote)
                                    .foregroundStyle(YukimoColor.textSecondary)
                                    if !t.workers.isEmpty {
                                        Text(t.workers)
                                            .font(YukimoTypography.footnote)
                                            .foregroundStyle(YukimoColor.textTertiary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(YukimoColor.primaryCoral)
                                }
                            }
                            .padding(YukimoSpacing.md)
                            .background(
                                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                                            lineWidth: isSelected ? 1.2 : 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Тип серий")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SourcePickerSheet: View {
    let sources: [EpisodeSourceDTO]
    let selectedID: Int64?
    let onSelect: (Int64) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    ForEach(sources, id: \.sourceID) { s in
                        let isSelected = s.sourceID == selectedID
                        Button {
                            onSelect(s.sourceID)
                            dismiss()
                        } label: {
                            HStack(spacing: YukimoSpacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(YukimoColor.softPink)
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "waveform")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(YukimoColor.primaryCoralDark)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name)
                                        .font(YukimoTypography.bodyEmph)
                                        .foregroundStyle(YukimoColor.textPrimary)
                                    Text("\(s.episodesCount) серий")
                                        .font(YukimoTypography.footnote)
                                        .foregroundStyle(YukimoColor.textSecondary)
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(YukimoColor.primaryCoral)
                                }
                            }
                            .padding(YukimoSpacing.md)
                            .background(
                                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                                            lineWidth: isSelected ? 1.2 : 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Озвучка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
