using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;            // Stretch
using Microsoft.UI.Xaml.Media.Imaging;

namespace AniAngliaWin.Controls;

/// <summary>
/// Image wrapper that shows a Yukimo shimmer until the bitmap is decoded.
/// Mirrors the iOS <c>YukimoAsyncImage</c> helper conceptually.
/// </summary>
public sealed partial class YukimoAsyncImage : UserControl
{
    public YukimoAsyncImage() => InitializeComponent();

    public static readonly DependencyProperty SourceUrlProperty =
        DependencyProperty.Register(nameof(SourceUrl), typeof(string),
            typeof(YukimoAsyncImage),
            new PropertyMetadata(null, OnSourceUrlChanged));

    /// <summary>HTTP(s) URL of the image to load. Setting null clears.</summary>
    public string? SourceUrl
    {
        get => GetValue(SourceUrlProperty) as string;
        set => SetValue(SourceUrlProperty, value);
    }

    public static readonly DependencyProperty StretchProperty =
        DependencyProperty.Register(nameof(Stretch), typeof(Stretch),
            typeof(YukimoAsyncImage),
            new PropertyMetadata(Microsoft.UI.Xaml.Media.Stretch.UniformToFill,
                (d, e) => ((YukimoAsyncImage)d).HostedImage.Stretch = (Stretch)e.NewValue));

    public Stretch Stretch
    {
        get => (Stretch)GetValue(StretchProperty);
        set => SetValue(StretchProperty, value);
    }

    private static void OnSourceUrlChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var ctrl = (YukimoAsyncImage)d;
        var raw = e.NewValue as string;
        ctrl.HostedImage.Opacity = 0;
        ctrl.Placeholder.Visibility = Visibility.Visible;

        if (string.IsNullOrWhiteSpace(raw))
        {
            ctrl.HostedImage.Source = null;
            return;
        }

        if (!Uri.TryCreate(raw, UriKind.Absolute, out var uri))
        {
            ctrl.HostedImage.Source = null;
            return;
        }

        // BitmapImage caches by URI inside the XAML framework, so flipping
        // back to the same release reuses the decoded bitmap.
        ctrl.HostedImage.Source = new BitmapImage(uri)
        {
            CreateOptions = BitmapCreateOptions.IgnoreImageCache | BitmapCreateOptions.None,
        };
    }

    private void OnImageOpened(object sender, RoutedEventArgs e)
    {
        // Fade the bitmap in; hide the shimmer behind it.
        var fade = new Microsoft.UI.Xaml.Media.Animation.DoubleAnimation
        {
            From = 0, To = 1,
            Duration = new Duration(TimeSpan.FromMilliseconds(220)),
            EasingFunction = new Microsoft.UI.Xaml.Media.Animation.QuadraticEase
            {
                EasingMode = Microsoft.UI.Xaml.Media.Animation.EasingMode.EaseOut,
            },
        };
        Microsoft.UI.Xaml.Media.Animation.Storyboard.SetTarget(fade, HostedImage);
        Microsoft.UI.Xaml.Media.Animation.Storyboard.SetTargetProperty(fade, "Opacity");
        var sb = new Microsoft.UI.Xaml.Media.Animation.Storyboard();
        sb.Children.Add(fade);
        sb.Begin();
        Placeholder.Visibility = Visibility.Collapsed;
    }

    private void OnImageFailed(object sender, ExceptionRoutedEventArgs e)
    {
        // Leave the shimmer running — looks better than a broken-image
        // icon while the network recovers.
        HostedImage.Opacity = 0;
        Placeholder.Visibility = Visibility.Visible;
    }
}
