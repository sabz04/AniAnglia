//
//  YukimoStreamDTO.h
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Single playable stream variant.
NS_SWIFT_NAME(StreamVariantDTO)
@interface YukimoStreamVariantDTO : NSObject
@property (nonatomic, readonly, copy) NSString *quality;   ///< "360", "480", "720", "1080", "hls", …
@property (nonatomic, readonly, copy) NSString *url;
@property (nonatomic, readonly) NSInteger height;          ///< numeric quality where applicable, 0 otherwise

+ (instancetype)variantWithQuality:(NSString *)quality url:(NSString *)url
    NS_SWIFT_NAME(make(quality:url:));
@end

NS_ASSUME_NONNULL_END
