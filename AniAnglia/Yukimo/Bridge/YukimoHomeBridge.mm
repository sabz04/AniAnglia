//
//  YukimoHomeBridge.mm
//

#import "YukimoHomeBridge.h"
#import "YukimoReleaseDTO.h"
#import "LibanixartApi.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiReleases.hpp>
#include <anixart/ApiSearch.hpp>
#include <anixart/ApiPageableRequests.hpp>
#include <anixart/ApiTypes.hpp>

#include <vector>
#include <utility>

NSString * const YukimoHomeErrorDomain = @"com.yukimo.home";

@interface YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)release;
@end

static NSError *makeHomeError(NSString *message) {
    return [NSError errorWithDomain:YukimoHomeErrorDomain
                               code:0
                           userInfo:@{ NSLocalizedDescriptionKey: message ?: @"" }];
}

static NSArray<YukimoReleaseDTO *> *mapReleases(const std::vector<anixart::Release::Ptr> &items) {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.size()];
    for (const auto &r : items) {
        YukimoReleaseDTO *dto = [YukimoReleaseDTO fromRelease:r];
        if (dto) [out addObject:dto];
    }
    return out;
}

@implementation YukimoHomeBridge

+ (instancetype)shared {
    static YukimoHomeBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoHomeBridge new]; });
    return instance;
}

#pragma mark Hero

- (void)loadHeroWithCompletion:(void (^)(YukimoReleaseDTO * _Nullable, NSError * _Nullable))completion {
    __block YukimoReleaseDTO *hero = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto release = api->releases().random_release(/*extended_mode*/ true);
            hero = [YukimoReleaseDTO fromRelease:release];
            return NO;
        } catch (const std::exception &e) {
            resultError = makeHomeError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = makeHomeError(@"Не удалось загрузить");
        completion(hero, resultError);
    }];
}

#pragma mark Continue Watching

- (void)loadContinueWatchingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoReleaseDTO *> *items = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pages = api->releases().get_history(0);
            auto v = pages->get();
            items = mapReleases(v);
            return NO;
        } catch (const std::exception &e) {
            resultError = makeHomeError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = makeHomeError(@"Не удалось загрузить историю");
        completion(items, resultError);
    }];
}

#pragma mark Recommendations

- (void)loadRecommendationsWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoReleaseDTO *> *items = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pages = api->search().recomendations(0); // libanixart legacy spelling
            auto v = pages->get();
            items = mapReleases(v);
            return NO;
        } catch (const std::exception &e) {
            resultError = makeHomeError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = makeHomeError(@"Не удалось загрузить рекомендации");
        completion(items, resultError);
    }];
}

#pragma mark Currently Watching

- (void)loadCurrentlyWatchingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoReleaseDTO *> *items = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pages = api->search().currently_watching(0);
            auto v = pages->get();
            items = mapReleases(v);
            return NO;
        } catch (const std::exception &e) {
            resultError = makeHomeError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = makeHomeError(@"Не удалось загрузить");
        completion(items, resultError);
    }];
}

#pragma mark Discussing

- (void)loadDiscussingWithCompletion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    __block NSArray<YukimoReleaseDTO *> *items = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            auto pages = api->search().discussing();
            auto v = pages->get();
            items = mapReleases(v);
            return NO;
        } catch (const std::exception &e) {
            resultError = makeHomeError([NSString stringWithUTF8String:e.what()]);
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) resultError = makeHomeError(@"Не удалось загрузить");
        completion(items, resultError);
    }];
}

@end
