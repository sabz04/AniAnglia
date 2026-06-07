//
//  EmptyStateView.h
//
//  Generic empty / error state: large SF Symbol, headline, optional subhead,
//  optional action button. Used everywhere a list returns nothing.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface EmptyStateView : UIView
@property(nonatomic, strong, nullable) UIImage*  icon;
@property(nonatomic, copy)             NSString* title;
@property(nonatomic, copy, nullable)   NSString* subtitle;
@property(nonatomic, copy, nullable)   NSString* actionTitle;
@property(nonatomic, copy, nullable)   void (^actionHandler)(void);
@end

NS_ASSUME_NONNULL_END
