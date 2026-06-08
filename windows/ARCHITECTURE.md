# AniAnglia for Windows — архитектура и фазы

> Этот документ задаёт направление для нативного Windows-клиента (рабочее
> название **AniAngliaWin**). Целевая аудитория — пользователи Windows 10
> (1809+) и Windows 11. Никаких веб-обёрток: настоящее нативное приложение
> с Fluent Design.

---

## TL;DR — рекомендуемый стек

| Слой | Технология | Почему |
| --- | --- | --- |
| UI | **WinUI 3** | Современный Microsoft-стек 2024+, Fluent Design «из коробки», нативный look на Win10/11, активная разработка |
| Язык | **C# / .NET 8** | Простой, быстрый цикл сборки, отличные dev-tools, идиоматично для XAML |
| Архитектура | **MVVM** через `CommunityToolkit.Mvvm` (source generators) | `[ObservableProperty]` / `[RelayCommand]` без boilerplate |
| Bridge к libanixart | **C++/WinRT runtime component** | Async через `IAsyncOperation<T>`, прямая интерполяция типов в C# |
| Player | **`MediaPlayerElement`** + кастомные TransportControls | Нативный HLS, аппаратное ускорение, PiP/CompactOverlay из коробки |
| Storage | `ApplicationData.Current.LocalSettings` + JSON в `LocalFolder` | Стандартный UWP-style sandbox |
| Network | `HttpClient` + `BackgroundDownloader` | Background-загрузки переживают перезапуск приложения |
| Packaging | **MSIX** (sideload + Store) | Современный формат, авто-обновления, чистая деинсталляция |
| DI | `Microsoft.Extensions.DependencyInjection` | Идиоматично для .NET |
| Charts | `LiveCharts2` или `CommunityToolkit.WinUI.Charts` | Donut chart на профиле |

### Почему не …

- **WPF** — зрелый, но устаревший дизайн, нет Mica/Acrylic «из коробки», MediaElement беднее MediaPlayerElement. **Используем только если WinUI 3 окажется блокером.**
- **Avalonia** — отличный кроссплатформенный фреймворк, но менее «нативный» на Win11. Стоит выбора **только если** в горизонте планируется Linux/Mac.
- **Tauri / Electron / WebView** — не «нативное». Отметаем.
- **Win32 / MFC** — выкручиваться вручную ради media-app — overkill.
- **MAUI** — мобильная фокусировка, на десктопе пока шероховатости. WinUI 3 чище.

---

## Структура solution

```
windows/
├── AniAngliaWin.sln
└── src/
    ├── AniAngliaWin/                     ← главный WinUI 3 проект
    │   ├── App.xaml + .cs
    │   ├── MainWindow.xaml + .cs         ← Shell (NavigationView)
    │   ├── Views/
    │   │   ├── Auth/
    │   │   │   ├── LoginPage.xaml
    │   │   │   ├── RegisterPage.xaml
    │   │   │   ├── ForgotPasswordPage.xaml
    │   │   │   └── VerificationPage.xaml
    │   │   ├── Home/HomePage.xaml
    │   │   ├── Search/SearchPage.xaml
    │   │   ├── Library/LibraryPage.xaml
    │   │   ├── Feed/
    │   │   │   ├── FeedPage.xaml
    │   │   │   └── CollectionDetailPage.xaml
    │   │   ├── Details/AnimeDetailsPage.xaml
    │   │   ├── Player/PlayerPage.xaml
    │   │   ├── Profile/ProfilePage.xaml
    │   │   └── Settings/SettingsPage.xaml
    │   ├── Controls/                     ← кастомные XAML-контролы
    │   │   ├── ReleaseCard.xaml
    │   │   ├── CollectionCard.xaml
    │   │   ├── PosterRail.xaml
    │   │   └── PlayerTransportControls.xaml
    │   ├── ViewModels/
    │   │   ├── Auth/*.cs
    │   │   ├── Home/HomeViewModel.cs
    │   │   ├── Details/AnimeDetailsViewModel.cs
    │   │   └── …
    │   ├── Services/
    │   │   ├── AnixartApiService.cs       ← обёртка над bridge
    │   │   ├── SessionService.cs          ← токен, ID профиля
    │   │   ├── SettingsService.cs         ← persisted prefs
    │   │   ├── DownloadsService.cs        ← BackgroundDownloader
    │   │   ├── ProgressStore.cs           ← per-episode progress
    │   │   └── WatchedStore.cs            ← cross-source watched set
    │   ├── Models/                        ← простые data classes
    │   ├── Themes/
    │   │   ├── Colors.xaml                ← coral, soft pink, surfaces
    │   │   ├── Typography.xaml            ← Inter / Segoe Variable
    │   │   └── Generic.xaml               ← control templates
    │   └── Assets/                        ← иконки, app-icon
    │
    └── AniAngliaWin.Bridge/              ← C++/WinRT component
        ├── AnixartBridge.idl              ← runtime classes для C#
        ├── AnixartBridge.h / .cpp
        ├── Session.h / .cpp               ← обёртка ApiSession
        ├── Releases.h / .cpp              ← ApiReleases facade
        ├── …                              ← по одному cpp на каждое ApiXxx
        └── pch.h
```

Это зеркалит структуру iOS-клиента (`Bridge/` + `Features/Main/...`),
чтобы переход между платформами был интуитивен.

---

## Архитектурные слои

```
┌─────────────────────────────────────────────────────────┐
│  Views (XAML pages + UserControls)                       │
│  - NavigationView shell                                  │
│  - Compiled bindings (x:Bind) для производительности     │
└──────────────────────────┬──────────────────────────────┘
                           │ DataContext
┌──────────────────────────▼──────────────────────────────┐
│  ViewModels (MVVM Toolkit)                               │
│  - [ObservableProperty] / [RelayCommand]                 │
│  - async/await друг с другом                             │
└──────────────────────────┬──────────────────────────────┘
                           │ DI
┌──────────────────────────▼──────────────────────────────┐
│  Services (singleton, registered in App.OnLaunched)      │
│  - AnixartApiService — фасад над bridge                  │
│  - SessionService / SettingsService                      │
│  - DownloadsService / ProgressStore / WatchedStore       │
└──────────────────────────┬──────────────────────────────┘
                           │ projected WinRT types
┌──────────────────────────▼──────────────────────────────┐
│  Bridge (C++/WinRT)                                      │
│  - ReleaseDTO / CollectionDTO / ProfileDTO как WinRT cls │
│  - async-обёртки: IAsyncOperation<IVector<ReleaseDTO>>   │
│  - все исключения libanixart → HResult с понятным msg    │
└──────────────────────────┬──────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────┐
│  libanixart (C++)                                        │
│  - Тот же бинарь, что в iOS (Windows-сборку запросим у   │
│    aateam, либо собьём из исходников)                    │
└──────────────────────────────────────────────────────────┘
```

### Bridge: почему C++/WinRT, а не P/Invoke

- **Async first-class.** Каждый запрос — `IAsyncOperation<T>` с COM apartment, и из C# просто `await api.LoadReleaseAsync(id)`. P/Invoke потребует ручной thread-marshaling.
- **Богатые типы.** WinRT projection отдаёт C# реальные классы с свойствами вместо struct'ов с marshaling-атрибутами.
- **Лучше для коллекций.** `IVector<T>` / `IObservableVector<T>` ⇄ `IList<T>` / `ObservableCollection<T>` без копий.
- **Исключения.** WinRT перебрасывает их как `Exception` с локализованным сообщением.
- **Уже знакомо.** В iOS-клиенте используется аналогичный паттерн «pure-Obj-C facade поверх C++»; здесь то же самое, но с WinRT.

### Bridge: pre-flight для libanixart

Сначала проверяем, что библиотека вообще собирается под Windows:

1. Нужен Windows-target в её CMake/Xcode-сборке. Если нет — открываем тикет к `aateam/libanixart`.
2. Зависимости (`netsess`, `curl`, `openssl`, `boost`) — есть готовые vcpkg-портры. Используем `vcpkg manifest`.
3. C++20 → `/std:c++20` в MSVC.

**Если libanixart упрётся** — fallback план: реализуем минимум API (auth, releases, episodes, search, collections) поверх `HttpClient` + `System.Text.Json`. Дороже, но не блокер.

---

## Темизация и UI-язык

- **Цвета:** тот же coral / soft-pink палет, что в Yukimo iOS. Переносим как `ThemeResource`-ы.
- **Backdrop:** `MicaController` (Win11) с fallback на `DesktopAcrylicController` (Win10).
- **Шрифт:** **Inter** (или Segoe UI Variable, если хотим строго системный). Семейство тоже зеркалит iOS-палитру.
- **Радиусы / spacing:** XAML `ThemeResource` — `YukimoRadiusCard = 20`, `YukimoSpacingLg = 16`, etc.
- **Анимации:** ConnectedAnimations при переходе hero-постера → details. Plus `ImplicitAnimations` (опасити/scale) для появления карточек.

Конечный визуальный язык должен ощущаться как «iOS-приложение, переосмысленное под Windows», а не как порт. Грубо: Mica + Fluent reveal + Acrylic + наши coral-acent + типографика.

---

## Фазы разработки

Идея — каждая фаза кончается **рабочим билдом**, на котором что-то можно делать руками. Минимальный полезный продукт после Phase 3.

### Phase 0 — Bootstrap (2–3 дня)
- [ ] Создать solution с двумя проектами: `AniAngliaWin` (WinUI 3, .NET 8) + `AniAngliaWin.Bridge` (C++/WinRT component).
- [ ] Настроить vcpkg manifest для libanixart-зависимостей.
- [ ] Подтвердить компиляцию libanixart под `x64-windows` (включая curl/openssl/boost). Если нет — fallback на HTTP-клиент, отдельный тикет.
- [ ] Базовая Mica/Acrylic shell-window, NavigationView с 5 пустыми пунктами.
- [ ] DI-контейнер (`Host.CreateApplicationBuilder`), регистрация заглушек сервисов.
- [ ] Theming: coral/pink палитра как ResourceDictionary, переключение Light/Dark.

**Acceptance:** запускается окно с Mica-фоном и левым NavigationView, переключение между tab'ами не падает.

### Phase 1 — Bridge и Auth (≈1 неделя)
- [ ] Bridge: первый рабочий runtime class — `AuthBridge` (`SignInAsync`, `SignUpAsync`, `VerifyAsync`, `RestoreAsync`).
- [ ] `SessionService`: чтение/запись токена + profile id в `LocalSettings`.
- [ ] LoginPage / RegisterPage / ForgotPasswordPage / VerificationPage с XAML-формами.
- [ ] Inline-валидация (логин/email/password) — `AuthValidator` static class.
- [ ] Ошибки сервера → `InAppNotification` (`MUXC InfoBar`).
- [ ] Avto-вход при наличии токена.

**Acceptance:** новая авторизация, sign-up через email-код, logout, restart-survival.

### Phase 2 — Main shell + Home (≈1 неделя)
- [ ] Bridge: `HomeBridge` (`LoadHero`, `LoadContinueWatching`, `LoadRecommendations`, `LoadCurrentlyWatching`, `LoadDiscussing`).
- [ ] HomePage: hero-карточка (16:11 постер с градиентом), 4 рейла `PosterRail`.
- [ ] `PosterCard` UserControl с `AsyncImage` (наша обёртка с in-memory кэшем).
- [ ] `ContinueWatchingCard` с прогресс-полосой.
- [ ] NavigationView — иконки (Segoe Fluent Icons): house / search / bookmark / chat / person.
- [ ] Empty/loading skeleton (`Shimmer` brush).

**Acceptance:** домашний экран с реальными данными для залогиненного пользователя.

### Phase 3 — Details + Player (≈1.5 недели)
- [ ] Bridge: `ReleaseDetailBridge` (load release / types / sources / episodes / vote / favorite / set list status).
- [ ] AnimeDetailsPage: blurred hero, identity row, action panel, Continue Watching, info strip, genres, synopsis, screenshots, episodes list.
- [ ] PlayerPage с `MediaPlayerElement` + кастомным `PlayerTransportControls`.
- [ ] Source/Type/Episode/Quality flyouts.
- [ ] `ProgressStore` (per-episode resume) + `WatchedStore` (cross-source set) — JSON в `LocalFolder`.
- [ ] PiP через `IsCompactOverlayEnabled`.

**Acceptance:** открываем релиз с домашнего, смотрим серию, выбираем озвучку и качество, возобновляем с того же места. **На этом моменте приложение уже полезно — Alpha-релиз.**

### Phase 4 — Search + Library (≈1 неделя)
- [ ] Bridge: `SearchBridge` (release/filter) + `LibraryBridge` (статусы списков).
- [ ] SearchPage: текстовое поле, история, фильтр-флайаут (год / сезон / тип / статус / жанры).
- [ ] LibraryPage: segment selector (Смотрю / В планах / Просмотрено / …), ListView с `ReleaseRowCard`.
- [ ] Сохранение последних запросов (`SettingsService`).

**Acceptance:** поиск по названию работает, фильтр-комбинации работают, библиотека показывает все 6 статусов.

### Phase 5 — Feed → Collections (≈1 неделя)
- [ ] Bridge: `CollectionsBridge` (all / favorite / detail / releases / set favorite / search).
- [ ] FeedPage > Collections: режим All/Favorite + sort menu (6 опций) + поиск с debounce.
- [ ] CollectionCard с author-cover (если есть) / fanned poster collage (fallback).
- [ ] CollectionDetailPage с infinite list of releases.
- [ ] (Опционально, Phase 5.1) Articles + Channels, как Phase 3+ в iOS roadmap.

**Acceptance:** свайп по коллекциям, открытие, листание релизов, добавление в избранное.

### Phase 6 — Profile + Settings (≈1 неделя)
- [ ] Bridge: `ProfileBridge` (`LoadMyProfile`, `EditAvatar`).
- [ ] ProfilePage: Hero (avatar + username) → SnapshotStrip (часы / тайтлы / любимые) → ActivityCard (donut) → ActionsCard (Downloads / Settings / Logout).
- [ ] Donut: `LiveCharts2 PieSeries`.
- [ ] SettingsPage: качество по умолчанию, авто-переход, тема, альтернативное подключение.
- [ ] Avatar upload через `FileOpenPicker` → JPEG resize → bridge.

**Acceptance:** профиль с реальной статистикой, смена аватара работает, настройки переживают перезапуск.

### Phase 7 — Downloads (≈1.5 недели)
- [ ] `DownloadsService` поверх `BackgroundDownloader` (HLS manifest → отдельный архив с фрагментами).
- [ ] DownloadsPage: список Entry с прогрессом, статусом, кнопками Pause/Resume/Cancel/Delete/Open.
- [ ] В плеере — `DownloadActionButton` (тот же стейт-машинд, что и на iOS).
- [ ] Offline-mode для плеера (играем локальный файл, фолбек на онлайн).

**Acceptance:** скачали серию, посмотрели offline.

### Phase 8 — Polish + Release (≈2 недели)
- [ ] Анимации: ConnectedAnimation hero ↔ details, ImplicitAnimations на карточках, page transitions.
- [ ] Adaptive layout (XAML `AdaptiveTrigger`) — поддержка узкого окна (NavigationView в pane-overlay).
- [ ] Mini-player (`CompactOverlay`) когда уходим со страницы плеера во время воспроизведения.
- [ ] Локализация (`.resw`): русский (primary) + английский (если попросят).
- [ ] Темная / светлая тема — реальный качественный mode-сюйп.
- [ ] Accessibility: AutomationProperties, keyboard navigation, high-contrast.
- [ ] MSIX-пакет, иконка, тайл, splash. Self-signed для sideload + Store сертификат если идём в Microsoft Store.
- [ ] CI: GitHub Actions с `windows-latest` для сборки и подписи.

**Acceptance:** Release-сборка готова к публикации.

---

## Открытые вопросы (нужны ответы перед Phase 0)

1. **Windows-сборка libanixart** — у `aateam` есть? Если нет, кто собирает (`vcpkg` + `cmake`)?
2. **Минимальная версия Windows.** Win10 1809 покрывает 99% пользователей; Win11-only позволяет жёстко полагаться на Mica и сэкономить XAML-fallbacks.
3. **Distribution model.** Microsoft Store, GitHub Release c MSIX-инсталлятором, или оба? От ответа зависит подписание.
4. **Архитектуры.** x64 — обязательно; ARM64 (Surface Pro X / Windows-on-ARM) — желательно, но удваивает CI-нагрузку.
5. **Параллельная разработка iOS ↔ Windows.** Делим состояние bridge'ей через общий C++ DTO-описатель или каждая платформа описывает DTO у себя? Я бы советовал второе — связность через libanixart, а не через слой DTO.

---

## Финальная рекомендация (короткой строкой)

> **WinUI 3 + .NET 8 + C# + C++/WinRT bridge → MSIX.**
> Простой, нативный, future-proof, идиоматичный 2026.
> Фазы 0–3 (≈3 недели) — Alpha, можно смотреть аниме на Windows.
