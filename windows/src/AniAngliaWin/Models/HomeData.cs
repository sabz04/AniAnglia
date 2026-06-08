using System.Collections.Generic;

namespace AniAngliaWin.Models;

/// <summary>
/// Snapshot of everything HomePage needs in a single call. Mirrors the
/// rails YukimoHomeBridge exposes on iOS: hero, continue watching,
/// recommendations, currently watching, discussing.
/// </summary>
public sealed class HomeData
{
    public Release? Hero { get; set; }
    public IReadOnlyList<Release> ContinueWatching { get; set; } = System.Array.Empty<Release>();
    public IReadOnlyList<Release> Recommendations { get; set; } = System.Array.Empty<Release>();
    public IReadOnlyList<Release> CurrentlyWatching { get; set; } = System.Array.Empty<Release>();
    public IReadOnlyList<Release> Discussing { get; set; } = System.Array.Empty<Release>();
}
