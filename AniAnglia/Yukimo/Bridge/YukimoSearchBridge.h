//
//  YukimoSearchBridge.h
//

#import <Foundation/Foundation.h>
#import "YukimoReleaseDTO.h"
#import "YukimoSearchFilter.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const YukimoSearchErrorDomain;

NS_SWIFT_NAME(SearchBridge)
@interface YukimoSearchBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

- (void)searchReleasesWithQuery:(NSString *)query
                           page:(NSInteger)page
                     completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable releases, NSError * _Nullable error))completion
    NS_SWIFT_NAME(searchReleases(query:page:completion:))
    NS_SWIFT_ASYNC_NAME(searchReleases(query:page:));

/// Filter-based search (genre, year, season, status, category, age, sort).
- (void)filterSearchWithFilter:(YukimoSearchFilterDTO *)filter
                          page:(NSInteger)page
                    completion:(void (^)(NSArray<YukimoReleaseDTO *> * _Nullable releases, NSError * _Nullable error))completion
    NS_SWIFT_NAME(filterSearch(filter:page:completion:))
    NS_SWIFT_ASYNC_NAME(filterSearch(filter:page:));

/// Returns the canonical list of genre names known to libanixart (RU).
- (NSArray<NSString *> *)availableGenres NS_SWIFT_NAME(availableGenres());

#pragma mark Local history (backed by AppDataController)

- (NSArray<NSString *> *)recentSearches NS_SWIFT_NAME(recentSearches());
- (void)addRecentSearch:(NSString *)query NS_SWIFT_NAME(addRecentSearch(_:));
- (void)removeRecentSearchAtIndex:(NSInteger)index NS_SWIFT_NAME(removeRecentSearch(at:));

@end

NS_ASSUME_NONNULL_END
