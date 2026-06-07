//
//  RestoreViewController.mm
//
//  Password restore screen — same architecture as sign-in / sign-up:
//  scroll view + vertical stack, large title, three inputs (username,
//  new password, confirm), single primary action.
//

#import "RestoreViewController.h"
#import "AppColor.h"
#import "AuthChrome.h"
#import "TextErrorField.h"
#import "CodeEnterViewController.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "AuthPerformer.h"

@interface RestoreViewController () <UITextFieldDelegate, CodeEnterViewControllerDelegate> {
    anixart::ApiRestorePending::UPtr _pending_restore;
}
@property(nonatomic, strong) LibanixartApi* api_proxy;

@property(nonatomic, retain) UIScrollView*   scroll_view;
@property(nonatomic, retain) UILabel*        title_label;
@property(nonatomic, retain) UILabel*        subtitle_label;
@property(nonatomic, retain) TextErrorField* login_view;
@property(nonatomic, retain) UITextField*    login_field;
@property(nonatomic, retain) TextErrorField* password_view;
@property(nonatomic, retain) UITextField*    password_field;
@property(nonatomic, retain) TextErrorField* password_re_view;
@property(nonatomic, retain) UITextField*    password_re_field;
@property(nonatomic, retain) UIButton*       restore_button;
@property(nonatomic, retain) UIActivityIndicatorView* restore_indicator;
@end

@implementation RestoreViewController

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    _api_proxy = [LibanixartApi sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [AuthChrome installBackgroundDecorationIn:self.view];
    [self setupViews];
    [self setupLayout];
    [self subscribeKeyboard];
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

    _login_view = [self makeFieldWithPlaceholder:@"Имя пользователя"
                                     contentType:UITextContentTypeUsername
                                          secure:NO];
    _login_field = _login_view.field;

    _password_view = [self makeFieldWithPlaceholder:@"Пароль"
                                        contentType:UITextContentTypeNewPassword
                                             secure:YES];
    _password_field = _password_view.field;

    _password_re_view = [self makeFieldWithPlaceholder:@"Повторите пароль"
                                           contentType:UITextContentTypeNewPassword
                                                secure:YES];
    _password_re_field = _password_re_view.field;

    _restore_button = [AuthChrome primaryButtonWithTitle:@"Продолжить"];
    [_restore_button addTarget:self action:@selector(restoreButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    _restore_indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _restore_indicator.color = UIColor.whiteColor;
    _restore_indicator.hidesWhenStopped = YES;
}

-(void)setupLayout {
    UIView* content = [UIView new];
    [_scroll_view addSubview:content];

    UIView* hero = [AuthChrome heroHeaderWithEyebrow:@"Сброс пароля"
                                            subtitle:@"Мы отправим код подтверждения на ваш email — затем вы сможете задать новый пароль."
                                            iconName:@"key.fill"];

    UIView* fieldsCard = [AuthChrome fieldsCardWithFields:
        @[_login_view, _password_view, _password_re_view]];

    [content addSubview:hero];
    [content addSubview:fieldsCard];
    [content addSubview:_restore_button];
    [_restore_button addSubview:_restore_indicator];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    _restore_button.translatesAutoresizingMaskIntoConstraints = NO;
    _restore_indicator.translatesAutoresizingMaskIntoConstraints = NO;

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

        [_restore_button.topAnchor      constraintEqualToAnchor:fieldsCard.bottomAnchor constant:AppSpacing24],
        [_restore_button.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [_restore_button.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],
        [_restore_button.bottomAnchor   constraintEqualToAnchor:content.bottomAnchor constant:-AppSpacing32],
        [_restore_button.heightAnchor   constraintEqualToConstant:54],

        [_restore_indicator.centerXAnchor constraintEqualToAnchor:_restore_button.centerXAnchor],
        [_restore_indicator.centerYAnchor constraintEqualToAnchor:_restore_button.centerYAnchor],
    ]];
}

-(TextErrorField*)makeFieldWithPlaceholder:(NSString*)placeholder
                               contentType:(UITextContentType)contentType
                                    secure:(BOOL)secure {
    TextErrorField* view = [TextErrorField new];
    UITextField* field = view.field;
    field.placeholder = placeholder;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.returnKeyType = UIReturnKeyNext;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.textContentType = contentType;
    field.secureTextEntry = secure;
    field.delegate = self;
    [field addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    return view;
}

-(UIButton*)makePrimaryButtonWithTitle:(NSString*)title {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline];
    button.backgroundColor = [AppColorProvider primaryColor];
    button.layer.cornerRadius = AppRadiusLarge;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    return button;
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

#pragma mark - Validation

-(BOOL)checkFieldAndShowError:(UITextField*)text_field {
    if (text_field.text.length == 0) {
        if (text_field == _login_field)        [_login_view       showError:@"Имя пользователя не может быть пусто"];
        else if (text_field == _password_field)[_password_view    showError:@"Пароль не может быть пуст"];
        else if (text_field == _password_re_field)
                                                [_password_re_view showError:@"Пароль не может быть пуст"];
        return NO;
    }
    if (text_field == _password_re_field) {
        if (![_password_field.text isEqualToString:_password_re_field.text]) {
            [_password_re_view showError:@"Пароли не совпадают"];
            return NO;
        }
    }
    return YES;
}

#pragma mark - UITextFieldDelegate

-(void)textFieldEditingChanged:(UITextField*)field {
    if (field == _login_field)       [_login_view       clearError];
    if (field == _password_field)    [_password_view    clearError];
    if (field == _password_re_field) [_password_re_view clearError];
}

-(BOOL)textFieldShouldReturn:(UITextField*)field {
    if (field == _login_field)    { [_password_field    becomeFirstResponder]; return NO; }
    if (field == _password_field) { [_password_re_field becomeFirstResponder]; return NO; }
    [field resignFirstResponder];
    [self restoreButtonTapped:nil];
    return NO;
}

#pragma mark - Actions

-(void)setLoading:(BOOL)loading {
    if (loading) {
        [_restore_indicator startAnimating];
        [_restore_button setTitle:@"" forState:UIControlStateNormal];
        _restore_button.enabled = NO;
    } else {
        [_restore_indicator stopAnimating];
        [_restore_button setTitle:@"Продолжить" forState:UIControlStateNormal];
        _restore_button.enabled = YES;
    }
}

-(IBAction)restoreButtonTapped:(id)sender {
    if (![self checkFieldAndShowError:_login_field] ||
        ![self checkFieldAndShowError:_password_field] ||
        ![self checkFieldAndShowError:_password_re_field]) {
        return;
    }
    using anixart::codes::auth::RestoreCode;
    std::string login    = TO_STDSTRING(_login_field.text);
    std::string password = TO_STDSTRING(_password_field.text);
    __block RestoreCode error_code = RestoreCode::Success;

    [self setLoading:YES];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try { self->_pending_restore = api->auth().restore(login, password); }
        catch (const anixart::RestoreError& e) { error_code = e.code; return YES; }
        return NO;
    } completion:^(BOOL errored) {
        [self setLoading:NO];
        if (!errored || error_code == RestoreCode::CodeAlreadySent) {
            CodeEnterViewController* vc = [CodeEnterViewController new];
            vc.delegate = self;
            if (error_code == RestoreCode::CodeAlreadySent) {
                [vc showCodeError:@"Код уже был отправлен"];
            }
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        if (error_code == RestoreCode::ProfileNotFound) {
            [self->_login_view showError:@"Имя пользователя не найдено"];
            return;
        }
        NSString* msg = error_code == RestoreCode::CodeCannotSend
            ? @"Не удалось отправить код"
            : @"Неизвестная ошибка";
        [self presentAlert:msg];
    }];
}

-(void)presentAlert:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"ОК" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CodeEnterViewControllerDelegate

-(void)didResendForCodeEnterViewController:(CodeEnterViewController*)vc completionHandler:(void(^)(BOOL))completion {
    using anixart::codes::auth::RestoreResendCode;
    __block RestoreResendCode error_code = RestoreResendCode::Success;
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try { self->_pending_restore->resend(); }
        catch (const anixart::RestoreResendError& e) { error_code = e.code; return YES; }
        return NO;
    } completion:^(BOOL errored) {
        completion(errored);
        if (!errored) return;
        NSString* msg = error_code == RestoreResendCode::CodeCannotSend
            ? @"Не удалось отправить код"
            : @"Неизвестная ошибка";
        [vc showCodeError:msg];
    }];
}

-(void)codeEnterViewController:(CodeEnterViewController*)vc didSubmitedCode:(NSString*)code completionHandler:(void(^)(BOOL))completion {
    using anixart::codes::auth::RestoreVerifyCode;
    std::string restore_code = TO_STDSTRING(code);
    __block anixart::Profile::Ptr profile;
    __block anixart::ProfileToken profile_token;
    __block RestoreVerifyCode error_code = RestoreVerifyCode::Success;

    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try {
            auto result = self->_pending_restore->verify(restore_code);
            profile       = std::move(result.first);
            profile_token = std::move(result.second);
        } catch (const anixart::RestoreVerifyError& e) {
            error_code = e.code;
            return YES;
        }
        return NO;
    } completion:^(BOOL errored) {
        completion(errored);
        if (!errored) {
            [AuthPerformer performAuthWithProfile:std::move(profile) profileToken:std::move(profile_token)];
            return;
        }
        NSString* msg;
        switch (error_code) {
            case RestoreVerifyCode::CodeExpired: msg = @"Код истёк"; break;
            case RestoreVerifyCode::CodeInvalid: msg = @"Неверный код"; break;
            default:                             msg = @"Неизвестная ошибка";      break;
        }
        [vc showCodeError:msg];
    }];
}

@end
