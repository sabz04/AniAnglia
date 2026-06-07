//
//  HomeViewModel.swift
//  Real API-backed home sections. No mocks.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class HomeViewModel {

    // MARK: Section state

    struct SectionState<T> {
        var items: [T] = []
        var isLoading: Bool = true
        var error: String? = nil
    }

    var greeting: String = "Привет"
    var profile: ProfileDTO?

    var hero: ReleaseDTO?
    var heroIsLoading: Bool = true
    var heroError: String?

    var continueWatching: SectionState<ReleaseDTO> = .init()
    var recommendations:  SectionState<ReleaseDTO> = .init()
    var currentlyWatching: SectionState<ReleaseDTO> = .init()
    var discussing:       SectionState<ReleaseDTO> = .init()

    // MARK: Lifecycle

    func loadAll() async {
        recomputeGreeting()
        async let profileTask:  Void = loadProfile()
        async let heroTask:     Void = loadHero()
        async let historyTask:  Void = loadContinueWatching()
        async let recsTask:     Void = loadRecommendations()
        async let watchingTask: Void = loadCurrentlyWatching()
        async let discussTask:  Void = loadDiscussing()
        _ = await (profileTask, heroTask, historyTask, recsTask, watchingTask, discussTask)
    }

    private func recomputeGreeting() {
        let h = Calendar.current.component(.hour, from: Date())
        greeting = switch h {
        case 5..<12:  "Доброе утро"
        case 12..<17: "Добрый день"
        case 17..<23: "Добрый вечер"
        default:       "Доброй ночи"
        }
    }

    // MARK: Profile

    func loadProfile() async {
        do {
            self.profile = try await withCheckedThrowingContinuation { cont in
                ProfileBridge.shared().loadMyProfile { dto, err in
                    if let dto { cont.resume(returning: dto) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.profile", code: -1)) }
                }
            }
        } catch {
            // Silent — header still renders with a generic greeting.
        }
    }

    // MARK: Hero

    func loadHero() async {
        heroIsLoading = true
        defer { heroIsLoading = false }
        do {
            self.hero = try await withCheckedThrowingContinuation { cont in
                HomeBridge.shared().loadHero { dto, err in
                    if let dto { cont.resume(returning: dto) }
                    else { cont.resume(throwing: err ?? NSError(domain: "yukimo.home", code: -1)) }
                }
            }
        } catch {
            heroError = "Не удалось загрузить рекомендацию"
        }
    }

    // MARK: Section loaders
    //
    // We can't factor these through WritableKeyPath because the @Observable
    // macro wraps stored properties in a way that defeats subscript mutation
    // — Swift reports the path as immutable. Inlining keeps it boring.

    private func fetch(
        _ request: @escaping (@escaping ([ReleaseDTO]?, Error?) -> Void) -> Void
    ) async throws -> [ReleaseDTO] {
        try await withCheckedThrowingContinuation { cont in
            request { items, err in
                if let items { cont.resume(returning: items) }
                else { cont.resume(throwing: err ?? NSError(domain: "yukimo.home", code: -1)) }
            }
        }
    }

    func loadContinueWatching() async {
        continueWatching.isLoading = true; continueWatching.error = nil
        do {
            continueWatching.items = try await fetch { HomeBridge.shared().loadContinueWatching(completion: $0) }
        } catch {
            continueWatching.error = error.localizedDescription
        }
        continueWatching.isLoading = false
    }

    func loadRecommendations() async {
        recommendations.isLoading = true; recommendations.error = nil
        do {
            recommendations.items = try await fetch { HomeBridge.shared().loadRecommendations(completion: $0) }
        } catch {
            recommendations.error = error.localizedDescription
        }
        recommendations.isLoading = false
    }

    func loadCurrentlyWatching() async {
        currentlyWatching.isLoading = true; currentlyWatching.error = nil
        do {
            currentlyWatching.items = try await fetch { HomeBridge.shared().loadCurrentlyWatching(completion: $0) }
        } catch {
            currentlyWatching.error = error.localizedDescription
        }
        currentlyWatching.isLoading = false
    }

    func loadDiscussing() async {
        discussing.isLoading = true; discussing.error = nil
        do {
            discussing.items = try await fetch { HomeBridge.shared().loadDiscussing(completion: $0) }
        } catch {
            discussing.error = error.localizedDescription
        }
        discussing.isLoading = false
    }
}
