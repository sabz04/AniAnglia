//
//  YukimoLibraryBridge.mm
//

#import "YukimoLibraryBridge.h"
#import "LibanixartApi.h"
#import "AppDataController.h"
#import "StringCvt.h"

#include <anixart/Api.hpp>
#include <anixart/ApiReleases.hpp>
#include <anixart/ApiSearch.hpp>
#include <anixart/ApiPageableRequests.hpp>
#include <anixart/ApiRequestTypes.hpp>

NSString * const YukimoLibraryErrorDomain = @"com.yukimo.library";

@interface YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)release;
@end

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

static anixart::Profile::ListSort toCxxListSort(YukimoListSort s) {
    switch (s) {
        case YukimoListSortDescending:        return anixart::Profile::ListSort::Descending;
        case YukimoListSortAscending:         return anixart::Profile::ListSort::Ascending;
        case YukimoListSortReleaseDescending: return anixart::Profile::ListSort::ReleaseDescending;
        case YukimoListSortReleaseAscending:  return anixart::Profile::ListSort::ReleaseAscending;
        case YukimoListSortTitleDescending:   return anixart::Profile::ListSort::TitleDescending;
        case YukimoListSortTitleAscending:    return anixart::Profile::ListSort::TitleAscending;
    }
    return anixart::Profile::ListSort::Descending;
}

@implementation YukimoLibraryBridge

+ (instancetype)shared {
    static YukimoLibraryBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoLibraryBridge new]; });
    return instance;
}

- (void)loadListForStatus:(YukimoListStatus)status
                     sort:(YukimoListSort)sort
                     page:(NSInteger)page
               completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable, NSError * _Nullable))completion {
    int32_t cxx_page = static_cast<int32_t>(page);
    __block NSArray<YukimoReleaseDTO *> *result = nil;
    __block NSError *resultError = nil;

    [[LibanixartApi sharedInstance] asyncCall:^BOOL(anixart::Api *api) {
        try {
            fprintf(stderr, "[Yukimo.lib] loadList status=%ld page=%d\n",
                    (long)status, cxx_page);
            std::vector<anixart::Release::Ptr> items;
            if (status == YukimoListStatusFavorite) {
                anixart::ProfileID my_id = [[AppDataController sharedInstance] getMyProfileID];
                auto pages = api->releases().profile_favorites(
                    my_id, toCxxListSort(sort), /*filter_announce*/ 0, cxx_page);
                items = pages->get();
            } else if (status == YukimoListStatusHistory) {
                // Viewing history — releases the user has actually watched.
                // First try the modern POST endpoint (`search().history_search`)
                // which returns a full Paginator<Release>. The older
                // GET `releases().get_history` uses an EmptyContentPaginator
                // and was observed to return 0 items on real accounts.
                anixart::requests::SearchRequest req;
                req.query = "";
                req.search_by = anixart::requests::SearchRequest::SearchBy::Basic;
                auto pages = api->search().history_search(req, cxx_page);
                items = pages->get();
                fprintf(stderr, "[Yukimo.lib] history_search returned %zu items\n", items.size());
                if (items.empty()) {
                    // Fallback to the old endpoint in case the account / lib
                    // version actually populates it.
                    auto old_pages = api->releases().get_history(cxx_page);
                    items = old_pages->get();
                    fprintf(stderr, "[Yukimo.lib] get_history fallback returned %zu items\n", items.size());
                }
            } else {
                auto pages = api->releases().my_profile_list(
                    toCxxListStatus(status), toCxxListSort(sort), cxx_page);
                items = pages->get();
            }
            NSMutableArray *out = [NSMutableArray arrayWithCapacity:items.size()];
            int dropped = 0;
            for (const auto &r : items) {
                YukimoReleaseDTO *dto = [YukimoReleaseDTO fromRelease:r];
                if (dto) [out addObject:dto];
                else dropped++;
            }
            fprintf(stderr, "[Yukimo.lib] mapped %lu / %zu items (dropped=%d)\n",
                    (unsigned long)out.count, items.size(), dropped);
            result = out;
            return NO;
        } catch (const std::exception &e) {
            fprintf(stderr, "[Yukimo.lib] EXCEPTION: %s\n", e.what());
            resultError = [NSError errorWithDomain:YukimoLibraryErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey:
                                              [NSString stringWithUTF8String:e.what()] }];
            return YES;
        }
    } completion:^(BOOL errored) {
        if (errored && resultError == nil) {
            resultError = [NSError errorWithDomain:YukimoLibraryErrorDomain
                                              code:0
                                          userInfo:@{ NSLocalizedDescriptionKey: @"Не удалось загрузить список" }];
        }
        completion(result, resultError);
    }];
}

@end
