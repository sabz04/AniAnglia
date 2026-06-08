using System.Collections;
using AniAngliaWin.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

/// <summary>
/// Horizontal scrollable row of releases preceded by a section header.
/// Used for Recommendations / Currently Watching / Discussing on the
/// home page. Continue Watching has its own rail (different cards).
/// </summary>
public sealed partial class PosterRail : UserControl
{
    public PosterRail() => InitializeComponent();

    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string),
            typeof(PosterRail),
            new PropertyMetadata("", (d, e) =>
                ((PosterRail)d).HeaderText.Text = e.NewValue as string ?? ""));

    public string Header
    {
        get => GetValue(HeaderProperty) as string ?? "";
        set => SetValue(HeaderProperty, value);
    }

    public static readonly DependencyProperty ItemsSourceProperty =
        DependencyProperty.Register(nameof(ItemsSource), typeof(IEnumerable),
            typeof(PosterRail),
            new PropertyMetadata(null, (d, e) =>
                ((PosterRail)d).Items.ItemsSource = e.NewValue));

    public IEnumerable? ItemsSource
    {
        get => GetValue(ItemsSourceProperty) as IEnumerable;
        set => SetValue(ItemsSourceProperty, value);
    }
}
