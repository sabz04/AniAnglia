//
//  YukimoSearchFilter.mm
//

#import "YukimoSearchFilter.h"

@implementation YukimoSearchFilterDTO

- (instancetype)init {
    if ((self = [super init])) {
        _sort = YukimoFilterSortDateUpdate;
        _startYear = 0;
        _endYear = 0;
        _season = YukimoReleaseSeasonUnknown;
        _status = 0;
        _category = 0;
        _genres = nil;
        _ageRatings = nil;
    }
    return self;
}

@end
