//
//  YukimoReleaseDTO.mm
//

#import "YukimoReleaseDTO.h"
#import "StringCvt.h"

#include <anixart/ApiTypes.hpp>
#include <memory>

@interface YukimoReleaseDTO ()
@property (nonatomic, readwrite) int64_t releaseID;
@property (nonatomic, readwrite, copy) NSString *titleRu;
@property (nonatomic, readwrite, copy) NSString *titleOriginal;
@property (nonatomic, readwrite, copy, nullable) NSString *imageURL;
@property (nonatomic, readwrite, copy) NSString *genres;
@property (nonatomic, readwrite, copy) NSString *year;
@property (nonatomic, readwrite) double grade;
@property (nonatomic, readwrite) NSInteger voteCount;
@property (nonatomic, readwrite) NSInteger myVote;
@property (nonatomic, readwrite) YukimoReleaseStatus status;
@property (nonatomic, readwrite) YukimoReleaseCategory category;
@property (nonatomic, readwrite) NSInteger episodesReleased;
@property (nonatomic, readwrite) NSInteger episodesTotal;
@property (nonatomic, readwrite) NSInteger lastViewEpisodePosition;
@property (nonatomic, readwrite, copy, nullable) NSString *lastViewEpisodeName;
@property (nonatomic, readwrite, copy, nullable) NSString *description_;
@property (nonatomic, readwrite) BOOL isFavorite;
@property (nonatomic, readwrite) NSInteger listStatus;
@property (nonatomic, readwrite, copy) NSArray<NSString *> *screenshotURLs;
@end

@implementation YukimoReleaseDTO
@end

/// Internal factory used by bridge classes (categorized as Obj-C++ helper).
@interface YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)release;
@end

@implementation YukimoReleaseDTO (Build)
+ (instancetype)fromRelease:(anixart::Release::Ptr)r {
    if (!r) return nil;
    YukimoReleaseDTO *dto = [YukimoReleaseDTO new];
    dto.releaseID        = static_cast<int64_t>(r->id);
    dto.titleRu          = TO_NSSTRING(r->title_ru);
    dto.titleOriginal    = TO_NSSTRING(r->title_original);
    dto.imageURL         = r->image_url.empty() ? nil : TO_NSSTRING(r->image_url);
    dto.genres           = TO_NSSTRING(r->genres);
    dto.year             = TO_NSSTRING(r->year);
    dto.grade            = r->grade;
    dto.voteCount        = r->vote_count;
    dto.myVote           = r->my_vote;
    dto.episodesReleased = r->episodes_released;
    dto.episodesTotal    = r->episodes_total;
    dto.description_     = r->description.empty() ? nil : TO_NSSTRING(r->description);
    dto.isFavorite       = r->is_favorite;
    NSMutableArray<NSString *> *shots = [NSMutableArray arrayWithCapacity:r->screenshot_image_urls.size()];
    for (const auto &url : r->screenshot_image_urls) {
        if (!url.empty()) [shots addObject:TO_NSSTRING(url)];
    }
    dto.screenshotURLs   = shots;
    switch (r->status) {
        case anixart::Release::Status::Finished: dto.status = YukimoReleaseStatusFinished; break;
        case anixart::Release::Status::Ongoing:  dto.status = YukimoReleaseStatusOngoing;  break;
        case anixart::Release::Status::Upcoming: dto.status = YukimoReleaseStatusUpcoming; break;
        default:                                  dto.status = YukimoReleaseStatusUnknown;  break;
    }
    switch (r->category) {
        case anixart::Release::Category::Series: dto.category = YukimoReleaseCategorySeries; break;
        case anixart::Release::Category::Movies: dto.category = YukimoReleaseCategoryMovies; break;
        case anixart::Release::Category::Ova:    dto.category = YukimoReleaseCategoryOva;    break;
        default:                                  dto.category = YukimoReleaseCategoryUnknown; break;
    }
    switch (r->profile_list_status) {
        case anixart::Profile::ListStatus::Watching: dto.listStatus = 1; break;
        case anixart::Profile::ListStatus::Plan:     dto.listStatus = 2; break;
        case anixart::Profile::ListStatus::Watched:  dto.listStatus = 3; break;
        case anixart::Profile::ListStatus::HoldOn:   dto.listStatus = 4; break;
        case anixart::Profile::ListStatus::Dropped:  dto.listStatus = 5; break;
        default:                                      dto.listStatus = 0; break;
    }
    if (r->last_view_episode) {
        dto.lastViewEpisodePosition = r->last_view_episode->position;
        dto.lastViewEpisodeName     = TO_NSSTRING(r->last_view_episode->name);
    }
    return dto;
}
@end
