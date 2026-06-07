//
//  SignUpViewController.mm
//
//  Account registration.
//
//  Four stacked inputs (login, email, password, confirm) inside a
//  scroll view, single full-width primary action, native keyboard
//  avoidance, and `textContentType` wired so iOS Passwords / Keychain
//  can autofill suggested strong passwords.
//

#import "SignUpViewController.h"
#import "AppColor.h"
#import "AuthChrome.h"
#import "TextErrorField.h"
#import "AuthChecker.h"
#import "CodeEnterViewController.h"
#import "AuthPerformer.h"
#import "LibanixartApi.h"
#import "StringCvt.h"

@interface SignUpViewController () <CodeEnterViewControllerDelegate> {
    anixart::ApiAuthPending::UPtr _pending_signup;
}
@property(nonatomic, strong) LibanixartApi* api_proxy;
@property(nonatomic, strong) AuthChecker*   auth_checker;

@property(nonatomic, retain) UIScrollView*   scroll_view;
@property(nonatomic, retain) UILabel*        title_label;
@property(nonatomic, retain) UILabel*        subtitle_label;
@property(nonatomic, retain) TextErrorField* login_view;
@property(nonatomic, retain) UITextField*    login_field;
@property(nonatomic, retain) TextErrorField* email_view;
@property(nonatomic, retain) UITextField*    email_field;
@property(nonatomic, retain) TextErrorField* password_view;
@property(nonatomic, retain) UITextField*    password_field;
@property(nonatomic, retain) TextErrorField* password_re_view;
@property(nonatomic, retain) UITextField*    password_re_field;
@property(nonatomic, retain) UIButton*       signup_button;
@property(nonatomic, retain) UIActivityIndicatorView* signup_indicator;
@end

@implementation SignUpViewController

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    _api_proxy    = [LibanixartApi sharedInstance];
    _auth_checker = [AuthChecker new];
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
                                    keyboardType:UIKeyboardTypeDefault
                                          secure:NO];
    _login_field = _login_view.field;

    _email_view = [self makeFieldWithPlaceholder:@"Email"
                                     contentType:UITextContentTypeEmailAddress
                                    keyboardType:UIKeyboardTypeEmailAddress
                                          secure:NO];
    _email_field = _email_view.field;

    _password_view = [self makeFieldWithPlaceholder:@"Пароль"
                                        contentType:UITextContentTypeNewPassword
                                       keyboardType:UIKeyboardTypeDefault
                                             secure:YES];
    _password_field = _password_view.field;

    _password_re_view = [self makeFieldWithPlaceholder:@"Повторите пароль"
                                           contentType:UITextContentTypeNewPassword
                                          keyboardType:UIKeyboardTypeDefault
                                                secure:YES];
    _password_re_field = _password_re_view.field;

    _signup_button = [AuthChrome primaryButtonWithTitle:@"Создать аккаунт"];
    [_signup_button addTarget:self action:@selector(signupButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    _signup_indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _signup_indicator.color = UIColor.whiteColor;
    _signup_indicator.hidesWhenStopped = YES;
}

-(void)setupLayout {
    UIView* content = [UIView new];
    [_scroll_view addSubview:content];

    UIView* hero = [AuthChrome heroHeaderWithEyebrow:@"Создайте аккаунт"
                                            subtitle:@"Зарегистрируйтесь, чтобы вести список просмотров, рейтинги и комментарии."
                                            iconName:@"person.crop.circle.badge.plus"];

    UIView* fieldsCard = [AuthChrome fieldsCardWithFields:
        @[_login_view, _email_view, _password_view, _password_re_view]];

    [content addSubview:hero];
    [content addSubview:fieldsCard];
    [content addSubview:_signup_button];
    [_signup_button addSubview:_signup_indicator];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    _signup_button.translatesAutoresizingMaskIntoConstraints = NO;
    _signup_indicator.translatesAutoresizingMaskIntoConstraints = NO;

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

        [_signup_button.topAnchor      constraintEqualToAnchor:fieldsCard.bottomAnchor constant:AppSpacing24],
        [_signup_button.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [_signup_button.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],
        [_signup_button.bottomAnchor   constraintEqualToAnchor:content.bottomAnchor constant:-AppSpacing32],
        [_signup_button.heightAnchor   constraintEqualToConstant:54],

        [_signup_indicator.centerXAnchor constraintEqualToAnchor:_signup_button.centerXAnchor],
        [_signup_indicator.centerYAnchor constraintEqualToAnchor:_signup_button.centerYAnchor],
    ]];
}

-(TextErrorField*)makeFieldWithPlaceholder:(NSString*)placeholder
                               contentType:(UITextContentType)contentType
                              keyboardType:(UIKeyboardType)keyboardType
                                    secure:(BOOL)secure {
    TextErrorField* view = [TextErrorField new];
    UITextField* field = view.field;
    field.placeholder = placeholder;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.returnKeyType = UIReturnKeyNext;
    field.keyboardType = keyboardType;
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
    if (text_field == _login_field) {
        if (_login_field.text.length == 0) {
            [_login_view showError:@"Имя пользователя не может быть пусто"];
            return NO;
        }
        AuthCheckerStatus status = [_auth_checker checkUsername:_login_field.text];
        if (status == AuthCheckerStatus::TooLong) {
            [_login_view showError:@"Имя пользователя слишком длинное"];
            return NO;
        }
    }
    else if (text_field == _email_field) {
        if (_email_field.text.length == 0) {
            [_email_view showError:@"Email не может быть пуст"];
            return NO;
        }
        AuthCheckerStatus status = [_auth_checker checkEmail:_email_field.text];
        if (status == AuthCheckerStatus::Invalid) {
            [_email_view showError:@"Недопустимый Email"];
            return NO;
        }
    }
    else if (text_field == _password_field) {
        AuthCheckerStatus status = [_auth_checker checkPassword:_password_field.text];
        if (status == AuthCheckerStatus::TooShort) {
            [_password_view showError:@"Пароль слишком короткий"];
            return NO;
        }
        if (status == AuthCheckerStatus::TooLong) {
            [_password_view showError:@"Пароль слишком длинный"];
            return NO;
        }
        if (status == AuthCheckerStatus::Invalid) {
            [_password_view showError:@"Пароль содержит недопустимые символы"];
            return NO;
        }
    }
    else if (text_field == _password_re_field) {
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
    if (field == _email_field)       [_email_view       clearError];
    if (field == _password_field)    [_password_view    clearError];
    if (field == _password_re_field) [_password_re_view clearError];
}

-(BOOL)textFieldShouldReturn:(UITextField*)field {
    if (field == _login_field)       { [_email_field       becomeFirstResponder]; return NO; }
    if (field == _email_field)       { [_password_field    becomeFirstResponder]; return NO; }
    if (field == _password_field)    { [_password_re_field becomeFirstResponder]; return NO; }
    [field resignFirstResponder];
    [self signupButtonTapped:nil];
    return NO;
}

#pragma mark - Actions

-(void)setLoading:(BOOL)loading {
    if (loading) {
        [_signup_indicator startAnimating];
        [_signup_button setTitle:@"" forState:UIControlStateNormal];
        _signup_button.enabled = NO;
    } else {
        [_signup_indicator stopAnimating];
        [_signup_button setTitle:@"Создать аккаунт" forState:UIControlStateNormal];
        _signup_button.enabled = YES;
    }
}

-(IBAction)signupButtonTapped:(id)sender {
    if (![self checkFieldAndShowError:_login_field] ||
        ![self checkFieldAndShowError:_email_field] ||
        ![self checkFieldAndShowError:_password_field] ||
        ![self checkFieldAndShowError:_password_re_field]) {
        return;
    }
    using anixart::codes::auth::SignUpCode;

    std::string username = TO_STDSTRING(_login_field.text);
    std::string email    = TO_STDSTRING(_email_field.text);
    std::string password = TO_STDSTRING(_password_field.text);
    __block SignUpCode error_code = SignUpCode::Success;

    [self setLoading:YES];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try {
            self->_pending_signup = api->auth().sign_up(username, email, password);
        } catch (const anixart::SignUpError& e) {
            error_code = e.code;
            return YES;
        }
        return NO;
    } completion:^(BOOL errored) {
        [self setLoading:NO];
        if (!errored || error_code == SignUpCode::CodeAlreadySent) {
            CodeEnterViewController* vc = [CodeEnterViewController new];
            vc.delegate = self;
            if (error_code == SignUpCode::CodeAlreadySent) {
                [vc showCodeError:@"Код уже был отправлен"];
            }
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        if (error_code == SignUpCode::LoginAlreadyTaken) {
            [self->_login_view showError:@"Имя пользователя уже занято"];
            return;
        }
        if (error_code == SignUpCode::EmailAlreadyTaken) {
            [self->_email_view showError:@"Email уже используется"];
            return;
        }
        if (error_code == SignUpCode::EmailServiceDisallowed) {
            [self->_email_view showError:@"Email сервис запрещён"];
            return;
        }

        NSString* error_msg;
        switch (error_code) {
            case SignUpCode::CodeCannotSend:
                error_msg = @"Не удалось отправить код";
                break;
            case SignUpCode::TooManyRegistrations:
                error_msg = @"Слишком много регистраций";
                break;
            default:
                error_msg = @"Неизвестная ошибка";
                break;
        }
        [self presentAlert:error_msg];
    }];
}

-(void)presentAlert:(NSString*)message {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"ОК" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - CodeEnterViewControllerDelegate

-(void)didResendForCodeEnterViewController:(CodeEnterViewController*)vc completionHandler:(void (^)(BOOL))completion {
    using anixart::codes::auth::ResendCode;
    __block ResendCode error_code = ResendCode::Success;
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try { self->_pending_signup->resend(); }
        catch (const anixart::ResendError& e) { error_code = e.code; return YES; }
        return NO;
    } completion:^(BOOL errored) {
        completion(errored);
        if (!errored) return;
        NSString* msg = error_code == ResendCode::CodeCannotSend
            ? @"Не удалось отправить код"
            : @"Неизвестная ошибка";
        [vc showCodeError:msg];
    }];
}

-(void)codeEnterViewController:(CodeEnterViewController*)vc didSubmitedCode:(NSString*)code completionHandler:(void (^)(BOOL))completion {
    using anixart::codes::auth::VerifyCode;
    std::string signup_code = TO_STDSTRING(code);
    __block anixart::Profile::Ptr  profile;
    __block anixart::ProfileToken  profile_token;
    __block VerifyCode error_code = VerifyCode::Success;

    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        try {
            auto ret = self->_pending_signup->verify(signup_code);
            profile       = std::move(ret.first);
            profile_token = std::move(ret.second);
        } catch (const anixart::VerifyError& e) {
            error_code = e.code;
            return YES;
        }
        return NO;
    } completion:^(BOOL errored) {
        completion(errored);
        if (!errored) {
            [AuthPerformer performAuthWithProfile:profile profileToken:std::move(profile_token)];
            return;
        }
        NSString* msg;
        switch (error_code) {
            case VerifyCode::CodeExpired: msg = @"Код истёк"; break;
            case VerifyCode::CodeInvalid: msg = @"Неверный код"; break;
            default:                      msg = @"Неизвестная ошибка";      break;
        }
        [vc showCodeError:msg];
    }];
}

@end
