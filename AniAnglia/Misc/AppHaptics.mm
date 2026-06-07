//
//  AppHaptics.mm
//

#import "AppHaptics.h"

static BOOL yk_hapticsAllowed(void) {
    // Reduce Motion shouldn't disable haptics, but we still gate to avoid
    // misbehaving on devices with no Taptic Engine — generators are no-ops
    // there, so the gate is mostly for symmetry.
    return YES;
}

@implementation AppHaptics

+(void)selection {
    if (!yk_hapticsAllowed()) return;
    UISelectionFeedbackGenerator* g = [UISelectionFeedbackGenerator new];
    [g prepare];
    [g selectionChanged];
}

+(void)impactLight  { [self _impactStyle:UIImpactFeedbackStyleLight]; }
+(void)impactMedium { [self _impactStyle:UIImpactFeedbackStyleMedium]; }
+(void)impactRigid  { [self _impactStyle:UIImpactFeedbackStyleRigid]; }

+(void)_impactStyle:(UIImpactFeedbackStyle)style {
    if (!yk_hapticsAllowed()) return;
    UIImpactFeedbackGenerator* g = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
    [g prepare];
    [g impactOccurred];
}

+(void)notifySuccess { [self _notify:UINotificationFeedbackTypeSuccess]; }
+(void)notifyWarning { [self _notify:UINotificationFeedbackTypeWarning]; }
+(void)notifyError   { [self _notify:UINotificationFeedbackTypeError]; }

+(void)_notify:(UINotificationFeedbackType)type {
    if (!yk_hapticsAllowed()) return;
    UINotificationFeedbackGenerator* g = [UINotificationFeedbackGenerator new];
    [g prepare];
    [g notificationOccurred:type];
}

@end
