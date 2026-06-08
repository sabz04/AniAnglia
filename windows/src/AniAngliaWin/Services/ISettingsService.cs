namespace AniAngliaWin.Services;

/// <summary>
/// Persisted app settings. Mirrors the iOS <c>AppSettingsDataController</c>
/// keys we care about. Each typed accessor reads/writes a single setting
/// and broadcasts a change event.
/// </summary>
public interface ISettingsService
{
    AppTheme Theme { get; set; }
    int DefaultQualityHeight { get; set; }      // 0 = Auto; 240/360/480/720/1080
    bool AutoNextEpisode { get; set; }
    bool RememberSource { get; set; }
    bool AlternativeConnection { get; set; }

    event EventHandler<string>? SettingChanged;  // key name
}

public enum AppTheme
{
    System,
    Light,
    Dark
}
