//
//  YukimoListStatus.h
//  Shared enum used by library + details bridges.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, YukimoListStatus) {
    YukimoListStatusNone     = 0,  ///< Not in any list
    YukimoListStatusWatching = 1,
    YukimoListStatusPlan     = 2,
    YukimoListStatusWatched  = 3,
    YukimoListStatusHoldOn   = 4,
    YukimoListStatusDropped  = 5,
    YukimoListStatusFavorite = 100, ///< Synthetic — represents the favorites list
    YukimoListStatusHistory  = 101, ///< Synthetic — represents the viewing history
};

typedef NS_ENUM(NSInteger, YukimoListSort) {
    YukimoListSortDescending        = 1,
    YukimoListSortAscending         = 2,
    YukimoListSortReleaseDescending = 3,
    YukimoListSortReleaseAscending  = 4,
    YukimoListSortTitleDescending   = 5,
    YukimoListSortTitleAscending    = 6,
};
