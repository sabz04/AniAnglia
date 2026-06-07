//
//  CodeEnterViewController.mm
//
//  Verification-code entry. Single centered field, primary submit button,
//  text-style "Resend code" link below. Native textContentType.oneTimeCode
//  lets iOS surface the SMS/email code in the QuickType bar automatically.
//

#import "CodeEnterViewController.h"
#import "AppColor.h"
#import "AuthChrome.h"
#import "TextErrorField.h"

@interface CodeEnterViewController () <UITextFieldDelegate>
@property(nonatomic, retain) UIScrollView*   scroll_view;
@property(nonatomic, retain) UILabel*        title_label;
@property(nonatomic, retain) UILabel*        subtitle_label;
@property(nonatomic, retain) TextErrorField* code_view;
@property(nonatomic, retain) UITextField*    code_field;
@property(nonatomic, retain) UILabel*        check_spam_label;
@property(nonatomic, retain) UIButton*       submit_button;
@property(nonatomic, retain) UIActivityIndicatorView* submit_indicator;
@property(nonatomic, retain) UIButton*       resend_button;
@property(nonatomic, retain) NSString*       pending_error_text;
@end

@implementation CodeEnterViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [AuthChrome installBackgroundDecorationIn:self.view];
    [self setupViews];
    [self setupLayout];
    [self subscribeKeyboard];

    if (_pending_error_text) {
        [_code_view showError:_pending_error_text];
        _pending_error_text = nil;
    }
}

-(void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Setup

-(void)setupViews {
    _scroll_view = [UIScrollView new];
    _scroll_view.alwaysBounceVertical = YES;
    _scroll_view.keyboardDismissMode  = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:_scroll_view];

    _code_view = [TextErrorField new];
    _code_field = _code_view.field;
    _code_field.placeholder = @"Введите код из email";
    _code_field.autocorrectionType = UITextAutocorrectionTypeNo;
    _code_field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _code_field.returnKeyType = UIReturnKeyDone;
    _code_field.clearButtonMode = UITextFieldViewModeWhileEditing;
    _code_field.textContentType = UITextContentTypeOneTimeCode;
    _code_field.keyboardType = UIKeyboardTypeDefault;
    _code_field.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightSemibold];
    _code_field.delegate = self;
    [_code_field addTarget:self action:@selector(codeFieldChanged) forControlEvents:UIControlEventEditingChanged];

    _submit_button = [AuthChrome primaryButtonWithTitle:@"Подтвердить"];
    [_submit_button addTarget:self action:@selector(onSubmitButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    _submit_indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _submit_indicator.color = UIColor.whiteColor;
    _submit_indicator.hidesWhenStopped = YES;

    _resend_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_resend_button setTitle:@"Отправить ещё раз" forState:UIControlStateNormal];
    [_resend_button setTitleColor:[AppColorProvider primaryColor] forState:UIControlStateNormal];
    _resend_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    [_resend_button addTarget:self action:@selector(onResendButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
}

-(void)setupLayout {
    UIView* content = [UIView new];
    [_scroll_view addSubview:content];

    UIView* hero = [AuthChrome heroHeaderWithEyebrow:@"Подтверждение"
                                            subtitle:@"Если код не приходит, проверьте папку «Спам» — он может задержаться на пару минут."
                                            iconName:@"envelope.badge.shield.half.filled.fill"];

    UIView* fieldsCard = [AuthChrome fieldsCardWithFields:@[_code_view]];

    [content addSubview:hero];
    [content addSubview:fieldsCard];
    [content addSubview:_submit_button];
    [_submit_button addSubview:_submit_indicator];
    [content addSubview:_resend_button];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    _submit_button.translatesAutoresizingMaskIntoConstraints = NO;
    _submit_indicator.translatesAutoresizingMaskIntoConstraints = NO;
    _resend_button.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll_view.topAnchor      constraintEqualToAnchor:safe.topAnchor],
        [_scroll_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [content.topAnchor      constraintEqualToAnchor:_scroll_view.contentLayoutGuide.topAnchor],
        [content.leadingAnchor  constraintEqualToAnchor:_scroll_view.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:_scroll_view.contentLayoutGuide.trailingAnchor],
        [content.bottomAnchor   constraintEqualToAnchor:_scroll_view.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor    constraintEqualToAnchor:_scroll_view.frameLayoutGuide.widthAnchor],

        [hero.topAnchor      constraintEqualToAnchor:content.topAnchor constant:AppSpacing24],
        [hero.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing24],
        [hero.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing24],

        [fieldsCard.topAnchor      constraintEqualToAnchor:hero.bottomAnchor constant:AppSpacing24],
        [fieldsCard.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [fieldsCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],

        [_submit_button.topAnchor      constraintEqualToAnchor:fieldsCard.bottomAnchor constant:AppSpacing24],
        [_submit_button.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [_submit_button.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],
        [_submit_button.heightAnchor   constraintEqualToConstant:54],

        [_submit_indicator.centerXAnchor constraintEqualToAnchor:_submit_button.centerXAnchor],
        [_submit_indicator.centerYAnchor constraintEqualToAnchor:_submit_button.centerYAnchor],

        [_resend_button.topAnchor    constraintEqualToAnchor:_submit_button.bottomAnchor constant:AppSpacing16],
        [_resend_button.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [_resend_button.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-AppSpacing32],
    ]];
}

#pragma mark - Keyboard

-(void)subscribeKeyboard {
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillShowNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillHide:)  name:UIKeyboardWillHideNotification object:nil];
}

-(void)keyboardWillChange:(NSNotification*)note {
    CGRect frame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect inView = [self.view convertRect:frame fromView:nil];
    CGFloat inset = MAX(0, CGRectGetMaxY(self.view.bounds) - inView.origin.y);
    _scroll_view.contentInset = UIEdgeInsetsMake(0, 0, inset, 0);
    _scroll_view.verticalScrollIndicatorInsets = _scroll_view.contentInset;
}

-(void)keyboardWillHide:(NSNotification*)note {
    _scroll_view.contentInset = UIEdgeInsetsZero;
    _scroll_view.verticalScrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - Public

-(void)showCodeError:(NSString*)error_message {
    if (!_code_view) { _pending_error_text = error_message; return; }
    if (error_message) [_code_view showError:error_message];
    else               [_code_view clearError];
}

#pragma mark - State

-(void)setSubmitLoading:(BOOL)loading {
    if (loading) {
        [_submit_indicator startAnimating];
        [_submit_button setTitle:@"" forState:UIControlStateNormal];
        _submit_button.enabled = NO;
    } else {
        [_submit_indicator stopAnimating];
        [_submit_button setTitle:@"Подтвердить" forState:UIControlStateNormal];
        _submit_button.enabled = YES;
    }
}

-(void)codeFieldChanged {
    [_code_view clearError];
}

#pragma mark - Actions

-(IBAction)onResendButtonPressed:(UIButton*)sender {
    _resend_button.enabled = NO;
    [_delegate didResendForCodeEnterViewController:self completionHandler:^(BOOL errored) {
        self->_resend_button.enabled = YES;
    }];
}

-(IBAction)onSubmitButtonPressed:(UIButton*)sender {
    [_code_field resignFirstResponder];
    [self setSubmitLoading:YES];
    [_delegate codeEnterViewController:self didSubmitedCode:_code_field.text completionHandler:^(BOOL errored) {
        [self setSubmitLoading:NO];
    }];
}

-(BOOL)textFieldShouldReturn:(UITextField*)text_field {
    [text_field resignFirstResponder];
    [self onSubmitButtonPressed:nil];
    return NO;
}

@end
