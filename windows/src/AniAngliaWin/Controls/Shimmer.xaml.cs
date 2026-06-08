using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace AniAngliaWin.Controls;

/// <summary>
/// Animated placeholder that slides a soft-white gradient across a pink
/// surface. Drop into any container where you'd previously have used
/// <c>.redacted(reason: .placeholder)</c> on iOS.
/// </summary>
public sealed partial class Shimmer : UserControl
{
    private Storyboard? _storyboard;

    public Shimmer()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        SizeChanged += (_, _) => RestartIfRunning();
    }

    private void OnLoaded(object sender, RoutedEventArgs e)   => StartAnimation();
    private void OnUnloaded(object sender, RoutedEventArgs e) => StopAnimation();

    private void RestartIfRunning()
    {
        if (_storyboard is null) return;
        StopAnimation();
        StartAnimation();
    }

    private void StartAnimation()
    {
        var width = ActualWidth > 0 ? ActualWidth : 320;
        // We translate from -width to +width so the highlight enters
        // from the left edge and exits on the right.
        var anim = new DoubleAnimation
        {
            From = -width,
            To = width,
            Duration = new Duration(System.TimeSpan.FromMilliseconds(1400)),
            RepeatBehavior = RepeatBehavior.Forever,
            EnableDependentAnimation = true,
        };
        Storyboard.SetTarget(anim, HighlightTransform);
        Storyboard.SetTargetProperty(anim, "X");
        _storyboard = new Storyboard();
        _storyboard.Children.Add(anim);
        _storyboard.Begin();
    }

    private void StopAnimation()
    {
        _storyboard?.Stop();
        _storyboard = null;
    }
}
