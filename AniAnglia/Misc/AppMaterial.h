//
//  AppMaterial.h
//
//  iOS 26 Liquid Glass abstraction with graceful fallback to `UIVisualEffectView`
//  on iOS 15–25 and solid surfaces on iOS 14. Honors Reduce Transparency and
//  Increase Contrast.
//
//  Usage:
//    UIView* bg = [AppMaterial glassBackgroundForStyle:AppMaterialStyleNav
//                                                shape:AppMaterialShapeCapsule];
//    [AppMaterial applyGlass:bg toContainer:button shape:AppMaterialShapeCapsule];
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AppMaterialStyle) {
    /// Heavy translucent surface — used under primary nav (tab bar, toolbar).
    AppMaterialStyleNav,
    /// Lighter translucent surface — floating pills, badges, overlay actions.
    AppMaterialStylePill,
    /// Modal-grade surface — bottom sheets, large panels over content.
    AppMaterialStyleSheet,
    /// Strongest contrast — player controls overlay (must read on bright video).
    AppMaterialStylePlayerControls,
    /// Light, very subtle — for non-critical chips and inline badges.
    AppMaterialStyleChip,
};

typedef NS_ENUM(NSInteger, AppMaterialShape) {
    AppMaterialShapeNone,      ///< No corner mask
    AppMaterialShapeCard,      ///< AppRadiusLarge, continuous
    AppMaterialShapeSheet,     ///< AppRadiusXLarge, continuous
    AppMaterialShapeCapsule,   ///< Pill / capsule (height/2 corner radius)
    AppMaterialShapeChip,      ///< AppRadiusMedium
};

@interface AppMaterial : NSObject

/// Returns a brand-new background view configured for `style`. The view is
/// either a `UIVisualEffectView` (with Liquid Glass on iOS 26+ when available)
/// or a solid `UIView` if transparency is reduced. Either way, callers treat
/// it as a normal `UIView` and add it as a background subview.
+(UIView*)glassBackgroundForStyle:(AppMaterialStyle)style
                            shape:(AppMaterialShape)shape;

/// Convenience: build a glass background and pin it to `container.bounds`,
/// behind all existing subviews. Returns the inserted background.
+(UIView*)applyGlassToView:(UIView*)container
                     style:(AppMaterialStyle)style
                     shape:(AppMaterialShape)shape;

/// Apply the shape's corner mask to an arbitrary view (continuous curve).
+(void)applyShape:(AppMaterialShape)shape toView:(UIView*)view;

/// YES when the current trait collection asks for solid surfaces (Reduce
/// Transparency or Increase Contrast or iOS<15).
+(BOOL)prefersSolidSurfaceForTraits:(nullable UITraitCollection*)traits;

/// Add a subtle 1px inner stroke + top highlight to a glass view. Idempotent.
+(void)decorateGlassEdges:(UIView*)glassBackground;

/// Apply a soft floating shadow appropriate for floating glass elements.
/// `pathBounds` is the view's bounds at time of call — recompute on layout.
+(void)applyFloatingShadowTo:(UIView*)view
                  withRadius:(CGFloat)cornerRadius
                  pathBounds:(CGRect)pathBounds;

@end

NS_ASSUME_NONNULL_END
