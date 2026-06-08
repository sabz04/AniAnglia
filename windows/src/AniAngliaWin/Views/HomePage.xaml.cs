using AniAngliaWin.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Views;

public sealed partial class HomePage : Page
{
    public HomeViewModel ViewModel { get; }

    public HomePage()
    {
        ViewModel = App.Services.GetRequiredService<HomeViewModel>();
        InitializeComponent();
    }
}
