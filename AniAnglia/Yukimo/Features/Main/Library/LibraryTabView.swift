//
//  LibraryTabView.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class LibraryViewModel {
    var status: YukimoListStatus = .watching
    var items: [ReleaseDTO] = []
    /// History tab is rendered from a local store — the backend's history
    /// endpoints (`get_history`, `history_search`) returned 0 items even
    /// for active accounts.
    var historyEntries: [YukimoHistoryStore.Entry] = []
    var isLoading: Bool = true
    var error: String?

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        print("[Yukimo.lib] vm.load start status=\(status.rawValue)")

        if status == .history {
            // Pure-local source of truth — populated whenever the user
            // taps "Смотреть" / "Продолжить" in AnimeDetails.
            self.historyEntries = YukimoHistoryStore.shared.all()
            self.items = []
            print("[Yukimo.lib] vm.load done historyEntries=\(historyEntries.count)")
            return
        }

        self.historyEntries = []
        do {
            self.items = try await withCheckedThrowingContinuation { cont in
                LibraryBridge.shared().loadList(status: status, sort: .descending, page: 0) { items, err in
                    if let items { cont.resume(returning: items) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.library", code: -1)) }
                }
            }
            print("[Yukimo.lib] vm.load done items=\(items.count) status=\(status.rawValue)")
        } catch {
            print("[Yukimo.lib] vm.load ERROR \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
    }
}

struct LibraryTabView: View {
    @State private var vm = LibraryViewModel()

    private static let statuses: [(YukimoListStatus, String, String)] = [
        (.watching, "Смотрю",      "play.circle.fill"),
        (.plan,     "В планах",     "bookmark.fill"),
        (.watched,  "Просмотрено",  "checkmark.circle.fill"),
        (.holdOn,   "Отложено",     "pause.circle.fill"),
        (.dropped,  "Брошено",      "xmark.circle.fill"),
        (.favorite, "Любимое",      "heart.fill"),
        (.history,  "История",      "clock.arrow.circlepath"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            statusStrip
                .padding(.top, YukimoSpacing.sm)

            ScrollView {
                VStack(spacing: YukimoSpacing.lg) {
                    if let error = vm.error {
                        YukimoErrorBanner(message: error)
                            .padding(.horizontal, YukimoSpacing.screenPadding)
                    }
                    if vm.isLoading && currentCount == 0 {
                        loadingList
                    } else if currentCount == 0 {
                        emptyView
                    } else if vm.status == .history {
                        historyList
                    } else {
                        regularList
                    }
                    Color.clear.frame(height: 60)
                }
                .padding(.top, YukimoSpacing.md)
            }
            .refreshable { await vm.load() }
        }
        .background(YukimoColor.background.ignoresSafeArea())
        .navigationTitle("Списки")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .onChange(of: vm.status) { _, _ in
            Task { await vm.load() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    DownloadsView()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(YukimoColor.primaryCoral)
                        if YukimoDownloadsManager.shared.entries.count > 0 {
                            Circle()
                                .fill(YukimoColor.primaryCoral)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(YukimoColor.background, lineWidth: 1.5))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .accessibilityLabel("Скачанное")
            }
        }
    }

    /// Tab strip with an underline-style indicator (iOS-native pattern,
    /// à la Twitter / Apple News). Horizontally scrollable because 7
    /// statuses don't fit even on iPhone 17 Pro.
    private var statusStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Self.statuses, id: \.0) { (status, title, sym) in
                        tabButton(status: status, title: title, sym: sym)
                            .id(status)
                    }
                }
                .padding(.horizontal, YukimoSpacing.screenPadding)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(YukimoColor.borderSoft)
                    .frame(height: 0.5)
            }
            .onChange(of: vm.status) { _, new in
                withAnimation(YukimoMotion.fast) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }

    private func tabButton(status: YukimoListStatus,
                           title: String,
                           sym: String) -> some View {
        let isSelected = vm.status == status
        return Button {
            withAnimation(YukimoMotion.springSoft) {
                vm.status = status
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: sym)
                        .font(.system(size: 13, weight: .semibold))
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .bold : .semibold, design: .rounded))
                }
                .foregroundStyle(isSelected ? YukimoColor.primaryCoral : YukimoColor.textSecondary)
                .padding(.horizontal, YukimoSpacing.md)
                .padding(.top, 10)

                // Coral underline only under the active tab.
                Rectangle()
                    .fill(isSelected ? YukimoColor.primaryCoral : Color.clear)
                    .frame(height: 2.5)
                    .clipShape(Capsule())
                    .padding(.horizontal, YukimoSpacing.sm)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Convenience: items for the regular API-driven lists, entries for
    /// the local history tab. Used by the loading / empty branches.
    private var currentCount: Int {
        vm.status == .history ? vm.historyEntries.count : vm.items.count
    }

    private var regularList: some View {
        LazyVStack(spacing: YukimoSpacing.sm) {
            Text("\(vm.items.count) в списке")
                .font(YukimoTypography.footnote)
                .foregroundStyle(YukimoColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, YukimoSpacing.md)
                .padding(.bottom, 2)

            ForEach(vm.items, id: \.releaseID) { r in
                NavigationLink(value: ReleaseRoute(releaseID: r.releaseID)) {
                    ReleaseRowCard(release: r)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, YukimoSpacing.md)
    }

    private var historyList: some View {
        LazyVStack(spacing: YukimoSpacing.sm) {
            Text("\(vm.historyEntries.count) в истории")
                .font(YukimoTypography.footnote)
                .foregroundStyle(YukimoColor.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, YukimoSpacing.md)
                .padding(.bottom, 2)

            ForEach(vm.historyEntries) { entry in
                NavigationLink(value: ReleaseRoute(releaseID: entry.releaseID)) {
                    HistoryEntryRowCard(entry: entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        YukimoHistoryStore.shared.remove(releaseID: entry.releaseID)
                        Task { await vm.load() }
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal, YukimoSpacing.md)
    }

    private var loadingList: some View {
        LazyVStack(spacing: YukimoSpacing.sm) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: YukimoSpacing.md) {
                    RoundedRectangle(cornerRadius: YukimoRadius.sm, style: .continuous)
                        .fill(YukimoColor.softPink)
                        .frame(width: 64, height: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(YukimoColor.softPink.opacity(0.8))
                            .frame(height: 14).frame(maxWidth: .infinity, alignment: .leading)
                        RoundedRectangle(cornerRadius: 4).fill(YukimoColor.softPink.opacity(0.5))
                            .frame(height: 10).frame(width: 160)
                        RoundedRectangle(cornerRadius: 4).fill(YukimoColor.softPink.opacity(0.4))
                            .frame(height: 10).frame(width: 200)
                    }
                    Spacer()
                }
                .padding(YukimoSpacing.md)
                .background(YukimoColor.surface,
                            in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            }
        }
        .padding(.horizontal, YukimoSpacing.md)
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private var emptyView: some View {
        VStack(spacing: YukimoSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(YukimoColor.primaryCoralLight)
            Text("Пока пусто")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
            Text("Добавь тайтлы в этот список, чтобы они появились здесь.")
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, YukimoSpacing.xxl)
        }
        .padding(.top, YukimoSpacing.huge)
    }
}
