# AniAngliaWin

WinUI 3 / .NET 8 desktop client. Same product as the iOS app, native
Windows visuals. See `ARCHITECTURE.md` for the long-form rationale and
phase plan; this file covers **getting it building**.

## Phase 0 — Bootstrap (the current state)

| What works | What doesn't yet |
| --- | --- |
| Mica/Acrylic shell window, coral theme, Light/Dark dictionaries, NavigationView with 5 tabs + Settings, placeholder page per tab, DI container, stub session/settings services persisted to `LocalSettings` | Bridge (Phase 1), Auth (Phase 1), real data (Phase 2+), media playback (Phase 3) |

## Prerequisites

Install once on a Windows 10 (1809+) or Windows 11 machine:

1. **Visual Studio 2022 17.10+** with these workloads:
   - *.NET desktop development*
   - *Desktop development with C++* (needed in Phase 1 for the bridge)
   - *Universal Windows Platform development* → check the **Windows App SDK C# Templates** optional component
2. **.NET 8 SDK** (auto-installed by the workload, or grab from <https://dot.net>)
3. **Windows App SDK runtime 1.5.x** — NuGet pulls the matching version, but unpackaged debugging needs the bootstrapper. Visual Studio prompts the first time.

## First-time setup

```powershell
# from the repo root
cd windows
dotnet restore AniAngliaWin.sln
```

Open `AniAngliaWin.sln` in Visual Studio. Set the startup project to
`AniAngliaWin`. **F5** runs in unpackaged mode (you'll see "AniAnglia"
in Task Manager, not the package name).

## What you should see on first run

- A 1280×800 window with Mica backdrop (Win11) or Acrylic (Win10).
- Title "AniAnglia" in the top-left drag region.
- Left-side compact NavigationView with five icons: Главная, Поиск,
  Списки, Лента, Профиль (Профиль pinned to the bottom).
- Selecting any tab loads a placeholder card centred in the content
  area: coral halo + glyph + "Скоро тут будет контент".
- The settings cog at the bottom-left works and pushes a placeholder
  Settings page using `DrillInNavigationTransitionInfo`.

If the window opens with **plain solid background** instead of Mica:
`MicaController.IsSupported()` returned false. That's fine on Win10 —
we fall back to `DesktopAcrylicController`. If both fail (e.g. running
under transparency-disabled Remote Desktop), it stays solid; not a bug.

## Project map

```
windows/
├── ARCHITECTURE.md             ← high-level plan, read this first
├── README.md                   ← you are here
├── AniAngliaWin.sln
├── global.json                 ← pins .NET 8
├── Directory.Build.props       ← Nullable + CPM
├── Directory.Packages.props    ← central NuGet versions
├── nuget.config
└── src/
    ├── AniAngliaWin/           ← C#/XAML host (this is what runs)
    │   ├── App.xaml(.cs)       ← DI container, theme dictionaries
    │   ├── MainWindow.xaml(.cs)← Mica/Acrylic backdrop + root Frame
    │   ├── Shell/              ← NavigationView shell + ItemInvoked logic
    │   ├── Views/              ← Home / Search / Library / Feed / Profile / Settings (placeholders)
    │   ├── ViewModels/         ← one per page, MVVM Toolkit source-gen
    │   ├── Services/           ← Session/Settings/Theme/Navigation (interfaces + impls + stubs)
    │   ├── Controls/           ← PlaceholderPanel UserControl
    │   └── Themes/             ← Colors / Typography / Tokens / ControlStyles
    └── AniAngliaWin.Bridge/    ← C++/WinRT bridge to libanixart (Phase 1)
```

## Theming

Direct port of the iOS Yukimo palette. Same names, same hex.

- `YukimoPrimaryCoralBrush` ⇄ `YukimoColor.primaryCoral` (Swift)
- `YukimoSurfaceBrush` ⇄ `YukimoColor.surface`
- …

Use `{ThemeResource YukimoXyzBrush}` in XAML so Light/Dark switches
automatically.

## Conventions

- **MVVM Toolkit source generators** — declare with `[ObservableProperty]`
  / `[RelayCommand]`, never write `INotifyPropertyChanged` boilerplate.
- **DI** — pages resolve their VM through `App.Services.GetRequiredService<T>()`
  in the code-behind constructor; XAML uses `x:Bind ViewModel.Foo`
  (compiled bindings, fastest path).
- **Strings** in source code stay Russian (primary language). When we
  add `.resw` files in Phase 8 the in-code strings become defaults.

## Next steps — Phase 1 starts when

1. We confirm a Windows build of `libanixart` (open question, see
   `ARCHITECTURE.md` § "Открытые вопросы").
2. We pick distribution mode (packaged vs unpackaged). Phase 0 builds
   both; Phase 8 will commit to one.
