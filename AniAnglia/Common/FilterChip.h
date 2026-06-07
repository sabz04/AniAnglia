//
//  FilterChip.h
//
//  Selectable pill used for filter bars. Tap toggles `selected`; the chip
//  animates between coral-filled (selected) and ghost-glass (deselected).
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FilterChip : UIControl
@property(nonatomic, copy)   NSString* title;
@property(nonatomic, strong, nullable) UIImage* icon;
@end

NS_ASSUME_NONNULL_END
