//
//  YukimoReleaseDTO.h
//  Plain Obj-C view of anixart::Release that Swift can consume directly.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YukimoReleaseStatus) {
    YukimoReleaseStatusUnknown  = 0,
    YukimoReleaseStatusFinished = 1,
    YukimoReleaseStatusOngoing  = 2,
    YukimoReleaseStatusUpcoming = 3,
};

typedef NS_ENUM(NSInteger, YukimoReleaseCategory) {
    YukimoReleaseCategoryUnknown = 0,
    YukimoReleaseCategorySeries  = 1,
    YukimoReleaseCategoryMovies  = 2,
    YukimoReleaseCategoryOva     = 3,
};

NS_SWIFT_NAME(ReleaseDTO)
@interface YukimoReleaseDTO : NSObject
@property (nonatomic, readonly) int64_t releaseID;
@property (nonatomic, readonly, copy) NSString *titleRu;
@property (nonatomic, readonly, copy) NSString *titleOriginal;
@property (nonatomic, readonly, copy, nullable) NSString *imageURL;
@property (nonatomic, readonly, copy) NSString *genres;          ///< Comma-separated as stored upstream.
@property (nonatomic, readonly, copy) NSString *year;
@property (nonatomic, readonly) double grade;                    ///< Average rating, 0.0–5.0.
@property (nonatomic, readonly) NSInteger voteCount;
@property (nonatomic, readonly) NSInteger myVote;                ///< 0 = not voted, otherwise 1..5.
@property (nonatomic, readonly) YukimoReleaseStatus status;
@property (nonatomic, readonly) YukimoReleaseCategory category;
@property (nonatomic, readonly) NSInteger episodesReleased;
@property (nonatomic, readonly) NSInteger episodesTotal;
@property (nonatomic, readonly) NSInteger lastViewEpisodePosition;
@property (nonatomic, readonly, copy, nullable) NSString *lastViewEpisodeName;
@property (nonatomic, readonly, copy, nullable) NSString *description_;
@property (nonatomic, readonly) BOOL isFavorite;
@property (nonatomic, readonly) NSInteger listStatus;          ///< Maps to YukimoListStatus, 0 = NotWatching.
@property (nonatomic, readonly, copy) NSArray<NSString *> *screenshotURLs;
@end

NS_ASSUME_NONNULL_END
