//
//  YukimoSearchBridge.mm
//

#import "YukimoSearchBridge.h"
#import "LibanixartApi.h"
#import "AppDataController.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiSearch.hpp>
#include <anixart/ApiPageableRequests.hpp>
#include <anixart/ApiRequestTypes.hpp>
#include <anixart/ApiTypes.hpp>
#include <chrono>

NSString * const YukimoSearchErrorDomain = @"com.yukimo.search";

@interface YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)release;
@end

@implementation YukimoSearchBridge

+ (instancetype)shared {
    static YukimoSearchBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoSearchBridge new]; });
    return instance;
}

- (void)searchReleasesWithQuery:(NSString *)query
                           page:(NSInteger)page
                     completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    if (query.length == 0) {
        completion(@[], nil);
        return;
    }
    std::string cxx_query = TO_STDSTRING(query);
    int32_t cxx_page = static_cast<int32_t>(page);
    __block NSArray<YukimoReleaseDTO *> *result = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            anixart::requests::SearchRequest req;
            req.query = cxx_query;
            req.search_by = anixart::requests::SearchRequest::SearchBy::Basic;
            auto pages = api->search().release_search(req, cxx_page);
            auto items = pages->get();
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.size()];
            for (const auto &r : items) {
                YukimoReleaseDTO *dto = [YukimoReleaseDTO fromRelease:r];
                if (dto) [out addObject:dto];
            }
            result = out;
            return NO;
        } catch (const std::exception &e) {
            resultError = [NSError errorWithDomain:YukimoSearchErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                              [NSString stringWithUTF8String:e.what()] }];
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = [NSError errorWithDomain:YukimoSearchErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey: @"Поиск не удался" }];
        }
        completion(result, resultError);
    }];
}

#pragma mark Filter search

- (void)filterSearchWithFilter:(YukimoSearchFilterDTO *)filter
                          page:(NSInteger)page
                    completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    YukimoSearchFilterDTO *snapshot = filter; // captured by block, immutable here
    int32_t cxx_page = static_cast<int32_t>(page);
    __block NSArray<YukimoReleaseDTO *> *result = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            anixart::requests::FilterRequest req;
            // Sort
            switch (snapshot.sort) {
                case YukimoFilterSortDateUpdate: req.sort = anixart::requests::FilterRequest::DateUpdate; break;
                case YukimoFilterSortGrade:      req.sort = anixart::requests::FilterRequest::Grade;      break;
                case YukimoFilterSortYear:       req.sort = anixart::requests::FilterRequest::Year;       break;
                case YukimoFilterSortPopular:    req.sort = anixart::requests::FilterRequest::Popular;    break;
            }
            if (snapshot.startYear > 0) {
                req.start_year = std::chrono::years(static_cast<int32_t>(snapshot.startYear));
            }
            if (snapshot.endYear > 0) {
                req.end_year = std::chrono::years(static_cast<int32_t>(snapshot.endYear));
            }
            switch (snapshot.season) {
                case YukimoReleaseSeasonWinter: req.season = anixart::Release::Season::Winter; break;
                case YukimoReleaseSeasonSpring: req.season = anixart::Release::Season::Spring; break;
                case YukimoReleaseSeasonSummer: req.season = anixart::Release::Season::Summer; break;
                case YukimoReleaseSeasonFall:   req.season = anixart::Release::Season::Fall;   break;
                default: break;
            }
            switch (snapshot.status) {
                case 1: req.status = anixart::Release::Status::Finished; break;
                case 2: req.status = anixart::Release::Status::Ongoing;  break;
                case 3: req.status = anixart::Release::Status::Upcoming; break;
                default: break;
            }
            switch (snapshot.category) {
                case 1: req.category = anixart::Release::Category::Series; break;
                case 2: req.category = anixart::Release::Category::Movies; break;
                case 3: req.category = anixart::Release::Category::Ova;    break;
                default: break;
            }
            for (NSString *g in (snapshot.genres ?: @[])) {
                req.genres.push_back(TO_STDSTRING(g));
            }
            for (NSNumber *n in (snapshot.ageRatings ?: @[])) {
                switch ([n integerValue]) {
                    case YukimoAgeRatingG:    req.age_ratings.push_back(anixart::Release::AgeRating::G);    break;
                    case YukimoAgeRatingPG6:  req.age_ratings.push_back(anixart::Release::AgeRating::PG6);  break;
                    case YukimoAgeRatingPG12: req.age_ratings.push_back(anixart::Release::AgeRating::PG12); break;
                    case YukimoAgeRatingR16:  req.age_ratings.push_back(anixart::Release::AgeRating::R16);  break;
                    case YukimoAgeRatingR18:  req.age_ratings.push_back(anixart::Release::AgeRating::R18);  break;
                    default: break;
                }
            }

            auto pages = api->search().filter_search(req, /*extended_mode*/ false, cxx_page);
            auto items = pages->get();
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.size()];
            for (const auto &r : items) {
                YukimoReleaseDTO *dto = [YukimoReleaseDTO fromRelease:r];
                if (dto) [out addObject:dto];
            }
            result = out;
            return NO;
        } catch (const std::exception &e) {
            resultError = [NSError errorWithDomain:YukimoSearchErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                              [NSString stringWithUTF8String:e.what()] }];
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = [NSError errorWithDomain:YukimoSearchErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey: @"Фильтр не сработал" }];
        }
        completion(result, resultError);
    }];
}

- (NSArray<NSString *> *)availableGenres {
    return [[LibanixartApi sharedInstance] getGenresArray] ?: @[];
}

#pragma mark History

- (NSArray<NSString *> *)recentSearches {
    return [[AppDataController sharedInstance] getSearchHistory] ?: @[];
}

- (void)addRecentSearch:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) return;
    [[AppDataController sharedInstance] addSearchHistoryItem:trimmed];
}

- (void)removeRecentSearchAtIndex:(NSInteger)index {
    if (index < 0) return;
    [[AppDataController sharedInstance] removeSearchHistoryItemAtIndex:index];
}

@end
