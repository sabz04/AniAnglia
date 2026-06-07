//
//  SplashView.swift
//  First-launch loading screen — coral animated text + soft spinner.
//  Replaces the earlier generated app-icon mark on purpose: the icon
//  is the launch image (static), the splash is what shows once the app
//  is alive and ready to animate.
//

import SwiftUI

struct SplashView: View {
    @State private var appeared = false
    @State private var dotPhase: Int = 0
    @State private var sparkleAngle: Double = 0
    @State private var ringSpin: Double = 0

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: YukimoSpacing.xl) {
                title
                loader
                statusLine
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.92)
            .animation(.spring(response: 0.7, dampingFraction: 0.78), value: appeared)
        }
        .onAppear {
            appeared = true
            startAmbientAnimations()
        }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            YukimoColor.background.ignoresSafeArea()

            // Wide coral halo
            RadialGradient(
                colors: [Color(hex: 0xFFB0AB).opacity(0.45),
                         Color(hex: 0xFF8AA0).opacity(0.20),
                         .clear],
                center: .center, startRadius: 60, endRadius: 360)
                .blur(radius: 14)
                .ignoresSafeArea()

            // Floating sparkles — minimal anime touch without a kawaii face.
            ForEach(0..<6, id: \.self) { i in
                let angle = Angle(degrees: sparkleAngle + Double(i) * 60)
                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: 0xFF8AA0).opacity(0.55))
                    .offset(x: cos(angle.radians) * 130,
                            y: sin(angle.radians) * 130)
            }
            .opacity(appeared ? 0.85 : 0)
        }
    }

    // MARK: Title

    private var title: some View {
        VStack(spacing: 4) {
            Text("Yukimo")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0xFF8A7E), Color(hex: 0xFF5566)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .tracking(1.2)
                .shadow(color: Color(hex: 0xFF5566).opacity(0.25), radius: 10, y: 4)

            Text("Аниме без лишнего")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(YukimoColor.textSecondary)
                .textCase(.uppercase)
                .tracking(3)
        }
    }

    // MARK: Loader — coral rotating ring + soft center dot

    private var loaderGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: 0xFFB0AB).opacity(0.10),
                Color(hex: 0xFF8AA0),
                Color(hex: 0xFF5566),
                Color(hex: 0xFF8AA0).opacity(0.10),
            ],
            center: .center)
    }

    private var loader: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.72)
                .stroke(loaderGradient,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(ringSpin))

            Circle()
                .fill(YukimoColor.primaryCoral.opacity(0.18))
                .frame(width: 18, height: 18)
                .scaleEffect(appeared ? 1.05 : 0.6)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                           value: appeared)
        }
    }

    // MARK: Status line — "Загружаем" with animated dots

    private var statusLine: some View {
        HStack(spacing: 4) {
            Text("Загружаем")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(YukimoColor.textPrimary)
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(YukimoColor.primaryCoral)
                        .frame(width: 5, height: 5)
                        .opacity(dotPhase == i ? 1 : 0.25)
                        .scaleEffect(dotPhase == i ? 1.2 : 0.85)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: dotPhase)
        }
    }

    // MARK: Ambient animations

    private func startAmbientAnimations() {
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            ringSpin = 360
        }
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            sparkleAngle = 360
        }
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
    }
}

// MARK: - Stylised logo mark (kept for LoginView / MainPlaceholderView)
//
// The splash screen above intentionally does NOT use this mark — the
// user asked to drop the generated kitsune-face icon from first launch.
// Other surfaces (login header, "Coming soon" placeholders) still need
// a graphical mark, so the implementation stays here.

struct YukimoLogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFB0AB), Color(hex: 0xFF6B66)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5))

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .offset(sparkleOffset(i))
                }

                Triangle()
                    .fill(Color.white)
                    .frame(width: 28, height: 36)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -28, y: -28)
                Triangle()
                    .fill(Color.white)
                    .frame(width: 28, height: 36)
                    .rotationEffect(.degrees(12))
                    .offset(x: 28, y: -28)

                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .offset(y: 6)

                HStack(spacing: 14) {
                    Circle().fill(Color(hex: 0xFF5E6B)).frame(width: 8, height: 8)
                    Circle().fill(Color(hex: 0xFF5E6B)).frame(width: 8, height: 8)
                }
                .offset(y: 6)
            }
        }
    }

    private func sparkleOffset(_ i: Int) -> CGSize {
        switch i {
        case 0: return .init(width: -44, height: -30)
        case 1: return .init(width:  44, height: -30)
        case 2: return .init(width: -36, height:  30)
        default: return .init(width:  40, height:  26)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
