//
//  YukimoEpisodeDTO.h
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(EpisodeTypeDTO)
@interface YukimoEpisodeTypeDTO : NSObject
@property (nonatomic, readonly) int64_t typeID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *workers;
@property (nonatomic, readonly) NSInteger episodesCount;
@property (nonatomic, readonly) NSInteger viewCount;
@end

NS_SWIFT_NAME(EpisodeSourceDTO)
@interface YukimoEpisodeSourceDTO : NSObject
@property (nonatomic, readonly) int64_t sourceID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) NSInteger episodesCount;
@end

NS_SWIFT_NAME(EpisodeDTO)
@interface YukimoEpisodeDTO : NSObject
@property (nonatomic, readonly) int64_t episodeID;
@property (nonatomic, readonly) NSInteger position;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *url;
@property (nonatomic, readonly) int64_t releaseID;
@property (nonatomic, readonly) int64_t sourceID;
@property (nonatomic, readonly) NSInteger playbackPosition;
@property (nonatomic, readonly) BOOL isWatched;
@property (nonatomic, readonly) BOOL isFiller;
@end

NS_ASSUME_NONNULL_END
