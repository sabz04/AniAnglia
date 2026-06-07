//
//  YukimoSearchFilter.h
//  Lightweight ObjC wrapper around anixart::requests::FilterRequest.
//  All fields are optional — a fresh instance does a free search.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YukimoFilterSort) {
    YukimoFilterSortDateUpdate = 0,
    YukimoFilterSortGrade      = 1,
    YukimoFilterSortYear       = 2,
    YukimoFilterSortPopular    = 3,
};

typedef NS_ENUM(NSInteger, YukimoReleaseSeason) {
    YukimoReleaseSeasonUnknown = 0,
    YukimoReleaseSeasonWinter  = 1,
    YukimoReleaseSeasonSpring  = 2,
    YukimoReleaseSeasonSummer  = 3,
    YukimoReleaseSeasonFall    = 4,
};

typedef NS_ENUM(NSInteger, YukimoAgeRating) {
    YukimoAgeRatingUnknown = 0,
    YukimoAgeRatingG       = 1,
    YukimoAgeRatingPG6     = 2,
    YukimoAgeRatingPG12    = 3,
    YukimoAgeRatingR16     = 4,
    YukimoAgeRatingR18     = 5,
};

NS_SWIFT_NAME(SearchFilterDTO)
@interface YukimoSearchFilterDTO : NSObject
@property (nonatomic) YukimoFilterSort sort;          ///< Default: DateUpdate
@property (nonatomic) NSInteger startYear;            ///< 0 = unset
@property (nonatomic) NSInteger endYear;              ///< 0 = unset
@property (nonatomic) YukimoReleaseSeason season;     ///< Unknown = unset
@property (nonatomic) NSInteger status;               ///< Maps to YukimoReleaseStatus, 0 = unset
@property (nonatomic) NSInteger category;             ///< Maps to YukimoReleaseCategory, 0 = unset
@property (nonatomic, copy, nullable) NSArray<NSString *> *genres;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *ageRatings;
@end

NS_ASSUME_NONNULL_END
