//
//  AppHaptics.h
//
//  Lightweight haptic feedback wrapper. Respects Reduce Motion / Accessibility
//  preferences: callers don't need to gate themselves.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppHaptics : NSObject

/// Soft tap — for selection feedback (chip toggle, tab change).
+(void)selection;

/// Medium impact — primary CTA tap, sheet open/close.
+(void)impactLight;
+(void)impactMedium;
+(void)impactRigid;

/// Notification — success/warning/error confirmations.
+(void)notifySuccess;
+(void)notifyWarning;
+(void)notifyError;

@end

NS_ASSUME_NONNULL_END
