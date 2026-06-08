using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class ShellViewModel : ObservableObject
{
    [ObservableProperty]
    private string title = "AniAnglia";
}
