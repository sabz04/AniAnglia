namespace AniAngliaWin.Models;

/// <summary>
/// Mirrors anixart::Release::Status. Same numbers as the iOS DTO so
/// future bridge code can serialise straight across.
/// </summary>
public enum ReleaseStatus
{
    Unknown  = 0,
    Finished = 1,
    Ongoing  = 2,
    Upcoming = 3,
}

public static class ReleaseStatusExtensions
{
    public static string ToRussianLabel(this ReleaseStatus s) => s switch
    {
        ReleaseStatus.Finished => "Завершено",
        ReleaseStatus.Ongoing  => "Онгоинг",
        ReleaseStatus.Upcoming => "Анонс",
        _                      => "",
    };
}
