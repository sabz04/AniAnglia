using CommunityToolkit.Mvvm.ComponentModel;

namespace AniAngliaWin.ViewModels;

public partial class LibraryViewModel : ObservableObject
{
    [ObservableProperty] private string headline = "Списки";
    [ObservableProperty] private string sub = "Смотрю · В планах · Просмотрено · Отложено · Брошено · Любимое (Phase 4)";
}
