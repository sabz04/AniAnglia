using AniAngliaWin.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Views;

public sealed partial class FeedPage : Page
{
    public FeedViewModel ViewModel { get; }

    public FeedPage()
    {
        ViewModel = App.Services.GetRequiredService<FeedViewModel>();
        InitializeComponent();
    }
}
