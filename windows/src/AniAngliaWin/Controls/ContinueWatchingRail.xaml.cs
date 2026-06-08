using System.Collections;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

public sealed partial class ContinueWatchingRail : UserControl
{
    public ContinueWatchingRail() => InitializeComponent();

    public static readonly DependencyProperty HeaderProperty =
        DependencyProperty.Register(nameof(Header), typeof(string),
            typeof(ContinueWatchingRail),
            new PropertyMetadata("", (d, e) =>
                ((ContinueWatchingRail)d).HeaderText.Text = e.NewValue as string ?? ""));

    public string Header
    {
        get => GetValue(HeaderProperty) as string ?? "";
        set => SetValue(HeaderProperty, value);
    }

    public static readonly DependencyProperty ItemsSourceProperty =
        DependencyProperty.Register(nameof(ItemsSource), typeof(IEnumerable),
            typeof(ContinueWatchingRail),
            new PropertyMetadata(null, (d, e) =>
                ((ContinueWatchingRail)d).Items.ItemsSource = e.NewValue));

    public IEnumerable? ItemsSource
    {
        get => GetValue(ItemsSourceProperty) as IEnumerable;
        set => SetValue(ItemsSourceProperty, value);
    }
}
