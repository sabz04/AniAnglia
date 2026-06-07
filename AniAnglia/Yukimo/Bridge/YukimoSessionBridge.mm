//
//  YukimoSessionBridge.mm
//

#import "YukimoSessionBridge.h"
#import "AppDataController.h"

@implementation YukimoSessionBridge

+ (instancetype)shared {
    static YukimoSessionBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoSessionBridge new]; });
    return instance;
}

- (BOOL)hasActiveSession {
    NSString *token = [[AppDataController sharedInstance] getToken];
    return token != nil && token.length > 0;
}

- (int64_t)currentProfileID {
    if (![self hasActiveSession]) return 0;
    auto pid = [[AppDataController sharedInstance] getMyProfileID];
    // anixart::ProfileID is a StrongTypedef over int64_t.
    return static_cast<int64_t>(pid);
}

@end
