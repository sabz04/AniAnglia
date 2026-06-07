//
//  FullTitleSheet.swift
//  Tap a truncated title in the hero → this sheet shows the full RU
//  + original variants without cramming them on the small hero text.
//

import SwiftUI

struct FullTitleSheet: View {
    let titleRu: String
    let titleOriginal: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: YukimoSpacing.lg) {
                    if !titleRu.isEmpty {
                        section(title: "Название",
                                value: titleRu,
                                primary: true)
                    }
                    if !titleOriginal.isEmpty && titleOriginal != titleRu {
                        section(title: "Оригинальное название",
                                value: titleOriginal,
                                primary: false)
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Название")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(YukimoColor.primaryCoral)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func section(title: String, value: String, primary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(YukimoTypography.caption)
                .foregroundStyle(YukimoColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(primary
                      ? .system(size: 24, weight: .bold, design: .rounded)
                      : .system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(primary ? YukimoColor.textPrimary : YukimoColor.textSecondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(YukimoSpacing.md)
        .background(YukimoColor.surface,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
    }
}
