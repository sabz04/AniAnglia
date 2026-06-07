//
//  SearchFiltersSheet.swift
//  Modern iOS filter sheet — sections, ranges, multi-select chips,
//  apply / reset toolbar. Matches Apple-Music-search / Crunchyroll
//  pattern: live filtering without leaving the sheet.
//

import SwiftUI

/// One applied filter chip + its origin slot in the filter struct, so
/// the removal action can target the right field without re-matching
/// the label.
struct AppliedChip: Hashable, Identifiable {
    enum Kind: Hashable {
        case sort
        case yearRange
        case status
        case category
        case season
        case genre(String)
    }
    let kind: Kind
    let label: String
    var id: Kind { kind }
}

struct YukimoSearchFilters: Equatable {
    enum Sort: Int, CaseIterable, Identifiable {
        case dateUpdate = 0, grade = 1, year = 2, popular = 3
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .dateUpdate: return "По дате обновления"
            case .grade:      return "По рейтингу"
            case .year:       return "По году"
            case .popular:    return "По популярности"
            }
        }
    }

    enum Status: Int, CaseIterable, Identifiable {
        case any = 0, finished = 1, ongoing = 2, upcoming = 3
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .any:      return "Любой"
            case .finished: return "Завершено"
            case .ongoing:  return "Онгоинг"
            case .upcoming: return "Анонс"
            }
        }
    }

    enum Category: Int, CaseIterable, Identifiable {
        case any = 0, series = 1, movies = 2, ova = 3
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .any:    return "Любая"
            case .series: return "ТВ Сериал"
            case .movies: return "Фильм"
            case .ova:    return "OVA"
            }
        }
    }

    enum Season: Int, CaseIterable, Identifiable {
        case any = 0, winter = 1, spring = 2, summer = 3, fall = 4
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .any:    return "Любой"
            case .winter: return "Зима"
            case .spring: return "Весна"
            case .summer: return "Лето"
            case .fall:   return "Осень"
            }
        }
    }

    var sort: Sort = .dateUpdate
    var startYear: Int = 0
    var endYear: Int = 0
    var status: Status = .any
    var category: Category = .any
    var season: Season = .any
    var genres: Set<String> = []

    var isEmpty: Bool {
        sort == .dateUpdate && startYear == 0 && endYear == 0
        && status == .any && category == .any && season == .any && genres.isEmpty
    }

    var appliedChipLabels: [String] {
        appliedChips.map(\.label)
    }

    /// Tagged version of `appliedChipLabels` — keeps a strongly-typed
    /// `kind` alongside the display string so `remove(_:)` can clear
    /// exactly the right slot without ambiguous label matching (e.g.
    /// genre name colliding with a season name).
    var appliedChips: [AppliedChip] {
        var out: [AppliedChip] = []
        if sort != .dateUpdate {
            out.append(.init(kind: .sort, label: sort.label))
        }
        if startYear > 0 && endYear > 0 {
            out.append(.init(kind: .yearRange, label: "\(startYear)–\(endYear)"))
        } else if startYear > 0 {
            out.append(.init(kind: .yearRange, label: "с \(startYear)"))
        } else if endYear > 0 {
            out.append(.init(kind: .yearRange, label: "до \(endYear)"))
        }
        if status != .any   { out.append(.init(kind: .status,   label: status.label)) }
        if category != .any { out.append(.init(kind: .category, label: category.label)) }
        if season != .any   { out.append(.init(kind: .season,   label: season.label)) }
        for g in genres.sorted() {
            out.append(.init(kind: .genre(g), label: g))
        }
        return out
    }

    mutating func remove(_ chip: AppliedChip) {
        switch chip.kind {
        case .sort:            sort = .dateUpdate
        case .yearRange:       startYear = 0; endYear = 0
        case .status:          status = .any
        case .category:        category = .any
        case .season:          season = .any
        case .genre(let name): genres.remove(name)
        }
    }

    /// Translate to the Obj-C DTO consumed by SearchBridge.filterSearch.
    func toBridgeFilter() -> SearchFilterDTO {
        let dto = SearchFilterDTO()
        dto.sort = bridgeSort
        dto.startYear = startYear
        dto.endYear = endYear
        dto.season = bridgeSeason
        dto.status = status.rawValue
        dto.category = category.rawValue
        dto.genres = Array(genres)
        return dto
    }

    private var bridgeSort: YukimoFilterSort {
        switch sort {
        case .dateUpdate: return .dateUpdate
        case .grade:      return .grade
        case .year:       return .year
        case .popular:    return .popular
        }
    }

    private var bridgeSeason: YukimoReleaseSeason {
        switch season {
        case .any:    return .unknown
        case .winter: return .winter
        case .spring: return .spring
        case .summer: return .summer
        case .fall:   return .fall
        }
    }
}

struct SearchFiltersSheet: View {
    @Binding var filters: YukimoSearchFilters
    let availableGenres: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Сортировка") {
                    Picker("Сортировать", selection: $filters.sort) {
                        ForEach(YukimoSearchFilters.Sort.allCases) { sort in
                            Text(sort.label).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(YukimoColor.primaryCoral)
                }

                Section("Год") {
                    Stepper("С \(filters.startYear == 0 ? "—" : "\(filters.startYear)")",
                            value: $filters.startYear, in: 0...2030, step: 1)
                    Stepper("По \(filters.endYear == 0 ? "—" : "\(filters.endYear)")",
                            value: $filters.endYear, in: 0...2030, step: 1)
                }

                Section("Тип") {
                    Picker("Тип", selection: $filters.category) {
                        ForEach(YukimoSearchFilters.Category.allCases) { cat in
                            Text(cat.label).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(YukimoColor.primaryCoral)
                }

                Section("Статус") {
                    Picker("Статус", selection: $filters.status) {
                        ForEach(YukimoSearchFilters.Status.allCases) { st in
                            Text(st.label).tag(st)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(YukimoColor.primaryCoral)
                }

                Section("Сезон") {
                    Picker("Сезон", selection: $filters.season) {
                        ForEach(YukimoSearchFilters.Season.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(YukimoColor.primaryCoral)
                }

                Section {
                    YukimoFlowLayout(hSpacing: 6, vSpacing: 8) {
                        ForEach(availableGenres, id: \.self) { genre in
                            genreChip(genre)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    HStack {
                        Text("Жанры")
                        Spacer()
                        if !filters.genres.isEmpty {
                            Text("\(filters.genres.count)")
                                .foregroundStyle(YukimoColor.primaryCoral)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(YukimoColor.background.ignoresSafeArea())
            .navigationTitle("Фильтры")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Сброс") {
                        withAnimation(YukimoMotion.springSoft) {
                            filters = YukimoSearchFilters()
                        }
                    }
                    .foregroundStyle(YukimoColor.danger)
                    .disabled(filters.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .foregroundStyle(YukimoColor.primaryCoral)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func genreChip(_ genre: String) -> some View {
        let isSelected = filters.genres.contains(genre)
        return Button {
            if isSelected { filters.genres.remove(genre) }
            else          { filters.genres.insert(genre) }
        } label: {
            Text(genre)
                .font(YukimoTypography.caption)
                .foregroundStyle(isSelected ? .white : YukimoColor.primaryCoralDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AnyShapeStyle(YukimoColor.primaryCoral) : AnyShapeStyle(YukimoColor.softPink),
                    in: Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? YukimoColor.primaryCoral : YukimoColor.primaryCoral.opacity(0.25),
                        lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
}
