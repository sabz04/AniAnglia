//
//  AppColor.h
//
//  yukimo design system — coral brand on iOS-native semantic surfaces, with
//  Liquid Glass tokens for floating navigation / sheets / overlays.
//
//  Tokens here are the only sanctioned source of color, typography, spacing,
//  radii and motion values across the app. Screens reference them by name;
//  never reference raw hex or `systemX` colors directly from view code.
//
//  Header must remain valid plain Obj-C — it is imported from both .m and .mm.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Color tokens

/// Semantic color tokens. Each token returns a dynamic `UIColor` that resolves
/// per `UITraitCollection`, so Light / Dark / Increase-Contrast all work for
/// free. Older method names are kept as aliases for backward compatibility.
@interface AppColorProvider : NSObject

// --- Surfaces -------------------------------------------------------------
+(UIColor*)backgroundColor;        ///< Screen background (light: white / dark: deep ink)
+(UIColor*)surfaceColor;           ///< Card surface
+(UIColor*)surfaceElevatedColor;   ///< Raised surface (modals, popovers, segmented chip)
+(UIColor*)surfaceSunkenColor;     ///< Lower-than-background (e.g. input field)

// Legacy aliases (kept so existing code compiles unchanged).
+(UIColor*)foregroundColor1;       ///< == surfaceColor
+(UIColor*)foregroundColor2;       ///< == surfaceElevatedColor

// --- Brand accents --------------------------------------------------------
+(UIColor*)primaryColor;           ///< coral — the only brand accent
+(UIColor*)primaryPressedColor;    ///< coral, slightly darker — pressed/highlight
+(UIColor*)primarySoftColor;       ///< coral tinted background (chips, glow under glass)
+(UIColor*)secondaryColor;         ///< pastel purple — rare secondary tint
+(UIColor*)accentBlueColor;        ///< pastel blue accent (info chips)
+(UIColor*)accentMintColor;        ///< mint/green accent (progress, voice-team badges)
+(UIColor*)accentYellowColor;      ///< soft yellow (ratings)

// --- Status ---------------------------------------------------------------
+(UIColor*)successColor;
+(UIColor*)warningColor;
+(UIColor*)infoColor;
+(UIColor*)dangerColor;
+(UIColor*)alertColor;             ///< legacy alias == dangerColor
+(UIColor*)idleColor;              ///< legacy alias == warningColor

// --- Text -----------------------------------------------------------------
+(UIColor*)textColor;              ///< primary label
+(UIColor*)textSecondaryColor;     ///< secondary label
+(UIColor*)textTertiaryColor;
+(UIColor*)textShyColor;           ///< legacy alias == textTertiaryColor
+(UIColor*)textOnPrimaryColor;     ///< text on coral fill (always white)
+(UIColor*)textOnGlassColor;       ///< text on glass overlays (high-contrast)

// --- Glass / overlay ------------------------------------------------------
+(UIColor*)glassSurfaceColor;          ///< translucent fill behind glass
+(UIColor*)glassSurfaceStrongColor;    ///< translucent fill, opaque-ish, for compact glass
+(UIColor*)glassBorderColor;           ///< 1px inner stroke on glass surfaces
+(UIColor*)glassHighlightColor;        ///< top-edge highlight (subtle linear gradient)
+(UIColor*)scrimColor;                 ///< 0–60% black overlay for poster-text legibility
+(UIColor*)scrimStrongColor;           ///< 0–75% black overlay
+(UIColor*)overlayDimColor;            ///< legacy alias == scrimColor

// --- Misc -----------------------------------------------------------------
+(UIColor*)separatorColor;
+(UIColor*)fillColor;              ///< subtle button/chip background
+(UIColor*)posterPlaceholderColor; ///< neutral grey shown while a poster loads

@end


#pragma mark - Typography

/// Apple text styles — each backed by `+[UIFontMetrics scaledFontForFont:]`
/// so Dynamic Type works out of the box. Values mirror Apple's defaults.
typedef NS_ENUM(NSInteger, AppTextStyle) {
    AppTextStyleLargeTitle,   // 34 regular
    AppTextStyleTitle1,       // 28 regular
    AppTextStyleTitle2,       // 22 regular
    AppTextStyleTitle3,       // 20 regular
    AppTextStyleHeadline,     // 17 semibold
    AppTextStyleBody,         // 17 regular
    AppTextStyleCallout,      // 16 regular
    AppTextStyleSubheadline,  // 15 regular
    AppTextStyleFootnote,     // 13 regular
    AppTextStyleCaption1,     // 12 regular
    AppTextStyleCaption2      // 11 regular
};

@interface UIFont (App)
/// Scaled font for the given Apple text style. Tracks Dynamic Type.
/// Title-grade styles (LargeTitle, Title1/2/3, Headline) use SF Rounded for a
/// soft, friendly aesthetic; body-grade styles stay on regular SF Pro to keep
/// long-form text crisply readable.
+(UIFont*)app_fontForStyle:(AppTextStyle)style;
/// Same, but with an explicit weight override.
+(UIFont*)app_fontForStyle:(AppTextStyle)style weight:(UIFontWeight)weight;
/// Same, with a monospaced-digit variant — use for ratings, durations, counters.
+(UIFont*)app_monospacedDigitFontForStyle:(AppTextStyle)style weight:(UIFontWeight)weight;
/// Explicitly rounded variant — for brand wordmarks and display elements.
+(UIFont*)app_roundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
@end


#pragma mark - Spacing

// 4-pt grid. Use these constants — keeps vertical rhythm consistent.
// Sized for iPhone first; Apple's standard layout margin is 16 (or 20 on .large).
static const CGFloat AppSpacing2  = 2;
static const CGFloat AppSpacing4  = 4;
static const CGFloat AppSpacing6  = 6;
static const CGFloat AppSpacing8  = 8;
static const CGFloat AppSpacing12 = 12;
static const CGFloat AppSpacing16 = 16;   // standard screen margin
static const CGFloat AppSpacing20 = 20;
static const CGFloat AppSpacing24 = 24;
static const CGFloat AppSpacing32 = 32;
static const CGFloat AppSpacing40 = 40;
static const CGFloat AppSpacing48 = 48;
static const CGFloat AppSpacing64 = 64;


#pragma mark - Radii

// Continuous corners — set cornerCurve = kCACornerCurveContinuous on the layer.
static const CGFloat AppRadiusSmall  = 8;    // chips, thumbnails, small posters
static const CGFloat AppRadiusMedium = 12;   // inputs, list rows, secondary buttons
static const CGFloat AppRadiusLarge  = 16;   // cards, primary buttons, posters
static const CGFloat AppRadiusXLarge = 22;   // sheets, large hero artwork
static const CGFloat AppRadiusXXLarge = 28;  // hero poster backdrops
static const CGFloat AppRadiusPill   = 999;  // capsule


#pragma mark - Motion

static const NSTimeInterval AppDurationFast    = 0.18;  // taps, micro-interactions
static const NSTimeInterval AppDurationDefault = 0.28;  // most transitions
static const NSTimeInterval AppDurationSlow    = 0.45;  // hero transitions

// Springs (UIViewPropertyAnimator). 0 = critical damping.
static const CGFloat AppSpringDampingDefault = 0.78;
static const CGFloat AppSpringDampingTaut    = 0.85;
static const CGFloat AppSpringDampingSoft    = 0.72;


NS_ASSUME_NONNULL_END
