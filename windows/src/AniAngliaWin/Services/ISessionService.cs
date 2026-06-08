namespace AniAngliaWin.Services;

/// <summary>
/// Per-user session — the persisted token and profile id. Mirrors
/// <c>YukimoSessionBridge</c> on iOS, but lives purely on the C# side
/// here until the C++/WinRT bridge is in.
/// </summary>
public interface ISessionService
{
    bool HasActiveSession { get; }
    long? CurrentProfileId { get; }
    string? Token { get; }

    void SetToken(string token, long profileId);
    void Clear();
}
