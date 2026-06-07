//
//  YukimoReleaseDetailBridge.h
//

#import <Foundation/Foundation.h>
#import "YukimoReleaseDTO.h"
#import "YukimoEpisodeDTO.h"
#import "YukimoListStatus.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoDetailsErrorDomain;

NS_SWIFT_NAME(ReleaseDetailBridge)
@interface YukimoReleaseDetailBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Full release fetch.
- (void)loadReleaseWithID:(int64_t)releaseID
               completion:(void (^)(YukimoReleaseDTO * _Nullable release, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadRelease(id:completion:))
    NS_SWIFT_ASYNC_NAME(loadRelease(id:));

- (void)loadEpisodeTypesForReleaseID:(int64_t)releaseID
                          completion:(void (^)(NSArray<YukimoEpisodeTypeDTO *> * _Nullable types, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadEpisodeTypes(releaseID:completion:))
    NS_SWIFT_ASYNC_NAME(loadEpisodeTypes(releaseID:));

- (void)loadEpisodeSourcesForReleaseID:(int64_t)releaseID
                                typeID:(int64_t)typeID
                            completion:(void (^)(NSArray<YukimoEpisodeSourceDTO *> * _Nullable sources, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadEpisodeSources(releaseID:typeID:completion:))
    NS_SWIFT_ASYNC_NAME(loadEpisodeSources(releaseID:typeID:));

- (void)loadEpisodesForReleaseID:(int64_t)releaseID
                          typeID:(int64_t)typeID
                        sourceID:(int64_t)sourceID
                      completion:(void (^)(NSArray<YukimoEpisodeDTO *> * _Nullable episodes, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadEpisodes(releaseID:typeID:sourceID:completion:))
    NS_SWIFT_ASYNC_NAME(loadEpisodes(releaseID:typeID:sourceID:));

#pragma mark Mutations

- (void)setListStatus:(YukimoListStatus)status
         forReleaseID:(int64_t)releaseID
           completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(setListStatus(_:releaseID:completion:))
    NS_SWIFT_ASYNC_NAME(setListStatus(_:releaseID:));

- (void)setFavorite:(BOOL)isFavorite
       forReleaseID:(int64_t)releaseID
         completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(setFavorite(_:releaseID:completion:))
    NS_SWIFT_ASYNC_NAME(setFavorite(_:releaseID:));

/// Rates the release with 1..5 stars. Pass 0 to remove the vote.
- (void)voteRelease:(int64_t)releaseID
              stars:(NSInteger)stars
         completion:(void (^)(BOOL success, NSError * _Nullable error))completion
    NS_SWIFT_NAME(vote(releaseID:stars:completion:))
    NS_SWIFT_ASYNC_NAME(vote(releaseID:stars:));

@end

NS_ASSUME_NONNULL_END
