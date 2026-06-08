using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Data;

namespace AniAngliaWin.Converters;

/// <summary>
/// Non-null and non-empty → Visible, otherwise Collapsed. Used for the
/// error banner on HomePage and anywhere else we'd write
/// <c>if (text is not null)</c> in code-behind.
/// </summary>
internal sealed class StringToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, string language) =>
        value is string s && !string.IsNullOrEmpty(s) ? Visibility.Visible : Visibility.Collapsed;

    public object ConvertBack(object value, Type targetType, object parameter, string language) =>
        throw new NotSupportedException();
}
