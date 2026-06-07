//
//  WatchStatusPill.mm
//

#import "WatchStatusPill.h"
#import "AppColor.h"
#import "AppMaterial.h"

@implementation WatchStatusPill {
    UIImageView* _icon;
    UILabel*     _label;
    UIView*      _tintWash;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    [AppMaterial applyGlassToView:self style:AppMaterialStyleChip shape:AppMaterialShapeCapsule];

    _tintWash = [UIView new];
    _tintWash.translatesAutoresizingMaskIntoConstraints = NO;
    _tintWash.userInteractionEnabled = NO;
    _tintWash.alpha = 0.25;
    [self insertSubview:_tintWash atIndex:1];

    _icon = [UIImageView new];
    _icon.contentMode = UIViewContentModeScaleAspectFit;
    _icon.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];

    _label = [UILabel new];
    _label.font = [UIFont app_fontForStyle:AppTextStyleCaption1 weight:UIFontWeightSemibold];
    _label.adjustsFontForContentSizeCategory = YES;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[_icon, _label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = AppSpacing4;
    stack.userInteractionEnabled = NO;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [_tintWash.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_tintWash.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_tintWash.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_tintWash.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [stack.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing8],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing8],
        [stack.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing4],
        [stack.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing4],
    ]];
    return self;
}

-(void)setStatus:(WatchStatusKind)status {
    [self setStatus:status text:nil];
}

-(void)setStatus:(WatchStatusKind)status text:(NSString*)customText {
    UIColor* tint;     NSString* symbol; NSString* fallback;
    switch (status) {
        case WatchStatusWatching: tint=[AppColorProvider accentMintColor];   symbol=@"play.fill";          fallback=@"Смотрю";       break;
        case WatchStatusPlanned:  tint=[AppColorProvider accentBlueColor];   symbol=@"clock.fill";         fallback=@"В планах";     break;
        case WatchStatusWatched:  tint=[AppColorProvider successColor];      symbol=@"checkmark.seal.fill";fallback=@"Просмотрено"; break;
        case WatchStatusOnHold:   tint=[AppColorProvider warningColor];      symbol=@"pause.fill";         fallback=@"Отложено";    break;
        case WatchStatusDropped:  tint=[AppColorProvider dangerColor];       symbol=@"xmark.octagon.fill"; fallback=@"Брошено";     break;
        case WatchStatusFavorite: tint=[AppColorProvider primaryColor];      symbol=@"heart.fill";         fallback=@"Любимое";     break;
        case WatchStatusNone:
        default:                  tint=[AppColorProvider textSecondaryColor];symbol=@"square.dashed";      fallback=@"—";           break;
    }
    _icon.image = [UIImage systemImageNamed:symbol];
    _icon.tintColor = tint;
    _label.text = customText ?: fallback;
    _label.textColor = tint;
    _tintWash.backgroundColor = tint;
    self.accessibilityLabel = _label.text;
}

@end
