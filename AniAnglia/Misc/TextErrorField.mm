//
//  TextErrorField.mm
//
//  Rounded text field with a coral focus border, optional password reveal
//  toggle (auto-installed for secure-text fields), and an attached error
//  label that animates in.
//

#import "TextErrorField.h"
#import "AppColor.h"

#pragma mark - Padded text field

/// UITextField subclass with horizontal padding only. Reserves trailing space
/// when an accessory (password reveal button) is present so the text doesn't
/// underrun the icon.
@interface AppPaddedTextField : UITextField
@property(nonatomic, assign) CGFloat trailingAccessoryWidth;
@end

@implementation AppPaddedTextField

static CGFloat const kHPadding = 16;

-(CGRect)textRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds, UIEdgeInsetsMake(0, kHPadding, 0, kHPadding + _trailingAccessoryWidth));
}
-(CGRect)editingRectForBounds:(CGRect)bounds {
    return [self textRectForBounds:bounds];
}
-(CGRect)placeholderRectForBounds:(CGRect)bounds {
    return [self textRectForBounds:bounds];
}
-(CGRect)clearButtonRectForBounds:(CGRect)bounds {
    CGRect r = [super clearButtonRectForBounds:bounds];
    r.origin.x -= 6 + _trailingAccessoryWidth;
    return r;
}

@end


#pragma mark - TextErrorField

@interface TextErrorField () <UITextFieldDelegate>
@property(nonatomic, retain) UITextField* field;
@property(nonatomic, retain) UILabel*     label;
@property(nonatomic, retain) UIButton*    reveal_button;  // password show/hide, nil for non-secure
@property(nonatomic, assign) BOOL hasError;
@property(nonatomic, weak)   id<UITextFieldDelegate> externalDelegate;
@end

@implementation TextErrorField

static CGFloat const kFieldHeight = 52;
static CGFloat const kFieldRadius = 14;
static CGFloat const kBorderWidth = 1.5;
static CGFloat const kRevealWidth = 44;

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    [self setup];
    [self applyColors];
    return self;
}

-(void)setup {
    _field = [AppPaddedTextField new];
    _field.font = [UIFont app_fontForStyle:AppTextStyleBody];
    _field.borderStyle = UITextBorderStyleNone;
    _field.layer.cornerRadius = kFieldRadius;
    _field.layer.cornerCurve = kCACornerCurveContinuous;
    _field.layer.borderWidth = 0;
    _field.adjustsFontForContentSizeCategory = YES;
    _field.delegate = self;
    [_field addTarget:self action:@selector(onEditingDidBegin) forControlEvents:UIControlEventEditingDidBegin];
    [_field addTarget:self action:@selector(onEditingDidEnd)   forControlEvents:UIControlEventEditingDidEnd];

    _label = [UILabel new];
    _label.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _label.numberOfLines = 0;
    _label.adjustsFontForContentSizeCategory = YES;
    _label.alpha = 0;

    [self addSubview:_field];
    [self addSubview:_label];

    _field.translatesAutoresizingMaskIntoConstraints = NO;
    _label.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_field.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_field.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_field.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_field.heightAnchor   constraintEqualToConstant:kFieldHeight],

        [_label.topAnchor      constraintEqualToAnchor:_field.bottomAnchor constant:AppSpacing6],
        [_label.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing4],
        [_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing4],
        [_label.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor]
    ]];
}

-(void)applyColors {
    _field.backgroundColor = [AppColorProvider surfaceSunkenColor];
    _field.textColor       = [AppColorProvider textColor];
    _label.textColor       = [AppColorProvider dangerColor];
    _field.layer.borderColor = _hasError
        ? [AppColorProvider dangerColor].CGColor
        : [AppColorProvider primaryColor].CGColor;
    if (_reveal_button) {
        _reveal_button.tintColor = [AppColorProvider textSecondaryColor];
    }
}

-(void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    [self applyColors];
}

#pragma mark - Reveal-on-secure

-(void)installRevealIfNeeded {
    if (_reveal_button || !_field.isSecureTextEntry) return;

    _reveal_button = [UIButton buttonWithType:UIButtonTypeSystem];
    _reveal_button.translatesAutoresizingMaskIntoConstraints = NO;
    _reveal_button.tintColor = [AppColorProvider textSecondaryColor];
    [_reveal_button setImage:[UIImage systemImageNamed:@"eye"] forState:UIControlStateNormal];
    [_reveal_button setPreferredSymbolConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold]
                                    forImageInState:UIControlStateNormal];
    [_reveal_button addTarget:self action:@selector(onRevealTapped) forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:_reveal_button];
    [NSLayoutConstraint activateConstraints:@[
        [_reveal_button.trailingAnchor constraintEqualToAnchor:_field.trailingAnchor constant:-AppSpacing8],
        [_reveal_button.centerYAnchor  constraintEqualToAnchor:_field.centerYAnchor],
        [_reveal_button.widthAnchor    constraintEqualToConstant:kRevealWidth - AppSpacing8],
        [_reveal_button.heightAnchor   constraintEqualToConstant:kFieldHeight],
    ]];
    ((AppPaddedTextField*)_field).trailingAccessoryWidth = kRevealWidth;
    [_field setNeedsLayout];
}

-(void)onRevealTapped {
    BOOL becomeVisible = _field.isSecureTextEntry;
    _field.secureTextEntry = !becomeVisible;
    NSString* sym = becomeVisible ? @"eye.slash" : @"eye";
    [_reveal_button setImage:[UIImage systemImageNamed:sym] forState:UIControlStateNormal];
}

#pragma mark - Focus highlight

-(void)onEditingDidBegin {
    [self installRevealIfNeeded];
    [UIView animateWithDuration:AppDurationFast animations:^{
        self->_field.layer.borderWidth = self->_hasError ? kBorderWidth : 1.0;
    }];
}

-(void)onEditingDidEnd {
    if (_hasError) return;
    [UIView animateWithDuration:AppDurationFast animations:^{
        self->_field.layer.borderWidth = 0;
    }];
}

#pragma mark - Error state

-(void)showError:(NSString*)message {
    _hasError = YES;
    _label.text = message;
    _field.layer.borderColor = [AppColorProvider dangerColor].CGColor;
    [UIView animateWithDuration:AppDurationFast animations:^{
        self->_field.layer.borderWidth = kBorderWidth;
        self->_label.alpha = 1;
    }];
}

-(void)clearError {
    if (!_hasError) return;
    _hasError = NO;
    _field.layer.borderColor = [AppColorProvider primaryColor].CGColor;
    [UIView animateWithDuration:AppDurationFast animations:^{
        self->_field.layer.borderWidth = self->_field.isFirstResponder ? 1.0 : 0;
        self->_label.alpha = 0;
    } completion:^(BOOL finished) {
        if (!self->_hasError) self->_label.text = nil;
    }];
}

#pragma mark - UITextFieldDelegate (forward to consumer)

// The consumer set `field.delegate = self` externally; we intercept it here to
// keep our focus animations working. Forward to whoever was set last.
-(void)setExternalDelegateIfNeeded:(id<UITextFieldDelegate>)d {
    if (d != (id)self) _externalDelegate = d;
}

-(BOOL)textFieldShouldReturn:(UITextField*)tf {
    if ([_externalDelegate respondsToSelector:@selector(textFieldShouldReturn:)]) {
        return [_externalDelegate textFieldShouldReturn:tf];
    }
    return YES;
}

@end
