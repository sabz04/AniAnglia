using System;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace AniAngliaWin.Services;

internal sealed class NavigationService : INavigationService
{
    private Frame? _frame;

    public void Initialize(Frame frame)
    {
        _frame = frame;
    }

    public bool NavigateTo(Type pageType, object? parameter = null)
    {
        if (_frame is null) return false;
        return _frame.Navigate(pageType, parameter, new EntranceNavigationTransitionInfo());
    }

    public bool CanGoBack => _frame?.CanGoBack ?? false;

    public void GoBack()
    {
        if (_frame?.CanGoBack == true) _frame.GoBack();
    }
}
