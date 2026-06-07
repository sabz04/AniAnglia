//
//  AppColor.mm
//
//  yukimo design system implementation.
//

#import "AppColor.h"

#pragma mark - dynamic-color helper

// Build a UIColor that resolves a different value in Light vs Dark.
static UIColor* yk_dyn(UIColor* light, UIColor* dark) {
    return [UIColor colorWithDynamicProvider:^UIColor* _Nonnull(UITraitCollection* tc) {
        return tc.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
    }];
}

// sRGB shortcut — every literal color in this file goes through it.
static UIColor* yk_srgb(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}


#pragma mark - AppColorProvider

@implementation AppColorProvider

// --- Surfaces ----------------------------------------------------------------

+(UIColor*)backgroundColor {
    // Light: clean white. Dark: deep ink, not pure black (OLED + premium feel).
    return yk_dyn(yk_srgb(255, 255, 255, 1.0),
                  yk_srgb( 14,  15,  20, 1.0));
}
+(UIColor*)surfaceColor {
    // Card surface — sits just above background.
    return yk_dyn(yk_srgb(247, 247, 250, 1.0),
                  yk_srgb( 24,  25,  32, 1.0));
}
+(UIColor*)surfaceElevatedColor {
    // Raised surface (modals, segmented chips, popovers).
    return yk_dyn(yk_srgb(255, 255, 255, 1.0),
                  yk_srgb( 32,  33,  42, 1.0));
}
+(UIColor*)surfaceSunkenColor {
    // Lower than background (input fields, search bar fill).
    return yk_dyn(yk_srgb(241, 241, 244, 1.0),
                  yk_srgb( 22,  23,  30, 1.0));
}

+(UIColor*)foregroundColor1 { return [self surfaceColor]; }
+(UIColor*)foregroundColor2 { return [self surfaceElevatedColor]; }

// --- Brand accents -----------------------------------------------------------

+(UIColor*)primaryColor {
    // Coral — soft red, premium, friendly. Same value in light & dark.
    return yk_srgb(255, 77, 79, 1.0);   // #FF4D4F
}
+(UIColor*)primaryPressedColor {
    return yk_srgb(232, 64, 66, 1.0);   // pressed
}
+(UIColor*)primarySoftColor {
    // Tinted background used under coral icons, chips, ghost buttons.
    return yk_dyn(yk_srgb(255, 230, 230, 1.0),
                  yk_srgb( 90,  35,  37, 0.55));
}

+(UIColor*)secondaryColor {
    // Pastel purple.
    return yk_dyn(yk_srgb(160, 138, 240, 1.0),
                  yk_srgb(178, 158, 248, 1.0));
}
+(UIColor*)accentBlueColor {
    return yk_dyn(yk_srgb(102, 168, 240, 1.0),
                  yk_srgb(122, 184, 250, 1.0));
}
+(UIColor*)accentMintColor {
    return yk_dyn(yk_srgb( 80, 200, 168, 1.0),
                  yk_srgb(100, 214, 184, 1.0));
}
+(UIColor*)accentYellowColor {
    return yk_dyn(yk_srgb(244, 196,  88, 1.0),
                  yk_srgb(248, 206, 110, 1.0));
}

// --- Status ------------------------------------------------------------------

+(UIColor*)successColor { return [self accentMintColor]; }
+(UIColor*)warningColor { return yk_srgb(245, 158,  11, 1.0); }
+(UIColor*)infoColor    { return [self accentBlueColor]; }
+(UIColor*)dangerColor  { return yk_srgb(232,  64,  66, 1.0); }

+(UIColor*)alertColor { return [self dangerColor]; }
+(UIColor*)idleColor  { return [self warningColor]; }

// --- Text --------------------------------------------------------------------

+(UIColor*)textColor          { return UIColor.labelColor; }
+(UIColor*)textSecondaryColor { return UIColor.secondaryLabelColor; }
+(UIColor*)textTertiaryColor  { return UIColor.tertiaryLabelColor; }
+(UIColor*)textShyColor       { return [self textTertiaryColor]; }
+(UIColor*)textOnPrimaryColor { return UIColor.whiteColor; }
+(UIColor*)textOnGlassColor   {
    // High contrast on glass surfaces. In dark it stays white; in light it
    // shifts to near-black so the label survives in a bright photo backdrop.
    return yk_dyn(yk_srgb( 16,  16,  20, 1.0),
                  yk_srgb(255, 255, 255, 1.0));
}

// --- Glass / overlay ---------------------------------------------------------

+(UIColor*)glassSurfaceColor {
    return yk_dyn([UIColor colorWithWhite:1.0 alpha:0.45],
                  [UIColor colorWithWhite:0.10 alpha:0.55]);
}
+(UIColor*)glassSurfaceStrongColor {
    return yk_dyn([UIColor colorWithWhite:1.0 alpha:0.72],
                  [UIColor colorWithWhite:0.12 alpha:0.78]);
}
+(UIColor*)glassBorderColor {
    return yk_dyn([UIColor colorWithWhite:1.0  alpha:0.55],
                  [UIColor colorWithWhite:1.0  alpha:0.10]);
}
+(UIColor*)glassHighlightColor {
    // Sits as a subtle top highlight on the glass edge.
    return [UIColor colorWithWhite:1.0 alpha:0.18];
}
+(UIColor*)scrimColor {
    return [UIColor colorWithWhite:0.0 alpha:0.4];
}
+(UIColor*)scrimStrongColor {
    return [UIColor colorWithWhite:0.0 alpha:0.7];
}
+(UIColor*)overlayDimColor { return [self scrimColor]; }

// --- Misc --------------------------------------------------------------------

+(UIColor*)separatorColor         { return UIColor.separatorColor; }
+(UIColor*)fillColor              { return UIColor.systemFillColor; }
+(UIColor*)posterPlaceholderColor {
    return yk_dyn(yk_srgb(230, 230, 234, 1.0),
                  yk_srgb( 40,  42,  52, 1.0));
}

@end


#pragma mark - UIFont (App)

@implementation UIFont (App)

// Returns the base size + UIFontTextStyle pair for an AppTextStyle.
// Mirrors Apple's defaults so Dynamic Type metrics are correct.
static void app_styleSpec(AppTextStyle style,
                          CGFloat* outSize,
                          UIFontWeight* outWeight,
                          UIFontTextStyle* outTextStyle) {
    switch (style) {
        case AppTextStyleLargeTitle:  *outSize = 34; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleLargeTitle; return;
        case AppTextStyleTitle1:      *outSize = 28; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleTitle1;     return;
        case AppTextStyleTitle2:      *outSize = 22; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleTitle2;     return;
        case AppTextStyleTitle3:      *outSize = 20; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleTitle3;     return;
        case AppTextStyleHeadline:    *outSize = 17; *outWeight = UIFontWeightSemibold; *outTextStyle = UIFontTextStyleHeadline;   return;
        case AppTextStyleBody:        *outSize = 17; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleBody;       return;
        case AppTextStyleCallout:     *outSize = 16; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleCallout;    return;
        case AppTextStyleSubheadline: *outSize = 15; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleSubheadline;return;
        case AppTextStyleFootnote:    *outSize = 13; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleFootnote;   return;
        case AppTextStyleCaption1:    *outSize = 12; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleCaption1;   return;
        case AppTextStyleCaption2:    *outSize = 11; *outWeight = UIFontWeightRegular;  *outTextStyle = UIFontTextStyleCaption2;   return;
    }
    *outSize = 17; *outWeight = UIFontWeightRegular; *outTextStyle = UIFontTextStyleBody;
}

// Title-grade text styles use SF Rounded for a softer brand feel. Body / small
// styles keep regular SF Pro because rounded text reads slightly fatter and
// hurts legibility in dense paragraphs.
static BOOL yk_isTitleGrade(AppTextStyle style) {
    switch (style) {
        case AppTextStyleLargeTitle:
        case AppTextStyleTitle1:
        case AppTextStyleTitle2:
        case AppTextStyleTitle3:
        case AppTextStyleHeadline:
            return YES;
        default:
            return NO;
    }
}

static UIFont* yk_baseFontForStyle(AppTextStyle style, CGFloat size, UIFontWeight weight) {
    UIFont* sys = [UIFont systemFontOfSize:size weight:weight];
    if (!yk_isTitleGrade(style)) return sys;
    UIFontDescriptor* rounded = [sys.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return rounded ? [UIFont fontWithDescriptor:rounded size:size] : sys;
}

+(UIFont*)app_fontForStyle:(AppTextStyle)style {
    CGFloat size; UIFontWeight weight; UIFontTextStyle ts;
    app_styleSpec(style, &size, &weight, &ts);
    UIFont* base = yk_baseFontForStyle(style, size, weight);
    return [[UIFontMetrics metricsForTextStyle:ts] scaledFontForFont:base];
}

+(UIFont*)app_fontForStyle:(AppTextStyle)style weight:(UIFontWeight)weight {
    CGFloat size; UIFontWeight ignored; UIFontTextStyle ts;
    app_styleSpec(style, &size, &ignored, &ts);
    UIFont* base = yk_baseFontForStyle(style, size, weight);
    return [[UIFontMetrics metricsForTextStyle:ts] scaledFontForFont:base];
}

+(UIFont*)app_monospacedDigitFontForStyle:(AppTextStyle)style weight:(UIFontWeight)weight {
    CGFloat size; UIFontWeight ignored; UIFontTextStyle ts;
    app_styleSpec(style, &size, &ignored, &ts);
    UIFont* base = [UIFont monospacedDigitSystemFontOfSize:size weight:weight];
    return [[UIFontMetrics metricsForTextStyle:ts] scaledFontForFont:base];
}

+(UIFont*)app_roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont* sys = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor* rounded = [sys.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return rounded ? [UIFont fontWithDescriptor:rounded size:size] : sys;
}

@end
