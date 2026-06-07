//
//  FilterChip.mm
//

#import "FilterChip.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppHaptics.h"

@implementation FilterChip {
    UIView*       _glassBackground;
    UIView*       _selectedBackground;
    UIImageView*  _iconView;
    UILabel*      _label;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;

    _glassBackground = [AppMaterial glassBackgroundForStyle:AppMaterialStyleChip shape:AppMaterialShapeCapsule];
    _glassBackground.translatesAutoresizingMaskIntoConstraints = NO;
    _glassBackground.userInteractionEnabled = NO;
    [self addSubview:_glassBackground];

    _selectedBackground = [UIView new];
    _selectedBackground.translatesAutoresizingMaskIntoConstraints = NO;
    _selectedBackground.userInteractionEnabled = NO;
    _selectedBackground.backgroundColor = [AppColorProvider primaryColor];
    _selectedBackground.alpha = 0;
    _selectedBackground.layer.cornerCurve = kCACornerCurveContinuous;
    _selectedBackground.layer.masksToBounds = YES;
    [self addSubview:_selectedBackground];

    _iconView = [UIImageView new];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
    _iconView.userInteractionEnabled = NO;

    _label = [UILabel new];
    _label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _label.adjustsFontForContentSizeCategory = YES;
    _label.userInteractionEnabled = NO;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = AppSpacing6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_glassBackground.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_glassBackground.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_glassBackground.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_glassBackground.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [_selectedBackground.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_selectedBackground.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_selectedBackground.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_selectedBackground.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [stack.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing12],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],
        [stack.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing8],
        [stack.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing8],
    ]];
    [self refresh];
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.height / 2.0;
    _selectedBackground.layer.cornerRadius = self.bounds.size.height / 2.0;
}

-(void)setTitle:(NSString*)title { _title = [title copy]; _label.text = title; self.accessibilityLabel = title; }
-(void)setIcon:(UIImage*)icon    { _icon = icon; _iconView.image = icon; _iconView.hidden = (icon == nil); }

-(void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [UIView animateWithDuration:AppDurationFast
                          delay:0
         usingSpringWithDamping:AppSpringDampingTaut
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        [self refresh];
    } completion:nil];
    [AppHaptics selection];
}

-(void)refresh {
    BOOL on = self.selected;
    _selectedBackground.alpha = on ? 1.0 : 0.0;
    _glassBackground.alpha    = on ? 0.0 : 1.0;
    _label.textColor    = on ? [AppColorProvider textOnPrimaryColor] : [AppColorProvider textColor];
    _iconView.tintColor = on ? [AppColorProvider textOnPrimaryColor] : [AppColorProvider primaryColor];
}

-(void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:AppDurationFast animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.96, 0.96) : CGAffineTransformIdentity;
    }];
}

@end
