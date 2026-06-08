using System;
using System.Collections.Generic;
using AniAngliaWin.Services;
using AniAngliaWin.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Navigation;

namespace AniAngliaWin.Shell;

/// <summary>
/// Hosts the global NavigationView and routes its taps into the content
/// frame. Each menu item maps to a Tag → Page type via <see cref="PageMap"/>.
/// </summary>
public sealed partial class ShellPage : Page
{
    private static readonly IReadOnlyDictionary<string, Type> PageMap = new Dictionary<string, Type>
    {
        ["home"]    = typeof(HomePage),
        ["search"]  = typeof(SearchPage),
        ["library"] = typeof(LibraryPage),
        ["feed"]    = typeof(FeedPage),
        ["profile"] = typeof(ProfilePage),
    };

    public ShellPage()
    {
        InitializeComponent();

        // Wire the global navigation service to our content frame so any
        // view-model can request a push without touching XAML.
        var nav = App.Services.GetRequiredService<INavigationService>();
        nav.Initialize(ContentFrame);

        Loaded += (_, _) =>
        {
            // Pick home as the first selection.
            if (NavView.MenuItems.Count > 0)
            {
                NavView.SelectedItem = NavView.MenuItems[0];
                NavigateByTag("home");
            }
        };
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.IsSettingsSelected)
        {
            ContentFrame.Navigate(typeof(SettingsPage), null, new DrillInNavigationTransitionInfo());
            return;
        }
        if (args.SelectedItemContainer is NavigationViewItem item &&
            item.Tag is string tag)
        {
            NavigateByTag(tag);
        }
    }

    private void NavView_ItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
    {
        if (args.IsSettingsInvoked)
        {
            ContentFrame.Navigate(typeof(SettingsPage), null, new DrillInNavigationTransitionInfo());
        }
    }

    private void NavigateByTag(string tag)
    {
        if (!PageMap.TryGetValue(tag, out var pageType)) return;

        // No-op when the requested page is already on top.
        if (ContentFrame.CurrentSourcePageType == pageType) return;

        ContentFrame.Navigate(pageType, null,
            new EntranceNavigationTransitionInfo());
    }
}
