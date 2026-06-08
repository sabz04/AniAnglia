namespace AniAngliaWin.Models;

/// <summary>
/// Same shape as <c>YukimoReleaseDTO</c> on iOS; intentional 1:1 mirror
/// so the C++/WinRT bridge can hand back these properties without us
/// reshaping anything at the C# layer.
/// </summary>
public sealed class Release
{
    public required long ReleaseId { get; init; }
    public required string TitleRu { get; init; }
    public string? TitleOriginal { get; init; }
    public string? ImageUrl { get; init; }
    public string? Genres { get; init; }
    public string? Year { get; init; }
    public double Grade { get; init; }
    public int VoteCount { get; init; }
    public ReleaseStatus Status { get; init; }
    public int EpisodesReleased { get; init; }
    public int EpisodesTotal { get; init; }

    public int? LastViewEpisodePosition { get; init; }
    public string? LastViewEpisodeName { get; init; }
    /// <summary>0..1, only meaningful for Continue Watching.</summary>
    public double LastViewProgress { get; init; }

    /// <summary>Best display title — RU first, otherwise the original.</summary>
    public string DisplayTitle => string.IsNullOrEmpty(TitleRu) ? (TitleOriginal ?? "") : TitleRu;

    public string EpisodesLabel
    {
        get
        {
            if (EpisodesTotal > 0 && EpisodesReleased > 0)
            {
                return EpisodesReleased == EpisodesTotal
                    ? $"{EpisodesTotal} серий"
                    : $"{EpisodesReleased}/{EpisodesTotal} серий";
            }
            return EpisodesReleased > 0 ? $"{EpisodesReleased} серий" : "";
        }
    }
}
