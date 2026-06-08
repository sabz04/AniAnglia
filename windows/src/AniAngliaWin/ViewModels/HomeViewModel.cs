using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using AniAngliaWin.Models;
using AniAngliaWin.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AniAngliaWin.ViewModels;

public partial class HomeViewModel : ObservableObject
{
    private readonly IHomeService _home;

    public HomeViewModel(IHomeService home)
    {
        _home = home;
    }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsContentReady))]
    private bool isLoading = true;

    [ObservableProperty]
    private string? error;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsContentReady))]
    private Release? hero;

    public ObservableCollection<Release> ContinueWatching { get; } = new();
    public ObservableCollection<Release> Recommendations { get; } = new();
    public ObservableCollection<Release> CurrentlyWatching { get; } = new();
    public ObservableCollection<Release> Discussing { get; } = new();

    /// <summary>True once the first <see cref="LoadAsync"/> finishes
    /// with a hero — used to flip the page from skeleton mode to real.</summary>
    public bool IsContentReady => !IsLoading && Hero is not null;

    /// <summary>Greeting shown in the page header — picks "good morning"
    /// / "good afternoon" / "good evening" based on the local hour.</summary>
    public string Greeting => DateTime.Now.Hour switch
    {
        < 5  => "Доброй ночи",
        < 12 => "Доброе утро",
        < 18 => "Добрый день",
        _    => "Добрый вечер",
    };

    [RelayCommand]
    public async Task LoadAsync()
    {
        try
        {
            IsLoading = true;
            Error = null;
            var data = await _home.LoadAsync();

            Hero = data.Hero;
            Refill(ContinueWatching, data.ContinueWatching);
            Refill(Recommendations, data.Recommendations);
            Refill(CurrentlyWatching, data.CurrentlyWatching);
            Refill(Discussing, data.Discussing);
        }
        catch (Exception ex)
        {
            Error = ex.Message;
        }
        finally
        {
            IsLoading = false;
        }
    }

    private static void Refill<T>(ObservableCollection<T> target, System.Collections.Generic.IReadOnlyList<T> source)
    {
        target.Clear();
        foreach (var item in source) target.Add(item);
    }
}
