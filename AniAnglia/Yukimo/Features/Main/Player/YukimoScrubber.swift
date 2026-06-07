//
//  YukimoScrubber.swift
//  Custom playback scrubber with coral gradient and a fat thumb on drag.
//

import SwiftUI

struct YukimoScrubber: View {
    var current: Double
    let total: Double
    var onScrubStart: (() -> Void)? = nil
    var onScrubChange: ((Double) -> Void)? = nil
    var onScrubEnd: ((Double) -> Void)? = nil

    @State private var isDragging: Bool = false
    @State private var dragFraction: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fraction = isDragging ? dragFraction : computedFraction
            let fillWidth = max(0, min(width, width * fraction))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: isDragging ? 6 : 4)
                Capsule()
                    .fill(LinearGradient(
                        colors: [YukimoColor.primaryCoralLight, YukimoColor.primaryCoral],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: fillWidth, height: isDragging ? 6 : 4)

                Circle()
                    .fill(.white)
                    .frame(width: isDragging ? 18 : 14,
                           height: isDragging ? 18 : 14)
                    .overlay(
                        Circle().stroke(YukimoColor.primaryCoral, lineWidth: 2))
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .offset(x: fillWidth - (isDragging ? 9 : 7))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onScrubStart?()
                        }
                        let f = max(0, min(1, value.location.x / max(width, 1)))
                        dragFraction = f
                        onScrubChange?(f)
                    }
                    .onEnded { _ in
                        let f = dragFraction
                        isDragging = false
                        onScrubEnd?(f)
                    }
            )
        }
        .frame(height: 30)
    }

    private var computedFraction: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, current / total))
    }
}

func formatPlaybackTime(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "--:--" }
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
}
