//
//  YukimoAsyncImage.swift
//  Cached async image. SwiftUI's AsyncImage doesn't cache between
//  view recreations, which makes carousels re-fetch every poster on
//  every scroll. We share a memory+disk URLCache and a tiny in-process
//  Image cache to keep posters smooth.
//

import SwiftUI
import UIKit

private final class YukimoImageCache {
    static let shared = YukimoImageCache()
    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession

    init() {
        memory.countLimit = 256
        let cache = URLCache(memoryCapacity: 32 * 1024 * 1024,
                             diskCapacity: 256 * 1024 * 1024,
                             diskPath: "yukimo.images")
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = cache
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        cfg.timeoutIntervalForRequest = 20
        session = URLSession(configuration: cfg)
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString
        if let cached = memory.object(forKey: key) { return cached }
        do {
            let (data, _) = try await session.data(from: url)
            guard let img = UIImage(data: data) else { return nil }
            memory.setObject(img, forKey: key)
            return img
        } catch {
            return nil
        }
    }

    func invalidate(url: URL) {
        let key = url.absoluteString as NSString
        memory.removeObject(forKey: key)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session.configuration.urlCache?.removeCachedResponse(for: request)
    }
}

/// Top-level helper for invalidating cached avatar/poster art after the user
/// updates it server-side. Lives outside the generic `YukimoAsyncImage` so it
/// can be called without specifying placeholder/failure types.
enum YukimoImageCacheUtil {
    static func invalidate(for urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        YukimoImageCache.shared.invalidate(url: url)
    }
}

struct YukimoAsyncImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    var transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.25))
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure

    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .transition(.opacity)
            } else if didLoad {
                failure()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { didLoad = true; return }
            if let cached = await YukimoImageCache.shared.image(for: url) {
                withTransaction(transaction) { self.image = cached }
            }
            didLoad = true
        }
    }
}

extension YukimoAsyncImage where Placeholder == YukimoImagePlaceholder, Failure == YukimoImagePlaceholder {
    init(url: URL?) {
        self.init(url: url, placeholder: { YukimoImagePlaceholder(isFailure: false) },
                            failure:     { YukimoImagePlaceholder(isFailure: true)  })
    }

    init(urlString: String?) {
        let url = (urlString?.isEmpty ?? true) ? nil : URL(string: urlString!)
        self.init(url: url)
    }
}

struct YukimoImagePlaceholder: View {
    var isFailure: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [YukimoColor.softPink, YukimoColor.palePink],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            if isFailure {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(YukimoColor.textTertiary)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(YukimoColor.primaryCoralLight)
                    .opacity(0.6)
            }
        }
    }
}
