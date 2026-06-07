//
//  YukimoProfileBridge.mm
//

#import "YukimoProfileBridge.h"
#import "YukimoProfileDTO.h"
#import "LibanixartApi.h"
#import "AppDataController.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiProfiles.hpp>
#include <anixart/ApiTypes.hpp>
#include <filesystem>
#include <utility>

NSString * const YukimoProfileErrorDomain = @"com.yukimo.profile";

@interface YukimoProfileDTO (Build)
+ (instancetype)fromProfile:(anixart::Profile::Ptr)profile;
@end

@implementation YukimoProfileBridge

+ (instancetype)shared {
    static YukimoProfileBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoProfileBridge new]; });
    return instance;
}

- (void)editAvatarWithJpegData:(NSData *)jpegData
                    completion:(void (^)(BOOL, NSError * _Nullable))completion {
    if (jpegData.length == 0) {
        completion(NO, [NSError errorWithDomain:YukimoProfileErrorDomain
                                           code:0
                                       userInfo:@{ NSLocalizedDescriptionKey: @"Пустое изображение" }]);
        return;
    }
    // Drop the JPEG bytes to a temp file — libanixart wants a filesystem path.
    NSString *tempName = [NSString stringWithFormat:@"yukimo-avatar-%@.jpg",
                          [[NSUUID UUID] UUIDString]];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempName];
    NSError *writeErr = nil;
    if (![jpegData writeToFile:tempPath options:NSDataWritingAtomic error:&writeErr]) {
        completion(NO, writeErr ?: [NSError errorWithDomain:YukimoProfileErrorDomain
                                                       code:0
                                                   userInfo:@{ NSLocalizedDescriptionKey: @"Не удалось записать файл" }]);
        return;
    }
    std::string cxx_path = TO_STDSTRING(tempPath);
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            api->profiles().edit_avatar(std::filesystem::path(cxx_path));
            return NO;
        } catch (const std::exception &e) {
            resultError = [NSError errorWithDomain:YukimoProfileErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                              [NSString stringWithUTF8String:e.what()] }];
            return YES;
        }
    } completion:^(BOOL errored) {
        // Best-effort cleanup of the temp file.
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
        if (errored && resultError == nil) {
            resultError = [NSError errorWithDomain:YukimoProfileErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey: @"Не удалось обновить аватар" }];
        }
        completion(resultError == nil, resultError);
    }];
}

- (void)loadMyProfileWithCompletion:(void (^)(YukimoProfileDTO * _Nullable, NSError * _Nullable))completion {
    anixart::ProfileID my_id = [[AppDataController sharedInstance] getMyProfileID];
    __block YukimoProfileDTO *dto = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pair = api->profiles().get_profile(my_id);
            anixart::Profile::Ptr profile = pair.first;
            dto = [YukimoProfileDTO fromProfile:profile];
            return NO;
        } catch (const std::exception &e) {
            resultError = [NSError errorWithDomain:YukimoProfileErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                              [NSString stringWithUTF8String:e.what()] }];
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = [NSError errorWithDomain:YukimoProfileErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey: @"Не удалось загрузить профиль" }];
        }
        completion(dto, resultError);
    }];
}

@end
