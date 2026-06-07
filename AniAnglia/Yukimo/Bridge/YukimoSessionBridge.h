//
//  YukimoSessionBridge.h
//  Pure Obj-C facade for reading session state from Swift.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(SessionBridge)
@interface YukimoSessionBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

/// YES if a non-empty token is stored in AppDataController.
@property (nonatomic, readonly) BOOL hasActiveSession;

/// Current profile ID as Int64 (anixart::ProfileID is a strong typedef over int64_t).
/// Returns 0 when there is no session.
@property (nonatomic, readonly) int64_t currentProfileID;

@end

NS_ASSUME_NONNULL_END
