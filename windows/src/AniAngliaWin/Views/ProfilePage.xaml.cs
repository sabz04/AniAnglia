using AniAngliaWin.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AniAngliaWin.Views;

public sealed partial class ProfilePage : Page
{
    public ProfileViewModel ViewModel { get; }

    public ProfilePage()
    {
        ViewModel = App.Services.GetRequiredService<ProfileViewModel>();
        InitializeComponent();
    }
}
