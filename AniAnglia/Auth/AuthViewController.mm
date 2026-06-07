//
//  AuthViewController.mm
//
//  Sign-in screen.
//
//  Layout: large title + subtitle, two inputs (username, password),
//  full-width primary action, secondary "Forgot password?" link, and a
//  trailing "Sign up" link near the bottom. Keyboard-aware scroll view.
//

#import "AuthViewController.h"
#import "AppColor.h"
#import "AppHaptics.h"
#import "AuthChrome.h"
#import "TextErrorField.h"
#import "LibanixartApi.h"
#import "AppDataController.h"
#import "StringCvt.h"
#import "RestoreViewController.h"
#import "SignUpViewController.h"
#import "MainWindow.h"
#import "MainTabBarController.h"

@interface AuthViewController ()
@property(nonatomic, retain) LibanixartApi*     api_proxy;
@property(nonatomic, retain) AppDataController* data_controller;

@property(nonatomic, retain) UIScrollView*  scroll_view;
@property(nonatomic, retain) UILabel*       title_label;
@property(nonatomic, retain) UILabel*       subtitle_label;
@property(nonatomic, retain) TextErrorField* login_view;
@property(nonatomic, retain) UITextField*    login_field;
@property(nonatomic, retain) TextErrorField* password_view;
@property(nonatomic, retain) UITextField*    password_field;
@property(nonatomic, retain) UIButton*      login_button;
@property(nonatomic, retain) UIActivityIndicatorView* login_indicator;
@property(nonatomic, retain) UIButton*      forgot_button;
@property(nonatomic, retain) UIButton*      signup_button;
@property(nonatomic, retain) UILabel*       signup_prompt_label;
@property(nonatomic, retain) UIStackView*   signup_row;
@end

@implementation AuthViewController

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    _api_proxy       = [LibanixartApi sharedInstance];
    _data_controller = [AppDataController sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
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

    _login_view  = [self makeFieldWithPlaceholder:@"Имя пользователя или Email"
                                      contentType:UITextContentTypeUsername
                                           secure:NO];
    _login_field = _login_view.field;

    _password_view  = [self makeFieldWithPlaceholder:@"Пароль"
                                         contentType:UITextContentTypePassword
                                              secure:YES];
    _password_field = _password_view.field;

    _login_button = [AuthChrome primaryButtonWithTitle:@"Войти"];
    [_login_button addTarget:self action:@selector(loginButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    _login_indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _login_indicator.color = UIColor.whiteColor;
    _login_indicator.hidesWhenStopped = YES;

    _forgot_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_forgot_button setTitle:@"Забыли пароль?" forState:UIControlStateNormal];
    _forgot_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    [_forgot_button setTitleColor:[AppColorProvider primaryColor] forState:UIControlStateNormal];
    [_forgot_button addTarget:self action:@selector(forgotButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    _signup_prompt_label = [UILabel new];
    _signup_prompt_label.text = @"Нет аккаунта?";
    _signup_prompt_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    _signup_prompt_label.textColor = [AppColorProvider textSecondaryColor];

    _signup_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_signup_button setTitle:@"Зарегистрироваться" forState:UIControlStateNormal];
    _signup_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    [_signup_button setTitleColor:[AppColorProvider primaryColor] forState:UIControlStateNormal];
    [_signup_button addTarget:self action:@selector(signUpButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

    _signup_row = [[UIStackView alloc] initWithArrangedSubviews:@[_signup_prompt_label, _signup_button]];
    _signup_row.axis = UILayoutConstraintAxisHorizontal;
    _signup_row.spacing = AppSpacing6;
    _signup_row.alignment = UIStackViewAlignmentCenter;
}

-(void)setupLayout {
    UIView* content = [UIView new];
    [_scroll_view addSubview:content];

    UIView* hero = [AuthChrome heroHeaderWithEyebrow:@"Добро пожаловать"
                                            subtitle:@"Войдите с аккаунтом Anixart, чтобы продолжить смотреть с того места, где остановились."
                                            iconName:@"sparkles"];

    UIView* fieldsCard = [AuthChrome fieldsCardWithFields:@[_login_view, _password_view]];

    UIStackView* actions = [[UIStackView alloc] initWithArrangedSubviews:@[_login_button, _forgot_button]];
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = AppSpacing16;
    actions.alignment = UIStackViewAlignmentFill;
    actions.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:hero];
    [content addSubview:fieldsCard];
    [content addSubview:actions];
    [content addSubview:_signup_row];
    [_login_button addSubview:_login_indicator];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    _signup_row.translatesAutoresizingMaskIntoConstraints = NO;
    _login_indicator.translatesAutoresizingMaskIntoConstraints = NO;

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
        [content.heightAnchor   constraintGreaterThanOrEqualToAnchor:_scroll_view.frameLayoutGuide.heightAnchor],

        [hero.topAnchor      constraintEqualToAnchor:content.topAnchor constant:AppSpacing32],
        [hero.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing24],
        [hero.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing24],

        [fieldsCard.topAnchor      constraintEqualToAnchor:hero.bottomAnchor constant:AppSpacing32],
        [fieldsCard.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [fieldsCard.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],

        [actions.topAnchor      constraintEqualToAnchor:fieldsCard.bottomAnchor constant:AppSpacing24],
        [actions.leadingAnchor  constraintEqualToAnchor:content.leadingAnchor constant:AppSpacing20],
        [actions.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-AppSpacing20],

        [_login_button.heightAnchor constraintEqualToConstant:54],

        [_signup_row.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [_signup_row.bottomAnchor  constraintEqualToAnchor:content.bottomAnchor constant:-AppSpacing32],
        [_signup_row.topAnchor     constraintGreaterThanOrEqualToAnchor:actions.bottomAnchor constant:AppSpacing24],

        [_login_indicator.centerXAnchor constraintEqualToAnchor:_login_button.centerXAnchor],
        [_login_indicator.centerYAnchor constraintEqualToAnchor:_login_button.centerYAnchor],
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
    field.returnKeyType = UIReturnKeyDone;
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

#pragma mark - Actions

-(IBAction)loginButtonTapped:(id)sender {
    if (![self checkAllFieldsIsCorrect]) return;
    [_login_field    resignFirstResponder];
    [_password_field resignFirstResponder];
    [self setLoading:YES];

    std::string login    = TO_STDSTRING(_login_field.text);
    std::string password = TO_STDSTRING(_password_field.text);
    __block BOOL errored = NO;
    __block anixart::codes::auth::SignInCode error_code;
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        try {
            auto [profile, token] = api->auth().sign_in(login, password);
            [self->_data_controller setToken:TO_NSSTRING(token.token)];
            [self->_data_controller setMyProfileID:profile->id];
            self->_api_proxy.api->set_token(token.token);
        }
        catch (anixart::SignInError& e) {
            errored = YES;
            error_code = e.code;
        }
        return YES;
    } withUICompletion:^{
        [self setLoading:NO];
        if (errored) {
            if (error_code == anixart::codes::auth::SignInCode::InvalidLogin) {
                [self->_login_view    showError:@"Неверное имя пользователя или Email"];
            } else if (error_code == anixart::codes::auth::SignInCode::InvalidPassword) {
                [self->_password_view showError:@"Неверный пароль"];
            }
            return;
        }
        [self setRootViewControllerToMain];
    }];
}

-(IBAction)forgotButtonTapped:(id)sender {
    [self.navigationController pushViewController:[RestoreViewController new] animated:YES];
}

-(IBAction)signUpButtonTapped:(id)sender {
    [self.navigationController pushViewController:[SignUpViewController new] animated:YES];
}

-(void)setLoading:(BOOL)loading {
    if (loading) {
        [_login_indicator startAnimating];
        [_login_button setTitle:@"" forState:UIControlStateNormal];
        _login_button.enabled = NO;
    } else {
        [_login_indicator stopAnimating];
        [_login_button setTitle:@"Войти" forState:UIControlStateNormal];
        _login_button.enabled = YES;
    }
}

#pragma mark - UITextFieldDelegate

-(void)textFieldEditingChanged:(UITextField*)field {
    if (field == _login_field)    [_login_view    clearError];
    if (field == _password_field) [_password_view clearError];
}

-(BOOL)textFieldShouldReturn:(UITextField*)text_field {
    if (text_field == _login_field) {
        [_password_field becomeFirstResponder];
        return NO;
    }
    [text_field resignFirstResponder];
    [self loginButtonTapped:nil];
    return NO;
}

-(BOOL)checkAllFieldsIsCorrect {
    BOOL ok = YES;
    if (_login_field.text.length == 0) {
        [_login_view showError:@"Имя пользователя не может быть пусто"];
        ok = NO;
    }
    if (_password_field.text.length == 0) {
        [_password_view showError:@"Пароль не может быть пуст"];
        ok = NO;
    }
    return ok;
}

-(void)setRootViewControllerToMain {
    MainWindow* main_window = (MainWindow*)[[UIApplication sharedApplication].delegate window];
    [main_window setRootViewController:[MainTabBarController new]];
}

@end
