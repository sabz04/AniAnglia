//
//  YukimoStreamDTO.mm
//

#import "YukimoStreamDTO.h"

@interface YukimoStreamVariantDTO ()
@property (nonatomic, readwrite, copy) NSString *quality;
@property (nonatomic, readwrite, copy) NSString *url;
@property (nonatomic, readwrite) NSInteger height;
@end

@implementation YukimoStreamVariantDTO

+ (instancetype)variantWithQuality:(NSString *)quality url:(NSString *)url {
    YukimoStreamVariantDTO *v = [YukimoStreamVariantDTO new];
    v.quality = quality;
    v.url = url;
    v.height = [quality integerValue]; // returns 0 for non-numeric like "hls"
    return v;
}

@end
