//
//  YukimoProfileDTO.mm
//

#import "YukimoProfileDTO.h"
#import "StringCvt.h"

#include <anixart/ApiTypes.hpp>
#include <chrono>

@interface YukimoProfileDTO ()
@property (nonatomic, readwrite) int64_t profileID;
@property (nonatomic, readwrite, copy) NSString *username;
@property (nonatomic, readwrite, copy, nullable) NSString *avatarURL;
@property (nonatomic, readwrite, copy) NSString *statusText;
@property (nonatomic, readwrite) NSInteger watchedMinutes;
@property (nonatomic, readwrite) NSInteger watchedCount;
@property (nonatomic, readwrite) NSInteger watchingCount;
@property (nonatomic, readwrite) NSInteger planCount;
@property (nonatomic, readwrite) NSInteger holdOnCount;
@property (nonatomic, readwrite) NSInteger droppedCount;
@property (nonatomic, readwrite) NSInteger favoriteCount;
@end

@implementation YukimoProfileDTO
@end

@interface YukimoProfileDTO (Build)
+ (instancetype)fromProfile:(anixart::Profile::Ptr)profile;
@end

@implementation YukimoProfileDTO (Build)
+ (instancetype)fromProfile:(anixart::Profile::Ptr)p {
    if (!p) return nil;
    YukimoProfileDTO *dto = [YukimoProfileDTO new];
    dto.profileID      = static_cast<int64_t>(p->id);
    dto.username       = TO_NSSTRING(p->username);
    dto.avatarURL      = p->avatar_url.empty() ? nil : TO_NSSTRING(p->avatar_url);
    dto.statusText     = TO_NSSTRING(p->status);
    dto.watchedMinutes = static_cast<NSInteger>(p->watched_time.count());
    dto.watchedCount   = p->watched_count;
    dto.watchingCount  = p->watching_count;
    dto.planCount      = p->plan_count;
    dto.holdOnCount    = p->hold_on_count;
    dto.droppedCount   = p->dropped_count;
    dto.favoriteCount  = p->favorite_count;
    return dto;
}
@end
