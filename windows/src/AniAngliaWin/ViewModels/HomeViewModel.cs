using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class HomeViewModel : ObservableObject
{
    [ObservableProperty] private string headline = "Скоро здесь будет ваша главная";
    [ObservableProperty] private string sub = "Hero · Continue Watching · Recommendations";
}
