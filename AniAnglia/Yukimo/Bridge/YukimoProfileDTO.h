//
//  YukimoProfileDTO.h
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ProfileDTO)
@interface YukimoProfileDTO : NSObject
@property (nonatomic, readonly) int64_t profileID;
@property (nonatomic, readonly, copy) NSString *username;
@property (nonatomic, readonly, copy, nullable) NSString *avatarURL;
@property (nonatomic, readonly, copy) NSString *statusText;
@property (nonatomic, readonly) NSInteger watchedMinutes;
@property (nonatomic, readonly) NSInteger watchedCount;
@property (nonatomic, readonly) NSInteger watchingCount;
@property (nonatomic, readonly) NSInteger planCount;
@property (nonatomic, readonly) NSInteger holdOnCount;
@property (nonatomic, readonly) NSInteger droppedCount;
@property (nonatomic, readonly) NSInteger favoriteCount;
@end

NS_ASSUME_NONNULL_END
