//
//  YukimoLibraryBridge.h
//

#import <Foundation/Foundation.h>
#import "YukimoReleaseDTO.h"
#import "YukimoListStatus.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoLibraryErrorDomain;

NS_SWIFT_NAME(LibraryBridge)
@interface YukimoLibraryBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Loads a page of the signed-in user's list for the given status. Pass
/// `YukimoListStatusFavorite` to load the favorites list (uses a separate
/// endpoint internally).
- (void)loadListForStatus:(YukimoListStatus)status
                     sort:(YukimoListSort)sort
                     page:(NSInteger)page
               completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable releases, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadList(status:sort:page:completion:))
    NS_SWIFT_ASYNC_NAME(loadList(status:sort:page:));

@end

NS_ASSUME_NONNULL_END
