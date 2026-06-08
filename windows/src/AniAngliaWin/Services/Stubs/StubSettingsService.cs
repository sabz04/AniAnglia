using System;
using Windows.Storage;

namespace AniAngliaWin.Services.Stubs;

/// <summary>
/// Backed by <see cref="ApplicationDataContainer"/> so settings survive
/// restarts in unpackaged mode too (ApplicationData.Current works for
/// both packaged + unpackaged Windows App SDK apps).
/// </summary>
internal sealed class StubSettingsService : ISettingsService
{
    private readonly ApplicationDataContainer _container =
        ApplicationData.Current.LocalSettings;

    public event EventHandler<string>? SettingChanged;

    public AppTheme Theme
    {
        get => ReadEnum(nameof(Theme), AppTheme.System);
        set => WriteEnum(nameof(Theme), value);
    }

    public int DefaultQualityHeight
    {
        get => ReadInt(nameof(DefaultQualityHeight), 720);
        set => WriteInt(nameof(DefaultQualityHeight), value);
    }

    public bool AutoNextEpisode
    {
        get => ReadBool(nameof(AutoNextEpisode), true);
        set => WriteBool(nameof(AutoNextEpisode), value);
    }

    public bool RememberSource
    {
        get => ReadBool(nameof(RememberSource), true);
        set => WriteBool(nameof(RememberSource), value);
    }

    public bool AlternativeConnection
    {
        get => ReadBool(nameof(AlternativeConnection), false);
        set => WriteBool(nameof(AlternativeConnection), value);
    }

    // === plumbing ===

    private bool ReadBool(string key, bool fallback) =>
        _container.Values[key] is bool b ? b : fallback;
    private void WriteBool(string key, bool value)
    {
        _container.Values[key] = value;
        SettingChanged?.Invoke(this, key);
    }

    private int ReadInt(string key, int fallback) =>
        _container.Values[key] is int i ? i : fallback;
    private void WriteInt(string key, int value)
    {
        _container.Values[key] = value;
        SettingChanged?.Invoke(this, key);
    }

    private T ReadEnum<T>(string key, T fallback) where T : struct, Enum
    {
        if (_container.Values[key] is string s && Enum.TryParse<T>(s, out var v)) return v;
        return fallback;
    }
    private void WriteEnum<T>(string key, T value) where T : struct, Enum
    {
        _container.Values[key] = value.ToString();
        SettingChanged?.Invoke(this, key);
    }
}
