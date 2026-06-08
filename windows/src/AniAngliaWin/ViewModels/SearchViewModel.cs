using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class SearchViewModel : ObservableObject
{
    [ObservableProperty] private string headline = "Поиск";
    [ObservableProperty] private string sub = "Текстовый запрос + фильтры (Phase 4)";
}
