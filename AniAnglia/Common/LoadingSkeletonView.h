//
//  LoadingSkeletonView.h
//
//  Animated shimmer placeholder. Used while content (poster grids, lists) is
//  loading. Cheap — single CAGradientLayer per skeleton; pauses when off-screen.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LoadingSkeletonView : UIView
/// Start/stop the shimmer animation. Auto-managed when added/removed from a
/// window, but callers can force-pause when paginating.
-(void)startAnimating;
-(void)stopAnimating;
@end

NS_ASSUME_NONNULL_END
