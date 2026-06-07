//
//  RatingSheet.swift
//  iOS-canonical "tap to rate" sheet — mirrors Apple Store and Apple
//  Podcasts patterns. Five large stars, optional "Remove rating" button.
//

import SwiftUI

struct RatingSheet: View {
    /// Currently saved rating, 0..5 (0 = not voted).
    let currentVote: Int
    /// Aggregate average shown as a hint above the stars.
    let aggregate: Double
    let aggregateCount: Int
    /// Called with the new value (0 to remove, 1...5 otherwise).
    let onRate: (Int) async -> Void

    @State private var preview: Int = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: YukimoSpacing.xl) {
            handle
            header

            stars

            // Lightweight hint of what the chosen rating means.
            if preview > 0 {
                Text(meaning(for: preview))
                    .font(YukimoTypography.subhead)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }

            actionRow

            Spacer(minLength: 0)
        }
        .padding(.horizontal, YukimoSpacing.xl)
        .padding(.top, YukimoSpacing.md)
        .padding(.bottom, YukimoSpacing.xxl)
        .background(YukimoColor.background.ignoresSafeArea())
        .onAppear { preview = currentVote }
    }

    private var handle: some View {
        Capsule()
            .fill(YukimoColor.borderSoft)
            .frame(width: 38, height: 5)
            .padding(.bottom, YukimoSpacing.sm)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(currentVote > 0 ? "Ваша оценка" : "Оцените тайтл")
                .font(YukimoTypography.title2)
                .foregroundStyle(YukimoColor.textPrimary)

            if aggregate > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 11, weight: .bold))
                    Text(String(format: "%.1f", aggregate))
                        .font(YukimoTypography.subhead)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("· \(aggregateCountText)")
                        .font(YukimoTypography.subhead)
                        .foregroundStyle(YukimoColor.textTertiary)
                }
            }
        }
    }

    private var stars: some View {
        HStack(spacing: YukimoSpacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(YukimoMotion.springSoft) { preview = star }
                } label: {
                    Image(systemName: star <= preview ? "star.fill" : "star")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(star <= preview ? Color.orange : YukimoColor.borderSoft)
                        .symbolEffect(.bounce, value: preview)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, YukimoSpacing.md)
    }

    private var actionRow: some View {
        VStack(spacing: YukimoSpacing.sm) {
            Button {
                let chosen = preview
                Task {
                    await onRate(chosen)
                    dismiss()
                }
            } label: {
                Text(currentVote == 0 ? "Поставить оценку" : "Сохранить")
            }
            .buttonStyle(.yukimoPrimary)
            .disabled(preview == 0)
            .opacity(preview == 0 ? 0.55 : 1)

            if currentVote > 0 {
                Button {
                    Task {
                        await onRate(0)
                        dismiss()
                    }
                } label: {
                    Text("Убрать оценку")
                        .foregroundStyle(YukimoColor.danger)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            }
        }
    }

    private var aggregateCountText: String {
        if aggregateCount >= 1000 {
            return "\(aggregateCount / 1000)k оценок"
        }
        return "\(aggregateCount) оценок"
    }

    private func meaning(for stars: Int) -> String {
        switch stars {
        case 1: return "Не понравилось"
        case 2: return "Так себе"
        case 3: return "Нормально"
        case 4: return "Понравилось"
        case 5: return "Шедевр"
        default: return ""
        }
    }
}
