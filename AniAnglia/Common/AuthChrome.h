//
//  AuthChrome.h
//
//  Reusable visual chrome shared by all four auth screens (sign-in, sign-up,
//  password restore, code entry). Three pieces:
//
//    1. Decorative background blob — a soft coral radial that sits in the
//       top-right of the screen, drawn behind everything.
//    2. Hero header — yukimo wordmark + SF Symbol icon + subtitle.
//    3. Glass field card — translucent rounded surface that hosts the inputs.
//
//  The point: any auth screen ends up feeling like part of yukimo, not a
//  blank Apple template with a button.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AuthChrome : NSObject

/// Insert a decorative coral blob at the very back of `view`. Idempotent.
+(void)installBackgroundDecorationIn:(UIView*)view;

/// Build a hero header containing the yukimo wordmark, an SF Symbol glyph,
/// and a screen-specific eyebrow/subtitle pair. The returned view sets its
/// own `translatesAutoresizingMaskIntoConstraints = NO`.
+(UIView*)heroHeaderWithEyebrow:(NSString*)eyebrow
                       subtitle:(NSString*)subtitle
                       iconName:(NSString*)sfSymbolName;

/// Wrap a vertical stack of field views in a glass card surface. Returns the
/// outer card view that should be added to the screen layout.
+(UIView*)fieldsCardWithFields:(NSArray<UIView*>*)fields;

/// Coral primary button used by every auth screen. Soft drop shadow + spring
/// press-scale animation. Caller is responsible for height (54pt convention)
/// and adding their own action.
+(UIButton*)primaryButtonWithTitle:(NSString*)title;

@end

NS_ASSUME_NONNULL_END
