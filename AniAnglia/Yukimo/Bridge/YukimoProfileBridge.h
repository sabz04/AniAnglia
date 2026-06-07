//
//  YukimoProfileBridge.h
//

#import <Foundation/Foundation.h>
#import "YukimoProfileDTO.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoProfileErrorDomain;

NS_SWIFT_NAME(ProfileBridge)
@interface YukimoProfileBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Fetches the signed-in user's profile (uses stored profile id).
- (void)loadMyProfileWithCompletion:(void (^)(YukimoProfileDTO * _Nullable profile, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadMyProfile(completion:))
    NS_SWIFT_ASYNC_NAME(loadMyProfile());

/// Upload a new avatar. Server only accepts JPEG, so callers must convert
/// any HEIC/PNG to JPEG before calling. Writes the data to a temp file then
/// dispatches the libanixart upload.
- (void)editAvatarWithJpegData:(NSData *)jpegData
                    completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(editAvatar(jpegData:completion:))
    NS_SWIFT_ASYNC_NAME(editAvatar(jpegData:));

@end

NS_ASSUME_NONNULL_END
