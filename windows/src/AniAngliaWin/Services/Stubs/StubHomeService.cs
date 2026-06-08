using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using AniAngliaWin.Models;

namespace AniAngliaWin.Services.Stubs;

/// <summary>
/// In-memory mock dataset. Lets every Home composition render with
/// realistic-ish content while the bridge is being built.
///
/// Uses <see href="https://picsum.photos"/> as a stand-in for poster URLs
/// — random images with a stable seed per release id so the same release
/// always renders with the same picture.
/// </summary>
internal sealed class StubHomeService : IHomeService
{
    public async Task<HomeData> LoadAsync(CancellationToken ct = default)
    {
        // Tiny artificial delay so the skeleton actually shows.
        await Task.Delay(450, ct);

        return new HomeData
        {
            Hero = MakeRelease(
                id: 1001,
                titleRu: "Магическая битва",
                titleOriginal: "Jujutsu Kaisen",
                genres: "Сёнен, Экшен, Сверхъестественное",
                year: "2023",
                grade: 4.7,
                voteCount: 18_240,
                status: ReleaseStatus.Ongoing,
                released: 23, total: 24),

            ContinueWatching = new[]
            {
                MakeContinueWatching(id: 2001, titleRu: "Frieren: Beyond Journey's End",
                    titleOriginal: "Sousou no Frieren",
                    grade: 4.9, status: ReleaseStatus.Ongoing,
                    released: 18, total: 28,
                    lastEpisode: 17, lastEpisodeName: "Тайна старого мага", progress: 0.43),
                MakeContinueWatching(id: 2002, titleRu: "Магическая битва",
                    titleOriginal: "Jujutsu Kaisen S2",
                    grade: 4.7, status: ReleaseStatus.Ongoing,
                    released: 23, total: 24,
                    lastEpisode: 22, lastEpisodeName: null, progress: 0.81),
                MakeContinueWatching(id: 2003, titleRu: "Создатели",
                    titleOriginal: "The Creator",
                    grade: 4.3, status: ReleaseStatus.Ongoing,
                    released: 7, total: 13,
                    lastEpisode: 7, lastEpisodeName: "Двойник", progress: 0.12),
            },

            Recommendations = MakeRail(start: 3001, count: 10, seedPrefix: "rec"),
            CurrentlyWatching = MakeRail(start: 4001, count: 10, seedPrefix: "cw"),
            Discussing = MakeRail(start: 5001, count: 10, seedPrefix: "dis"),
        };
    }

    // ===== helpers =====

    private static Release MakeRelease(long id, string titleRu, string titleOriginal,
        string genres, string year, double grade, int voteCount,
        ReleaseStatus status, int released, int total)
    {
        return new Release
        {
            ReleaseId = id,
            TitleRu = titleRu,
            TitleOriginal = titleOriginal,
            ImageUrl = PosterUrl(id),
            Genres = genres,
            Year = year,
            Grade = grade,
            VoteCount = voteCount,
            Status = status,
            EpisodesReleased = released,
            EpisodesTotal = total,
        };
    }

    private static Release MakeContinueWatching(long id, string titleRu, string titleOriginal,
        double grade, ReleaseStatus status, int released, int total,
        int lastEpisode, string? lastEpisodeName, double progress)
    {
        return new Release
        {
            ReleaseId = id,
            TitleRu = titleRu,
            TitleOriginal = titleOriginal,
            ImageUrl = PosterUrl(id),
            Year = "2024",
            Grade = grade,
            Status = status,
            EpisodesReleased = released,
            EpisodesTotal = total,
            LastViewEpisodePosition = lastEpisode,
            LastViewEpisodeName = lastEpisodeName,
            LastViewProgress = progress,
        };
    }

    private static IReadOnlyList<Release> MakeRail(long start, int count, string seedPrefix)
    {
        var list = new List<Release>(count);
        var rng = new Random(seedPrefix.GetHashCode());
        for (var i = 0; i < count; i++)
        {
            var id = start + i;
            list.Add(new Release
            {
                ReleaseId = id,
                TitleRu = SampleTitle(rng, i),
                TitleOriginal = null,
                ImageUrl = PosterUrl(id),
                Year = (2020 + (i % 6)).ToString(),
                Grade = Math.Round(3.6 + rng.NextDouble() * 1.3, 1),
                VoteCount = rng.Next(450, 25_000),
                Status = (ReleaseStatus)((i % 3) + 1),
                EpisodesReleased = 6 + i,
                EpisodesTotal = 12 + i,
            });
        }
        return list;
    }

    private static string PosterUrl(long id) =>
        // 2:3 aspect — Anixart posters are roughly that ratio, so the
        // stub matches the real layout.
        $"https://picsum.photos/seed/anianglia-{id}/300/450";

    private static readonly string[] _sampleTitles =
    [
        "Клинок, рассекающий демонов",
        "Хвост Феи",
        "Призрак в доспехах",
        "Атака титанов",
        "Стальной алхимик: Братство",
        "Моб Психо 100",
        "Ванпанчмен",
        "Ванпис",
        "Берсерк",
        "Сейлор Мун",
        "Тетрадь смерти",
        "Хантер х Хантер",
    ];

    private static string SampleTitle(Random rng, int index) =>
        _sampleTitles[(index + rng.Next(_sampleTitles.Length)) % _sampleTitles.Length];
}
