//
//  ProfileTabView.swift
//  Chart-driven profile screen with editable avatar. No stats grid — the
//  donut chart replaces all the redundant numbers.
//

import SwiftUI
import PhotosUI
import Observation

@Observable
@MainActor
final class ProfileTabViewModel {
    var profile: ProfileDTO?
    var isLoading: Bool = true
    var isUploadingAvatar: Bool = false
    var error: String?
    var avatarRefreshKey: UUID = UUID()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.profile = try await withCheckedThrowingContinuation { cont in
                ProfileBridge.shared().loadMyProfile { dto, err in
                    if let dto { cont.resume(returning: dto) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.profile", code: -1)) }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uploadAvatar(_ jpegData: Data) async {
        isUploadingAvatar = true
        error = nil
        defer { isUploadingAvatar = false }
        // Invalidate the in-process image cache for the current avatar URL so
        // any subsequent fetch hits the network.
        if let urlString = profile?.avatarURL {
            YukimoImageCacheUtil.invalidate(for: urlString)
        }
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                ProfileBridge.shared().editAvatar(jpegData: jpegData) { ok, err in
                    if ok { cont.resume() }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.profile", code: -1)) }
                }
            }
            avatarRefreshKey = UUID()
            await load()
            // Invalidate again in case the URL changed in the reloaded profile.
            if let urlString = profile?.avatarURL {
                YukimoImageCacheUtil.invalidate(for: urlString)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProfileTabView: View {
    @Environment(YukimoAppState.self) private var app
    @State private var vm = ProfileTabViewModel()
    @State private var photoPick: PhotosPickerItem?
    @State private var settingsVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                profileHeader(vm.profile)

                if let p = vm.profile {
                    ProfileDistributionChart(profile: p)
                        .padding(.horizontal, YukimoSpacing.screenPadding)
                } else if vm.isLoading {
                    chartSkeleton
                }

                if let error = vm.error {
                    YukimoErrorBanner(message: error)
                        .padding(.horizontal, YukimoSpacing.screenPadding)
                }

                Button("Выйти") {
                    app.logoutToOnboarding()
                }
                .buttonStyle(.yukimoSecondary)
                .padding(.horizontal, YukimoSpacing.screenPadding)

                Color.clear.frame(height: 60)
            }
            .padding(.top, YukimoSpacing.lg)
        }
        .background(YukimoColor.background.ignoresSafeArea())
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .onChange(of: photoPick) { _, new in
            guard let new else { return }
            Task { await handlePicked(new) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    settingsVisible = true
                } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
                .accessibilityLabel("Настройки")
            }
        }
        .sheet(isPresented: $settingsVisible) {
            SettingsView()
        }
    }

    // MARK: Header — avatar (PhotosPicker), name, optional status text

    private func profileHeader(_ profile: ProfileDTO?) -> some View {
        VStack(spacing: YukimoSpacing.md) {
            PhotosPicker(selection: $photoPick,
                         matching: .images,
                         photoLibrary: .shared()) {
                avatarStack(url: profile?.avatarURL)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Text(profile?.username ?? "Загрузка")
                .font(YukimoTypography.title)
                .foregroundStyle(YukimoColor.textPrimary)
                .redacted(reason: profile == nil ? .placeholder : [])

            if let status = profile?.statusText, !status.isEmpty {
                Text(status)
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, YukimoSpacing.xxl)
            }
        }
    }

    private func avatarStack(url: String?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            avatar(url: url)
                .id(vm.avatarRefreshKey)

            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                Image(systemName: vm.isUploadingAvatar ? "arrow.triangle.2.circlepath" : "pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(YukimoColor.primaryCoral)
                    .symbolEffect(.pulse, options: .repeating, isActive: vm.isUploadingAvatar)
            }
            .offset(x: 4, y: 4)
        }
    }

    @ViewBuilder
    private func avatar(url: String?) -> some View {
        if let url, !url.isEmpty {
            YukimoAsyncImage(urlString: url)
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                .overlay(Circle().stroke(YukimoColor.primaryCoral.opacity(0.4), lineWidth: 2))
                .yukimoShadow(YukimoShadow.soft)
                .overlay {
                    if vm.isUploadingAvatar {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }
        } else {
            ZStack {
                Circle().fill(YukimoColor.softPink)
                Image(systemName: "person.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(YukimoColor.primaryCoral)
                if vm.isUploadingAvatar {
                    Circle().fill(.black.opacity(0.35))
                    ProgressView().tint(.white)
                }
            }
            .frame(width: 112, height: 112)
            .overlay(Circle().stroke(YukimoColor.primaryCoral.opacity(0.4), lineWidth: 2))
        }
    }

    private var chartSkeleton: some View {
        RoundedRectangle(cornerRadius: YukimoRadius.lg, style: .continuous)
            .fill(YukimoColor.softPink.opacity(0.6))
            .frame(height: 380)
            .padding(.horizontal, YukimoSpacing.screenPadding)
            .redacted(reason: .placeholder)
            .shimmering()
    }

    // MARK: Photos → JPEG → upload

    private func handlePicked(_ item: PhotosPickerItem) async {
        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            vm.error = "Не удалось прочитать изображение"
            return
        }
        guard let image = UIImage(data: raw) else {
            vm.error = "Неподдерживаемый формат"
            return
        }
        guard let jpeg = downsizedJpeg(from: image, maxDimension: 1024, quality: 0.85) else {
            vm.error = "Не удалось закодировать JPEG"
            return
        }
        await vm.uploadAvatar(jpeg)
        photoPick = nil
    }

    private func downsizedJpeg(from image: UIImage,
                               maxDimension: CGFloat,
                               quality: CGFloat) -> Data? {
        let size = image.size
        let scaleFactor = min(1, maxDimension / max(size.width, size.height))
        if scaleFactor >= 1 {
            return image.jpegData(compressionQuality: quality)
        }
        let newSize = CGSize(width: size.width * scaleFactor,
                             height: size.height * scaleFactor)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
