//
//  WatchStatusPill.h
//
//  Capsule pill showing watch status: watching / planned / watched / dropped /
//  on-hold. Color-coded but also carries a status-specific SF Symbol so the
//  state isn't conveyed by color alone (a11y rule).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WatchStatusKind) {
    WatchStatusNone,
    WatchStatusWatching,
    WatchStatusPlanned,
    WatchStatusWatched,
    WatchStatusOnHold,
    WatchStatusDropped,
    WatchStatusFavorite,
};

@interface WatchStatusPill : UIView
-(void)setStatus:(WatchStatusKind)status;
-(void)setStatus:(WatchStatusKind)status text:(nullable NSString*)customText;
@end

NS_ASSUME_NONNULL_END
