using AniAngliaWin.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Views;

public sealed partial class SearchPage : Page
{
    public SearchViewModel ViewModel { get; }

    public SearchPage()
    {
        ViewModel = App.Services.GetRequiredService<SearchViewModel>();
        InitializeComponent();
    }
}
