//
//  AnimeWatchButton.swift
//  Rich primary CTA. Three contexts:
//   • Continue — "Продолжить · Серия N" with optional "Осталось 12:34".
//   • Start fresh — "Смотреть" + "Начать с 1 серии".
//   • Loading / Unavailable — disabled with informative copy.
//

import SwiftUI

enum AnimeWatchContext: Equatable {
    case loading
    case unavailable(reason: String)
    case startFresh(totalEpisodes: Int)
    /// Resume state — user has saved progress.
    ///   `resumeSeconds`: where in the episode they stopped (start point to
    ///   continue from, NOT remaining time). Subtitle reads "Серия N · С m:ss".
    case resume(displayNumber: Int, episodeName: String?, resumeSeconds: Double?)

    var title: String {
        switch self {
        case .loading:                    return "Готовим серии…"
        case .unavailable:                return "Недоступно"
        case .startFresh:                 return "Смотреть"
        case .resume:                     return "Продолжить просмотр"
        }
    }

    var subtitle: String? {
        switch self {
        case .loading:                    return nil
        case .unavailable(let r):         return r
        case .startFresh(let total):      return total > 1 ? "Начать с 1 серии" : nil
        case .resume(let n, let name, let resume):
            // "Серия N · Название · С m:ss" — episode name always shown
            // if available, timestamp tacked on when there's saved
            // playback progress. Truncated to 2 lines in the button.
            var parts: [String] = ["Серия \(n)"]
            if let name, !name.isEmpty {
                parts.append(name)
            }
            if let resume, resume > 5 {
                let total = Int(resume)
                let min = total / 60
                let sec = total % 60
                parts.append("С \(min):\(String(format: "%02d", sec))")
            }
            return parts.joined(separator: " · ")
        }
    }

    var isDisabled: Bool {
        switch self {
        case .loading, .unavailable: return true
        default: return false
        }
    }
}

struct AnimeWatchButton: View {
    let context: AnimeWatchContext
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let subtitle = context.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, YukimoSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(coralGradient,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 0.8))
            .yukimoShadow(YukimoShadow.glow)
            .opacity(context.isDisabled ? 0.55 : 1)
        }
        .buttonStyle(WatchPressStyle())
        .disabled(context.isDisabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: context)
        .accessibilityLabel(accessibilityLabel)
    }

    private var coralGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFF8A7E), Color(hex: 0xFF5566)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var accessibilityLabel: String {
        switch context {
        case .resume(let n, _, _):
            return "Продолжить просмотр, серия \(n)"
        case .startFresh:
            return "Смотреть, начать с первой серии"
        case .loading:
            return "Загружаем серии"
        case .unavailable(let r):
            return r
        }
    }
}

private struct WatchPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(YukimoMotion.springSoft, value: configuration.isPressed)
    }
}
