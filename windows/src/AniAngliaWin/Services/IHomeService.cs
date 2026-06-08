using System.Threading;
using System.Threading.Tasks;
using AniAngliaWin.Models;

namespace AniAngliaWin.Services;

/// <summary>
/// Loads the data backing HomePage. Phase 2 uses a stub; Phase 1 will
/// swap in a bridge-backed implementation that hits the real Anixart API.
/// The interface contract stays the same so neither the VM nor the View
/// has to change.
/// </summary>
public interface IHomeService
{
    Task<HomeData> LoadAsync(CancellationToken ct = default);
}
