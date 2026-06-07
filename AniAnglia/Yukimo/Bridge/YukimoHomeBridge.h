//
//  YukimoHomeBridge.h
//  Pure Obj-C facade for Home screen data. Each method runs on a
//  background queue and dispatches its completion to main. Errors
//  are surfaced via NSError so SwiftUI can render an empty state.
//

#import <Foundation/Foundation.h>
#import "YukimoReleaseDTO.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoHomeErrorDomain;

NS_SWIFT_NAME(HomeBridge)
@interface YukimoHomeBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// Random release as the hero. Uses anixart::ApiReleases::random_release(true).
- (void)loadHeroWithCompletion:(void (^)(YukimoReleaseDTO * _Nullable hero, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadHero(completion:))
    NS_SWIFT_ASYNC_NAME(loadHero());

/// Continue watching. Backed by releases().get_history(0).
- (void)loadContinueWatchingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable items, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadContinueWatching(completion:))
    NS_SWIFT_ASYNC_NAME(loadContinueWatching());

/// Personalized recommendations. Backed by search().recomendations(0). Note
/// the legacy spelling in libanixart — we expose the corrected name to Swift.
- (void)loadRecommendationsWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable items, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadRecommendations(completion:))
    NS_SWIFT_ASYNC_NAME(loadRecommendations());

/// "Currently Watching" feed. Backed by search().currently_watching(0).
- (void)loadCurrentlyWatchingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable items, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadCurrentlyWatching(completion:))
    NS_SWIFT_ASYNC_NAME(loadCurrentlyWatching());

/// Currently-discussed feed. Backed by search().discussing().
- (void)loadDiscussingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable items, NSError * _Nullable error))completion
    NS_SWIFT_NAME(loadDiscussing(completion:))
    NS_SWIFT_ASYNC_NAME(loadDiscussing());

@end

NS_ASSUME_NONNULL_END
