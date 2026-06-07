//
//  YukimoPlayerBridge.h
//

#import <Foundation/Foundation.h>
#import "YukimoStreamDTO.h"
#import "YukimoEpisodeDTO.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoPlayerErrorDomain;

NS_SWIFT_NAME(PlayerBridge)
@interface YukimoPlayerBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Resolves a single episode to a list of playable stream variants (qualities).
/// Internally fetches the episode target then runs the matching parser
/// (Kodik / Libria) on its embed URL. Order is sorted by descending height.
- (void)resolveStreamsForReleaseID:(int64_t)releaseID
                          sourceID:(int64_t)sourceID
                          position:(NSInteger)position
                        completion:(void (^)(NSArray<YukimoStreamVariantDTO *> * _Nullable variants, NSError * _Nullable error))completion
    NS_SWIFT_NAME(resolveStreams(releaseID:sourceID:position:completion:))
    NS_SWIFT_ASYNC_NAME(resolveStreams(releaseID:sourceID:position:));

/// Resolves a single embed URL directly to its variants. Useful when the
/// Episode object is already in hand (skips the get_episode_target hop).
- (void)resolveStreamsForEmbedURL:(NSString *)embedURL
                       completion:(void (^)(NSArray<YukimoStreamVariantDTO *> * _Nullable variants, NSError * _Nullable error))completion
    NS_SWIFT_NAME(resolveStreams(embedURL:completion:))
    NS_SWIFT_ASYNC_NAME(resolveStreams(embedURL:));

/// Marks an episode as watched server-side. Best-effort — failures are silent.
- (void)markWatchedReleaseID:(int64_t)releaseID
                    sourceID:(int64_t)sourceID
                    position:(NSInteger)position
                  completion:(void (^_Nullable)(void))completion
    NS_SWIFT_NAME(markWatched(releaseID:sourceID:position:completion:));

@end

NS_ASSUME_NONNULL_END
