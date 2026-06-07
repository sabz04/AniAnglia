//
//  TextErrorField.h
//
//  Rounded text field with an attached error label.
//  Matches Apple's input-field aesthetic in Settings / Mail / App Store.
//
//  Public API kept stable: `field`, `label`, `-showError:`, `-clearError`.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TextErrorField : UIView
@property(nonatomic, readonly) UITextField* field;  // input
@property(nonatomic, readonly) UILabel*     label;  // error caption under the field

-(void)showError:(NSString*)message;
-(void)clearError;
@end

NS_ASSUME_NONNULL_END
