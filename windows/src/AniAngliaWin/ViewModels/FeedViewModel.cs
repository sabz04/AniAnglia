using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class FeedViewModel : ObservableObject
{
    [ObservableProperty] private string headline = "Лента";
    [ObservableProperty] private string sub = "Подборки сообщества (Phase 5)";
}
