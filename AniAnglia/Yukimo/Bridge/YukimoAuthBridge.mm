//
//  YukimoAuthBridge.mm
//  Obj-C++ implementation. Bridges libanixart C++ auth to a Swift-safe facade.
//

#import "YukimoAuthBridge.h"
#import "LibanixartApi.h"
#import "AppDataController.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiAuth.hpp>
#include <anixart/ApiErrors.hpp>
#include <anixart/ApiErrorCodes.hpp>
#include <memory>
#include <utility>

NSString * const YukimoAuthErrorDomain = @"com.yukimo.auth";

#pragma mark - YukimoAuthPending

@interface YukimoAuthPending () {
@public
    anixart::ApiAuthPending::UPtr _signupPending;
    anixart::ApiRestorePending::UPtr _restorePending;
}
@end

@implementation YukimoAuthPending
- (BOOL)isSignUp { return _signupPending != nullptr; }
@end


#pragma mark - Error mapping

static NSError *makeError(YukimoAuthErrorCode code, NSString *message) {
    return [NSError errorWithDomain:YukimoAuthErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"" }];
}

static NSError *mapSignInError(const anixart::SignInError &e) {
    using C = anixart::codes::auth::SignInCode;
    switch (e.code) {
        case C::InvalidLogin:    return makeError(YukimoAuthErrorInvalidLogin,    @"Неверный логин");
        case C::InvalidPassword: return makeError(YukimoAuthErrorInvalidPassword, @"Неверный пароль");
        case C::Banned:          return makeError(YukimoAuthErrorAccountBanned,   @"Аккаунт заблокирован");
        case C::PermBanned:      return makeError(YukimoAuthErrorAccountPermBanned, @"Аккаунт заблокирован навсегда");
        case C::Unathorized:     return makeError(YukimoAuthErrorUnauthorized,    @"Не авторизован");
        case C::Failed:          return makeError(YukimoAuthErrorServerFailure,   @"Сервер вернул ошибку");
        default:                 return makeError(YukimoAuthErrorUnknown,         @"Не удалось войти");
    }
}

static NSError *mapSignUpError(const anixart::SignUpError &e) {
    using C = anixart::codes::auth::SignUpCode;
    switch (e.code) {
        case C::InvalidLogin:       return makeError(YukimoAuthErrorInvalidLogin,        @"Некорректный логин");
        case C::InvalidPassword:    return makeError(YukimoAuthErrorInvalidPassword,     @"Некорректный пароль");
        case C::InvalidEmail:       return makeError(YukimoAuthErrorInvalidEmail,        @"Некорректный email");
        case C::LoginAlreadyTaken:  return makeError(YukimoAuthErrorLoginAlreadyTaken,   @"Логин уже занят");
        case C::EmailAlreadyTaken:  return makeError(YukimoAuthErrorEmailAlreadyTaken,   @"Email уже зарегистрирован");
        case C::Failed:             return makeError(YukimoAuthErrorServerFailure,       @"Сервер вернул ошибку");
        default:                    return makeError(YukimoAuthErrorUnknown,             @"Не удалось зарегистрироваться");
    }
}

static NSError *mapRestoreError(const anixart::RestoreError &e) {
    using C = anixart::codes::auth::RestoreCode;
    switch (e.code) {
        case C::ProfileNotFound: return makeError(YukimoAuthErrorInvalidLogin, @"Пользователь не найден");
        case C::CodeAlreadySent: return makeError(YukimoAuthErrorTooManyAttempts, @"Код уже отправлен — проверьте почту");
        case C::CodeCannotSend:  return makeError(YukimoAuthErrorServerFailure, @"Не удалось отправить код");
        case C::Failed:          return makeError(YukimoAuthErrorServerFailure, @"Сервер вернул ошибку");
        default:                 return makeError(YukimoAuthErrorUnknown,       @"Не удалось восстановить пароль");
    }
}

static NSError *mapRestoreVerifyError(const anixart::RestoreVerifyError &e) {
    using C = anixart::codes::auth::RestoreVerifyCode;
    switch (e.code) {
        case C::CodeInvalid:     return makeError(YukimoAuthErrorInvalidCode,    @"Неверный код подтверждения");
        case C::CodeExpired:     return makeError(YukimoAuthErrorCodeExpired,    @"Срок действия кода истёк");
        case C::InvalidPassword: return makeError(YukimoAuthErrorInvalidPassword, @"Некорректный пароль");
        case C::ProfileNotFound: return makeError(YukimoAuthErrorInvalidLogin,   @"Пользователь не найден");
        case C::Failed:          return makeError(YukimoAuthErrorServerFailure,  @"Сервер вернул ошибку");
        default:                 return makeError(YukimoAuthErrorUnknown,        @"Не удалось подтвердить");
    }
}

static NSError *mapSignUpVerifyError(const anixart::VerifyError &e) {
    using C = anixart::codes::auth::VerifyCode;
    switch (e.code) {
        case C::CodeInvalid:        return makeError(YukimoAuthErrorInvalidCode,      @"Неверный код подтверждения");
        case C::CodeExpired:        return makeError(YukimoAuthErrorCodeExpired,      @"Срок действия кода истёк");
        case C::InvalidLogin:       return makeError(YukimoAuthErrorInvalidLogin,     @"Некорректный логин");
        case C::InvalidEmail:       return makeError(YukimoAuthErrorInvalidEmail,     @"Некорректный email");
        case C::InvalidPassword:    return makeError(YukimoAuthErrorInvalidPassword,  @"Некорректный пароль");
        case C::LoginAlreadyTaken:  return makeError(YukimoAuthErrorLoginAlreadyTaken,@"Логин уже занят");
        case C::EmailAlreadyTaken:  return makeError(YukimoAuthErrorEmailAlreadyTaken,@"Email уже зарегистрирован");
        case C::Failed:             return makeError(YukimoAuthErrorServerFailure,    @"Сервер вернул ошибку");
        default:                    return makeError(YukimoAuthErrorUnknown,          @"Не удалось подтвердить");
    }
}


#pragma mark - YukimoAuthBridge

@implementation YukimoAuthBridge

+ (instancetype)shared {
    static YukimoAuthBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoAuthBridge new]; });
    return instance;
}

- (void)persistSessionFromProfile:(anixart::Profile::Ptr)profile
                            token:(const anixart::ProfileToken &)token {
    AppDataController *store = [AppDataController sharedInstance];
    [store setToken:TO_NSSTRING(token.token)];
    if (profile) {
        [store setMyProfileID:profile->id];
    }
    [[LibanixartApi sharedInstance] getApi]->set_token(token.token);
}

#pragma mark Sign-In

- (void)signInWithLogin:(NSString *)login
               password:(NSString *)password
             completion:(void (^)(BOOL, NSError * _Nullable))completion {
    std::string c_login = TO_STDSTRING(login);
    std::string c_password = TO_STDSTRING(password);
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pair = api->auth().sign_in(c_login, c_password);
            anixart::Profile::Ptr profile = pair.first;
            anixart::ProfileToken token   = pair.second;
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self persistSessionFromProfile:profile token:token];
            });
            return NO;
        } catch (const anixart::SignInError &e) {
            resultError = mapSignInError(e);
            return YES;
        } catch (const std::exception &e) {
            resultError = makeError(YukimoAuthErrorNetwork, [NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = makeError(YukimoAuthErrorNetwork, @"Проблема с подключением");
        }
        completion(resultError == nil, resultError);
    }];
}

#pragma mark Sign-Up

- (void)signUpWithLogin:(NSString *)login
                  email:(NSString *)email
               password:(NSString *)password
             completion:(void (^)(YukimoAuthPending * _Nullable, NSError * _Nullable))completion {
    std::string c_login = TO_STDSTRING(login);
    std::string c_email = TO_STDSTRING(email);
    std::string c_password = TO_STDSTRING(password);
    __block NSError *resultError = nil;
    __block YukimoAuthPending *pending = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto p = api->auth().sign_up(c_login, c_email, c_password);
            pending = [YukimoAuthPending new];
            pending->_signupPending = std::move(p);
            return NO;
        } catch (const anixart::SignUpError &e) {
            resultError = mapSignUpError(e);
            return YES;
        } catch (const std::exception &e) {
            resultError = makeError(YukimoAuthErrorNetwork, [NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = makeError(YukimoAuthErrorNetwork, @"Проблема с подключением");
        }
        completion(pending, resultError);
    }];
}

- (void)verifySignUp:(YukimoAuthPending *)pending
                code:(NSString *)code
          completion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (pending == nil || pending->_signupPending == nullptr) {
        completion(NO, makeError(YukimoAuthErrorUnknown, @"Сессия регистрации потеряна"));
        return;
    }
    std::string c_code = TO_STDSTRING(code);
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pair = pending->_signupPending->verify(c_code);
            anixart::Profile::Ptr profile = pair.first;
            anixart::ProfileToken token   = pair.second;
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self persistSessionFromProfile:profile token:token];
            });
            return NO;
        } catch (const anixart::VerifyError &e) {
            resultError = mapSignUpVerifyError(e);
            return YES;
        } catch (const std::exception &e) {
            resultError = makeError(YukimoAuthErrorNetwork, [NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = makeError(YukimoAuthErrorNetwork, @"Проблема с подключением");
        }
        completion(resultError == nil, resultError);
    }];
}

#pragma mark Restore

- (void)restorePasswordWithLoginOrEmail:(NSString *)loginOrEmail
                            newPassword:(NSString *)newPassword
                             completion:(void (^)(YukimoAuthPending * _Nullable, NSError * _Nullable))completion {
    std::string c_login = TO_STDSTRING(loginOrEmail);
    std::string c_new_password = TO_STDSTRING(newPassword);
    __block NSError *resultError = nil;
    __block YukimoAuthPending *pending = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto p = api->auth().restore(c_login, c_new_password);
            pending = [YukimoAuthPending new];
            pending->_restorePending = std::move(p);
            return NO;
        } catch (const anixart::RestoreError &e) {
            resultError = mapRestoreError(e);
            return YES;
        } catch (const std::exception &e) {
            resultError = makeError(YukimoAuthErrorNetwork, [NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = makeError(YukimoAuthErrorNetwork, @"Проблема с подключением");
        }
        completion(pending, resultError);
    }];
}

- (void)verifyRestore:(YukimoAuthPending *)pending
                 code:(NSString *)code
           completion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (pending == nil || pending->_restorePending == nullptr) {
        completion(NO, makeError(YukimoAuthErrorUnknown, @"Сессия восстановления потеряна"));
        return;
    }
    std::string c_code = TO_STDSTRING(code);
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pair = pending->_restorePending->verify(c_code);
            anixart::Profile::Ptr profile = pair.first;
            anixart::ProfileToken token   = pair.second;
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self persistSessionFromProfile:profile token:token];
            });
            return NO;
        } catch (const anixart::RestoreVerifyError &e) {
            resultError = mapRestoreVerifyError(e);
            return YES;
        } catch (const std::exception &e) {
            resultError = makeError(YukimoAuthErrorNetwork, [NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = makeError(YukimoAuthErrorNetwork, @"Проблема с подключением");
        }
        completion(resultError == nil, resultError);
    }];
}

#pragma mark Logout

- (void)logout {
    [[AppDataController sharedInstance] setToken:@""];
    [[LibanixartApi sharedInstance] getApi]->set_token("");
}

@end
