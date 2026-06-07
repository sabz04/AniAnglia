//
//  YukimoSettingsBridge.h
//  Minimal settings surface for Swift. We only need theme + notifications
//  for Phase 3 (Auth). Will expand in later phases.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, YukimoTheme) {
    YukimoThemeLight = 0,
    YukimoThemeDark = 1,
    YukimoThemeSystem = 2,
};

/// Name of NSNotification posted whenever any setting changes.
/// `userInfo[YukimoSettingsBridge.notificationKeyName]` carries the setting key.
extern NSString * const YukimoSettingsChangedNotification;
extern NSString * const YukimoSettingsKeyTheme;

NS_SWIFT_NAME(SettingsBridge)
@interface YukimoSettingsBridge : NSObject

+ (instancetype)shared NS_SWIFT_NAME(shared());

@property (nonatomic) YukimoTheme theme;

/// Default playback height: 0 = Auto, otherwise 240/360/480/720/1080.
/// Persisted to the legacy `AppSettingsDataController` under
/// `preffered_quality` so the legacy UIKit settings see the same value.
@property (nonatomic) NSInteger defaultQualityHeight;

/// Auto-advance to the next episode when the current one ends.
@property (nonatomic) BOOL autoNextEpisode;

/// When opening the player, prefer the source the user picked last
/// time on this release instead of the highest-episode-count source.
@property (nonatomic) BOOL rememberSource;

@end

NS_ASSUME_NONNULL_END
