namespace AniAngliaWin.Services.Stubs;

/// <summary>
/// In-memory placeholder. Replaced in Phase 1 with a real implementation
/// that talks to the C++/WinRT auth bridge and persists to LocalSettings.
/// </summary>
internal sealed class StubSessionService : ISessionService
{
    public bool HasActiveSession => Token is not null;
    public long? CurrentProfileId { get; private set; }
    public string? Token { get; private set; }

    public void SetToken(string token, long profileId)
    {
        Token = token;
        CurrentProfileId = profileId;
    }

    public void Clear()
    {
        Token = null;
        CurrentProfileId = null;
    }
}
