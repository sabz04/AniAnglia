//
//  AppBackdrop.h
//
//  Soft brand backdrop that lives behind every primary screen. Two faint
//  radial gradient blobs — coral in the top-right, pastel blue in the
//  bottom-left — drawn over the host view's solid background. Idempotent
//  (calling twice on the same view is a no-op).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppBackdrop : NSObject

/// Install the soft yukimo backdrop behind every other subview of `view`.
+(void)installIn:(UIView*)view;

@end

NS_ASSUME_NONNULL_END
