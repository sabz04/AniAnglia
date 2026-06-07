# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

AniAnglia is an unofficial iOS client for **Anixart** (anime catalog/streaming). Written in Objective-C++ (`.mm`) on top of a C++20 core. Min deployment target iOS 14.0; project is built with the iOS 17.4 SDK.

Note the naming split: the Xcode project, native target, and source group are all `AniAnglia`, but the **shared scheme is `iOSAnixart`** and the product name is `AniAngliaXIX`. Old files retain `iOSAnixart` references in headers/comments — that's expected, not a rename in progress.

## Build & run

Open `AniAnglia.xcodeproj` in Xcode and build the `iOSAnixart` scheme. There is no Swift Package Manager / CocoaPods / Carthage setup — all third-party C++ libraries are vendored as `.xcframework` bundles under `AniAnglia/Libraries/`.

CI build (mirrors `.github/workflows/build.yml`, runs unsigned, packages an `.ipa`):

```bash
xcodebuild -project AniAnglia.xcodeproj \
  -scheme iOSAnixart \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ONLY_ACTIVE_ARCH=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES
```

To package an `.ipa`, copy the produced `.app` into a `Payload/` directory and zip it (see the `Create Payload and package IPA` step in the workflow).

There is no test target, no linter config, and no Swift code. Workflow is `workflow_dispatch`-only — CI does not run on push/PR.

## Vendored C++ libraries

Located in `AniAnglia/Libraries/`:

- `aateam/libanixart` — first-party C++ wrapper around the Anixart HTTP API (`anixart::Api`, `anixart::parsers::Parsers`). This is the data-layer brain of the app. **Bumping this library is the usual fix for "site changed, parsing broke" bugs** (see commit `927e4054` for the pattern: "Update libanixart. Fixes kodik parsing in player").
- `aateam/libnetsess` — HTTP/session backend used by libanixart.
- `aateam/libtorrentrepo` — first-party torrent-repo abstraction.
- `libtorrent/` — libtorrent-rasterbar + `try_signal`. The two large `.a` archives inside `libtorrent.xcframework` are **gitignored** and must be obtained out-of-band before the project will link.
- `include/` — headers only (boost, curlpp, libtorrent, openssl, ext, utilspp) consumed by the libraries above.

Each `aateam/<lib>/include/` directory contains the public headers you import from Objective-C++ (`#import <anixart/Api.hpp>`, etc.).

## Architecture

### Bootstrap
`main.mm` → `AppDelegate` → `SceneDelegate` constructs `MainWindow` (a custom `UIWindow`). `MainWindow.getFirstRootViewController` decides between `AuthViewController` (no token) and `MainTabBarController` (have token) based on `[AppDataController sharedInstance] getToken`. The window subscribes to settings changes to apply theme overrides live.

### Two singletons drive everything

1. **`LibanixartApi` (`Misc/Anixart/LibanixartApi.{h,mm}`)** — owns the C++ `anixart::Api*`. All network calls go through one of:
   - `-asyncCall:completion:` (preferred) — runs the block on a background queue, catches `anixart::ApiError`, `network::JsonError`, `network::UrlSessionError`, `std::runtime_error`, and dispatches `completion(errored)` back to the main queue.
   - `-performAsyncBlock:withUICompletion:` (DEPRECATED — leave alone in old code, don't use in new code).

   New API-touching code should `#import "LibanixartApi.h"` and call `[[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api* api){ ... } completion:^(BOOL errored){ ... }]`. **Never** call `_api->...` synchronously from the main queue.

2. **`AppDataController` (`Misc/AppDataController.{h,mm}`)** — persists token, profile ID, search history, saved release-type filters, and exposes a nested `AppSettingsDataController` for typed settings (theme, display style, default player, preferred quality, skip time, auto-next, max cache, alternative connection). Settings changes broadcast `NSNotification` named `app_settings::notification_name` (= `@"AppSettingsDataControllerValueChanged"`) with `userInfo[notification_info_key]` = setting name and `userInfo[notification_info_value]` = new value. `MainWindow` and `LibanixartApi` both listen — when adding a new setting, follow the same pattern (constant in `app_settings::` namespace, getter/setter pair, post on set, observer reacts).

### Pageable lists

Lists with API-driven pagination (releases, comments, collections, profiles, votes, history) are built on `Common/Pageable/PageableDataProvider` + a `<PageableDataProviderDelegate>`. Concrete providers: `ReleasesPageableDataProvider`, `CommentsPageableDataProvider`, `CollectionsPageableDataProvider`, `ProfilesPageableDataProvider`, plus `ReleasesOnePageDataProvider` for non-paginated result sets that reuse the same delegate API. The delegate gets `didBeginLoadingPageAtIndex:` / `didLoadPageAtIndex:` / `didFailPageAtIndex:` plus a coarse `didUpdateDataForPageableDataProvider:`. When wiring a new list view, prefer composing an existing provider over re-implementing pagination.

### Folder map
- `Core/` — `AppDelegate`, `SceneDelegate`, `MainWindow`, `main.mm`.
- `Auth/` — login (`AuthViewController`), sign-up, password restore, code entry, plus `AuthChecker` (client-side validation enum) and `AuthPerformer`.
- `Main/` — `MainTabBarController` and the top-level tabs: `MainViewController`, `DiscoverViewController`, `Search/`, `Settings/`.
- `Releases/` — release detail screen + player stack: `ReleaseViewController`, `EpisodeSelectViewController`, `SourceSelectViewController`, `TypeSelectViewController`, `PlayerViewController` (AVKit-based).
- `Profiles/` — user profile screens (own + others), friends, comments tab.
- `Common/` — shared building blocks: pageable providers, generic table/collection VCs (`ReleasesTableViewController`, `ReleasesCollectionViewController`, `CommentsTableViewController`, …), reusable cells, `ExpandableLabel`, `StarsVoteView`, `LoadableView`, `SegmentedPageViewController`, etc. Reach for these before writing one-off list code.
- `Misc/` — `AppColor` (semantic colors), `StringCvt` (NS↔std::string with `TO_STDSTRING` macro), `TimeCvt`, `SharedRunningData` (`asyncGetMyProfile:` helper), `TextErrorField`, `DataReloadable` protocol.
- `Assets.xcassets/` — colors and images.
- `en.lproj/`, `ru.lproj/` — `Localizable.strings`. Russian is the primary language (UI text in source is Russian); English is a translation. Genre/studio dictionaries in `LibanixartApi.mm` are Russian-only by design (they match server-side values).

### Conventions worth knowing
- Objective-C++ everywhere: files are `.mm`, not `.m`, because they include C++ headers. New API-touching files should be `.mm`. The handful of `.m` files (e.g., `SearchViewController.m`, `SettingsTableViewController.m`, `CustomTableViewCells.m`, `StarsVoteView.m`) are pure Obj-C view code with no C++ deps — keep them that way unless you need C++.
- ARC is enabled (`CLANG_ENABLE_OBJC_ARC = YES`). C++ objects owned by Obj-C classes (e.g., `_api` in `LibanixartApi`) are `new`/`delete`d manually in `init`/`dealloc`.
- C++ standard is `c++20`.
- Naming: snake_case for locals/ivars (`_app_data_controller`, `is_alternative_connection`), camelCase for Obj-C method selectors. C++ enums are scoped (`enum class`). Match the surrounding file's style.
- When introducing a singleton, follow the `+sharedInstance` + `dispatch_once` pattern used in `LibanixartApi`/`AppDataController`.

---

# Yukimo Worklog (active redesign — SwiftUI on top of existing Obj-C++ API)

> Persistent notes for the Yukimo redesign. The legacy UIKit app is being replaced by a new SwiftUI app called **Yukimo**, reusing only the API foundation. Old UI is being deprecated but kept compilable until the new shell is complete. **Do not delete legacy code unless explicitly asked** — we link past it instead.

## Audit findings (2026-06-03)

- `CFBundleDisplayName` in `AniAnglia/Info.plist` is already `yukimo` — no Info.plist rename needed for Auth Flow.
- Single Xcode target `AniAnglia`, single scheme `iOSAnixart`, `PRODUCT_NAME = AniAngliaXIX`.
- `IPHONEOS_DEPLOYMENT_TARGET = 17.4` at target level (14.0 at project level — target wins). Safe to use `@Observable`, `symbolEffect`, async/await, `NavigationStack`.
- `CLANG_ENABLE_MODULES = YES`. Swift settings (`SWIFT_VERSION` etc.) NOT set yet — must be added.
- Test device **Sabirov** = iPhone iOS 26.3.1 (UDID `00008110-0012289414C0A01E`). This is the device-side target for Liquid Glass.
- Legacy auth path: `MainWindow.getFirstRootViewController` → reads token from `[AppDataController sharedInstance] getToken` → `AuthViewController` (no token) or `MainTabBarController` (token). The redesign replaces both branches.

## API foundation we reuse (do NOT rewrite)

- `LibanixartApi.h` (`Misc/Anixart/`) — singleton. `asyncCall:completion:` is the preferred entry; runs block on bg queue, dispatches completion to main, catches `anixart::ApiError`/`network::JsonError`/`network::UrlSessionError`/`std::runtime_error`. **Header imports `<anixart/Api.hpp>` directly → CANNOT go in Swift bridging header.**
- `AppDataController.h` — token (NSString) in NSUserDefaults under key `"token"`. Profile ID = `anixart::ProfileID` (`StrongTypedef<int64_t>`). Settings via nested `AppSettingsDataController`, broadcasts `app_settings::notification_name` on change. **Exposes C++ types (ProfileID, `enum class Theme`, `std::chrono` durations) → CANNOT be in bridging header directly.**
- `AuthChecker.h` — exposes `enum class AuthCheckerStatus { Normal, TooShort, TooLong, Invalid }` and `checkUsername:`/`checkEmail:`/`checkPassword:`. **`enum class` in header → C++ → CANNOT be in bridging header.** We reimplement validation in Swift instead (rules are trivial; not worth wrapping).
- `AuthPerformer.h` — exposes `anixart::Profile::Ptr`/`anixart::ProfileToken` in signatures → C++ in header → wrap in `YukimoSessionBridge`.
- `StringCvt.h` — inline `TO_NSSTRING(std::string)` / `TO_STDSTRING(NSString*)` — use inside `.mm` bridge files.

### Libanixart auth surface (from `ApiAuth.hpp`)
```
api->auth().sign_in(login, password)           // → std::pair<Profile::Ptr, ProfileToken>; throws SignInError(SignInCode)
api->auth().sign_up(login, email, password)    // → ApiAuthPending::UPtr; throws SignUpError(SignUpCode)
ApiAuthPending::verify(email_code)              // → std::pair<Profile::Ptr, ProfileToken>
api->auth().restore(email_or_username, new_pw) // → ApiRestorePending::UPtr; throws RestoreError(RestoreCode)
ApiRestorePending::verify(email_code)           // → std::pair<Profile::Ptr, ProfileToken>
```
Error codes live in `ApiErrorCodes.hpp`: `codes::auth::SignInCode`, `SignUpCode`, `RestoreCode`, `RestoreVerifyCode`. Common: `Success=0`, `Failed=1`, `InvalidLogin=2`, `InvalidPassword=3`, plus signup-specific `InvalidEmail=3`, `LoginAlreadyTaken=5`, `EmailAlreadyTaken=6`. The bridge maps these to a Swift enum.

## SwiftUI integration architecture

- **Bridging header:** `AniAnglia/Yukimo/Bridge/Yukimo-Bridging-Header.h`. Imports ONLY Swift-safe Obj-C facades (`YukimoAuthBridge.h`, `YukimoSessionBridge.h`, `YukimoSettingsBridge.h`). Never `#import "LibanixartApi.h"` here.
- **Per Apple's clang importer:** `enum class`, C++ namespaces, `std::*`, and `#include` of C++ in an Obj-C header all break Swift import → use thin pure-Obj-C facades.
- **`-Swift.h` filename:** `PRODUCT_NAME` is `AniAngliaXIX`, so default would be `AniAngliaXIX-Swift.h`. We will set `PRODUCT_MODULE_NAME = AniAnglia` explicitly so Obj-C++ files use `#import "AniAnglia-Swift.h"` — matches target/source-group name.
- **UIHostingController from Obj-C++:** Obj-C cannot construct Swift generics. Pattern: `@objc final class YukimoHostFactory: NSObject { @objc static func makeRoot() -> UIViewController { UIHostingController(rootView: YukimoRootView()) } }` then `[YukimoHostFactory makeRoot]` from `SceneDelegate.mm`.
- **async/await from Obj-C completion:** use `NS_SWIFT_ASYNC_NAME` on bridge methods so Swift sees clean `try await api.signIn(login:password:)`.

## Required pbxproj edits

Add to BOTH Debug and Release `XCBuildConfiguration` of the `AniAnglia` target (NOT project-level — avoid polluting xcframework builds):
```
SWIFT_VERSION = 5.0;
SWIFT_OBJC_BRIDGING_HEADER = "AniAnglia/Yukimo/Bridge/Yukimo-Bridging-Header.h";
SWIFT_OBJC_INTERFACE_HEADER_NAME = "AniAnglia-Swift.h";
PRODUCT_MODULE_NAME = AniAnglia;
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;
SWIFT_INSTALL_OBJC_HEADER = YES;
DEFINES_MODULE = NO;
SWIFT_EMIT_LOC_STRINGS = YES;
```
Per-config:
```
Debug:   SWIFT_OPTIMIZATION_LEVEL = "-Onone";  SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG";  SWIFT_COMPILATION_MODE = singlefile;
Release: SWIFT_OPTIMIZATION_LEVEL = "-O";       SWIFT_COMPILATION_MODE = wholemodule;
```
All new Swift files + bridge headers must be added as `PBXFileReference` + `PBXBuildFile` and listed under the source-group + the `PBXSourcesBuildPhase`. Bridging header itself is NOT a build phase member.

## Folder map for new code (under `AniAnglia/Yukimo/`)

```
Yukimo/
  Bridge/
    Yukimo-Bridging-Header.h       (lists includes for bridging)
    YukimoAuthBridge.h / .mm        (signIn / signUp / verifySignUp / restore / verifyRestore / logout)
    YukimoSessionBridge.h / .mm     (hasToken, currentProfileID, clearSession; reads AppDataController)
    YukimoSettingsBridge.h / .mm    (theme get/set, notifications subscribe — used for live theme override)
  App/
    YukimoHostFactory.swift         (@objc factory called from SceneDelegate.mm)
    YukimoRootView.swift            (top-level router: splash → onboarding/auth → main)
    YukimoAppState.swift            (@Observable global state: session, theme, route)
    YukimoRoute.swift               (enum routes for AuthFlow)
  DesignSystem/
    Theme/
      YukimoColor.swift             (semantic + raw tokens, light/dark via Asset Catalog OR computed)
      YukimoTypography.swift        (.rounded design, sized tokens)
      YukimoSpacing.swift           (4/8/12/16/20/24/32/40/56)
      YukimoRadius.swift            (xs=8, sm=12, md=16, lg=20, xl=28, pill)
      YukimoShadow.swift            (soft / elevated / glass-tint)
      YukimoMotion.swift            (fast/normal/slow + spring presets)
    Modifiers/
      GlassBackground.swift         (iOS 26 glassEffect with material fallback)
      ReduceTransparencyAware.swift (toggle for accessibility)
    Components/
      YukimoPrimaryButton.swift
      YukimoSecondaryButton.swift
      YukimoTextField.swift
      YukimoSecureField.swift
      YukimoGlassCard.swift
      YukimoGradientBackground.swift
      YukimoErrorBanner.swift
      YukimoLoadingOverlay.swift
      YukimoCodeInput.swift
      YukimoPageIndicator.swift
      YukimoIcon.swift              (SF Symbol wrapper with consistent rendering mode)
  Features/
    Auth/
      Splash/SplashView.swift
      Onboarding/OnboardingView.swift + OnboardingPage.swift
      Login/LoginView.swift + LoginViewModel.swift
      Register/RegisterView.swift + RegisterViewModel.swift
      ForgotPassword/ForgotPasswordView.swift + ForgotPasswordViewModel.swift
      Verification/VerificationView.swift + VerificationViewModel.swift
      Success/AuthSuccessView.swift
      Shared/AuthValidator.swift   (Swift port of AuthChecker rules)
      Shared/AuthError.swift       (Swift error enum mapped from bridge codes)
    Main/
      MainPlaceholderView.swift    (until Phase 4)
```

## Risk notes

- **`AppDataController.h` cannot be `#import`ed in the bridging header** because it transitively pulls `LibanixartApi.h` (which pulls `<anixart/Api.hpp>`). Bridge writes/reads via `[[AppDataController sharedInstance] ...]` inside `.mm` files — Swift sees only `YukimoSessionBridge`.
- **`MainWindow.mm` constructs the root VC right now.** Path: keep `MainWindow` alive (it owns settings observer + theme override). Change `getFirstRootViewController` to call `[YukimoHostFactory makeRoot]`. Legacy `AuthViewController` and `MainTabBarController` remain on disk but unreferenced from boot.
- **Tracking which screens cannot be replaced this iteration:** old AVKit player, release lists, profile tabs all stay in the Obj-C side. After Auth, Phase 4+ Main Shell can either re-host them via `UIViewControllerRepresentable` or be rewritten — TBD.
- **pbxproj corruption risk:** every file/group/buildphase edit is hand-rolled. Make all edits in one shot, validate by running `xcodebuild -list` after.

## Phase status

- [x] Phase 1 — Audit (notes above)
- [x] Phase 2 — Design System (color/typography/spacing/radius/shadow/motion tokens + 11 components)
- [x] Phase 3 — Auth Flow (Splash → Onboarding → Login → Register → Forgot → Verification → Success)
- [x] Phase 4 — Main Shell + Home (TabView + HomeView with real API, no mocks)
- [x] Phase 5 — Core screens (Details + Search + Library, all live API)
- [x] Phase 7 — Build on Sabirov — succeeded on simulator (iPhone 17 Pro) and on device (iOS 26.3.1)

## Phase 3 ship log (2026-06-03)

### Bridge surface (Obj-C++ → Swift)

| File | Purpose |
| --- | --- |
| `Yukimo/Bridge/Yukimo-Bridging-Header.h` | Only includes the three pure-Obj-C bridges below |
| `Yukimo/Bridge/YukimoAuthBridge.{h,mm}` | `AuthBridge` Swift facade: `signIn/signUp/verifySignUp/restorePassword/verifyRestore/logout` + opaque `AuthPending` for verify flows + `YukimoAuthErrorCode` `NS_ENUM` (NOT NS_ERROR_ENUM — Swift import is more predictable as a plain `RawRepresentable` enum) |
| `Yukimo/Bridge/YukimoSessionBridge.{h,mm}` | `SessionBridge.shared().hasActiveSession`, `currentProfileID` as `Int64` |
| `Yukimo/Bridge/YukimoSettingsBridge.{h,mm}` | `SettingsBridge.shared().theme` + `YukimoSettingsChangedNotification` that re-broadcasts `app_settings::notification_name` under a stable name |

Bridge rules learned the hard way:
- `__weak typeof(self) weakSelf` → must be `__weak __typeof__(self) weakSelf` in `.mm`, otherwise clang rejects `typeof` as a keyword.
- C++17 structured bindings (`auto [a, b] = ...`) **cannot be captured in Obj-C blocks**. Always copy into named `T a = pair.first; T b = pair.second;` before the block.
- The lib's verify-step error type is `anixart::VerifyError` (sign-up) and `anixart::RestoreVerifyError` (restore), with `codes::auth::VerifyCode` / `RestoreVerifyCode`. The case names are `CodeInvalid`/`CodeExpired` (not `InvalidCode`).
- `anixart::codes::auth::RestoreCode` cases: `ProfileNotFound`/`CodeAlreadySent`/`CodeCannotSend` (no `InvalidLogin`).

### Swift surface

Top-level entry: `MainWindow.getFirstRootViewController` → `[YukimoHostFactory makeRootViewController]` → `UIHostingController(rootView: YukimoRootView())`.

`@Observable` `YukimoAppState` drives route transitions (splash → onboarding/login → register → verify → success → main). Legacy `AuthViewController` / `MainTabBarController` still compile but are unreachable from boot.

Design system tokens loaded by every screen: `YukimoColor`, `YukimoTypography`, `YukimoSpacing`, `YukimoRadius`, `YukimoShadow`, `YukimoMotion`, `.yukimoGlass(...)` modifier (iOS 26 `glassEffect` with `.ultraThinMaterial` fallback and Reduce Transparency solid-surface fallback).

### Build commands that worked

```bash
# Simulator (fast compile check):
xcodebuild -project AniAnglia.xcodeproj -scheme iOSAnixart \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build_yukimo \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

# Real device "Sabirov" (00008110-0012289414C0A01E, iOS 26.3.1):
xcodebuild -project AniAnglia.xcodeproj -scheme iOSAnixart \
  -configuration Debug \
  -destination 'platform=iOS,id=00008110-0012289414C0A01E,name=Sabirov' \
  -derivedDataPath build_yukimo_device \
  -allowProvisioningUpdates build

# Install + launch:
xcrun devicectl device install app --device 00008110-0012289414C0A01E \
  build_yukimo_device/Build/Products/Debug-iphoneos/AniAngliaXIX.app
xcrun devicectl device process launch --device 00008110-0012289414C0A01E org.aateam.AniAnglia
```

### pbxproj automation

`scripts/yukimo_setup_xcodeproj.rb` is **idempotent** — re-run after creating new Swift/.mm files under `AniAnglia/Yukimo/` and it will register them in the project + sources phase without duplicating refs. It also enforces the Swift build settings (deployment target 17.0, bridging header path, module name `AniAnglia`).

### Deployment target bump

Bumped `IPHONEOS_DEPLOYMENT_TARGET` from 14.0 → 17.0 because: `@Observable`, `@Environment(MyObservable.self)`, `.symbolEffect`, `.sensoryFeedback`, `.scrollDismissesKeyboard` are all iOS 17+. Sabirov runs iOS 26.3.1 so this is safe in production. Legacy code on this target compiles unchanged. iOS 26 features (`.glassEffect`) live behind `if #available(iOS 26.0, *)` with material/solid fallbacks.

## Phase 4 ship log (2026-06-03)

### Bridge surface for Main

| File | Provides to Swift |
| --- | --- |
| `Yukimo/Bridge/YukimoReleaseDTO.{h,mm}` | `ReleaseDTO`: id, titleRu, titleOriginal, imageURL, genres, year, grade, voteCount, status (enum), episodesReleased/Total, lastViewEpisodePosition/Name, description_, isFavorite |
| `Yukimo/Bridge/YukimoProfileDTO.{h,mm}` | `ProfileDTO`: id, username, avatarURL, statusText, watchedMinutes, watchedCount, watchingCount, planCount, favoriteCount |
| `Yukimo/Bridge/YukimoHomeBridge.{h,mm}` | `HomeBridge`: `loadHero`, `loadContinueWatching`, `loadRecommendations`, `loadCurrentlyWatching`, `loadDiscussing` — all NS_SWIFT_ASYNC_NAME so Swift sees them as `try await` |
| `Yukimo/Bridge/YukimoProfileBridge.{h,mm}` | `ProfileBridge.loadMyProfile()` — reads stored `anixart::ProfileID` from `AppDataController`, calls `api->profiles().get_profile(id)` |

### libanixart endpoints actually used by Home

- Hero: `api->releases().random_release(/*extended*/true)`
- Continue watching: `api->releases().get_history(0)->get()` (returns `Release` vector with `last_view_episode` populated)
- Recommendations: `api->search().recomendations(0)->get()` (note legacy spelling — `recomendations` not `recommendations`)
- Currently watching: `api->search().currently_watching(0)->get()`
- Discussing: `api->search().discussing()->get()`
- Profile: `api->profiles().get_profile(my_id)` — returns `std::pair<Profile::Ptr, bool /*is_my_profile*/>`

### Bridge patterns confirmed in this phase

- Internal `+ (instancetype)fromRelease:(anixart::Release::Ptr)` factory categories on the DTO classes keep C++ types out of the public header but still let bridge files convert in one place.
- `auto pair = ...; auto a = pair.first; auto b = pair.second;` — never structured bindings into a block.
- DTO category `+fromX` lives in `.mm` (so C++ headers are scoped), declared as a category to allow the bridge implementation file to call it without forward-declaring everything in the main impl.

### Swift Home surface

`Yukimo/Features/Main/`:
- `YukimoMainTabView.swift` — 5-tab `TabView` (Главная/Поиск/Списки/Лента/Профиль). Uses the legacy `.tabItem` API which picks up Liquid Glass automatically when built against SDK 26.
- `Home/HomeView.swift` — scroll with header (greeting + avatar), Hero, Continue Watching rail, Recommendations rail, Currently Watching rail, Discussing rail. `.refreshable` triggers `vm.loadAll()`.
- `Home/HomeViewModel.swift` — `@Observable @MainActor` class. **One catch:** `@Observable` defeats `WritableKeyPath<HomeViewModel, struct>` mutation (Swift reports "self is immutable"). Solution: inline each section loader explicitly. Don't try to factor with a generic `load(into: keyPath, ...)` helper — it won't compile.
- `Home/Components/HeroCard.swift`, `PosterCard.swift`, `ContinueWatchingCard.swift`, `PosterRail.swift` — display layer.
- `Tabs/ProfileTabView.swift` — real profile load via `ProfileBridge`, stats grid, logout button.
- `Tabs/PlaceholderTabView.swift` — branded "coming soon" stub for Search/Library/Feed.
- `DesignSystem/Networking/YukimoAsyncImage.swift` — URLCache-backed (32 MB mem / 256 MB disk) image loader. Built-in `AsyncImage` re-fetches across recompositions in carousels — this wrapper deduplicates with `NSCache<NSString, UIImage>`.

### Asset Catalog

`AniAnglia/Assets.xcassets/AppIcon.appiconset/`: regenerated all PNGs from `/Users/sabirovzulfat/Downloads/609384a1-14a8-4498-9b3c-a948aec26b74.png` (1254×1254 source) via `sips -z`. `Contents.json` already maps to `yukimo-*.png` so no JSON changes needed. Filenames: `yukimo-20.png`, `yukimo-20@2x.png`, ..., `yukimo-1024.png` (15 files total covering iPhone + iPad + marketing).

### Boot path (unchanged)

`MainWindow.getFirstRootViewController` → `[YukimoHostFactory makeRootViewController]` → `UIHostingController(rootView: YukimoRootView())`. `YukimoRootView` now switches `.main` to `YukimoMainTabView()` (replaced the old `YukimoMainPlaceholderView`). `MainPlaceholderView.swift` is dead code retained on disk; not referenced from anywhere.

## Phase 5 ship log (2026-06-03)

### New Obj-C++ bridges (all .h are pure Obj-C, all C++ lives in .mm)

| Bridge | Swift surface | libanixart endpoints used |
| --- | --- | --- |
| `YukimoReleaseDetailBridge` (`ReleaseDetailBridge`) | `loadRelease(id:)`, `loadEpisodeTypes(releaseID:)`, `loadEpisodeSources(releaseID:typeID:)`, `loadEpisodes(releaseID:typeID:sourceID:)`, `setListStatus(_:releaseID:)`, `setFavorite(_:releaseID:)` | `releases().get_release`, `episodes().get_release_types/sources/episodes`, `releases().add/remove_release_to_profile_list`, `releases().add/remove_release_to_favorites` |
| `YukimoSearchBridge` (`SearchBridge`) | `searchReleases(query:page:)`, `recentSearches()`, `addRecentSearch(_:)`, `removeRecentSearch(at:)` | `search().release_search(SearchRequest{Basic, query}, page)`; history reads/writes via `AppDataController.getSearchHistory/addSearchHistoryItem/removeSearchHistoryItemAtIndex` |
| `YukimoLibraryBridge` (`LibraryBridge`) | `loadList(status:sort:page:)` | `releases().my_profile_list(ListStatus, ListSort, page)` for Watching/Plan/Watched/HoldOn/Dropped; `releases().profile_favorites(myID, sort, 0, page)` for Favorites |
| `YukimoEpisodeDTO` (`EpisodeTypeDTO`, `EpisodeSourceDTO`, `EpisodeDTO`) | Read-only DTOs | wraps `anixart::EpisodeType`, `EpisodeSource`, `Episode` |
| `YukimoListStatus.h` (header-only) | `YukimoListStatus` + `YukimoListSort` `NS_ENUM`s | maps to `anixart::Profile::ListStatus` / `ListSort` in bridge files; `Favorite = 100` is a synthetic value for the favorites endpoint |

### New SwiftUI surface

`Yukimo/Features/Main/`:
- `Details/AnimeDetailsView.swift` — backdrop header, poster overlay, title (RU + original), meta chips (rating/year/episodes/genres), CTA row (Watch / Favorite / Add to list via confirmationDialog), description with expand, episode type strip + source strip + episode list. Tap on episode → SFSafariViewController (Kodik/Libria embed URL) via `IdentifiableURL` sheet.
- `Details/AnimeDetailsViewModel.swift` — `@Observable @MainActor`. Cascading load: release → types → sources → episodes. Mutations re-fetch release to surface updated `isFavorite` / `profile_list_status` from server.
- `Search/SearchTabView.swift` — custom search field (not SwiftUI `.searchable` because we want the field in the body, not in toolbar, for consistent paddings + animated focus). Recent searches from `AppDataController` via `SearchBridge`. Results as adaptive `LazyVGrid` of `PosterCard`s; each is a `NavigationLink(value: ReleaseRoute(...))`.
- `Library/LibraryTabView.swift` — segmented status strip (6 pills), grid of posters per status, refreshable, reloads on `onChange(of: status)`. `Favorite` pill calls `profile_favorites` instead of `my_profile_list`.

### Navigation

Each tab in `YukimoMainTabView` wraps its content in `NavigationStack(path: $tabPath)` with `.navigationDestination(for: ReleaseRoute.self) { route in AnimeDetailsView(releaseID: route.releaseID) }`. Poster cards in Home rails, ContinueWatchingCards, Search grid, and Library grid are all `NavigationLink(value: ReleaseRoute(releaseID: r.releaseID))`. Back nav is native swipe + chevron.

`ReleaseRoute` is a tiny `struct { let releaseID: Int64 }: Hashable`. Using a typed wrapper instead of bare `Int64` prevents accidental matches with unrelated `Int64` destinations in the same NavigationStack.

### Things that worked but weren't obvious

- `EpisodeTypeID(typeID)` / `EpisodeSourceID(sourceID)` / `ReleaseID(releaseID)` — the StrongTypedef wrappers accept implicit construction from `int64_t` inside the bridge `.mm` files; from Swift we just pass plain `Int64`.
- `confirmationDialog` for "Add to list" — gives us a native iOS sheet with 5 list states + destructive "remove" without writing a custom sheet.
- For the episode tap I went with `SFSafariViewController` instead of trying to wire up the existing AVKit Kodik flow. The legacy Obj-C player needs source/type/episode triplet plus its own parser; bringing it in is a Phase 6 problem. Until then, Safari renders the Kodik embed fine.

### Build commands unchanged

Same as Phase 3 (see above). Result on Sabirov (iOS 26.3.1) after this round: build succeeded, app installed at `/var/containers/Bundle/Application/61A5A2D7-.../AniAngliaXIX.app`, launched.

## Phase 6 ship log (2026-06-03) — UI polish + built-in player

### UI fixes shipped

- **HeroCard locked size.** Wrapped the inner ZStack in `GeometryReader` and forced `width × (width × 11/16)`. No more reflow between `redacted` skeleton and loaded data.
- **AnimeDetails compact header.** Old 16:12 backdrop replaced by a 200pt-fixed backdrop + 80×120 floating poster that peeks below it (offset y: 32, total header 232pt). Content (title, stats, actions) is reachable in the first viewport on iPhone.
- **Search + Library → vertical list of `ReleaseRowCard`s.** Replaced both `LazyVGrid` with `LazyVStack(spacing: sm)` of horizontal cards (64×96 poster + title + meta + genres + chevron). Horizontal screen padding dropped from `screenPadding (20)` to `md (12)` for both — more breathing room and edge-to-edge feel.
- **StatStrip + GenresChipsRow** (`Yukimo/Features/Main/Details/Components/StatStrip.swift`). Replaces the mixed horizontal pill scroll in AnimeDetails. Stat cells equal width: rating, year, episodes, status — each with icon + bold value + tiny secondary label. Genres pulled into a dedicated coral-tinted chip strip below, with a "Жанры" label header.
- **`PickerRow` + `TypePickerSheet` + `SourcePickerSheet`** (`SourcePickerRow.swift`). Replaces the cramped horizontal source/type pill rows. Each picker is a glass row showing label + currently selected (with subtitle = episodes count), tap opens a sheet with full list including episodes count and workers (for types). `.disabled(...) if count <= 1`.

### Player

| File | Provides |
| --- | --- |
| `Yukimo/Bridge/YukimoStreamDTO.{h,mm}` | `StreamVariantDTO`: `quality`, `url`, `height` (parsed int from quality string; non-numeric like `"hls"` → 0) |
| `Yukimo/Bridge/YukimoPlayerBridge.{h,mm}` | `PlayerBridge`: `resolveStreams(releaseID:sourceID:position:)`, `resolveStreams(embedURL:)`, `markWatched(releaseID:sourceID:position:)` |
| `Yukimo/Features/Main/Player/YukimoPlayerView.swift` | SwiftUI player wrapping `AVPlayerViewController`. Floating glass top bar with title + episode position + quality button. `confirmationDialog` for quality switch. |

#### How quality resolution works

1. `PlayerBridge.resolveStreams(releaseID, sourceID, position)` calls `api->episodes().get_episode_target(rid, sid, pos)` to get the Episode embed URL.
2. Runs `[[LibanixartApi sharedInstance] getParsers]->extract_info(embed_url)` — same code path the legacy `PlayerController` uses. Returns `std::unordered_map<std::string, std::string>` of `{ quality_key → playable_url }`.
3. Maps to `[StreamVariantDTO]` and **sorts by descending height**; non-numeric qualities (`hls`, `master`) come last.
4. SwiftUI picks 720p when available, else highest numeric, else first item.
5. Quality switch keeps playback position: `previousTime = player.currentTime()` → `player.replaceCurrentItem(with: AVPlayerItem(url: newURL))` → `player.seek(to: previousTime, tolerance: .zero)` → resume if was playing.

#### Player UX choices

- Native `AVPlayerViewController` provides scrubber/AirPlay/PiP/fullscreen/transport controls — we do **not** rebuild any of those.
- `AVAudioSession.setCategory(.playback)` set in `.task` before `model.load()` so audio works with silent switch + background.
- `markWatched()` fires on `.onDisappear` — best-effort, never blocks dismissal.
- `fullScreenCover(item: PlayerSession)` from AnimeDetailsView; the `Identifiable` value carries `sourceID + position`.

#### Skipped (Phase 6 → Phase 7)

- Player doesn't yet handle "Up next" / auto-advance to next episode.
- No skip-intro feature even though `AppSettingsDataController.getDefaultSkipTime` exists in legacy storage.
- `EpisodeTypeID` + variant kept simple — the bridge always uses the user's `selectedSourceID` from details. A future iteration could let the player itself switch source mid-watch.

### Bridge surface delta after Phase 6

Bridging header now exports: AuthBridge, SessionBridge, SettingsBridge, ReleaseDTO, ProfileDTO, EpisodeTypeDTO/SourceDTO/EpisodeDTO, YukimoListStatus/Sort enums, HomeBridge, ProfileBridge, ReleaseDetailBridge, SearchBridge, LibraryBridge, **StreamVariantDTO**, **PlayerBridge**.

### Result on Sabirov

`** BUILD SUCCEEDED **` for both simulator (iPhone 17 Pro) and device (`00008110-0012289414C0A01E`, iOS 26.3.1). App installed at `/var/containers/Bundle/Application/55F8100C-.../AniAngliaXIX.app`, launched via `devicectl device process launch`. Hero card locked, list views compact, dub/type pickers redesigned, episode tap opens the built-in player with quality selection.

## Phase 7 ship log (2026-06-03) — list slim-down, details hero, custom player

### List card simplified

`ReleaseRowCard` now: poster · title (bold, 2 lines) · rating row (★ value) · 2-line description snippet. Removed original title, meta line, genres chip line, chevron. Description goes through a cheap HTML cleanup (`<br>`, `&nbsp;`, `&amp;`, `&quot;`) before being shown.

`displayTitle`/`statusLabel`/`statusTint` extensions on `ReleaseDTO` consolidated into `ReleaseRowCard.swift`. The duplicate in `PosterCard.swift` was removed — leaving both compiles fails with "invalid redeclaration".

### Details hero — premium stretched-blur look

`Yukimo/Features/Main/Details/Components/DetailsHero.swift`. Single image rendered twice:
1. **Stretched blurred backdrop** — `aspectRatio(.fill)` + `blur(radius: 60, opaque: true)` + `scaleEffect(1.15)` (hides blur edges that creep past the frame) + saturation boost + coral-to-dark gradient wash.
2. **Sharp centered poster** on top — 140×210, white border, soft shadow.
3. Title (centered, white, with shadow), original (centered, dim white), genres scroll (white-glass chips) all on the blurred surface.

Layout in `AnimeDetailsView`: hero is 460pt tall, then `StatStrip` floats upward via `offset(y: -36)` + `padding(.bottom, -36)` so the tiles overlap into the bottom of the hero — like the album page in Apple Music. The view also sets `ignoresSafeArea(edges: .top)` and `toolbarBackground(.hidden, for: .navigationBar)` + `toolbarColorScheme(.dark, for: .navigationBar)` so the back chevron stays readable on top of the blurred backdrop.

### Single Озвучка picker

`Тип серий` dropped from Details. Only one `PickerRow` rendered with `label: "Озвучка"`. The active `selectedTypeID` is still set by `AnimeDetailsViewModel` (picks first type automatically); the type can be changed later inside the player if needed.

### Custom player — full rewrite

Files (`Yukimo/Features/Main/Player/`):

| File | Purpose |
| --- | --- |
| `PlayerLayerHost.swift` | `UIViewRepresentable` wrapping a tiny `UIView` whose `layerClass` is `AVPlayerLayer`. Zero native controls — pure surface. |
| `YukimoScrubber.swift` | Custom 4 → 6pt track with coral gradient, 14 → 18pt white thumb on drag, `DragGesture(minimumDistance: 0)`, callbacks `onScrubStart/Change/End`. |
| `YukimoPlayerModel.swift` | `@Observable @MainActor` state — owns `AVPlayer`, episode list, source list, quality variants, scrub time, periodic time observer, end-of-item observer. |
| `YukimoPlayerView.swift` | Full SwiftUI overlay: tap-to-toggle controls, auto-hide after 3.5s of inactivity while playing, top bar, center play/pause + skip ±10s, bottom deck with prev/next episode + Озвучка/Серии/Качество pill row, scrubber with time labels. Bottom-sheet pickers (`PlayerSourceSheet`, `PlayerEpisodesSheet`, `PlayerQualitySheet`). |

#### Behaviour

- Controls hide automatically only when **playing** and **not scrubbing**. Any control interaction calls `bumpAutoHide()` to reset the 3.5s timer.
- Quality swap preserves time: `previousTime = player.currentTime()` → `replaceCurrentItem(with:)` → `seek(to:tolerance: .zero)`.
- Source swap re-fetches episode list for the new source, attempts to preserve the same numeric position; falls back to first episode.
- `markCurrentWatched()` fires on episode end AND on `teardown()` (i.e. `.onDisappear`). End-of-item observer auto-advances to the next episode if any.
- `isScrubbing` toggled during drag — the periodic time observer respects it so the thumb doesn't fight the user's drag.
- `selectedSourceID + selectedTypeID + initialPosition + initialEpisodes/Types/Sources` are passed from Details — no double-fetch on player open.
- `persistentSystemOverlays(.hidden)` + `statusBarHidden(true)` clear status bar + home indicator for full immersion.

#### Why custom

`AVPlayerViewController.showsPlaybackControls = false` would let us put SwiftUI overlay on top of the native player, but the native control surface still receives taps in some areas and creates the exact overlap the user complained about. Going to `AVPlayerLayer` directly eliminates that conflict.

### Bridge unchanged this round

No new Obj-C++ bridges. Everything works against the existing `PlayerBridge` / `ReleaseDetailBridge`.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator (iPhone 17 Pro) + device. Installed at `/var/containers/Bundle/Application/F63E9B0A-.../AniAngliaXIX.app`. Launched.

## Phase 8 ship log (2026-06-03) — screenshots, progress save, episode list fix

### DTO + bridge

`YukimoReleaseDTO.screenshotURLs: NSArray<NSString *>` — added in `.h` + `.mm` + `+fromRelease:` factory, fed from `anixart::Release::screenshot_image_urls`. Empty entries filtered out. Surfaced to Swift as `[String]`.

### Local progress store

`Yukimo/Features/Main/Player/YukimoProgressStore.swift` — UserDefaults-backed, keyed `yukimo.progress.<releaseID>.<sourceID>.<position>`. Stores `{ seconds, duration, savedAt }` as JSON. Writes happen on a background dispatch queue so the player thread never blocks.

API:
- `save(releaseID:sourceID:position:seconds:duration:)`
- `resumeSeconds(releaseID:sourceID:position:)` — returns the saved seconds only if it's a useful resume point (`5s ≤ saved ≤ duration − 15s`); `nil` otherwise.
- `clear(releaseID:sourceID:position:)` — called on end-of-item.

### Player integration

`YukimoPlayerModel`:
- `@ObservationIgnored lastProgressSave: Date` + `pendingResumeSeconds: Double?` added.
- On `applyVariant(resumeFromZero: true)` — looks up the resume point and stashes it as `pendingResumeSeconds`. The periodic time observer applies the seek the first time AVPlayer reports a finite, non-zero duration (since the seek would otherwise no-op before the asset loads).
- Periodic time observer also saves progress every 5 wall-clock seconds while playing and not scrubbing.
- `playEpisode(at:)` and `teardown()` both save final progress before closing.
- End-of-item handler calls `clear(...)` for the current episode so a fully-watched ep doesn't trigger a useless resume on next open.

### Episode list fix — "грузится только одна серия"

Two changes:
1. **SwiftUI ForEach IDs switched from `episodeID` → `position`.** The libanixart `Episode::id` field has been observed to come back identical for multiple episodes from some sources; ForEach was using it as a Hashable identity and collapsing the list into a single row. Position is unique per `(release, type, source)` and stable across re-fetches.
2. **`YukimoPlayerModel.refetchEpisodes()`** called from `configure()`. Even when Details already loaded episodes, the player re-fetches as a safety net. Best-effort: on failure the inherited list is kept.

Both `AnimeDetailsView.episodesBlock` and `PlayerEpisodesSheet` use `id: \.position`.

### UI changes

- **Hero card scrim** stiffened: 5-stop gradient (clear → clear at 40% → 0.45 black at 70% → 0.80 at 92% → 0.90 at 100%). Title/CTA legible on any poster.
- **DetailsHero spacing**: removed the redundant `Spacer(minLength: 28)` and the inner `VStack(spacing: 4)` for title. Single bottom-anchored VStack with `spacing: YukimoSpacing.sm`, poster gets `padding(.bottom, sm)`, genres get `padding(.top, 2)`. Bottom padding `md`. The gap below genres is now visually balanced against the StatStrip that floats up via `offset(y: -36)`.
- **Озвучка picker removed from Details.** Selection happens entirely inside the player. `selectedSourceID`/`selectedTypeID` are still set in `AnimeDetailsViewModel` by the type/source cascade — the player inherits the initial choice and lets the user change it via the bottom sheet.
- **`ScreenshotsBlock`** added between description and episodes. Horizontal 220×124 thumbnails (16:9), each with a small number badge. Tap opens `ScreenshotsViewer` — a fullScreenCover with paged `TabView`, tap-to-dismiss, top-right × button, "N / M" counter at the bottom.
- Renders nothing when the release has no screenshots — no padded empty space.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/EFD66A14-.../AniAngliaXIX.app`. Launched.

## Phase 9 ship log (2026-06-03) — episode count fix + layout cleanup

### Root cause of "only one episode loads"

It wasn't the bridge or SwiftUI ID — both were correct. The issue was the **auto-pick logic** in `AnimeDetailsViewModel`. Many releases on Anixart list an unwatchable PV / трейлер / эпизод-0 source first, with `episodes_count == 1`. The view-model was always picking `types.first` and then `sources.first`, so for those titles the player loaded one-episode "trailer" sources even when the real 25-episode dub was right next to it in the list.

Fix:
- `preferredType(_:)` returns the `EpisodeTypeDTO` with the highest `episodesCount` (ties broken by API order).
- `preferredSource(_:)` does the same for `EpisodeSourceDTO`.
- `loadEpisodeTypes()` calls `preferredType`, then `selectType` calls `preferredSource`.
- `YukimoPlayerModel.refetchEpisodes()` does the same swap defensively before re-fetching, in case Details inherited a stale choice.

### Layout — full Details redesign

The previous design floated `StatStrip` up via `offset(y: -36)` so the stat tiles overlapped the bottom of `DetailsHero`. With genres rendered inside the hero, the chips peeked out behind the tiles (visible in the user's screenshot as "су…" leaking past the rightmost tile). Cleaned up:

- **`DetailsHero` now contains nothing but the blurred backdrop + centered poster.** Poster sticks below the backdrop edge via `offset(y: posterSize.height * 0.35)` for a floating feel. Backdrop height is 220pt; poster 150×225.
- **Title / original / genres / stats / actions all live below on the light surface.** No negative offsets, no overlap. The first content block under the hero (`titleBlock`) has `padding(.top, 84)` to give the floating poster room.
- **Genres rendered as their own strip on light surface** with coral chips on `softPink`. No more on-dark variant inside the hero.
- **`StatStrip` rendered at normal `screenPadding` with no offset.**

The hero now serves purely as atmosphere; all functional content sits on a clean, readable light surface below.

### Home hero card

`HeroCard.aspectRatio` changed from **16:11 (1.45)** → **5:4 (1.25)**. About 16% more height on a phone — more visual presence for the daily recommendation without dominating Home.

### Episode list rendering

Both `AnimeDetailsView.episodesBlock` and `PlayerEpisodesSheet` now use `ForEach(Array(episodes.enumerated()), id: \.offset)` — an index-based identity that is guaranteed unique regardless of whether the parser returns duplicate `episodeID` or `position` values for any source.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/9DD83716-.../AniAngliaXIX.app`. Launched.

## Phase 10 ship log (2026-06-03) — orientation lock, PiP, per-episode progress, donut chart

### DTO additions

- `YukimoReleaseDTO.category: YukimoReleaseCategory` — `Unknown / Series / Movies / Ova`. Swift extensions add `categoryLabel` ("Сериал" / "Фильм" / "OVA / ONA") and `categoryIcon` (`tv` / `film.fill` / `play.tv`).
- `YukimoProfileDTO.holdOnCount` + `droppedCount` — the two list buckets that were missing from the donut chart. Pulled from `anixart::Profile::hold_on_count / dropped_count`.

### Orientation lock

`Yukimo/App/YukimoOrientationLock.swift` — `@objc` global singleton with `var allowed: UIInterfaceOrientationMask = .portrait` + `setPortrait()` / `setLandscape()` helpers. The setter both flips the mask and calls `UIWindowScene.requestGeometryUpdate(.iOS(interfaceOrientations:))` (iOS 16+) so the rotation happens immediately.

`AppDelegate.mm` imports `AniAnglia-Swift.h` and implements:
```objc
- (UIInterfaceOrientationMask)application:(UIApplication *)application
   supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return [YukimoOrientationLock shared].allowed;
}
```

Player calls `YukimoOrientationLock.shared.setLandscape()` in `.task` (before loading streams) and `setPortrait()` in `.onDisappear`. Everything else in the app stays portrait-only.

### PiP

`PlayerLayerHost` now exposes an `onPiPReady` callback. On `makeUIView` it creates an `AVPictureInPictureController(playerLayer:)`, sets `canStartPictureInPictureAutomaticallyFromInline = true`, and hands the controller to SwiftUI via `DispatchQueue.main.async`. `YukimoPlayerView` stores it in `@State private var pipController` and renders a `pip.enter` glass icon button at the top-right of the player top bar. Tap → `pip.startPictureInPicture()` if `isPictureInPicturePossible`. `Info.plist` already had `UIBackgroundModes` → `audio`.

### Episode numbering from 1

Both `AnimeDetailsView.episodeRow` and `PlayerEpisodesSheet.rowFor` now display `displayNumber: idx + 1` (where `idx` is the index from `Array(episodes.enumerated())`). The actual `Episode::position` value is still used for API calls (`get_episode_target`, progress store keys, `playEpisode(at:)`). Player top bar label uses `episodeButtonLabel` which finds the current episode's index and returns `"Серия \(index + 1)"`.

### Per-episode progress display

Both episode lists now render a coral progress capsule under the row and a `clock.arrow.circlepath` "С 14:23" label whenever `YukimoProgressStore.shared.load(...)` returns a saved point with > 5s and no full-completion. Server-watched flag still shows the green "Просмотрено" badge.

### Watched-on-exit (instant UI)

`AnimeDetailsViewModel` got:
- `locallyWatchedPositions: Set<Int>`
- `isEpisodeWatched(_:)` — server flag OR local set
- `markEpisodeWatched(at:)`
- `refreshAfterPlayer() async` — re-fetches the episode list for the current `(typeID, sourceID)` to catch the authoritative `is_watched` flip the server made when the player called `add_watched_episode`.

`AnimeDetailsView.fullScreenCover(item:onDismiss:)` calls `vm.markEpisodeWatched(at: lastPlayedPosition)` synchronously and then kicks off `vm.refreshAfterPlayer()`. The UI shows the watched marker immediately and updates the rest when the network call returns.

### Details — pure Column rewrite

The hero is just an atmosphere strip (140pt). All content (poster, title, original, category badge, genres, stat tiles, action row, description, screenshots, episodes) lives below it as **sibling rows in a single VStack** with explicit `.padding(.top, ...)` between them. **No ZStack overlaps, no negative offsets, no floating views.** The poster and StatStrip are normal block children — guaranteed unable to overlap with title or genres no matter the screen size.

### Profile donut chart

`Yukimo/Features/Main/Tabs/ProfileDistributionChart.swift` — Swift Charts `SectorMark` donut (innerRadius 0.62, angularInset 2, cornerRadius 6). Six slices: Смотрю / В планах / Просмотрено / Отложено / Брошено / Любимое. Zero-count slices are filtered out so an empty user doesn't render a stripe of color. Center label shows total titles. Legend below with colored dot · label · count · percent.

`ProfileTabView` now: avatar → stats grid (added Отложено tile) → chart card → logout. Wrapped in YukimoSurfaceCard-styled rounded surface.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/D827FF88-.../AniAngliaXIX.app`. The launch step reported "device locked" (cosmetic — install succeeded). The new build is on the device, ready when the user unlocks.

## Phase 11 ship log (2026-06-03) — details polish

### Layout: poster + title row, left-aligned

Replaced the centered poster + centered title + standalone category badge with a single `posterTitleRow(release)` view. `HStack(alignment: .top, spacing: md)`:
- 120×180 poster on the leading edge with `RoundedRectangle(YukimoRadius.md)`, soft border, drop shadow.
- Title block on the right, all `alignment: .leading`:
  - **Category as small-caps label above the title** — `.font(.system(size: 11, weight: .bold, design: .rounded)) + .textCase(.uppercase) + .tracking(1.2) + .foregroundStyle(YukimoColor.primaryCoral)`. "ТВ Сериал" → renders as "ТВ СЕРИАЛ" with letter spacing. Replaces the chip that used to sit between original title and genres.
  - Title (YukimoTypography.title2, leading multiline, up to 3 lines).
  - Original (subhead, secondary, up to 2 lines).

The standalone `categoryBadge` helper and `centeredPoster` / `titleBlock` helpers are gone. `categoryLabel` for `Series` changed from "Сериал" to "ТВ Сериал".

### Backdrop fade

`backdropBar(_:)` rewritten:
- Base layer = `YukimoColor.background` (so the bottom of the blurred image dissolves seamlessly into the page).
- Blur **lowered from 60 → 40**; saturation **lowered from 1.25 → 1.10**.
- The image gets a `.mask(LinearGradient(stops: [white@0, white@0.55, clear@1]))` so opacity tapers smoothly from full at top → fully transparent at bottom → revealing the page background underneath.
- A separate `LinearGradient` darken overlay (`black@0.40 → black@0.30 → black@0.0`) sits on top. Darker than before but with its own bottom fade so it doesn't bleed onto the content below.
- Backdrop height bumped from 140pt → 180pt to give the fade more room.

The net effect: a slightly darker, slightly less blurry header that smoothly dissolves into `YukimoColor.background` at the bottom — no hard seam between hero and content.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/B38F0B70-.../AniAngliaXIX.app`. Launched.

## Phase 12 ship log (2026-06-03) — rate flow, avatar upload, details UX rework

### Bridge surface additions

| Method | libanixart endpoint |
| --- | --- |
| `ReleaseDetailBridge.vote(releaseID:stars:)` | `releases().release_vote(rid, stars)` (or `delete_release_vote` when `stars == 0`) |
| `ProfileBridge.editAvatar(jpegData:)` | `profiles().edit_avatar(std::filesystem::path)` — writes JPEG to `NSTemporaryDirectory()/yukimo-avatar-UUID.jpg`, dispatches, then cleans up |
| `ReleaseDTO.myVote: NSInteger` | `anixart::Release::my_vote` — `0` means not voted, otherwise `1..5` |

The avatar API only accepts JPEG (`.png` / `.jpeg` rejected upstream) — the Swift side converts whatever the user picked to JPEG with `UIImage.jpegData(compressionQuality:)` after downsizing to a max edge of 1024pt.

### Profile — chart-only with editable avatar

`ProfileTabView` rewritten:
- Removed the redundant `statsGrid` (every number it showed is duplicated in the chart legend).
- Header now: `PhotosPicker(selection: $photoPick, matching: .images)` wrapped around the 112pt circular avatar. On the avatar's bottom-right corner: a 36pt white circle with a `pencil` icon (turns into a spinning `arrow.triangle.2.circlepath` during upload via `.symbolEffect(.rotate, options: .repeating, isActive:)`).
- During the upload the avatar gets a black scrim + centered `ProgressView`. After success `avatarRefreshKey` (a `UUID` State) is flipped and applied via `.id(...)` so `YukimoAsyncImage`'s internal cache treats it as a fresh fetch — even when the URL is identical.
- After header: `ProfileDistributionChart`, then "Выйти" button.

`ProfileTabViewModel.uploadAvatar(_ jpegData:)` calls `ProfileBridge.editAvatar` and reloads the profile on success.

### Details — new content order under the title

Following 2025-26 streaming-app best practice (Apple TV+, Crunchyroll v3, HiAnime). The order under the poster+title row is now:

1. **Inline metadata line** — `"2024 · 25/25 серий · Онгоинг"` rendered as dot-separated subhead text, no tile chrome. Replaces the heavy `StatStrip` tiles.
2. **Genres** — coral chips (unchanged).
3. **DetailsActionRow** — primary CTA + secondary icon row:
   - Full-width `Смотреть` button.
   - Below: a 3-cell row of vertical icon labels with rounded surfaces — `bookmark.fill` "В список" (`Menu` with sections "В список" + destructive "Удалить из списка"), `star` "Оценить" (opens rating sheet), `heart` "Любимое". Selected state tints the icon coral and swaps the background to `softPink`. `symbolEffect(.bounce)` on state change.
   - The old `confirmationDialog` for list status is gone — `Menu` is the modern iOS pattern (Letterboxd / Goodreads / Crunchyroll 2024).
4. **Aggregate rating row** — `★ 4.9 · 12k оценок` left-aligned, `"Оценить"` ghost button on the right (so the rating action exists in two spots — the inline ghost button is a fast tap, the action row is more visible).
5. **SynopsisBlock** — 3-line clamp with a `LinearGradient(clear → background)` fading edge over the bottom 28pt. Tap anywhere on the text expands with `.spring(response: 0.45, damping: 0.78)`. No "Read more" button — the fade IS the affordance (Apple TV+ pattern). Cheap HTML cleanup applied.
6. **Screenshots** (unchanged).
7. **Episodes** (unchanged — index-based IDs, per-episode progress capsule).

### RatingSheet

`Yukimo/Features/Main/Details/Components/RatingSheet.swift` — the canonical "tap to rate" sheet pattern (App Store + Apple Podcasts). Drag handle, header, aggregate hint, 5 large `star.fill` buttons (38pt) with `.symbolEffect(.bounce, value:)` on tap. Shows the rating's meaning ("Не понравилось" / "Шедевр" etc.). "Поставить оценку" disabled until a star is picked; if the user already voted, "Убрать оценку" destructive secondary appears. Presents as `.medium` detent.

`AnimeDetailsViewModel.voteRelease(_ stars:)` calls the bridge, re-loads the release on success so the new `myVote` and updated aggregate `grade` propagate.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/EC34CFC3-.../AniAngliaXIX.app`. Launched.

## Phase 13 ship log (2026-06-03) — list status, wrap genres, profile fix, search filters

### Bridge additions

| Surface | What |
| --- | --- |
| `YukimoReleaseDTO.listStatus: NSInteger` | Maps `anixart::Profile::ListStatus` to 0..5 (0=NotWatching, 1=Watching, 2=Plan, 3=Watched, 4=HoldOn, 5=Dropped). Swift extension `listStatusLabel` ("Смотрю" / "В планах" / …) + `listStatusIcon`. |
| `YukimoSearchFilter.{h,mm}` | Pure-ObjC `SearchFilterDTO` wrapping every optional field of `anixart::requests::FilterRequest` — sort, year range, season, status, category, genres, age ratings. Used by the new filter search. |
| `SearchBridge.filterSearch(filter:page:completion:)` | Calls `api->search().filter_search(FilterRequest{...}, /*extended_mode*/ false, page)`. Builds the FilterRequest from the DTO. |
| `SearchBridge.availableGenres()` | Returns `LibanixartApi.getGenresArray()` — the canonical 45-name RU genre list. |

### Profile — chart-only, fixed avatar upload

The file had been quietly reverted to the old statsGrid version between Phase 12 and now (probably an editor race). Rewrote it once more, definitively this time:
- `statsGrid` and `statCard` deleted.
- `PhotosPicker(matching: .images)` wraps the avatar with `.contentShape(Circle())` so the whole disc is tappable.
- `YukimoImageCacheUtil.invalidate(for: urlString)` clears the in-process `NSCache` + the URLCache entry BEFORE and AFTER the upload, so the new image actually appears even if the server returns the same URL.
- `symbolEffect(.rotate)` is iOS 18 — replaced with `.pulse, options: .repeating, isActive:`.
- `YukimoImageCacheUtil` is a top-level enum (not a static on the generic `YukimoAsyncImage<P,F>`, which Swift refused to call without type witnesses).

### `ProfileDistributionChart` — minimal legend

Removed the card wrapping, the chart's title row, and the icon-circles in the legend. Just: donut → six legend rows of `[● colored dot] [label] [percent]`. No counts (the slice angles already encode them). No surface chrome. Visually it now reads as "chart + key", not "card + tiles".

### Details polish

- **Title-block metadata strip** — `★ 4.9 · 2024 · 25/25 сер. · Онгоинг` rendered as one dot-separated `footnote` line under the original title, inside the right column of the poster+title HStack. Replaces the old standalone metadata line under the poster.
- **Aggregate rating row removed** — duplicate of the metadata strip + already accessible via the action row's star button.
- **Genres are now a wrap** — `YukimoFlowLayout`, custom `Layout` impl. Chips lay out left-to-right, wrapping to a new row when the line is full. No horizontal scroll. (Replaces the old `ScrollView(.horizontal)`.)
- **`DetailsActionRow.bookmark` shows current list** — when `release.listStatus != 0`, the icon flips to the matching filled SF Symbol (`play.fill` for Watching, `bookmark.fill` for Plan, `checkmark.circle.fill` for Watched, etc.) AND the caption becomes the status label ("Смотрю" / "В планах" / …). Menu items get a `checkmark` symbol next to the currently active list. "Удалить из списка" only appears when the release IS in a list.

### `YukimoFlowLayout`

New `DesignSystem/Components/YukimoFlowLayout.swift` — custom `Layout` impl with `hSpacing` / `vSpacing`. Computes row breaks lazily, places subviews row by row. Used by genres in Details and by the genre multi-select in the filter sheet.

### Search filters

`Yukimo/Features/Main/Search/SearchFiltersSheet.swift`:
- Filter struct `YukimoSearchFilters` (`Equatable`) with: sort, startYear, endYear, status, category, season, genres set.
- `Form` sections: Сортировка (Picker.menu), Год (two `Stepper`s, 0 = unset), Тип, Статус, Сезон (each Picker.menu), and Жанры — `YukimoFlowLayout` of toggle-chips backed by `availableGenres`.
- Toolbar: "Сброс" (destructive, disabled when empty), "Готово".
- Sheet detents `.medium, .large`, drag indicator.

`SearchTabView`:
- Search bar gets a sibling 52pt **filter button** with `slider.horizontal.3`. Coral fill + white badge with applied-filter count when any filter is active.
- Below the search bar, when filters are non-empty: a horizontal scroll of coral chips listing every applied filter + "Очистить" trailing ghost button.
- VM auto-runs search via `.onChange(of: vm.filters)`.
- For "filter-only" (empty query), VM calls `SearchBridge.filterSearch(...)`; for free-text it still calls `searchReleases(query:page:)`.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/082565D4-.../AniAngliaXIX.app`. Launched.

## Phase 14 ship log (2026-06-03) — optimistic overrides, yellow rating, hide-empty rails

### Optimistic state overrides

`AnimeDetailsViewModel` now keeps `localListStatus: Int?` and `localMyVote: Int?`. The mutations set the override **before** the bridge call, so the UI flips immediately. `loadRelease()` runs afterwards to pick up the server's authoritative state, but the override survives because the server's `profile_list_status` / `my_vote` fields sometimes come back as 0 right after a write (server-side propagation lag — observed on Anixart specifically).

`effectiveListStatus()` / `effectiveMyVote()` return `local ?? release.field` and are the only values the view reads.

`DetailsActionRow` no longer reads `release.listStatus` or `release.myVote` directly — it takes `currentListStatus: Int` and `currentVote: Int` as parameters. The bookmark cell's icon and caption flip to "Просмотрено" / "Смотрю" / "В планах" / etc the moment the user taps. The rate cell does the same.

### Yellow rating everywhere

- **Title-block metadata strip** rewritten: rating is now an HStack of `Image(systemName: "star.fill")` + the value (both `.foregroundStyle(.orange)`, `.bold`, `.rounded` design). The rest of the strip — year · episodes · status — stays gray (`textTertiary`). The rating reads at a glance.
- **Rate action button** — when `currentVote > 0`, the `iconLabel` helper takes an `accent: .orange` parameter that swaps the chip background from coral-soft-pink to orange-tinted (`orange.opacity(0.18)`), strokes the chip in orange, and tints both icon and label orange. The default coral path is untouched, so list/favorite stay coral-themed.

### Empty rail = render nothing

`PosterRail` now returns `EmptyView()` when `items.isEmpty && !isLoading` — the user complained about Recommendations rendering an empty placeholder when the recommender returned nothing. The loading-skeleton branch still appears while fetching.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/E8962187-.../AniAngliaXIX.app`. Launch attempt returned the harmless "device locked" error — install is on the device, ready when unlocked.

## Phase 15 ship log (2026-06-03) — InfoStrip, GenresSection, friendly error state

### `InfoStrip`

`Yukimo/Features/Main/Details/Components/InfoStrip.swift` — a row of four equal-width stat tiles that takes over from the cramped inline metadata strip in the title block:
- **Rating tile** — yellow accented (`.foregroundStyle(.orange)`, `orange.opacity(0.12)` background, `orange.opacity(0.35)` stroke). Star icon + bold rating + secondary "12k оценок" label.
- **Year tile** — calendar icon (lavender accent), bold year, "Год" label.
- **Episodes tile** — `play.rectangle.fill` (sky accent), "25/25", "Серий".
- **Status tile** — status-specific icon (`antenna.radiowaves.left.and.right` / `checkmark.seal.fill` / `hourglass`) tinted by `release.statusTint`, label "Статус".

Tiles use `RoundedRectangle(YukimoRadius.md)` with `0.5pt` stroke. The rating tile is visually distinct so it doesn't disappear next to the neutral year/episodes/status trio.

### `GenresSection`

Standalone block — `Label("Жанры", systemImage: "tag.fill")` header + `YukimoFlowLayout` wrap of coral chips. Now lives BELOW the action row and ABOVE description (genres are secondary discovery info, not part of the at-a-glance stat panel).

### New content order under the poster+title row

1. `posterTitleRow` (poster + title block: caps, title, original — no metadata)
2. `InfoStrip` (rating tile + year + episodes + status)
3. `DetailsActionRow` (Watch + List/Rate/Favorite)
4. `GenresSection`
5. `SynopsisBlock`
6. `ScreenshotsBlock`
7. `episodesBlock`

Each numeric metadata now has a dedicated rendering surface; the title block is just the identity strip (category, title, original).

### `LoadFailureState`

`Yukimo/Features/Main/Details/Components/LoadFailureState.swift` replaces the small `YukimoErrorBanner` shown when `vm.releaseError != nil`. New layout:
- Large soft-pink halo with `exclamationmark.icloud` (hierarchical render).
- Title "Не удалось загрузить".
- Body — `friendlyMessage` strips `libanixart::` / `anixart::` prefixes from the error and, if it sees "generic" / "release error", replaces it with: "Сервер вернул ошибку. Это бывает, когда у Anixart проблемы — попробуйте ещё раз через минуту."
- "Попробовать снова" YukimoPrimary button (max width 280pt) that calls `vm.load()`.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/D7EE2BCB-.../AniAngliaXIX.app`. Launched.

## Phase 16 ship log (2026-06-03) — full premium details redesign

### New components (`Yukimo/Features/Main/Details/Components/`)

| File | Purpose |
| --- | --- |
| `DetailsBadge` | Pill badge for hero (`.onDark` / `.onLight`), category + status |
| `AnimeDetailsToolbar` + `DetailsScrollOffsetKey` | Floating glass toolbar (back / share / more), opacity tweens with scroll |
| `AnimeHeroHeader` | Collapsing 480pt hero — blurred backdrop with mask fade, centered 154×231 poster, category+status badges, rounded-bold title, original, quick meta `★ 4.9 · 2024 · 25/25 серий` |
| `AnimeWatchButton` + `AnimeWatchContext` | Rich primary CTA — `.loading` / `.unavailable` / `.startFresh(total)` / `.resume(displayNumber, name, remaining)`. Coral gradient, white play disc, title + subtitle |
| `AnimeSecondaryActionsRow` | List Menu (checkmark on active) · Rate (orange when voted) · Favorite |
| `ContinueWatchingBlock` | Resume card with mini poster, "Серия N · Название", time-remaining label, coral progress bar |
| `EpisodeSourceSummary` | Big chip "Озвучка: AniLibria · 12 серий" + optional secondary "Тип: …" row, tap opens picker sheets |
| `EpisodeRow` | Number tile (green on watched), title, filler/watched/resume labels, coral progress bar, `play.circle.fill` on resume target |
| `EpisodesSection` | Wraps header + summary + LazyVStack + loading/error/empty states |

Deleted: `DetailsHero.swift`, `StatStrip.swift` (dead).

### ViewModel additions

`AnimeDetailsViewModel`:
- `displayNumber(forPosition:)`, `resumeEpisode`, `hasResumeProgress`, `resumeProgress`
- `watchContext: AnimeWatchContext` — combines episode availability + server last-view + local `YukimoProgressStore`
- `currentTypeName` / `currentTypeWorkers` / `currentSourceName` / `currentSourceEpisodeCount`

### Layout

```
ZStack(alignment: .top)
├─ ScrollView (coord-space "detailsScroll")
│   └─ VStack(spacing: 0)
│      ├─ AnimeHeroHeader            (480pt)
│      ├─ AnimeWatchButton           (rich)
│      ├─ AnimeSecondaryActionsRow   (List/Rate/Fav)
│      ├─ ContinueWatchingBlock      (only if resume)
│      ├─ InfoStrip                  (4 tiles)
│      ├─ GenresSection              (flow wrap)
│      ├─ SynopsisBlock | empty
│      ├─ EpisodesSection
│      │   ├─ Header "Серии · N"
│      │   ├─ EpisodeSourceSummary   (taps → picker sheets)
│      │   └─ LazyVStack of EpisodeRow
│      └─ ScreenshotsBlock
└─ AnimeDetailsToolbar (overlay, glass fades in)
```

### Toolbar scroll-fade

`-proxy.frame(in: .named("detailsScroll")).minY` via `DetailsScrollOffsetKey`. Material opacity 0→1 across offset 60→180. Title visibility 0→1 across 320→390 (appears only after hero title is gone).

### Share / Copy link

`ShareLink(item: URL("https://anixart.tv/release/\(id)"))` for share icon. `Menu` → "Скопировать ссылку" behind ellipsis (`UIPasteboard.general.string = ...` + success haptic).

### `ReleaseDTO` fields used

`releaseID`, `titleRu`, `titleOriginal`, `imageURL`, `genres`, `year`, `grade`, `voteCount`, `myVote`, `status`, `category`, `episodesReleased`, `episodesTotal`, `lastViewEpisodePosition`, `lastViewEpisodeName`, `description_`, `isFavorite`, `listStatus`, `screenshotURLs`. Plus full Episode tree. Local: `YukimoProgressStore`, `locallyWatchedPositions`, `localMyVote`, `localListStatus`.

Not yet wired: `studio`, `country`, `director`, `author`, `age_rating`, `duration`, `broadcast`, `season`, `favorite_count`, `watching_count`, `recomended_releases`, `related_releases`, `vote1_count..vote5_count`.

### pbxproj script update

`scripts/yukimo_setup_xcodeproj.rb` now sweeps stale file refs — anything under `AniAnglia/Yukimo/` missing from disk is removed from `PBXFileReference` AND build phases. Fixes "Build input files cannot be found" after deletions.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/0FCADD29-.../AniAngliaXIX.app`. Launch returned the harmless "device locked" error — install is on the device, ready when unlocked.

## Phase 17 ship log (2026-06-03) — toolbar tappability, hero slim-down, player error, title popup

### Toolbar safe area

The outer `.ignoresSafeArea(edges: .top)` on the ZStack was pushing the toolbar BUTTONS under the dynamic island where they were neither visible nor tappable. Removed it; added `.ignoresSafeArea(.container, edges: .top)` only to the inner `ScrollView`. Hero still goes edge-to-edge; toolbar HStack stays in safe area while the `toolbarBackground` continues to extend behind the status bar.

### Hero slim-down

Hero is now 460pt (down from 480). Dropped: status badge + quick meta row (`★ · year · episodes`). What's left: blurred backdrop + centered poster + category badge + title + original. Padding between hero and the Watch CTA bumped `lg → xxxl` (16 → 32pt) so the CTA has visible breathing room.

### Long title popup

`FullTitleSheet.swift` — `.medium` / `.large` detents, drag indicator. Tap on the hero title opens it; full RU and original names are shown in selectable sections. Hero title now `.lineLimit(2) + .truncationMode(.tail)`; original `.lineLimit(1)`.

### InfoStrip removed

The 4-tile rating/year/episodes/status block under the action row is gone — it was duplicating the hero's identity zone. After Watch + secondary actions + optional ContinueWatching, the next block is now Genres.

### Player error z-order

`YukimoPlayerView` was rendering the error overlay BEFORE the controls in the ZStack — controls covered it. Reordered to:

```swift
ZStack {
    Color.black; PlayerLayerHost(...)
    if controlsVisible && model.error == nil {
        controlsScrim; VStack { topBar; ... }
    }
    if model.isLoading { loadingOverlay }
    else if let err = model.error {
        Color.black.opacity(0.65).ignoresSafeArea()
            .contentShape(Rectangle()).onTapGesture {}  // swallow taps
        errorOverlay(err)
    }
}
```

So an error: hides controls, dims the screen, blocks taps to PlayerLayerHost, and shows "Не удалось получить ссылку" with a working "Закрыть" button on top.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/C50EA71A-.../AniAngliaXIX.app`. Launched.

## Phase 18 ship log (2026-06-03) — global watched store, hero polish, source-summary drop

### `YukimoWatchedStore`

`Yukimo/Features/Main/Player/YukimoWatchedStore.swift` — UserDefaults-backed `Set<Int>` of watched episode positions per `releaseID`. **No source dimension** — once an episode is watched in any дубляже, every source treats it as watched. Background queue for writes; JSON-encoded.

Written by:
- `YukimoPlayerModel.markCurrentWatched()` — fires alongside the server API call, every time the player marks watched.
- End-of-item observer in `YukimoPlayerModel` — also persists locally so the offline / lost-network case is covered.

Read by:
- `AnimeDetailsViewModel.isEpisodeWatched(_:)` — ORs server flag with locally-watched set AND with the global store.
- `PlayerEpisodesSheet.rowFor(_:displayNumber:)` — same OR, so switching to a fresh дубляж still shows green badges for everything you've already seen.

### Hero polish

`AnimeHeroHeader` extended:
- **Status pill on poster top-right**: `Circle()` color dot + uppercase tracked label (`ОНГОИНГ` / `АНОНС` / `ЗАВЕРШЕНО`) on `.black.opacity(0.55)` + `.ultraThinMaterial` capsule with `.white.opacity(0.22)` stroke. Dot color: ongoing → success green, finished → near-white, upcoming → lavender.
- **Divider after title**: `Capsule().fill(.white.opacity(0.28))` 44×1.5pt — gives a clean visual break before the meta tokens.
- **Meta row**: `[★ 4.9] · [2024]`. Star bold orange; rating and year are rounded-bold white with subtle black shadow for legibility on the blurred backdrop. Renders only if grade > 0 OR year non-empty.

### EpisodesSection — source summary removed

Per user request, the anime profile no longer shows the «Озвучка: AniLibria · N серий» chip or the secondary «Тип: …» row. The body is just `header` + `content`. Source/type changes are made inside the player via the existing bottom sheets.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/A08B503E-.../AniAngliaXIX.app`. Launched.

## Phase 19 ship log (2026-06-04) — hero compaction, EpisodesSection scrub

### EpisodesSection — really, this time

The previous "drop source summary" edit didn't stick — `body` still rendered `EpisodeSourceSummary` when `canChangeSource || typeName != nil`. Replaced the whole file: struct now only has the params it actually uses (`episodes`, `isLoading`, `errorMessage`, `releaseID`, `selectedSourceID`, `isEpisodeWatched`, `resumePosition`, `onPickEpisode`), and `body` is just `VStack { header; content }`. No source pickers, no type pickers. `AnimeDetailsView` no longer holds `typePickerVisible` / `sourcePickerVisible` state and the two `.sheet(...)` modifiers for them are gone.

### Hero compaction

`AnimeHeroHeader` tightened so the bottom never bleeds into the Watch CTA:
- Poster shrunk from 154×231 → **140×210**.
- VStack spacing 14 → **10**.
- Spacer top minLength 90 → **60**.
- `.padding(.bottom, 28)` → **18**.
- Title font 26 → **22**, original 14 → **12**, divider width 44 → **36**.
- Hero frame **460 → 420**.

### Rating + year as Column

`metaColumn` replaces the previous horizontal `metaRow`:

```swift
VStack(spacing: 2) {
    HStack { star + grade }      // ★ 4.9 — bold white, orange star
    Text(release.year)           // 2024 — semibold white, 0.85 alpha
}
```

The vertical stack is intentional — rating on top, year below — and the whole block is small enough that it can't push into the Watch button below the hero. `accessibilityElement(children: .combine)` so VoiceOver reads them as one chunk.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/BEABDC5B-.../AniAngliaXIX.app`. Launched.

## Phase 20 ship log (2026-06-04) — full details redesign

### Files changed

- `AnimeDetailsView.swift` — reorganized layout; restored `InfoStrip` and source/type picker sheets; richer loading skeleton.
- `EpisodesSection.swift` — re-added optional source/type summary above the episode list; only renders when there's something meaningful to switch.
- `ContinueWatchingBlock.swift` — `YukimoCardPressStyle` for subtle scale-on-press across the whole card.

### New layout below the hero

```
VStack(spacing: xl) {
    // 1. PRIMARY ACTION PANEL (Watch + List/Rate/Favorite)
    VStack(spacing: md) {
        AnimeWatchButton(context: vm.watchContext)
        AnimeSecondaryActionsRow(...)
    }

    // 2. Continue Watching — only when hasResumeProgress
    if vm.hasResumeProgress { ContinueWatchingBlock(...) }

    // 3. InfoStrip — 4 tiles (yellow rating, year, episodes, status)
    InfoStrip(release: release)

    // 4. Genres (flow-wrap)
    if !release.genres.isEmpty { GenresSection(raw: release.genres) }

    // 5. Synopsis (gradient-fade collapse / expand)
    SynopsisBlock(text: desc, expanded: $descriptionExpanded)
      // ...or emptyDescription placeholder

    // 6. Episodes — header + EpisodeSourceSummary (taps open
    //    TypePickerSheet / SourcePickerSheet) + LazyVStack of EpisodeRow.
    EpisodesSection(...)

    // 7. Screenshots — horizontal carousel + fullscreen viewer.
    ScreenshotsBlock(urls: release.screenshotURLs)
}
.padding(.top, xxxl)   // breathing room from the hero
```

### EpisodesSection now smart about source summary

`shouldShowSummary` gates the chip — only renders when `sourceName` is non-empty AND (`canChangeSource` || `canChangeType` || `typeWorkers` is non-empty). Single-source releases don't get a useless card. The summary card opens `SourcePickerSheet`; the optional secondary "Тип: …" row opens `TypePickerSheet`.

### Loading skeleton overhaul

`AnimeDetailsView.loadingSkeleton` replaces the bare-bones poster+two-lines placeholder. Now mocks the whole stack: 140×210 poster, title bar, original bar, full-width CTA, 3-cell secondary row, 4-tile info strip. Shimmer + redacted reason makes it feel alive while libanixart resolves.

### Continue Watching scale-on-press

`YukimoCardPressStyle` (nested struct) — `scaleEffect(configuration.isPressed ? 0.98 : 1.0) + springSoft` animation. Applies the iOS-feel "card press" to the entire Continue Watching surface without changing its visual chrome.

### Toolbar trigger tweaked

Title fade-in threshold dropped 320 → 280, so on the shorter 420pt hero the toolbar title appears at the right moment (just after the hero title is out of view).

### What stays the same

API, DTO, ViewModel, bridges, mutations. All numeric values and persistence (YukimoProgressStore, YukimoWatchedStore, optimistic localListStatus/localMyVote) untouched.

### How to test

1. Open any anime → hero shows poster (status pill top-right), category badge, title, divider, ★ rating + year column.
2. Hero fades into clean light surface; Watch CTA + 3 secondary buttons sit at top.
3. If `release.lastViewEpisodePosition > 0` → "Продолжить · Серия N" CTA + Continue Watching card with progress bar.
4. InfoStrip below the action panel: rating tile in yellow, then year / episodes / status with their accent colors.
5. Genres wrap. Synopsis collapses to 3 lines with a gradient fade; tap anywhere to expand.
6. EpisodesSection: source summary chip with chevron (tap → SourcePickerSheet). Multi-type? Secondary chip (tap → TypePickerSheet).
7. Episode rows: number tile green if watched (cross-source via YukimoWatchedStore), coral progress bar if has saved time, ★ Resume target highlighted.
8. Screenshots open fullscreen viewer.
9. Pull down then up → toolbar glass fades in past ~60pt, title appears past ~280pt.
10. Scroll all the way back → glass clears, full hero visible again.

### Result on Sabirov

`** BUILD SUCCEEDED **` simulator + device. Installed at `/var/containers/Bundle/Application/30E14A5B-.../AniAngliaXIX.app`. Launched.

