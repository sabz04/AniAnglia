using System;
using AniAngliaWin.Services;
using AniAngliaWin.Services.Stubs;
using AniAngliaWin.ViewModels;
using AniAngliaWin.Views;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;

namespace AniAngliaWin;

/// <summary>
/// App entry point. Holds the DI container and the single MainWindow.
/// Pages resolve their view models from <see cref="Services"/> via DI.
/// </summary>
public partial class App : Application
{
    /// <summary>
    /// The DI container. Populated in <see cref="OnLaunched"/>.
    /// Services are resolved through <c>App.Services.GetRequiredService&lt;T&gt;()</c>
    /// so view-models stay constructor-injected and pages stay light.
    /// </summary>
    public static IServiceProvider Services { get; private set; } = null!;

    /// <summary>
    /// The one and only top-level window. Pages push into its root Frame.
    /// </summary>
    public static MainWindow MainWindow { get; private set; } = null!;

    public App()
    {
        InitializeComponent();
        UnhandledException += OnUnhandledException;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        Services = BuildServiceProvider();

        MainWindow = new MainWindow();
        MainWindow.Activate();
    }

    private static IServiceProvider BuildServiceProvider()
    {
        var services = new ServiceCollection();

        services.AddLogging(b => b.AddDebug().SetMinimumLevel(LogLevel.Debug));

        // === Services. Stub-first; swap to bridge-backed impls in Phase 1+. ===
        services.AddSingleton<ISessionService, StubSessionService>();
        services.AddSingleton<ISettingsService, StubSettingsService>();
        services.AddSingleton<IThemeService, ThemeService>();
        services.AddSingleton<INavigationService, NavigationService>();
        services.AddSingleton<IHomeService, StubHomeService>();

        // === Page view-models. Transient — fresh state on each navigation. ===
        services.AddTransient<ShellViewModel>();
        services.AddTransient<HomeViewModel>();
        services.AddTransient<SearchViewModel>();
        services.AddTransient<LibraryViewModel>();
        services.AddTransient<FeedViewModel>();
        services.AddTransient<ProfileViewModel>();

        return services.BuildServiceProvider();
    }

    private void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        // Qualified — both Microsoft.UI.Xaml and System expose this type.
        System.Diagnostics.Debug.WriteLine($"[App] UNHANDLED: {e.Exception}");
        // In production: log + offer Restart. For now don't suppress.
    }
}
