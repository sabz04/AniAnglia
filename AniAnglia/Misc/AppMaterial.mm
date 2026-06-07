//
//  AppMaterial.mm
//
//  Liquid Glass / material abstraction.
//
//  iOS 26+ exposes a `UIGlassEffect` class. We resolve it via NSClassFromString
//  at runtime so the project keeps building against the iOS 17.4 SDK that's in
//  CI today. The compiled code probes for it and falls back to UIBlurEffect.
//

#import "AppMaterial.h"
#import "AppColor.h"


#pragma mark - shape helper

static CGFloat yk_radiusForShape(AppMaterialShape shape, CGRect bounds) {
    switch (shape) {
        case AppMaterialShapeNone:    return 0;
        case AppMaterialShapeChip:    return AppRadiusMedium;
        case AppMaterialShapeCard:    return AppRadiusLarge;
        case AppMaterialShapeSheet:   return AppRadiusXLarge;
        case AppMaterialShapeCapsule: return MIN(bounds.size.height, bounds.size.width) / 2.0;
    }
    return 0;
}


#pragma mark - solid-fallback surface

// Shown when Reduce Transparency is on. Mimics UIVisualEffectView's contentView
// so callers can use one cast-free code path.
@interface YKSolidSurfaceView : UIView
@property(nonatomic, strong, readonly) UIView* contentView;
@property(nonatomic, assign) AppMaterialStyle style;
@end

@implementation YKSolidSurfaceView

-(instancetype)initWithStyle:(AppMaterialStyle)style {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _style = style;
    _contentView = [UIView new];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_contentView];
    [NSLayoutConstraint activateConstraints:@[
        [_contentView.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_contentView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_contentView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
    ]];
    [self refreshFill];
    return self;
}

-(void)refreshFill {
    switch (_style) {
        case AppMaterialStylePlayerControls:
            self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
            return;
        case AppMaterialStyleNav:
        case AppMaterialStyleSheet:
            self.backgroundColor = [AppColorProvider surfaceElevatedColor];
            return;
        case AppMaterialStylePill:
        case AppMaterialStyleChip:
        default:
            self.backgroundColor = [AppColorProvider surfaceColor];
            return;
    }
}

-(void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    [self refreshFill];
}

@end


#pragma mark - glass background view

// Owns either a UIVisualEffectView (iOS 15-25 blur or iOS 26 Liquid Glass) or
// a solid fallback; manages its own 1px inner stroke and corner shape so
// callers don't have to think about layout passes.
@interface YKGlassBackgroundView : UIView
@property(nonatomic, strong, readonly) UIView* contentView;
@property(nonatomic, assign) AppMaterialStyle style;
@property(nonatomic, assign) AppMaterialShape shape;
@end

@implementation YKGlassBackgroundView {
    UIView*  _surface;        // either UIVisualEffectView or YKSolidSurfaceView
    CALayer* _borderLayer;
}

// Probe for the iOS 26 `UIGlassEffect` class. Cached once.
static Class yk_glassEffectClass(void) {
    static Class klass = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(iOS 26.0, *)) {
            klass = NSClassFromString(@"UIGlassEffect");
        }
    });
    return klass;
}

static UIVisualEffect* yk_effectForStyle(AppMaterialStyle style) {
    Class glassClass = yk_glassEffectClass();
    if (glassClass) {
        UIVisualEffect* effect = [[glassClass alloc] init];
        if ([effect respondsToSelector:@selector(setValue:forKey:)]) {
            // UIGlassEffect.interactive (iOS 26) enables motion-reactive
            // refraction. Defensive KVC so SDK absence doesn't crash.
            @try { [effect setValue:@YES forKey:@"interactive"]; } @catch (__unused id e) {}
        }
        return effect;
    }
    UIBlurEffectStyle blur;
    switch (style) {
        case AppMaterialStyleNav:            blur = UIBlurEffectStyleSystemChromeMaterial;        break;
        case AppMaterialStyleSheet:          blur = UIBlurEffectStyleSystemMaterial;              break;
        case AppMaterialStylePlayerControls: blur = UIBlurEffectStyleSystemUltraThinMaterialDark; break;
        case AppMaterialStylePill:
        case AppMaterialStyleChip:
        default:                             blur = UIBlurEffectStyleSystemUltraThinMaterial;     break;
    }
    return [UIBlurEffect effectWithStyle:blur];
}

-(instancetype)initWithStyle:(AppMaterialStyle)style shape:(AppMaterialShape)shape {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _style = style;
    _shape = shape;
    [self buildSurface];
    [self installBorderLayer];
    self.layer.cornerCurve = kCACornerCurveContinuous;
    return self;
}

-(void)buildSurface {
    BOOL solid = UIAccessibilityIsReduceTransparencyEnabled();
    if (solid) {
        YKSolidSurfaceView* fallback = [[YKSolidSurfaceView alloc] initWithStyle:_style];
        fallback.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:fallback];
        _surface = fallback;
        _contentView = fallback.contentView;
    } else {
        UIVisualEffectView* fx = [[UIVisualEffectView alloc] initWithEffect:yk_effectForStyle(_style)];
        fx.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:fx];

        // Faint brand wash inside the contentView gives the glass a warm tone
        // on Nav / Sheet styles. Skipped on player controls (must stay neutral).
        if (_style == AppMaterialStyleNav || _style == AppMaterialStyleSheet) {
            UIView* wash = [UIView new];
            wash.backgroundColor = [AppColorProvider glassSurfaceColor];
            wash.translatesAutoresizingMaskIntoConstraints = NO;
            wash.userInteractionEnabled = NO;
            [fx.contentView addSubview:wash];
            [NSLayoutConstraint activateConstraints:@[
                [wash.topAnchor      constraintEqualToAnchor:fx.contentView.topAnchor],
                [wash.leadingAnchor  constraintEqualToAnchor:fx.contentView.leadingAnchor],
                [wash.trailingAnchor constraintEqualToAnchor:fx.contentView.trailingAnchor],
                [wash.bottomAnchor   constraintEqualToAnchor:fx.contentView.bottomAnchor],
            ]];
        }
        _surface = fx;
        _contentView = fx.contentView;
    }

    [NSLayoutConstraint activateConstraints:@[
        [_surface.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_surface.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_surface.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_surface.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
    ]];
    self.layer.masksToBounds = YES;
}

-(void)installBorderLayer {
    _borderLayer = [CALayer layer];
    _borderLayer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _borderLayer.borderColor = [AppColorProvider glassBorderColor].CGColor;
    _borderLayer.cornerCurve = kCACornerCurveContinuous;
    _borderLayer.zPosition   = 1000;
    [self.layer addSublayer:_borderLayer];
}

-(void)layoutSubviews {
    [super layoutSubviews];
    if (_shape == AppMaterialShapeCapsule) {
        self.layer.cornerRadius = self.bounds.size.height / 2.0;
    } else {
        self.layer.cornerRadius = yk_radiusForShape(_shape, self.bounds);
    }
    _borderLayer.frame = self.bounds;
    _borderLayer.cornerRadius = self.layer.cornerRadius;
}

-(void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    _borderLayer.borderColor = [AppColorProvider glassBorderColor].CGColor;
}

@end


#pragma mark - AppMaterial

@implementation AppMaterial

+(BOOL)prefersSolidSurfaceForTraits:(UITraitCollection*)traits {
    if (UIAccessibilityIsReduceTransparencyEnabled()) return YES;
    return NO;
}

+(UIView*)glassBackgroundForStyle:(AppMaterialStyle)style
                            shape:(AppMaterialShape)shape {
    return [[YKGlassBackgroundView alloc] initWithStyle:style shape:shape];
}

+(UIView*)applyGlassToView:(UIView*)container
                     style:(AppMaterialStyle)style
                     shape:(AppMaterialShape)shape {
    UIView* bg = [self glassBackgroundForStyle:style shape:shape];
    bg.translatesAutoresizingMaskIntoConstraints = NO;
    bg.userInteractionEnabled = NO;
    [container insertSubview:bg atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [bg.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [bg.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [bg.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [bg.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return bg;
}

+(void)applyShape:(AppMaterialShape)shape toView:(UIView*)view {
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.masksToBounds = YES;
    if (shape == AppMaterialShapeCapsule) {
        view.layer.cornerRadius = view.bounds.size.height / 2.0;
    } else {
        view.layer.cornerRadius = yk_radiusForShape(shape, view.bounds);
    }
}

+(void)decorateGlassEdges:(UIView*)glassBackground {
    // Edge decoration is owned by YKGlassBackgroundView. This method is kept
    // for callers that may need to redecorate after a custom transform.
}

+(void)applyFloatingShadowTo:(UIView*)view
                  withRadius:(CGFloat)cornerRadius
                  pathBounds:(CGRect)pathBounds {
    view.layer.shadowColor   = UIColor.blackColor.CGColor;
    view.layer.shadowOpacity = 0.18;
    view.layer.shadowRadius  = 24;
    view.layer.shadowOffset  = CGSizeMake(0, 12);
    view.layer.shadowPath    = [UIBezierPath bezierPathWithRoundedRect:pathBounds
                                                          cornerRadius:cornerRadius].CGPath;
    view.layer.masksToBounds = NO;
}

@end
