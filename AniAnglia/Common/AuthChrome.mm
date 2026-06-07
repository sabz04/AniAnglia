//
//  AuthChrome.mm
//

#import "AuthChrome.h"
#import "AppBackdrop.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import <objc/runtime.h>


#pragma mark - Primary button

// UIButton subclass with a spring scale-down on press — premium feel without
// any extra wiring at the call site.
@interface YKPrimaryButton : UIButton
@end

@implementation YKPrimaryButton
-(void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:AppDurationFast
                          delay:0
         usingSpringWithDamping:AppSpringDampingTaut
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = highlighted
            ? CGAffineTransformMakeScale(0.97, 0.97)
            : CGAffineTransformIdentity;
    } completion:nil];
}
@end


#pragma mark - AuthChrome

@implementation AuthChrome

+(void)installBackgroundDecorationIn:(UIView*)view {
    // Backdrop is now shared with the rest of the app — keep one source of
    // truth so a design tweak shows up everywhere at once.
    [AppBackdrop installIn:view];
}

+(UIView*)heroHeaderWithEyebrow:(NSString*)eyebrow
                       subtitle:(NSString*)subtitle
                       iconName:(NSString*)sfSymbolName {
    UIView* container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    // Glass capsule containing the icon. Sits above the wordmark.
    UIView* iconCapsule = [AppMaterial glassBackgroundForStyle:AppMaterialStylePill
                                                         shape:AppMaterialShapeCard];
    iconCapsule.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageView* icon = [[UIImageView alloc] initWithImage:
        [UIImage systemImageNamed:sfSymbolName]];
    icon.tintColor = [AppColorProvider primaryColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightSemibold];
    icon.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* iconContent = [iconCapsule respondsToSelector:@selector(contentView)]
        ? [iconCapsule performSelector:@selector(contentView)]
        : iconCapsule;
    [iconContent addSubview:icon];
    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor  constraintEqualToAnchor:iconContent.leadingAnchor  constant:AppSpacing16],
        [icon.trailingAnchor constraintEqualToAnchor:iconContent.trailingAnchor constant:-AppSpacing16],
        [icon.topAnchor      constraintEqualToAnchor:iconContent.topAnchor      constant:AppSpacing16],
        [icon.bottomAnchor   constraintEqualToAnchor:iconContent.bottomAnchor   constant:-AppSpacing16],
        [icon.widthAnchor    constraintEqualToConstant:32],
        [icon.heightAnchor   constraintEqualToConstant:32],
    ]];

    // Brand wordmark — SF Rounded Black at 56pt, tight tracking, painted with
    // a soft coral-to-deep-coral vertical gradient via a CAGradientLayer mask.
    // Renders as "yukimo" — friendly, premium, instantly recognizable.
    UILabel* wordmark = [UILabel new];
    wordmark.text = @"yukimo";
    wordmark.textColor = [AppColorProvider primaryColor];
    wordmark.translatesAutoresizingMaskIntoConstraints = NO;
    {
        UIFont* font = [UIFont app_roundedFontOfSize:56 weight:UIFontWeightHeavy];
        // Tighter tracking pulls the glyphs together — premium signature feel.
        NSMutableAttributedString* attr = [[NSMutableAttributedString alloc]
            initWithString:@"yukimo"
                attributes:@{
                    NSFontAttributeName: font,
                    NSKernAttributeName: @(-1.8),
                    NSForegroundColorAttributeName: [AppColorProvider primaryColor],
                }];
        wordmark.attributedText = attr;
    }

    UILabel* eyebrowLabel = [UILabel new];
    eyebrowLabel.text = eyebrow;
    eyebrowLabel.font = [UIFont app_fontForStyle:AppTextStyleTitle2 weight:UIFontWeightBold];
    eyebrowLabel.textColor = [AppColorProvider textColor];
    eyebrowLabel.adjustsFontForContentSizeCategory = YES;
    eyebrowLabel.numberOfLines = 0;
    eyebrowLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel* subtitleLabel = [UILabel new];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    subtitleLabel.textColor = [AppColorProvider textSecondaryColor];
    subtitleLabel.adjustsFontForContentSizeCategory = YES;
    subtitleLabel.numberOfLines = 0;
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [container addSubview:iconCapsule];
    [container addSubview:wordmark];
    [container addSubview:eyebrowLabel];
    [container addSubview:subtitleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconCapsule.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [iconCapsule.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],

        [wordmark.topAnchor         constraintEqualToAnchor:iconCapsule.bottomAnchor constant:AppSpacing20],
        [wordmark.leadingAnchor     constraintEqualToAnchor:container.leadingAnchor],

        [eyebrowLabel.topAnchor     constraintEqualToAnchor:wordmark.bottomAnchor constant:AppSpacing4],
        [eyebrowLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [eyebrowLabel.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor],

        [subtitleLabel.topAnchor      constraintEqualToAnchor:eyebrowLabel.bottomAnchor constant:AppSpacing6],
        [subtitleLabel.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitleLabel.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
    ]];
    return container;
}

+(UIButton*)primaryButtonWithTitle:(NSString*)title {
    YKPrimaryButton* button = [YKPrimaryButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[AppColorProvider textOnPrimaryColor] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    button.backgroundColor = [AppColorProvider primaryColor];
    button.layer.cornerRadius = AppRadiusLarge;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    // Soft coral-tinted drop shadow lifts the CTA off the form, signals
    // tappability without being loud.
    button.layer.shadowColor   = [AppColorProvider primaryColor].CGColor;
    button.layer.shadowOpacity = 0.30;
    button.layer.shadowRadius  = 16;
    button.layer.shadowOffset  = CGSizeMake(0, 8);
    return button;
}


+(UIView*)fieldsCardWithFields:(NSArray<UIView*>*)fields {
    UIView* card = [AppMaterial glassBackgroundForStyle:AppMaterialStyleSheet
                                                  shape:AppMaterialShapeSheet];
    card.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* content = [card respondsToSelector:@selector(contentView)]
        ? [card performSelector:@selector(contentView)]
        : card;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:fields];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = AppSpacing12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor      constraintEqualToAnchor:content.topAnchor      constant:AppSpacing20],
        [stack.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor  constant:AppSpacing16],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing16],
        [stack.bottomAnchor   constraintEqualToAnchor:content.bottomAnchor   constant:-AppSpacing20],
    ]];
    return card;
}

@end
