//
//  RatingBadge.h
//
//  Tinted-glass badge showing a rating number, e.g. "8.4". Used on poster
//  cards and on the release detail screen.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RatingBadge : UIView
/// Convenience: configure with a numeric rating in 0–10 range.
-(void)setRating:(float)rating;
/// Set arbitrary text (e.g. "Топ-100", "Новинка").
-(void)setText:(NSString*)text;
@end

NS_ASSUME_NONNULL_END
