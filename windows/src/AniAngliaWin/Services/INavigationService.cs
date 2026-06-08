using System;

namespace AniAngliaWin.Services;

/// <summary>
/// Wraps the shell's content <see cref="Microsoft.UI.Xaml.Controls.Frame"/>.
/// View-models talk to navigation via this interface so they don't depend
/// on Xaml types directly — keeps them unit-testable.
/// </summary>
public interface INavigationService
{
    void Initialize(Microsoft.UI.Xaml.Controls.Frame frame);
    bool NavigateTo(Type pageType, object? parameter = null);
    bool CanGoBack { get; }
    void GoBack();
}
