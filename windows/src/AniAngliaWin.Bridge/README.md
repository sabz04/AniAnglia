# AniAngliaWin.Bridge — C++/WinRT runtime component

> Empty in Phase 0. Real implementation lands in Phase 1 alongside the
> auth flow.

## What this project is

A WinRT component that wraps the vendored C++ `libanixart` library and
exposes Swift-style "DTO + bridge" runtime classes that the C# host can
consume directly through `await api.SignInAsync(login, password)` etc.

Mirrors the role of `AniAnglia/Yukimo/Bridge/` on iOS.

## Phase 1 plan

1. Create `AniAngliaWin.Bridge.vcxproj` (C++/WinRT 2.0+, `/std:c++20`,
   `x64;arm64`, `windowsappsdk` references).
2. Pull `libanixart` (`netsess`, `curl`, `openssl`, `boost`) via
   `vcpkg manifest` — one `vcpkg.json` sitting next to this README.
3. Author `AnixartBridge.idl` with the smallest possible surface:
   ```idl
   namespace AniAngliaWin.Bridge
   {
       [default_interface]
       runtimeclass AuthBridge
       {
           AuthBridge();
           Windows.Foundation.IAsyncOperation<ProfileSession> SignInAsync(String login, String password);
           Windows.Foundation.IAsyncOperation<ProfileSession> SignUpVerifyAsync(String email, String code);
           // …
       }
   }
   ```
4. Implement in `AuthBridge.cpp` — synchronous libanixart calls hosted
   inside `winrt::Windows::System::Threading::ThreadPool::RunAsync` so
   they don't block the UI thread.
5. Add a `<ProjectReference>` from `AniAngliaWin.csproj` to this
   `.vcxproj` so the C# side picks up generated projections.

## Why C++/WinRT, not P/Invoke

See `windows/ARCHITECTURE.md` — short version: async-first, real WinRT
types from C# without marshalling, and exceptions cross the ABI cleanly.

## Open questions blocked on the libanixart owners

- Is there a Windows-target build already? If not, who owns the vcpkg
  port?
- Will the same set of `vcpkg`-tracked dependencies (`curl`, `openssl`,
  `boost`) match what the iOS XCFramework links against, or do we need
  a different set on Windows?
