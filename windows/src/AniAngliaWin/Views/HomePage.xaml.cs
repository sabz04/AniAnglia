using AniAngliaWin.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Views;

public sealed partial class HomePage : Page
{
    public HomeViewModel ViewModel { get; }

    public HomePage()
    {
        ViewModel = App.Services.GetRequiredService<HomeViewModel>();
        InitializeComponent();
        Loaded += async (_, _) =>
        {
            if (ViewModel.Hero is null)
            {
                await ViewModel.LoadAsync();
            }
        };
    }

    private async void OnRefreshClick(object sender, RoutedEventArgs e)
    {
        await ViewModel.LoadAsync();
    }
}
