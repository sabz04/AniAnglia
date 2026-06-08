using System;

namespace AniAngliaWin.Services;

/// <summary>
/// Default theme service backed by the settings store. Reads on
/// construction, writes through the settings service, and re-broadcasts.
/// </summary>
internal sealed class ThemeService : IThemeService
{
    private readonly ISettingsService _settings;

    public ThemeService(ISettingsService settings)
    {
        _settings = settings;
        _settings.SettingChanged += OnSettingChanged;
    }

    public AppTheme CurrentTheme => _settings.Theme;

    public void SetTheme(AppTheme theme)
    {
        if (_settings.Theme == theme) return;
        _settings.Theme = theme;
    }

    public event EventHandler<AppTheme>? ThemeChanged;

    private void OnSettingChanged(object? sender, string key)
    {
        if (key == nameof(ISettingsService.Theme))
        {
            ThemeChanged?.Invoke(this, _settings.Theme);
        }
    }
}
