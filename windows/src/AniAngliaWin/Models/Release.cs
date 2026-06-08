namespace AniAngliaWin.Models;

/// <summary>
/// Same shape as <c>YukimoReleaseDTO</c> on iOS; intentional 1:1 mirror
/// so the C++/WinRT bridge can hand back these properties without us
/// reshaping anything at the C# layer.
/// </summary>
public sealed class Release
{
    public long ReleaseId { get; set; }
    public string TitleRu { get; set; } = "";
    public string? TitleOriginal { get; set; }
    public string? ImageUrl { get; set; }
    public string? Genres { get; set; }
    public string? Year { get; set; }
    public double Grade { get; set; }
    public int VoteCount { get; set; }
    public ReleaseStatus Status { get; set; }
    public int EpisodesReleased { get; set; }
    public int EpisodesTotal { get; set; }

    public int? LastViewEpisodePosition { get; set; }
    public string? LastViewEpisodeName { get; set; }
    /// <summary>0..1, only meaningful for Continue Watching.</summary>
    public double LastViewProgress { get; set; }

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
