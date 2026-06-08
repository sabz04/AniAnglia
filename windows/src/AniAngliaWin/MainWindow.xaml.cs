using System;
using AniAngliaWin.Services;
using AniAngliaWin.Shell;
using Microsoft.UI.Composition.SystemBackdrops;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Windows.Graphics;
using WinRT;
using WinRT.Interop;

namespace AniAngliaWin;

/// <summary>
/// Top-level window. Owns the Mica/Acrylic backdrop, the global theme
/// listener and hosts a single <see cref="ShellPage"/> in the root frame.
/// All page navigation happens INSIDE the shell.
/// </summary>
public sealed partial class MainWindow : Window
{
    // Both MicaController and DesktopAcrylicController are IDisposable
    // but share no public base class — store as IDisposable so the
    // null-out / Dispose flow works regardless of which one is active.
    private IDisposable? _backdropController;
    private SystemBackdropConfiguration? _backdropConfig;

    public MainWindow()
    {
        InitializeComponent();
        ConfigureWindowChrome();
        ApplyBackdrop();
        ApplyTheme(App.Services.GetRequiredService<IThemeService>().CurrentTheme);

        // Listen for runtime theme changes — keeps Mica tint in sync.
        if (RootGrid is FrameworkElement root)
        {
            root.ActualThemeChanged += (_, _) =>
            {
                if (_backdropConfig is not null)
                {
                    _backdropConfig.Theme = ConvertTheme(root.ActualTheme);
                }
            };
        }

        // First navigation — the shell.
        RootFrame.Navigate(typeof(ShellPage));
    }

    private void ConfigureWindowChrome()
    {
        // Extend the client area into the title bar so Mica can paint
        // edge-to-edge. The shell's TitleBar UI sits inside the Frame.
        ExtendsContentIntoTitleBar = true;

        var hwnd = WindowNative.GetWindowHandle(this);
        var id = Win32Interop.GetWindowIdFromWindow(hwnd);
        var appWindow = AppWindow.GetFromWindowId(id);

        // Initial size — a generous 1280x800 reads great on a 1080p display
        // and stays usable on a 1366x768 laptop.
        appWindow.Resize(new SizeInt32(1280, 800));

        if (appWindow.TitleBar is { } titleBar)
        {
            titleBar.ButtonBackgroundColor = Microsoft.UI.Colors.Transparent;
            titleBar.ButtonInactiveBackgroundColor = Microsoft.UI.Colors.Transparent;
        }
    }

    private void ApplyBackdrop()
    {
        if (!MicaController.IsSupported() && !DesktopAcrylicController.IsSupported())
        {
            return;
        }

        _backdropConfig = new SystemBackdropConfiguration
        {
            IsInputActive = true,
            Theme = ConvertTheme(((FrameworkElement)Content).ActualTheme)
        };
        Activated += (_, args) =>
        {
            if (_backdropConfig is not null)
            {
                _backdropConfig.IsInputActive = args.WindowActivationState != WindowActivationState.Deactivated;
            }
        };
        Closed += (_, _) =>
        {
            _backdropController?.Dispose();
            _backdropController = null;
            _backdropConfig = null;
        };

        // Win11 → Mica. Win10 1809+ → DesktopAcrylic. Otherwise plain bg.
        if (MicaController.IsSupported())
        {
            var mica = new MicaController { Kind = MicaKind.Base };
            mica.AddSystemBackdropTarget(this.As<Microsoft.UI.Composition.ICompositionSupportsSystemBackdrop>());
            mica.SetSystemBackdropConfiguration(_backdropConfig);
            _backdropController = mica;
        }
        else if (DesktopAcrylicController.IsSupported())
        {
            var acrylic = new DesktopAcrylicController();
            acrylic.AddSystemBackdropTarget(this.As<Microsoft.UI.Composition.ICompositionSupportsSystemBackdrop>());
            acrylic.SetSystemBackdropConfiguration(_backdropConfig);
            _backdropController = acrylic;
        }
    }

    private static SystemBackdropTheme ConvertTheme(ElementTheme theme) => theme switch
    {
        ElementTheme.Light => SystemBackdropTheme.Light,
        ElementTheme.Dark  => SystemBackdropTheme.Dark,
        _                  => SystemBackdropTheme.Default,
    };

    private void ApplyTheme(AppTheme theme)
    {
        if (RootGrid is FrameworkElement root)
        {
            root.RequestedTheme = theme switch
            {
                AppTheme.Light => ElementTheme.Light,
                AppTheme.Dark  => ElementTheme.Dark,
                _              => ElementTheme.Default,
            };
        }
    }
}
