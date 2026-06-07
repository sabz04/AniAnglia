//
//  YukimoPlayerView.swift
//  Custom AVPlayerLayer-based player with full SwiftUI control surface:
//  top bar, center play/pause, scrubber, skip ±10s, episode prev/next,
//  source/episodes/quality bottom sheets, and auto-hiding controls.
//

import SwiftUI
import AVKit
import AVFoundation

struct YukimoPlayerView: View {
    @State private var model: YukimoPlayerModel
    @State private var controlsVisible: Bool = true
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var activeSheet: PlayerSheet? = nil
    @State private var pipController: AVPictureInPictureController? = nil
    @State private var didFirstAppear: Bool = false
    /// Floating "−10 / +10" badge that pulses for ~700 ms after a
    /// double-tap on the left/right side of the player.
    @State private var doubleTapBadge: DoubleTapBadge? = nil

    private enum DoubleTapBadge: Equatable {
        case left, right
        var systemImage: String { self == .left ? "gobackward.10" : "goforward.10" }
        var alignment: Alignment { self == .left ? .leading : .trailing }
        var label: String { self == .left ? "−10 c" : "+10 c" }
    }

    @Environment(\.dismiss) private var dismiss

    enum PlayerSheet: String, Identifiable {
        case source     // EpisodeSource = the player engine (Kodik / Sibnet / …)
        case type       // EpisodeType   = the dubbing studio (AniLibria / AniDub / …)
        case episodes
        case quality
        var id: String { rawValue }
    }

    init(releaseID: Int64,
         releaseTitle: String,
         initialTypeID: Int64,
         initialSourceID: Int64,
         initialPosition: Int,
         initialEpisodes: [EpisodeDTO],
         initialTypes: [EpisodeTypeDTO],
         initialSources: [EpisodeSourceDTO],
         forcedLocalManifest: URL? = nil,
         offlineEntries: [YukimoDownloadsManager.Entry] = []) {
        self._model = State(initialValue: YukimoPlayerModel(
            releaseID: releaseID,
            releaseTitle: releaseTitle,
            types: initialTypes,
            sources: initialSources,
            episodes: initialEpisodes,
            initialTypeID: initialTypeID,
            initialSourceID: initialSourceID,
            initialPosition: initialPosition,
            forcedLocalManifest: forcedLocalManifest,
            offlineEntries: offlineEntries))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerHost(player: model.player) { ctrl in
                pipController = ctrl
            }
                .ignoresSafeArea()

            // Two transparent zones (left/right halves) — single tap
            // toggles controls instantly, double tap skips ±10s like
            // YouTube / Netflix. SwiftUI handles the 2-tap-wins-over-1
            // delay; on the playback layer the latency is invisible.
            HStack(spacing: 0) {
                tapZone(side: .left)
                tapZone(side: .right)
            }
            .ignoresSafeArea()

            // Skip-feedback badge — fades in on double tap, holds
            // briefly, fades out. Independent of `controlsVisible`.
            if let badge = doubleTapBadge {
                doubleTapBadgeView(badge)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            // Controls always rendered when `controlsVisible` — even on
            // error/loading — so the user can still reach the bottom
            // deck pickers (Плеер / Озвучка / Серии / Качество). The
            // center slot swaps between play-pause, loading spinner,
            // and the compact error banner.
            if controlsVisible {
                controlsScrim
                    .transition(.opacity)
                    .allowsHitTesting(false)        // tap passes through

                // NOTE: no separate "tap to collapse" layer here. The
                // tap zones below the scrim handle single-tap (toggle
                // controls) and double-tap (skip ±10s) — putting another
                // single-tap layer on top would swallow the second tap
                // before the zone could register it.

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    centerStateSlot
                    Spacer()
                    bottomDeck
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .opacity(didFirstAppear ? 1 : 0)   // soft fade-in on appear
        .animation(.easeOut(duration: 0.35), value: didFirstAppear)
        .task {
            // Rotate to landscape when the player opens, restore portrait on close.
            YukimoOrientationLock.shared.setLandscape()
            model.configure()
            await model.loadCurrentEpisode()
            scheduleAutoHide()
        }
        .onAppear { didFirstAppear = true }
        .onDisappear { didFirstAppear = false }
        .onDisappear {
            YukimoOrientationLock.shared.setPortrait()
            model.teardown()
        }
        .onChange(of: model.error) { _, newError in
            // When an error fires mid-playback the controls may have been
            // auto-hidden — bring them back so the user can reach the
            // Плеер / Озвучка pickers without tapping.
            if newError != nil {
                hideTask?.cancel()
                withAnimation(YukimoMotion.fast) { controlsVisible = true }
            }
        }
        .onChange(of: model.shouldDismissPlayer) { _, shouldDismiss in
            // Set when the user unmarks the currently-playing episode
            // from the sheet's context menu.
            if shouldDismiss { dismiss() }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(YukimoColor.background)
        }
    }

    // MARK: Tap zones — single tap toggles controls, double tap ±10s

    private func tapZone(side: DoubleTapBadge) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onTapGesture(count: 2) {
                handleDoubleTap(side: side)
            }
            .onTapGesture(count: 1) {
                toggleControls()
            }
    }

    private func handleDoubleTap(side: DoubleTapBadge) {
        let delta: Double = side == .left ? -10 : 10
        model.skip(by: delta)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            doubleTapBadge = side
        }
        // Auto-hide after a brief moment.
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                if doubleTapBadge == side { doubleTapBadge = nil }
            }
        }
    }

    private func doubleTapBadgeView(_ badge: DoubleTapBadge) -> some View {
        HStack {
            if badge == .right { Spacer() }
            VStack(spacing: 6) {
                Image(systemName: badge.systemImage)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text(badge.label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(.black.opacity(0.45), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 0.5))
            .padding(.horizontal, 80)
            if badge == .left { Spacer() }
        }
        .allowsHitTesting(false)
    }

    // Center slot — chooses between error banner / loading spinner /
    // play-pause controls, in that priority order.
    @ViewBuilder
    private var centerStateSlot: some View {
        if let err = model.error {
            errorBanner(err)
        } else if model.isLoading {
            loadingOverlay
        } else {
            centerPlayPause
        }
    }

    // MARK: Auto-hide

    private func toggleControls() {
        withAnimation(YukimoMotion.fast) { controlsVisible.toggle() }
        if controlsVisible { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        // Don't even arm the timer if an error overlay is showing — the
        // user needs the bottom deck (Плеер / Озвучка / Скачать) and
        // the close button to recover.
        guard model.error == nil else { return }
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled,
               model.isPlaying,
               !model.isScrubbing,
               model.error == nil {
                withAnimation(YukimoMotion.normal) { controlsVisible = false }
            }
        }
    }

    private func bumpAutoHide() { scheduleAutoHide() }

    // MARK: Scrim

    private var controlsScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.55), .black.opacity(0), .black.opacity(0.55)],
            startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .top, spacing: YukimoSpacing.sm) {
            glassIconButton(systemImage: "xmark") {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(model.releaseTitle)
                    .font(YukimoTypography.bodyEmph)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(episodeButtonLabel) · \(model.selectedSourceName)")
                    .font(YukimoTypography.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // PiP — pop the video out into a floating window.
            if let pip = pipController {
                glassIconButton(systemImage: "pip.enter") {
                    if pip.isPictureInPicturePossible {
                        pip.startPictureInPicture()
                        bumpAutoHide()
                    }
                }
            }
        }
        .padding(.horizontal, YukimoSpacing.md)
        .padding(.top, YukimoSpacing.sm)
    }

    // MARK: Center play/pause

    @ViewBuilder
    private var centerPlayPause: some View {
        HStack(spacing: 40) {
            glassIconButton(systemImage: "gobackward.10", size: 44, iconSize: 22) {
                model.skip(by: -10)
                bumpAutoHide()
            }
            .opacity(model.isLoading ? 0.4 : 1)
            .disabled(model.isLoading)

            Button {
                model.togglePlayPause()
                bumpAutoHide()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                        .frame(width: 86, height: 86)
                    if model.isBuffering {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.6)
                    } else {
                        Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: model.isPlaying ? 0 : 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(model.isLoading ? 0.4 : 1)
            .disabled(model.isLoading || model.isBuffering)

            glassIconButton(systemImage: "goforward.10", size: 44, iconSize: 22) {
                model.skip(by: 10)
                bumpAutoHide()
            }
            .opacity(model.isLoading ? 0.4 : 1)
            .disabled(model.isLoading)
        }
    }

    // MARK: Bottom deck

    private var bottomDeck: some View {
        VStack(spacing: YukimoSpacing.md) {
            scrubberBlock

            HStack(spacing: 12) {
                glassIconButton(
                    systemImage: "backward.end.fill",
                    enabled: model.hasPreviousEpisode
                ) {
                    Task { await model.previousEpisode(); bumpAutoHide() }
                }

                // Player engine (Kodik / Sibnet / …)
                pillButton(systemImage: "play.tv.fill", label: model.selectedSourceName) {
                    activeSheet = .source
                    bumpAutoHide()
                }

                // Dubbing studio (AniLibria / AniDub / …)
                pillButton(systemImage: "mic.fill", label: model.selectedTypeName) {
                    activeSheet = .type
                    bumpAutoHide()
                }

                pillButton(systemImage: "list.number", label: episodeButtonLabel) {
                    activeSheet = .episodes
                    bumpAutoHide()
                }

                pillButton(systemImage: "slider.horizontal.3", label: model.selectedQualityLabel) {
                    activeSheet = .quality
                    bumpAutoHide()
                }

                downloadButton

                glassIconButton(
                    systemImage: "forward.end.fill",
                    enabled: model.hasNextEpisode
                ) {
                    Task { await model.nextEpisode(); bumpAutoHide() }
                }
            }
            .padding(.horizontal, YukimoSpacing.md)
        }
        .padding(.bottom, YukimoSpacing.lg)
    }

    /// "Скачать" / progress / "Скачано" — best-effort HLS grab that runs
    /// alongside playback.
    private var downloadButton: some View {
        let downloads = YukimoDownloadsManager.shared
        let entry = downloads.entry(releaseID: model.releaseID,
                                    sourceID: model.selectedSourceID,
                                    position: model.currentPosition)
        let icon: String
        let label: String
        switch entry?.status {
        case .finished?:    icon = "checkmark.circle.fill"; label = "Скачано"
        case .downloading?: icon = "arrow.down.circle";    label = "\(Int(((entry?.progress ?? 0) * 100).rounded()))%"
        case .queued?:      icon = "hourglass";            label = "Жду"
        case .failed?:      icon = "exclamationmark.triangle.fill"; label = "Скачать"
        case .cancelled?, nil: icon = "arrow.down.circle"; label = "Скачать"
        }
        return pillButton(systemImage: icon, label: label) {
            startDownload()
            bumpAutoHide()
        }
    }

    private func startDownload() {
        guard let variant = model.selectedVariant else { return }
        let episodeName = model.currentEpisode?.name.isEmpty == false
            ? model.currentEpisode?.name : nil
        let displayNumber: Int = {
            if let idx = model.episodes.firstIndex(where: { $0.position == model.currentPosition }) {
                return idx + 1
            }
            return model.currentPosition + 1
        }()
        YukimoDownloadsManager.shared.start(
            releaseID: model.releaseID,
            sourceID: model.selectedSourceID,
            sourceName: model.selectedSourceName,
            typeID: model.selectedTypeID,
            typeName: model.selectedTypeName,
            position: model.currentPosition,
            displayNumber: displayNumber,
            releaseTitle: model.releaseTitle,
            episodeName: episodeName,
            manifestURL: variant.url,
            qualityLabel: model.selectedQualityLabel)
    }

    private var episodeButtonLabel: String {
        if let index = model.episodes.firstIndex(where: { $0.position == model.currentPosition }) {
            return "Серия \(index + 1)"
        }
        if model.currentEpisode != nil {
            return "Серия \(model.currentPosition + 1)"
        }
        return "Серии"
    }

    // MARK: Scrubber row

    private var scrubberBlock: some View {
        HStack(spacing: YukimoSpacing.md) {
            Text(formatPlaybackTime(model.currentTime))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 56, alignment: .leading)

            YukimoScrubber(
                current: model.currentTime,
                total: max(model.duration, 0),
                onScrubStart: {
                    model.isScrubbing = true
                    bumpAutoHide()
                },
                onScrubChange: { fraction in
                    model.currentTime = fraction * max(model.duration, 0)
                },
                onScrubEnd: { fraction in
                    model.seek(toFraction: fraction)
                    model.isScrubbing = false
                    bumpAutoHide()
                })

            Text(formatPlaybackTime(model.duration))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 56, alignment: .trailing)
        }
        .padding(.horizontal, YukimoSpacing.md)
    }

    // MARK: Sheets

    @ViewBuilder
    private func sheetContent(for sheet: PlayerSheet) -> some View {
        switch sheet {
        case .source:
            PlayerSourceSheet(model: model) { activeSheet = nil }
        case .type:
            PlayerTypeSheet(model: model) { activeSheet = nil }
        case .episodes:
            PlayerEpisodesSheet(model: model) { activeSheet = nil }
        case .quality:
            PlayerQualitySheet(model: model) { activeSheet = nil }
        }
    }

    // MARK: Loading / error overlays

    private var loadingOverlay: some View {
        VStack(spacing: YukimoSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.2)
            if let msg = model.loadingMessage {
                Text(msg)
                    .font(YukimoTypography.callout)
                    .foregroundStyle(.white)
            }
        }
        .padding(YukimoSpacing.xxl)
        .background(.black.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
    }

    /// Compact glass banner that sits in place of the play-pause button.
    /// Lets the user retry the same stream OR keep the bottom deck open
    /// so they can switch плеер / озвучку manually.
    private func errorBanner(_ raw: String) -> some View {
        let message = friendlyMessage(raw)
        return VStack(spacing: YukimoSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.orange)
                Text("Не удалось воспроизвести")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    bumpAutoHide()
                    await model.loadCurrentEpisode()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Повторить")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, YukimoSpacing.lg)
        .padding(.vertical, YukimoSpacing.md)
        .frame(maxWidth: 380)
        .background(.black.opacity(0.55),
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.6))
    }

    /// Translates the most common AVPlayer / NSURLSession failure strings
    /// into something the user can act on — "permission" / "forbidden"
    /// usually means Kodik's IP-bound CDN rejected the request, so we
    /// nudge them toward the picker row.
    private func friendlyMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("permission")
            || lower.contains("forbidden")
            || lower.contains("authentication") {
            return "Этот источник недоступен с вашей сети. Выберите другую озвучку или плеер на панели ниже."
        }
        if lower.contains("could not connect")
            || lower.contains("not connected to the internet")
            || lower.contains("offline") {
            return "Не удалось подключиться к серверу. Проверьте интернет или смените плеер ниже."
        }
        return raw
    }

    // MARK: Reusable glass controls

    private func glassIconButton(systemImage: String,
                                 size: CGFloat = 38,
                                 iconSize: CGFloat = 15,
                                 enabled: Bool = true,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.10))
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.8))
                    .frame(width: size, height: size)
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    private func pillButton(systemImage: String,
                            label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, YukimoSpacing.md)
            .padding(.vertical, 10)
            .background(.white.opacity(0.10), in: Capsule())
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Player sheets

private struct PlayerSourceSheet: View {
    let model: YukimoPlayerModel
    let onClose: () -> Void

    private var offlineSourceGroups: [(name: String, sourceID: Int64, count: Int)] {
        let groups = Dictionary(grouping: model.offlineEntries) { $0.sourceID }
        return groups.map { (sid, items) in
            (items.first?.sourceName ?? "Плеер", sid, items.count)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    if model.isOfflineMode {
                        ForEach(offlineSourceGroups, id: \.sourceID) { group in
                            offlineRow(name: group.name, sourceID: group.sourceID, count: group.count)
                        }
                    } else {
                        ForEach(model.episodeSources, id: \.sourceID) { s in
                            rowFor(s)
                        }
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Плеер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово", action: onClose)
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
    }

    private func offlineRow(name: String, sourceID: Int64, count: Int) -> some View {
        let isSelected = sourceID == model.selectedSourceID
        return Button {
            // Switch to an entry that matches this source — prefer same
            // current position, fall back to the first downloaded one.
            let candidates = model.offlineEntries.filter { $0.sourceID == sourceID }
            let target = candidates.first(where: { $0.position == model.currentPosition })
                ?? candidates.first
            guard let target else { return }
            Task {
                onClose()
                await model.switchToOfflineEntry(target)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("\(count) скачано")
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isSelected ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func rowFor(_ s: EpisodeSourceDTO) -> some View {
        let isSelected = s.sourceID == model.selectedSourceID
        return Button {
            Task {
                onClose()
                await model.switchSource(s.sourceID)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("\(s.episodesCount) серий")
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isSelected ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerTypeSheet: View {
    let model: YukimoPlayerModel
    let onClose: () -> Void

    private var offlineTypeGroups: [(name: String, typeID: Int64, count: Int)] {
        let groups = Dictionary(grouping: model.offlineEntries) { $0.typeID }
        return groups.map { (tid, items) in
            (items.first?.typeName ?? "Озвучка", tid, items.count)
        }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    if model.isOfflineMode {
                        ForEach(offlineTypeGroups, id: \.typeID) { group in
                            offlineRow(name: group.name, typeID: group.typeID, count: group.count)
                        }
                    } else {
                        ForEach(model.episodeTypes, id: \.typeID) { t in
                            rowFor(t)
                        }
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Озвучка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово", action: onClose)
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
    }

    private func offlineRow(name: String, typeID: Int64, count: Int) -> some View {
        let isSelected = typeID == model.selectedTypeID
        return Button {
            let candidates = model.offlineEntries.filter { $0.typeID == typeID }
            let target = candidates.first(where: { $0.position == model.currentPosition })
                ?? candidates.first
            guard let target else { return }
            Task {
                onClose()
                await model.switchToOfflineEntry(target)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("\(count) скачано")
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isSelected ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func rowFor(_ t: EpisodeTypeDTO) -> some View {
        let isSelected = t.typeID == model.selectedTypeID
        return Button {
            Task {
                onClose()
                await model.switchType(t.typeID)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                    if !t.workers.isEmpty {
                        Text(t.workers)
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textSecondary)
                            .lineLimit(2)
                    } else {
                        Text("\(t.episodesCount) серий")
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textSecondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isSelected ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isSelected ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isSelected ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }
}

private struct PlayerEpisodesSheet: View {
    let model: YukimoPlayerModel
    let onClose: () -> Void

    /// Guards the auto-scroll-to-current logic so opening the sheet,
    /// scrolling away manually, and coming back doesn't snap to current.
    @State private var didInitialScroll: Bool = false

    private let pageSize = 10

    @State private var initialized = false
    @State private var windowStart: Int = 0
    @State private var windowEnd: Int = 0   // inclusive

    /// Anchor row: current playing episode if known, otherwise the
    /// most recently watched (cross-source). The sheet opens with the
    /// anchor as the topmost row of the initial 10-episode window so
    /// the user lands exactly on "where they stopped".
    private var anchorIndex: Int {
        if let i = model.episodes.firstIndex(where: { $0.position == model.currentPosition }) {
            return i
        }
        let watched = YukimoWatchedStore.shared
        for i in stride(from: model.episodes.count - 1, through: 0, by: -1) {
            let pos = model.episodes[i].position
            if model.episodes[i].isWatched
                || watched.isWatched(releaseID: model.releaseID, position: pos) {
                return i
            }
        }
        return 0
    }

    private var canExpandUp: Bool   { windowStart > 0 }
    private var canExpandDown: Bool { windowEnd < model.episodes.count - 1 }

    var body: some View {
        NavigationStack {
            Group {
                if model.isOfflineMode {
                    offlineList
                } else {
                    onlineList
                }
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово", action: onClose)
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
    }

    /// Offline list — render `model.offlineEntries` straight, no
    /// pagination. Tap swaps the playing manifest.
    private var offlineList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    ForEach(Array(model.offlineEntries.enumerated()), id: \.offset) { idx, entry in
                        offlineRow(entry)
                            .id(idx)
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .onAppear { autoScrollIfNeeded(proxy: proxy, target: offlineAnchorIndex) }
        }
    }

    private var onlineList: some View {
        // No pagination — every episode is rendered straight away.
        // `LazyVStack` keeps the off-screen cost flat.
        //
        // Per-row refresh on long-press "unmark" is wired via `_ =
        // model.watchedToggleToken` INSIDE `rowFor` — that ties each row
        // to the trigger without putting `.id(token)` on the whole stack.
        // The latter rebuilds the entire LazyVStack on every bump and
        // ScrollViewReader's UIScrollView then restores contentOffset
        // proportionally → on a 1000+ episode list the user lands in
        // the middle instead of at the anchor.
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    ForEach(Array(model.episodes.enumerated()), id: \.element.position) { idx, ep in
                        rowFor(ep, displayNumber: idx + 1)
                            .id(ep.position)
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .task { await scrollOnlineAnchor(proxy: proxy) }
        }
    }

    /// Position to centre on when the sheet first appears. Online mode
    /// only — offline goes through `offlineAnchorEntryID`. Anchors on
    /// the user's actual progress (watched store / in-progress
    /// timestamp), not always on `currentPosition`.
    private func currentOnlineAnchor() -> Int? {
        guard !model.episodes.isEmpty else { return nil }
        let anchorPos = model.anchorPositionForSheet()
        print("[Yukimo.sheet] anchor: currentPosition=\(model.currentPosition) anchorPos=\(anchorPos) episodes.count=\(model.episodes.count) firstPos=\(model.episodes.first?.position ?? -1) lastPos=\(model.episodes.last?.position ?? -1)")
        return anchorPos
    }

    private var offlineAnchorIndex: Int? {
        guard !model.offlineEntries.isEmpty else { return nil }
        return model.offlineEntries.firstIndex {
            $0.position == model.currentPosition
                && $0.sourceID == model.selectedSourceID
        }
    }

    /// Online scroll: wait one runloop hop + 350 ms for the sheet's
    /// presentation animation and the LazyVStack to materialize a row
    /// window around the anchor, then jump straight to it. Single pass
    /// (no animation) — animated `scrollTo` over 1000+ rows is unreliable
    /// because LazyVStack doesn't know item heights ahead of time.
    private func scrollOnlineAnchor(proxy: ScrollViewProxy) async {
        guard !didInitialScroll else { return }
        didInitialScroll = true
        guard let anchorPos = currentOnlineAnchor() else { return }
        try? await Task.sleep(nanoseconds: 350_000_000)
        proxy.scrollTo(anchorPos, anchor: .center)
    }

    /// Offline list scrolls by index — entries are few and have stable
    /// `id` so a single pass after a short delay is enough.
    private func autoScrollIfNeeded(proxy: ScrollViewProxy, target: Int?) {
        guard !didInitialScroll, let target else { return }
        didInitialScroll = true
        proxy.scrollTo(target, anchor: .center)
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private var navigationTitle: String {
        if model.isOfflineMode {
            return "Скачано · \(model.offlineEntries.count)"
        }
        let total = model.episodes.count
        if total == 0 { return "Серии" }
        return "Серии · \(total)"
    }

    private func offlineRow(_ entry: YukimoDownloadsManager.Entry) -> some View {
        let isCurrent = entry.position == model.currentPosition
            && entry.sourceID == model.selectedSourceID
        return Button {
            Task {
                onClose()
                await model.switchToOfflineEntry(entry)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.success.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Text("\(entry.displayNumber)")
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Серия \(entry.displayNumber)")
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text(offlineMetaLine(entry))
                        .font(YukimoTypography.caption)
                        .foregroundStyle(YukimoColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isCurrent ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isCurrent ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isCurrent ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func offlineMetaLine(_ entry: YukimoDownloadsManager.Entry) -> String {
        var parts: [String] = ["Скачано"]
        if !entry.typeName.isEmpty   { parts.append(entry.typeName) }
        if !entry.qualityLabel.isEmpty { parts.append(entry.qualityLabel) }
        return parts.joined(separator: " · ")
    }

    // MARK: Pagination

    private func initializeWindowIfNeeded() {
        guard !initialized else { return }
        let count = model.episodes.count
        guard count > 0 else { return }
        initialized = true

        let anchor = anchorIndex
        if count <= pageSize {
            windowStart = 0
            windowEnd   = count - 1
            return
        }
        // Anchor at the top of the initial 10-row window. If anchor is
        // close to the end, shift back so we still render a full page.
        windowStart = anchor
        windowEnd   = min(count - 1, windowStart + pageSize - 1)
        if windowEnd - windowStart < pageSize - 1 {
            windowStart = max(0, windowEnd - pageSize + 1)
        }
    }

    private func expandUp(proxy: ScrollViewProxy) {
        let oldFirst = windowStart
        windowStart  = max(0, windowStart - pageSize)
        // Pin the visual position to the row that was at the top before
        // we prepended — without this the new rows push existing content
        // down and the user loses their place.
        DispatchQueue.main.async {
            proxy.scrollTo(oldFirst, anchor: .top)
        }
    }

    private func expandDown(proxy: ScrollViewProxy) {
        windowEnd = min(model.episodes.count - 1, windowEnd + pageSize)
    }

    private enum PaginationDirection { case up, down }

    private func paginationButton(direction: PaginationDirection,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: direction == .up ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                Text(direction == .up ? "Показать выше" : "Показать ниже")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(YukimoColor.primaryCoralDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(YukimoColor.softPink,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(YukimoColor.primaryCoral.opacity(0.3), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
    }

    private func rowFor(_ ep: EpisodeDTO, displayNumber: Int) -> some View {
        let isCurrent = ep.position == model.currentPosition
        // Reading `watchedToggleToken` ties this row to the @Observable
        // trigger bumped on toggle — without it, SwiftUI wouldn't know
        // the row needs to re-render after a long-press menu action.
        _ = model.watchedToggleToken
        // Watched resolution lives on the model so a local "unmark"
        // can defeat libanixart's sticky server-side `is_watched`.
        let isWatched = model.isEpisodeWatchedInPlayer(ep)
        let progress = YukimoProgressStore.shared.load(
            releaseID: model.releaseID,
            sourceID: model.selectedSourceID,
            position: ep.position)
        let progressFraction: Double = {
            guard let p = progress, p.duration > 0 else { return 0 }
            return min(1, max(0, p.seconds / p.duration))
        }()
        return Button {
            Task {
                onClose()
                await model.playEpisode(at: ep.position)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: YukimoSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isWatched ? YukimoColor.success.opacity(0.18) : YukimoColor.softPink)
                            .frame(width: 44, height: 44)
                        Text("\(displayNumber)")
                            .font(YukimoTypography.bodyEmph)
                            .foregroundStyle(isWatched ? YukimoColor.success : YukimoColor.primaryCoralDark)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Серия \(displayNumber)")
                            .font(YukimoTypography.body)
                            .foregroundStyle(YukimoColor.textPrimary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if ep.isFiller {
                                Text("Филлер")
                                    .font(YukimoTypography.caption)
                                    .foregroundStyle(YukimoColor.warning)
                            }
                            if isWatched {
                                Label("Просмотрено", systemImage: "checkmark")
                                    .font(YukimoTypography.caption)
                                    .foregroundStyle(YukimoColor.success)
                            } else if let p = progress, p.seconds > 5 {
                                Label("С \(formatPlaybackTime(p.seconds))", systemImage: "clock.arrow.circlepath")
                                    .font(YukimoTypography.caption)
                                    .foregroundStyle(YukimoColor.primaryCoral)
                            }
                        }
                    }
                    Spacer()
                    if isCurrent {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(YukimoColor.primaryCoral)
                    }
                }
                if progressFraction > 0 {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(YukimoColor.borderSoft)
                            Capsule()
                                .fill(YukimoColor.primaryCoral)
                                .frame(width: max(4, proxy.size.width * progressFraction))
                        }
                    }
                    .frame(height: 3)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isCurrent ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isCurrent ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isCurrent ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isWatched {
                Button {
                    model.setWatched(false, position: ep.position)
                } label: {
                    Label("Убрать из просмотренных", systemImage: "eye.slash")
                }
            } else {
                Button {
                    model.setWatched(true, position: ep.position)
                } label: {
                    Label("Отметить как просмотренное", systemImage: "checkmark.circle")
                }
            }
        }
    }
}

private struct PlayerQualitySheet: View {
    let model: YukimoPlayerModel
    let onClose: () -> Void

    /// Distinct quality labels across the currently downloaded entries
    /// for this anime. We also track the matching entry's IDs so the
    /// user can swap qualities (typically they download the same episode
    /// at different bitrates).
    private var offlineQualities: [(label: String, entries: [YukimoDownloadsManager.Entry])] {
        let groups = Dictionary(grouping: model.offlineEntries) {
            $0.qualityLabel.isEmpty ? "—" : $0.qualityLabel
        }
        return groups.map { (label, items) in
            (label, items.sorted { $0.displayNumber < $1.displayNumber })
        }.sorted { $0.label < $1.label }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: YukimoSpacing.sm) {
                    if model.isOfflineMode {
                        ForEach(offlineQualities, id: \.label) { group in
                            offlineRow(label: group.label, entries: group.entries)
                        }
                    } else {
                        ForEach(model.variants, id: \.quality) { v in
                            rowFor(v)
                        }
                    }
                }
                .padding(YukimoSpacing.screenPadding)
            }
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Качество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово", action: onClose)
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
        }
    }

    private func offlineRow(label: String,
                            entries: [YukimoDownloadsManager.Entry]) -> some View {
        let isCurrent = model.currentOfflineEntry?.qualityLabel == label
        return Button {
            // Prefer same episode at the requested quality.
            let target = entries.first(where: { $0.position == model.currentPosition })
                ?? entries.first
            guard let target else { return }
            Task {
                onClose()
                await model.switchToOfflineEntry(target)
            }
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(YukimoTypography.bodyEmph)
                        .foregroundStyle(YukimoColor.textPrimary)
                    Text("\(entries.count) скачано")
                        .font(YukimoTypography.footnote)
                        .foregroundStyle(YukimoColor.textSecondary)
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isCurrent ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isCurrent ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isCurrent ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }

    private func rowFor(_ v: StreamVariantDTO) -> some View {
        let isCurrent = model.selectedVariant?.quality == v.quality
        let label = v.height > 0 ? "\(v.height)p" : v.quality
        return Button {
            onClose()
            model.switchToVariant(v)
        } label: {
            HStack(spacing: YukimoSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 40, height: 40)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                }
                Text(label)
                    .font(YukimoTypography.bodyEmph)
                    .foregroundStyle(YukimoColor.textPrimary)
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(YukimoColor.primaryCoral)
                }
            }
            .padding(YukimoSpacing.md)
            .background(
                isCurrent ? YukimoColor.softPink.opacity(0.6) : YukimoColor.surface,
                in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(isCurrent ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: isCurrent ? 1.2 : 0.5))
        }
        .buttonStyle(.plain)
    }
}
