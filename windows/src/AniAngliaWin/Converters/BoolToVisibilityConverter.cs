using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace AniAngliaWin.Converters;

/// <summary>
/// True → Visible, False → Collapsed. Pass parameter "Invert" (any
/// truthy value) to flip the mapping. Unlike WPF, WinUI 3 ships no
/// built-in BooleanToVisibility, so we roll our own.
/// </summary>
internal sealed class BoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language)
    {
        var flag = value is bool b && b;
        if (parameter is string s && !string.IsNullOrEmpty(s)) flag = !flag;
        return flag ? Visibility.Visible : Visibility.Collapsed;
    }

    public object ConvertBack(object value, Type targetType, object parameter, string language) =>
        throw new NotSupportedException();
}
