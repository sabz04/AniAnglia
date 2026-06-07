//
//  YukimoPlayerBridge.mm
//

#import "YukimoPlayerBridge.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "YukimoVKParser.h"
#import "YukimoSibnetParser.h"

#include <anixart/Api.hpp>
#include <anixart/ApiEpisodes.hpp>
#include <anixart/ApiReleases.hpp>
#include <anixart/Parsers.hpp>
#include <anixart/ApiTypes.hpp>
#include <unordered_map>
#include <string>

NSString * const YukimoPlayerErrorDomain = @"com.yukimo.player";

@interface YukimoStreamVariantDTO (Build)
+ (instancetype)variantWithQuality:(NSString *)quality url:(NSString *)url;
@end

static NSArray<YukimoStreamVariantDTO *> *mapStreams(const std::unordered_map<std::string, std::string> &streams) {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:streams.size()];
    for (const auto &kv : streams) {
        NSString *q   = TO_NSSTRING(kv.first);
        NSString *url = TO_NSSTRING(kv.second);
        if (q.length == 0 || url.length == 0) continue;
        [out addObject:[YukimoStreamVariantDTO variantWithQuality:q url:url]];
    }
    [out sortUsingComparator:^NSComparisonResult(YukimoStreamVariantDTO *a, YukimoStreamVariantDTO *b) {
        // Descending: higher quality first; non-numeric (hls/master) trails.
        if (a.height == b.height) return NSOrderedSame;
        if (a.height == 0) return NSOrderedDescending; // unknown after numeric
        if (b.height == 0) return NSOrderedAscending;
        return a.height < b.height ? NSOrderedDescending : NSOrderedAscending;
    }];
    return out;
}

static NSError *playerError(NSString *message) {
    return [NSError errorWithDomain:YukimoPlayerErrorDomain
                               code:0
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"" }];
}

@implementation YukimoPlayerBridge

+ (instancetype)shared {
    static YukimoPlayerBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoPlayerBridge new]; });
    return instance;
}

#pragma mark Resolve

- (void)resolveStreamsForReleaseID:(int64_t)releaseID
                          sourceID:(int64_t)sourceID
                          position:(NSInteger)position
                        completion:(void (^)(NSArray<YukimoStreamVariantDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoStreamVariantDTO *> *result = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            fprintf(stderr, "[Yukimo.bridge] resolveStreams releaseID=%lld sourceID=%lld position=%ld\n",
                    (long long)releaseID, (long long)sourceID, (long)position);
            auto target = api->episodes().get_episode_target(
                anixart::ReleaseID(releaseID),
                anixart::EpisodeSourceID(sourceID),
                static_cast<int32_t>(position));
            if (!target || target->url.empty()) {
                fprintf(stderr, "[Yukimo.bridge] ERROR target empty (target=%p, urlEmpty=%d)\n",
                        target.get(), target ? (int)target->url.empty() : -1);
                resultError = playerError(@"Эпизод недоступен");
                return YES;
            }
            fprintf(stderr, "[Yukimo.bridge] embed URL: %s\n", target->url.c_str());
            std::unordered_map<std::string, std::string> streams;
            if (yukimo::parsers::VKParser::can_handle(target->url)) {
                fprintf(stderr, "[Yukimo.bridge] routing to YukimoVKParser\n");
                yukimo::parsers::VKParser vk;
                streams = vk.extract_info(target->url);
            } else if (yukimo::parsers::SibnetParser::can_handle(target->url)) {
                fprintf(stderr, "[Yukimo.bridge] routing to YukimoSibnetParser\n");
                yukimo::parsers::SibnetParser sn;
                streams = sn.extract_info(target->url);
            } else {
                streams = [[LibanixartApi sharedInstance] getParsers]->extract_info(target->url);
            }
            fprintf(stderr, "[Yukimo.bridge] extract_info returned %zu streams\n", streams.size());
            if (streams.empty()) {
                resultError = playerError(@"Не удалось получить ссылки на видео");
                return YES;
            }
            for (const auto &kv : streams) {
                fprintf(stderr, "[Yukimo.bridge]   stream q=%s url=%.120s\n",
                        kv.first.c_str(), kv.second.c_str());
            }
            result = mapStreams(streams);
            return NO;
        } catch (const std::exception &e) {
            fprintf(stderr, "[Yukimo.bridge] EXCEPTION resolveStreams: %s\n", e.what());
            resultError = playerError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = playerError(@"Не удалось подготовить плеер");
        completion(result, resultError);
    }];
}

- (void)resolveStreamsForEmbedURL:(NSString *)embedURL
                       completion:(void (^)(NSArray<YukimoStreamVariantDTO *> * _Nullable, NSError * _Nullable))completion {
    if (embedURL.length == 0) {
        completion(nil, playerError(@"Пустая ссылка"));
        return;
    }
    std::string cxx_url = TO_STDSTRING(embedURL);
    __block NSArray<YukimoStreamVariantDTO *> *result = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto streams = [[LibanixartApi sharedInstance] getParsers]->extract_info(cxx_url);
            if (streams.empty()) {
                resultError = playerError(@"Парсер не нашёл потоков");
                return YES;
            }
            result = mapStreams(streams);
            return NO;
        } catch (const std::exception &e) {
            resultError = playerError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = playerError(@"Парсер вернул ошибку");
        completion(result, resultError);
    }];
}

#pragma mark Watched

- (void)markWatchedReleaseID:(int64_t)releaseID
                    sourceID:(int64_t)sourceID
                    position:(NSInteger)position
                  completion:(void (^_Nullable)(void))completion {
    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            api->episodes().add_watched_episode(
                anixart::ReleaseID(releaseID),
                anixart::EpisodeSourceID(sourceID),
                static_cast<int32_t>(position));
            return NO;
        } catch (const std::exception &) {
            return YES;
        }
    } completion:^(BOOL errored) {
        if (completion) completion();
    }];
}

@end
