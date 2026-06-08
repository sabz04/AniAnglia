using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Controls;

/// <summary>
/// Friendly empty-state for pages that aren't built yet. Used by every
/// Phase-0 placeholder page; gone the moment a real page replaces it.
/// </summary>
public sealed partial class PlaceholderPanel : UserControl
{
    public PlaceholderPanel() => InitializeComponent();

    public static readonly DependencyProperty TitleProperty =
        DependencyProperty.Register(nameof(Title), typeof(string),
            typeof(PlaceholderPanel),
            new PropertyMetadata("", OnTitleChanged));

    public string Title
    {
        get => (string)GetValue(TitleProperty);
        set => SetValue(TitleProperty, value);
    }

    public static readonly DependencyProperty SubtitleProperty =
        DependencyProperty.Register(nameof(Subtitle), typeof(string),
            typeof(PlaceholderPanel),
            new PropertyMetadata("", OnSubtitleChanged));

    public string Subtitle
    {
        get => (string)GetValue(SubtitleProperty);
        set => SetValue(SubtitleProperty, value);
    }

    public static readonly DependencyProperty GlyphProperty =
        DependencyProperty.Register(nameof(Glyph), typeof(string),
            typeof(PlaceholderPanel),
            new PropertyMetadata("", OnGlyphChanged));

    public string Glyph
    {
        get => (string)GetValue(GlyphProperty);
        set => SetValue(GlyphProperty, value);
    }

    private static void OnTitleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is PlaceholderPanel p) p.TitleText.Text = e.NewValue as string ?? "";
    }
    private static void OnSubtitleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is PlaceholderPanel p) p.SubtitleText.Text = e.NewValue as string ?? "";
    }
    private static void OnGlyphChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is PlaceholderPanel p) p.GlyphIcon.Glyph = e.NewValue as string ?? "";
    }
}
