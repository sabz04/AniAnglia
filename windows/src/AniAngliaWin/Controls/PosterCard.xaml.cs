using AniAngliaWin.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

/// <summary>
/// 2:3 poster card — release artwork, title, rating + year. Used by every
/// horizontal rail except Continue Watching (which uses a wider card with
/// a progress bar).
/// </summary>
public sealed partial class PosterCard : UserControl
{
    public PosterCard() => InitializeComponent();

    public static readonly DependencyProperty ReleaseProperty =
        DependencyProperty.Register(nameof(Release), typeof(Release),
            typeof(PosterCard),
            new PropertyMetadata(null, OnReleaseChanged));

    public Release? Release
    {
        get => GetValue(ReleaseProperty) as Release;
        set => SetValue(ReleaseProperty, value);
    }

    private static void OnReleaseChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var card = (PosterCard)d;
        var release = e.NewValue as Release;
        if (release is null)
        {
            card.TitleText.Text = "";
            card.GradeText.Text = "";
            card.YearText.Text  = "";
            card.YearDot.Visibility = Visibility.Collapsed;
            card.StatusPill.Visibility = Visibility.Collapsed;
            card.Poster.SourceUrl = null;
            return;
        }

        card.TitleText.Text = release.DisplayTitle;
        card.GradeText.Text = release.Grade > 0 ? release.Grade.ToString("0.0") : "—";
        card.YearText.Text  = release.Year ?? "";
        card.YearDot.Visibility = string.IsNullOrEmpty(release.Year) ? Visibility.Collapsed : Visibility.Visible;
        card.Poster.SourceUrl = release.ImageUrl;

        var statusLabel = release.Status.ToRussianLabel();
        if (!string.IsNullOrEmpty(statusLabel))
        {
            card.StatusText.Text = statusLabel.ToUpper();
            card.StatusPill.Visibility = Visibility.Visible;
        }
        else
        {
            card.StatusPill.Visibility = Visibility.Collapsed;
        }
    }
}
