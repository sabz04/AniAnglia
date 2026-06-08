using System.Collections.Generic;

namespace AniAngliaWin.Models;

/// <summary>
/// Snapshot of everything HomePage needs in a single call. Mirrors the
/// rails YukimoHomeBridge exposes on iOS: hero, continue watching,
/// recommendations, currently watching, discussing.
/// </summary>
public sealed class HomeData
{
    public required Release? Hero { get; init; }
    public required IReadOnlyList<Release> ContinueWatching { get; init; }
    public required IReadOnlyList<Release> Recommendations { get; init; }
    public required IReadOnlyList<Release> CurrentlyWatching { get; init; }
    public required IReadOnlyList<Release> Discussing { get; init; }
}
