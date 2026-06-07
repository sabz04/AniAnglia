//
//  YukimoAuthBridge.h
//  Pure Obj-C facade over libanixart auth. Safe for Swift bridging.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoAuthErrorDomain;

/// Plain NS_ENUM keeps Swift import predictable: directly usable as
/// `YukimoAuthErrorCode(rawValue: nsError.code)`. We separately keep the
/// domain constant above and pair them manually in error construction.
typedef NS_ENUM(NSInteger, YukimoAuthErrorCode) {
    YukimoAuthErrorUnknown = 0,
    YukimoAuthErrorNetwork = 1,
    YukimoAuthErrorInvalidLogin = 2,
    YukimoAuthErrorInvalidPassword = 3,
    YukimoAuthErrorInvalidEmail = 4,
    YukimoAuthErrorLoginAlreadyTaken = 5,
    YukimoAuthErrorEmailAlreadyTaken = 6,
    YukimoAuthErrorAccountBanned = 7,
    YukimoAuthErrorAccountPermBanned = 8,
    YukimoAuthErrorUnauthorized = 9,
    YukimoAuthErrorInvalidCode = 10,
    YukimoAuthErrorCodeExpired = 11,
    YukimoAuthErrorTooManyAttempts = 12,
    YukimoAuthErrorServerFailure = 13,
} NS_SWIFT_NAME(YukimoAuthErrorCode);

/// Represents a server-side pending step (sign-up email confirmation, restore confirmation).
/// Opaque to Swift — passed back into `verify*` calls.
NS_SWIFT_NAME(AuthPending)
@interface YukimoAuthPending : NSObject
@property (nonatomic, readonly) BOOL isSignUp;     ///< NO means restore
@end


NS_SWIFT_NAME(AuthBridge)
@interface YukimoAuthBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Sign in with login + password. On success, writes token + profile id to
/// AppDataController and configures the underlying anixart::Api token state.
- (void)signInWithLogin:(NSString *)login
               password:(NSString *)password
             completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(signIn(login:password:completion:))
    NS_SWIFT_ASYNC_NAME(signIn(login:password:));

/// Begin sign-up. On success returns a pending object that must be passed to
/// `verifySignUp:code:completion:` along with the code from the email.
- (void)signUpWithLogin:(NSString *)login
                  email:(NSString *)email
               password:(NSString *)password
             completion:(void (^)(YukimoAuthPending * _Nullable pending, NSError * _Nullable error))completion
    NS_SWIFT_NAME(signUp(login:email:password:completion:))
    NS_SWIFT_ASYNC_NAME(signUp(login:email:password:));

/// Finish sign-up by verifying the email code. On success the session is established.
- (void)verifySignUp:(YukimoAuthPending *)pending
                code:(NSString *)code
          completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(verifySignUp(pending:code:completion:))
    NS_SWIFT_ASYNC_NAME(verifySignUp(pending:code:));

/// Begin password restore. `loginOrEmail` is either a username or email.
- (void)restorePasswordWithLoginOrEmail:(NSString *)loginOrEmail
                            newPassword:(NSString *)newPassword
                             completion:(void (^)(YukimoAuthPending * _Nullable pending, NSError * _Nullable error))completion
    NS_SWIFT_NAME(restorePassword(loginOrEmail:newPassword:completion:))
    NS_SWIFT_ASYNC_NAME(restorePassword(loginOrEmail:newPassword:));

/// Finish password restore by verifying the email code.
- (void)verifyRestore:(YukimoAuthPending *)pending
                 code:(NSString *)code
           completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(verifyRestore(pending:code:completion:))
    NS_SWIFT_ASYNC_NAME(verifyRestore(pending:code:));

/// Clears local session (token + profile id). Does not call server.
- (void)logout NS_SWIFT_NAME(logout());

@end

NS_ASSUME_NONNULL_END
