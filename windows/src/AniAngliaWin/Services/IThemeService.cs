namespace AniAngliaWin.Services;

/// <summary>
/// Reads/writes the user's chosen theme. Decoupled from
/// <see cref="ISettingsService"/> so the shell can observe theme-only
/// changes without subscribing to the full settings stream.
/// </summary>
public interface IThemeService
{
    AppTheme CurrentTheme { get; }

    void SetTheme(AppTheme theme);

    event EventHandler<AppTheme>? ThemeChanged;
}
