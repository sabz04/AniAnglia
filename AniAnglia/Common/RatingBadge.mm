//
//  RatingBadge.mm
//

#import "RatingBadge.h"
#import "AppColor.h"
#import "AppMaterial.h"

@implementation RatingBadge {
    UIImageView* _star;
    UILabel*     _label;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self buildSubviews];
    return self;
}

-(void)buildSubviews {
    [AppMaterial applyGlassToView:self
                            style:AppMaterialStylePill
                            shape:AppMaterialShapeCapsule];

    _star = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"star.fill"]];
    _star.tintColor = [AppColorProvider accentYellowColor];
    _star.contentMode = UIViewContentModeScaleAspectFit;
    _star.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:10 weight:UIImageSymbolWeightBold];

    _label = [UILabel new];
    _label.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleFootnote weight:UIFontWeightSemibold];
    _label.textColor = [AppColorProvider textOnGlassColor];
    _label.adjustsFontForContentSizeCategory = YES;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[_star, _label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = AppSpacing4;
    stack.userInteractionEnabled = NO;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing8],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing8],
        [stack.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing4],
        [stack.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing4],
    ]];
}

-(void)setRating:(float)rating {
    _label.text = [NSString stringWithFormat:@"%.1f", rating];
    _star.hidden = NO;
    self.accessibilityLabel = [NSString stringWithFormat:@"Рейтинг %.1f из 10", rating];
}

-(void)setText:(NSString*)text {
    _label.text = text;
    _star.hidden = YES;
    self.accessibilityLabel = text;
}

@end
