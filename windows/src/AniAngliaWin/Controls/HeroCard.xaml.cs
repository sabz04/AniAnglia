using AniAngliaWin.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

/// <summary>
/// Full-width hero card. Big artwork with a dark bottom scrim, title,
/// original title, status pill, meta strip, primary Watch CTA. Goes at
/// the top of HomePage as the "featured" slot.
/// </summary>
public sealed partial class HeroCard : UserControl
{
    public HeroCard() => InitializeComponent();

    public static readonly DependencyProperty ReleaseProperty =
        DependencyProperty.Register(nameof(Release), typeof(Release),
            typeof(HeroCard),
            new PropertyMetadata(null, OnReleaseChanged));

    public Release? Release
    {
        get => GetValue(ReleaseProperty) as Release;
        set => SetValue(ReleaseProperty, value);
    }

    private static void OnReleaseChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var card = (HeroCard)d;
        var release = e.NewValue as Release;
        if (release is null)
        {
            card.TitleText.Text = "";
            card.OriginalText.Text = "";
            card.GradeText.Text = "";
            card.YearText.Text = "";
            card.EpisodesText.Text = "";
            card.HeroImage.SourceUrl = null;
            card.StatusPill.Visibility = Visibility.Collapsed;
            return;
        }

        card.HeroImage.SourceUrl = release.ImageUrl;
        card.TitleText.Text = release.DisplayTitle;
        card.OriginalText.Text = release.TitleOriginal ?? "";
        card.OriginalText.Visibility = string.IsNullOrEmpty(release.TitleOriginal)
            ? Visibility.Collapsed : Visibility.Visible;
        card.GradeText.Text = release.Grade > 0 ? release.Grade.ToString("0.0") : "—";
        card.YearText.Text = release.Year ?? "";
        card.YearText.Visibility = string.IsNullOrEmpty(release.Year) ? Visibility.Collapsed : Visibility.Visible;
        card.EpisodesText.Text = release.EpisodesLabel;
        card.EpisodesText.Visibility = string.IsNullOrEmpty(release.EpisodesLabel) ? Visibility.Collapsed : Visibility.Visible;

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
