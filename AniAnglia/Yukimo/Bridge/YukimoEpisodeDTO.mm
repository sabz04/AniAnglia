//
//  YukimoEpisodeDTO.mm
//

#import "YukimoEpisodeDTO.h"
#import "StringCvt.h"

#include <anixart/ApiTypes.hpp>

#pragma mark - YukimoEpisodeTypeDTO

@interface YukimoEpisodeTypeDTO ()
@property (nonatomic, readwrite) int64_t typeID;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite, copy) NSString *workers;
@property (nonatomic, readwrite) NSInteger episodesCount;
@property (nonatomic, readwrite) NSInteger viewCount;
@end

@implementation YukimoEpisodeTypeDTO @end

@interface YukimoEpisodeTypeDTO (Build)
+ (instancetype)fromType:(anixart::EpisodeType::Ptr)type;
@end

@implementation YukimoEpisodeTypeDTO (Build)
+ (instancetype)fromType:(anixart::EpisodeType::Ptr)t {
    if (!t) return nil;
    YukimoEpisodeTypeDTO *dto = [YukimoEpisodeTypeDTO new];
    dto.typeID = static_cast<int64_t>(t->id);
    dto.name = TO_NSSTRING(t->name);
    dto.workers = TO_NSSTRING(t->workers);
    dto.episodesCount = t->episodes_count;
    dto.viewCount = t->view_count;
    return dto;
}
@end

#pragma mark - YukimoEpisodeSourceDTO

@interface YukimoEpisodeSourceDTO ()
@property (nonatomic, readwrite) int64_t sourceID;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite) NSInteger episodesCount;
@end

@implementation YukimoEpisodeSourceDTO @end

@interface YukimoEpisodeSourceDTO (Build)
+ (instancetype)fromSource:(anixart::EpisodeSource::Ptr)source;
@end

@implementation YukimoEpisodeSourceDTO (Build)
+ (instancetype)fromSource:(anixart::EpisodeSource::Ptr)s {
    if (!s) return nil;
    YukimoEpisodeSourceDTO *dto = [YukimoEpisodeSourceDTO new];
    dto.sourceID = static_cast<int64_t>(s->id);
    dto.name = TO_NSSTRING(s->name);
    dto.episodesCount = s->episodes_count;
    return dto;
}
@end

#pragma mark - YukimoEpisodeDTO

@interface YukimoEpisodeDTO ()
@property (nonatomic, readwrite) int64_t episodeID;
@property (nonatomic, readwrite) NSInteger position;
@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite, copy) NSString *url;
@property (nonatomic, readwrite) int64_t releaseID;
@property (nonatomic, readwrite) int64_t sourceID;
@property (nonatomic, readwrite) NSInteger playbackPosition;
@property (nonatomic, readwrite) BOOL isWatched;
@property (nonatomic, readwrite) BOOL isFiller;
@end

@implementation YukimoEpisodeDTO @end

@interface YukimoEpisodeDTO (Build)
+ (instancetype)fromEpisode:(anixart::Episode::Ptr)episode;
@end

@implementation YukimoEpisodeDTO (Build)
+ (instancetype)fromEpisode:(anixart::Episode::Ptr)e {
    if (!e) return nil;
    YukimoEpisodeDTO *dto = [YukimoEpisodeDTO new];
    dto.episodeID = static_cast<int64_t>(e->id);
    dto.position = e->position;
    dto.name = TO_NSSTRING(e->name);
    dto.url = TO_NSSTRING(e->url);
    dto.releaseID = e->release_id;
    dto.sourceID = e->source_id;
    dto.playbackPosition = static_cast<NSInteger>(e->playback_position);
    dto.isWatched = e->is_watched;
    dto.isFiller = e->is_filler;
    return dto;
}
@end
