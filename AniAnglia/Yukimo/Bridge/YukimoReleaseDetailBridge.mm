//
//  YukimoReleaseDetailBridge.mm
//

#import "YukimoReleaseDetailBridge.h"
#import "LibanixartApi.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiReleases.hpp>
#include <anixart/ApiEpisodes.hpp>
#include <anixart/ApiTypes.hpp>
#include <vector>

NSString * const YukimoDetailsErrorDomain = @"com.yukimo.details";

@interface YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)release;
@end
@interface YukimoEpisodeTypeDTO (Build)
+ (instancetype)fromType:(anixart::EpisodeType::Ptr)type;
@end
@interface YukimoEpisodeSourceDTO (Build)
+ (instancetype)fromSource:(anixart::EpisodeSource::Ptr)source;
@end
@interface YukimoEpisodeDTO (Build)
+ (instancetype)fromEpisode:(anixart::Episode::Ptr)episode;
@end

static NSError *detailsError(NSString *msg) {
    return [NSError errorWithDomain:YukimoDetailsErrorDomain
                               code:0
                           userInfo:@{ NSLocalizedDescriptionKey: msg ?: @"" }];
}

static anixart::Profile::ListStatus toCxxListStatus(YukimoListStatus s) {
    switch (s) {
        case YukimoListStatusWatching: return anixart::Profile::ListStatus::Watching;
        case YukimoListStatusPlan:     return anixart::Profile::ListStatus::Plan;
        case YukimoListStatusWatched:  return anixart::Profile::ListStatus::Watched;
        case YukimoListStatusHoldOn:   return anixart::Profile::ListStatus::HoldOn;
        case YukimoListStatusDropped:  return anixart::Profile::ListStatus::Dropped;
        default:                       return anixart::Profile::ListStatus::NotWatching;
    }
}

@implementation YukimoReleaseDetailBridge

+ (instancetype)shared {
    static YukimoReleaseDetailBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoReleaseDetailBridge new]; });
    return instance;
}

#pragma mark Load Release

- (void)loadReleaseWithID:(int64_t)releaseID
               completion:(void (^)(YukimoReleaseDTO * _Nullable, NSError * _Nullable))completion {
    __block YukimoReleaseDTO *dto = nil;
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto r = api->releases().get_release(anixart::ReleaseID(releaseID));
            dto = [YukimoReleaseDTO fromRelease:r];
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось загрузить тайтл");
        completion(dto, resultError);
    }];
}

#pragma mark Episode Tree

- (void)loadEpisodeTypesForReleaseID:(int64_t)releaseID
                          completion:(void (^)(NSArray<YukimoEpisodeTypeDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoEpisodeTypeDTO *> *result = nil;
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto types = api->episodes().get_release_types(anixart::ReleaseID(releaseID));
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:types.size()];
            for (const auto &t : types) {
                YukimoEpisodeTypeDTO *dto = [YukimoEpisodeTypeDTO fromType:t];
                if (dto) [out addObject:dto];
            }
            result = out;
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось загрузить озвучки");
        completion(result, resultError);
    }];
}

- (void)loadEpisodeSourcesForReleaseID:(int64_t)releaseID
                                typeID:(int64_t)typeID
                            completion:(void (^)(NSArray<YukimoEpisodeSourceDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoEpisodeSourceDTO *> *result = nil;
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto sources = api->episodes().get_release_sources(
                anixart::ReleaseID(releaseID), anixart::EpisodeTypeID(typeID));
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:sources.size()];
            for (const auto &s : sources) {
                YukimoEpisodeSourceDTO *dto = [YukimoEpisodeSourceDTO fromSource:s];
                if (dto) [out addObject:dto];
            }
            result = out;
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось загрузить источники");
        completion(result, resultError);
    }];
}

- (void)loadEpisodesForReleaseID:(int64_t)releaseID
                          typeID:(int64_t)typeID
                        sourceID:(int64_t)sourceID
                      completion:(void (^)(NSArray<YukimoEpisodeDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoEpisodeDTO *> *result = nil;
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto eps = api->episodes().get_release_episodes(
                anixart::ReleaseID(releaseID),
                anixart::EpisodeTypeID(typeID),
                anixart::EpisodeSourceID(sourceID),
                anixart::Episode::Sort::FromLeast);
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:eps.size()];
            for (const auto &e : eps) {
                YukimoEpisodeDTO *dto = [YukimoEpisodeDTO fromEpisode:e];
                if (dto) [out addObject:dto];
            }
            result = out;
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось загрузить серии");
        completion(result, resultError);
    }];
}

#pragma mark Mutations

- (void)setListStatus:(YukimoListStatus)status
         forReleaseID:(int64_t)releaseID
           completion:(void (^)(BOOL, NSError * _Nullable))completion {
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            anixart::ReleaseID rid(releaseID);
            // Server semantics: a release lives in exactly one list. Setting NotWatching
            // removes it from any list; otherwise we call add_release_to_profile_list which
            // upstream handles the transition for us.
            if (status == YukimoListStatusNone) {
                // Use remove_release_from_profile_list with a "best-effort" sweep: the
                // server tolerates calling remove with any status if the release isn't in
                // that list — but the simpler path is to just call with Watching (default).
                api->releases().remove_release_from_profile_list(
                    rid, anixart::Profile::ListStatus::Watching);
            } else {
                api->releases().add_release_to_profile_list(rid, toCxxListStatus(status));
            }
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось изменить список");
        completion(resultError == nil, resultError);
    }];
}

- (void)voteRelease:(int64_t)releaseID
              stars:(NSInteger)stars
         completion:(void (^)(BOOL, NSError * _Nullable))completion {
    __block NSError *resultError = nil;
    int32_t cxx_stars = static_cast<int32_t>(stars);
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            anixart::ReleaseID rid(releaseID);
            if (cxx_stars <= 0) {
                api->releases().delete_release_vote(rid);
            } else {
                api->releases().release_vote(rid, cxx_stars);
            }
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось сохранить оценку");
        completion(resultError == nil, resultError);
    }];
}

- (void)setFavorite:(BOOL)isFavorite
       forReleaseID:(int64_t)releaseID
         completion:(void (^)(BOOL, NSError * _Nullable))completion {
    __block NSError *resultError = nil;
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            anixart::ReleaseID rid(releaseID);
            if (isFavorite) {
                api->releases().add_release_to_favorites(rid);
            } else {
                api->releases().remove_release_from_favorites(rid);
            }
            return NO;
        } catch (const std::exception &e) {
            resultError = detailsError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = detailsError(@"Не удалось обновить");
        completion(resultError == nil, resultError);
    }];
}

@end
