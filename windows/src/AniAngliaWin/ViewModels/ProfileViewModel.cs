using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class ProfileViewModel : ObservableObject
{
    [ObservableProperty] private string headline = "Профиль";
    [ObservableProperty] private string sub = "Аватар, статистика, активность (Phase 6)";
}
