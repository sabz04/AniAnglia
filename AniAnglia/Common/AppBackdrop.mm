//
//  AppBackdrop.mm
//

#import "AppBackdrop.h"
#import "AppColor.h"
#import <objc/runtime.h>

#pragma mark - YKBackdropView

// Two radial gradient blobs drawn into the view's own CGContext: coral in the
// top-right, pastel blue in the bottom-left. Redraws on bounds / trait changes
// so it always reads correctly.
@interface YKBackdropView : UIView
@end

@implementation YKBackdropView

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
    return self;
}

-(void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat coral_radius = MAX(rect.size.width, rect.size.height) * 0.95;
    CGPoint coral_centre = CGPointMake(rect.size.width  + coral_radius * 0.15,
                                       -coral_radius * 0.15);

    UIColor* coral = [[AppColorProvider primaryColor] colorWithAlphaComponent:0.30];
    UIColor* fade  = [[AppColorProvider primaryColor] colorWithAlphaComponent:0.0];
    CGFloat locations[] = { 0.0, 1.0 };

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef coral_g = CGGradientCreateWithColors(
        space,
        (CFArrayRef)@[ (id)coral.CGColor, (id)fade.CGColor ],
        locations);
    CGContextDrawRadialGradient(ctx, coral_g, coral_centre, 0, coral_centre, coral_radius,
                                kCGGradientDrawsBeforeStartLocation);
    CGGradientRelease(coral_g);

    CGFloat blue_radius = MAX(rect.size.width, rect.size.height) * 0.7;
    CGPoint blue_centre = CGPointMake(-blue_radius * 0.2,
                                      rect.size.height + blue_radius * 0.2);
    UIColor* blue  = [[AppColorProvider accentBlueColor] colorWithAlphaComponent:0.20];
    UIColor* blue0 = [[AppColorProvider accentBlueColor] colorWithAlphaComponent:0.0];
    CGGradientRef blue_g = CGGradientCreateWithColors(
        space,
        (CFArrayRef)@[ (id)blue.CGColor, (id)blue0.CGColor ],
        locations);
    CGContextDrawRadialGradient(ctx, blue_g, blue_centre, 0, blue_centre, blue_radius,
                                kCGGradientDrawsBeforeStartLocation);
    CGGradientRelease(blue_g);
    CGColorSpaceRelease(space);
}

-(void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    [self setNeedsDisplay];
}

@end


#pragma mark - AppBackdrop

@implementation AppBackdrop

+(void)installIn:(UIView*)view {
    static char kBackdropKey;
    if (objc_getAssociatedObject(view, &kBackdropKey)) return;

    YKBackdropView* backdrop = [YKBackdropView new];
    backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    [view insertSubview:backdrop atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [backdrop.topAnchor      constraintEqualToAnchor:view.topAnchor],
        [backdrop.leadingAnchor  constraintEqualToAnchor:view.leadingAnchor],
        [backdrop.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
        [backdrop.bottomAnchor   constraintEqualToAnchor:view.bottomAnchor],
    ]];
    objc_setAssociatedObject(view, &kBackdropKey, backdrop, OBJC_ASSOCIATION_ASSIGN);
}

@end
