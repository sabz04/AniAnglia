//
//  ProfileDistributionChart.swift
//  Minimal donut + ultra-clean legend (no card chrome, no big icons).
//

import SwiftUI
import Charts

struct ProfileDistributionChart: View {
    let profile: ProfileDTO

    private struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    private var slices: [Slice] {
        [
            Slice(label: "Смотрю",      count: profile.watchingCount, color: YukimoColor.primaryCoral),
            Slice(label: "В планах",    count: profile.planCount,     color: YukimoColor.accentSky),
            Slice(label: "Просмотрено", count: profile.watchedCount,  color: YukimoColor.success),
            Slice(label: "Отложено",    count: profile.holdOnCount,   color: YukimoColor.warning),
            Slice(label: "Брошено",     count: profile.droppedCount,  color: YukimoColor.danger),
            Slice(label: "Любимое",     count: profile.favoriteCount, color: YukimoColor.accentLavender),
        ].filter { $0.count > 0 }
    }

    private var total: Int { slices.reduce(0) { $0 + $1.count } }

    var body: some View {
        if total == 0 {
            // Brand-coloured empty state instead of a card.
            VStack(spacing: YukimoSpacing.sm) {
                Image(systemName: "chart.pie")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(YukimoColor.primaryCoralLight)
                Text("Пока нет статистики")
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, YukimoSpacing.huge)
        } else {
            VStack(spacing: YukimoSpacing.xl) {
                donut
                legend
            }
        }
    }

    // MARK: Donut

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Titles", slice.count),
                innerRadius: .ratio(0.66),
                angularInset: 2)
                .cornerRadius(6)
                .foregroundStyle(slice.color)
        }
        .frame(height: 240)
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 2) {
                Text("\(total)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(YukimoColor.textPrimary)
                Text("всего")
                    .font(YukimoTypography.caption)
                    .foregroundStyle(YukimoColor.textTertiary)
            }
        }
    }

    // MARK: Legend — colored dot + label + percent

    private var legend: some View {
        VStack(spacing: 12) {
            ForEach(slices) { slice in
                HStack(spacing: YukimoSpacing.md) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Spacer()
                    Text(percentLabel(for: slice.count))
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                        .monospacedDigit()
                }
            }
        }
    }

    private func percentLabel(for count: Int) -> String {
        guard total > 0 else { return "" }
        let percent = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", percent)
    }
}
