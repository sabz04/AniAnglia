//
//  YukimoGradientBackground.swift
//  Aurora-style coral/pink/cream background used on auth screens.
//

import SwiftUI

struct YukimoGradientBackground: View {
    @Environment(\.colorScheme) private var scheme

    /// Optional drift animation for ambient feel.
    var animated: Bool = true

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            base
            blobs
        }
        .ignoresSafeArea()
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private var base: some View {
        Group {
            if scheme == .dark {
                LinearGradient(
                    colors: [Color(hex: 0x1B0F14), Color(hex: 0x2A1820), Color(hex: 0x3A1F2A)],
                    startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(
                    colors: [Color(hex: 0xFFF6F4), Color(hex: 0xFFE6E1), Color(hex: 0xFFD2CB)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    private var blobs: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                blob(color: Color(hex: 0xFFB0AB).opacity(scheme == .dark ? 0.25 : 0.55),
                     diameter: w * 1.0)
                    .offset(x: -w * 0.35 + phase * 18,
                            y: -h * 0.10 - phase * 16)
                blob(color: Color(hex: 0xFFD8DD).opacity(scheme == .dark ? 0.18 : 0.65),
                     diameter: w * 0.9)
                    .offset(x: w * 0.30 - phase * 14,
                            y: h * 0.18 + phase * 12)
                blob(color: Color(hex: 0xD9C6FF).opacity(scheme == .dark ? 0.18 : 0.35),
                     diameter: w * 0.7)
                    .offset(x: w * 0.05 + phase * 12,
                            y: h * 0.55 - phase * 10)
            }
            .blur(radius: 60)
        }
    }

    private func blob(color: Color, diameter: CGFloat) -> some View {
        Circle().fill(color).frame(width: diameter, height: diameter)
    }
}

#Preview {
    YukimoGradientBackground()
}
