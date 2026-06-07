//
//  ScreenshotsBlock.swift
//  Horizontal carousel of release screenshots that open into a paged
//  fullscreen viewer. Renders nothing when there are no screenshots.
//

import SwiftUI

struct ScreenshotsBlock: View {
    let urls: [String]
    @State private var viewerStartIndex: ViewerStart?

    private struct ViewerStart: Identifiable {
        let index: Int
        var id: Int { index }
    }

    var body: some View {
        if urls.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: YukimoSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Скриншоты", systemImage: "photo.stack")
                        .font(YukimoTypography.title3)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Spacer()
                    Text("\(urls.count)")
                        .font(YukimoTypography.subhead)
                        .foregroundStyle(YukimoColor.textTertiary)
                }
                .padding(.horizontal, YukimoSpacing.screenPadding)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: YukimoSpacing.sm) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                            Button {
                                viewerStartIndex = ViewerStart(index: idx)
                            } label: {
                                thumbnail(url: url, index: idx)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, YukimoSpacing.screenPadding)
                }
            }
            .fullScreenCover(item: $viewerStartIndex) { start in
                ScreenshotsViewer(urls: urls, startIndex: start.index)
            }
        }
    }

    private func thumbnail(url: String, index: Int) -> some View {
        ZStack(alignment: .bottomTrailing) {
            YukimoAsyncImage(urlString: url)
                .aspectRatio(16.0/9.0, contentMode: .fill)
                .frame(width: 220, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                        .stroke(YukimoColor.borderSoft, lineWidth: 0.5))

            // Number badge — gives the user a sense of order.
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(6)
        }
    }
}

struct ScreenshotsViewer: View {
    let urls: [String]
    let startIndex: Int

    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [String], startIndex: Int) {
        self.urls = urls
        self.startIndex = startIndex
        self._index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                    YukimoAsyncImage(urlString: url)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(idx)
                        .contentShape(Rectangle())
                        .onTapGesture { dismiss() }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.4), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, YukimoSpacing.md)
                .padding(.trailing, YukimoSpacing.md)

                Spacer()

                Text("\(index + 1) / \(urls.count)")
                    .font(YukimoTypography.subhead)
                    .foregroundStyle(.white)
                    .padding(.horizontal, YukimoSpacing.md)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.bottom, YukimoSpacing.xxl)
            }
        }
        .statusBarHidden(true)
        .preferredColorScheme(.dark)
    }
}
