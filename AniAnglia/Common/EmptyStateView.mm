//
//  EmptyStateView.mm
//

#import "EmptyStateView.h"
#import "AppColor.h"
#import "AppHaptics.h"

@implementation EmptyStateView {
    UIImageView*  _iconView;
    UILabel*      _titleLabel;
    UILabel*      _subtitleLabel;
    UIButton*     _actionButton;
    UIStackView*  _stack;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    _iconView = [UIImageView new];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = [AppColorProvider textTertiaryColor];
    _iconView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:44 weight:UIImageSymbolWeightRegular];

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    _titleLabel.textColor = [AppColorProvider textColor];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.numberOfLines = 0;
    _titleLabel.adjustsFontForContentSizeCategory = YES;

    _subtitleLabel = [UILabel new];
    _subtitleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    _subtitleLabel.textColor = [AppColorProvider textSecondaryColor];
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.numberOfLines = 0;
    _subtitleLabel.adjustsFontForContentSizeCategory = YES;

    _actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _actionButton.tintColor = [AppColorProvider primaryColor];
    _actionButton.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    [_actionButton addTarget:self action:@selector(onActionTapped) forControlEvents:UIControlEventTouchUpInside];

    _stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _titleLabel, _subtitleLabel, _actionButton]];
    _stack.axis = UILayoutConstraintAxisVertical;
    _stack.alignment = UIStackViewAlignmentCenter;
    _stack.spacing = AppSpacing12;
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_stack setCustomSpacing:AppSpacing16 afterView:_iconView];
    [_stack setCustomSpacing:AppSpacing20 afterView:_subtitleLabel];

    [self addSubview:_stack];
    [NSLayoutConstraint activateConstraints:@[
        [_stack.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [_stack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_stack.leadingAnchor  constraintGreaterThanOrEqualToAnchor:self.leadingAnchor  constant:AppSpacing24],
        [_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor    constant:-AppSpacing24],
    ]];

    self.icon = [UIImage systemImageNamed:@"sparkles"];
    return self;
}

-(void)setIcon:(UIImage*)icon         { _icon = icon; _iconView.image = icon; _iconView.hidden = (icon == nil); }
-(void)setTitle:(NSString*)title      { _title = [title copy]; _titleLabel.text = title; _titleLabel.hidden = (title.length == 0); }
-(void)setSubtitle:(NSString*)s       { _subtitle = [s copy]; _subtitleLabel.text = s; _subtitleLabel.hidden = (s.length == 0); }
-(void)setActionTitle:(NSString*)t {
    _actionTitle = [t copy];
    [_actionButton setTitle:t forState:UIControlStateNormal];
    _actionButton.hidden = (t.length == 0);
}

-(void)onActionTapped {
    [AppHaptics impactLight];
    if (_actionHandler) _actionHandler();
}

@end
