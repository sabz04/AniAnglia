//
//  SearchTabView.swift
//

import SwiftUI
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query: String = ""
    var filters: YukimoSearchFilters = YukimoSearchFilters()
    var results: [ReleaseDTO] = []
    var isLoading: Bool = false
    var error: String?
    var recents: [String] = []

    @ObservationIgnored var availableGenres: [String] = []

    init() {
        reloadRecents()
        availableGenres = SearchBridge.shared().availableGenres()
    }

    func reloadRecents() {
        recents = SearchBridge.shared().recentSearches()
    }

    func clearRecent(at index: Int) {
        SearchBridge.shared().removeRecentSearch(at: index)
        reloadRecents()
    }

    var hasFilters: Bool { !filters.isEmpty }

    var hasAnythingToShow: Bool { !query.isEmpty || hasFilters }

    func submit() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            SearchBridge.shared().addRecentSearch(trimmed)
            reloadRecents()
        }
        await runSearch()
    }

    func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty && filters.isEmpty {
            results = []
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            if !q.isEmpty {
                // Free-text search: server doesn't accept the filter struct here,
                // so we rely on the basic search endpoint.
                self.results = try await withCheckedThrowingContinuation { cont in
                    SearchBridge.shared().searchReleases(query: q, page: 0) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.search", code: -1)) }
                    }
                }
            } else {
                // Filter-only search.
                self.results = try await withCheckedThrowingContinuation { cont in
                    SearchBridge.shared().filterSearch(filter: filters.toBridgeFilter(), page: 0) { items, err in
                        if let items { cont.resume(returning: items) }
                        else { cont.resume(throwing: err ?? NSError(domain: "yukimo.search", code: -1)) }
                    }
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct SearchTabView: View {
    @State private var vm = SearchViewModel()
    @State private var filtersSheetVisible = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: YukimoSpacing.xl) {
                searchField
                    .padding(.horizontal, YukimoSpacing.screenPadding)
                    .padding(.top, YukimoSpacing.md)

                if vm.hasFilters {
                    appliedFiltersStrip
                }

                if let error = vm.error {
                    YukimoErrorBanner(message: error)
                        .padding(.horizontal, YukimoSpacing.screenPadding)
                }

                if !vm.hasAnythingToShow {
                    if !vm.recents.isEmpty {
                        recentsBlock
                    } else {
                        emptyHint
                    }
                } else if vm.isLoading {
                    ProgressView()
                        .tint(YukimoColor.primaryCoral)
                        .padding(.vertical, YukimoSpacing.huge)
                } else if vm.results.isEmpty {
                    Text("Ничего не найдено")
                        .font(YukimoTypography.body)
                        .foregroundStyle(YukimoColor.textTertiary)
                        .padding(.vertical, YukimoSpacing.huge)
                } else {
                    LazyVStack(spacing: YukimoSpacing.sm) {
                        Text("\(vm.results.count) результатов")
                            .font(YukimoTypography.footnote)
                            .foregroundStyle(YukimoColor.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, YukimoSpacing.md)
                            .padding(.bottom, 2)

                        ForEach(vm.results, id: \.releaseID) { r in
                            NavigationLink(value: ReleaseRoute(releaseID: r.releaseID)) {
                                ReleaseRowCard(release: r)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, YukimoSpacing.md)
                }

                Color.clear.frame(height: 60)
            }
        }
        .background(YukimoColor.background.ignoresSafeArea())
        .navigationTitle("Поиск")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $filtersSheetVisible) {
            SearchFiltersSheet(filters: $vm.filters,
                               availableGenres: vm.availableGenres)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: vm.filters) { _, _ in
            Task { await vm.runSearch() }
        }
    }

    // MARK: Search field + filter button

    private var searchField: some View {
        HStack(spacing: YukimoSpacing.sm) {
            HStack(spacing: YukimoSpacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(fieldFocused ? YukimoColor.primaryCoral : YukimoColor.textTertiary)

                TextField("Найти аниме",
                          text: $vm.query,
                          prompt: Text("Найти аниме").foregroundStyle(YukimoColor.textTertiary))
                    .font(YukimoTypography.body)
                    .foregroundStyle(YukimoColor.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($fieldFocused)
                    .onSubmit { Task { await vm.submit() } }

                if !vm.query.isEmpty {
                    Button {
                        vm.query = ""
                        vm.results = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(YukimoColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, YukimoSpacing.lg)
            .frame(height: 52)
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous)
                    .stroke(fieldFocused ? YukimoColor.primaryCoral : YukimoColor.borderSoft,
                            lineWidth: fieldFocused ? 1.5 : 1))
            .animation(YukimoMotion.fast, value: fieldFocused)

            filterButton
        }
    }

    private var filterButton: some View {
        Button {
            filtersSheetVisible = true
        } label: {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous)
                        .fill(vm.hasFilters ? YukimoColor.primaryCoral : YukimoColor.surface)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(vm.hasFilters ? .white : YukimoColor.textPrimary)
                }
                .frame(width: 52, height: 52)
                .overlay(
                    RoundedRectangle(cornerRadius: YukimoRadius.field, style: .continuous)
                        .stroke(vm.hasFilters ? .clear : YukimoColor.borderSoft, lineWidth: 1))

                if vm.hasFilters {
                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Text("\(vm.filters.appliedChipLabels.count)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(YukimoColor.primaryCoral))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var appliedFiltersStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.filters.appliedChips) { chip in
                    Button {
                        withAnimation(YukimoMotion.springSoft) {
                            vm.filters.remove(chip)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(chip.label)
                                .font(YukimoTypography.caption)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(YukimoColor.primaryCoralDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(YukimoColor.softPink, in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Убрать фильтр \(chip.label)")
                }
                Button("Очистить") {
                    withAnimation(YukimoMotion.springSoft) {
                        vm.filters = YukimoSearchFilters()
                    }
                }
                .buttonStyle(.yukimoGhost)
            }
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
    }

    // MARK: Recents

    private var recentsBlock: some View {
        VStack(alignment: .leading, spacing: YukimoSpacing.md) {
            Text("Недавние запросы")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
                .padding(.horizontal, YukimoSpacing.screenPadding)

            VStack(spacing: 0) {
                ForEach(Array(vm.recents.enumerated()), id: \.element) { idx, item in
                    Button {
                        vm.query = item
                        Task { await vm.runSearch() }
                    } label: {
                        HStack(spacing: YukimoSpacing.md) {
                            Image(systemName: "clock")
                                .foregroundStyle(YukimoColor.textTertiary)
                            Text(item)
                                .font(YukimoTypography.body)
                                .foregroundStyle(YukimoColor.textPrimary)
                            Spacer()
                            // X tap removes the entry without firing the
                            // parent row's "search this query" action.
                            Button {
                                vm.clearRecent(at: idx)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(YukimoColor.textTertiary)
                                    .padding(8)         // bigger hit area
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, YukimoSpacing.lg)
                        .padding(.vertical, YukimoSpacing.md)
                        // Make the entire row a hit target — without this
                        // taps over the Spacer between text and X don't
                        // count and only the text itself runs the search.
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.horizontal, YukimoSpacing.lg)
                }
            }
            .background(YukimoColor.surface,
                        in: RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: YukimoRadius.md, style: .continuous)
                    .stroke(YukimoColor.borderSoft, lineWidth: 0.5))
            .padding(.horizontal, YukimoSpacing.screenPadding)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: YukimoSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(YukimoColor.primaryCoralLight)
            Text("Найди что посмотреть")
                .font(YukimoTypography.title3)
                .foregroundStyle(YukimoColor.textPrimary)
            Text("Введи название тайтла или подбери через фильтры.")
                .font(YukimoTypography.body)
                .foregroundStyle(YukimoColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, YukimoSpacing.xxl)
        }
        .padding(.top, YukimoSpacing.huge)
    }
}
