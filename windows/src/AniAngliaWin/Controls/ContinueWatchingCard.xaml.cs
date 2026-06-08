using System;
using AniAngliaWin.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

/// <summary>
/// Wide horizontal card used on the Continue Watching rail. Mirrors the
/// iOS <c>ContinueWatchingCard</c>: mini-poster + title + episode name
/// + coral progress bar.
/// </summary>
public sealed partial class ContinueWatchingCard : UserControl
{
    public ContinueWatchingCard()
    {
        InitializeComponent();
        // Resize the progress fill to match the parent track on layout pass.
        SizeChanged += (_, _) => RefreshProgressWidth();
    }

    public static readonly DependencyProperty ReleaseProperty =
        DependencyProperty.Register(nameof(Release), typeof(Release),
            typeof(ContinueWatchingCard),
            new PropertyMetadata(null, OnReleaseChanged));

    public Release? Release
    {
        get => GetValue(ReleaseProperty) as Release;
        set => SetValue(ReleaseProperty, value);
    }

    private static void OnReleaseChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var card = (ContinueWatchingCard)d;
        var release = e.NewValue as Release;
        if (release is null)
        {
            card.TitleText.Text = "";
            card.EpisodeText.Text = "";
            card.PercentText.Text = "";
            card.ProgressFill.Width = 0;
            card.Poster.SourceUrl = null;
            return;
        }

        card.TitleText.Text = release.DisplayTitle;
        card.Poster.SourceUrl = release.ImageUrl;
        card.EpisodeText.Text = BuildEpisodeLabel(release);
        card.PercentText.Text = $"{(int)Math.Round(release.LastViewProgress * 100)}% просмотрено";
        card.RefreshProgressWidth();
    }

    private static string BuildEpisodeLabel(Release r)
    {
        var ep = r.LastViewEpisodePosition is int pos ? $"Серия {pos}" : "Продолжить";
        return string.IsNullOrEmpty(r.LastViewEpisodeName) ? ep : $"{ep} · {r.LastViewEpisodeName}";
    }

    private void RefreshProgressWidth()
    {
        if (Release is null) return;
        // Track width = (card width − poster − padding − spacing) approx.
        // Easier: use the actual rendered grid column instead — query the
        // sibling rectangle width.
        if (ProgressFill?.Parent is Grid track && track.ActualWidth > 0)
        {
            ProgressFill.Width = Math.Max(0, track.ActualWidth * Math.Clamp(Release.LastViewProgress, 0, 1));
        }
    }
}
