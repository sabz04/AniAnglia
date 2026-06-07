//
//  YukimoSettingsBridge.mm
//

#import "YukimoSettingsBridge.h"
#import "AppDataController.h"

NSString * const YukimoSettingsChangedNotification = @"YukimoSettingsChangedNotification";
NSString * const YukimoSettingsKeyTheme = @"theme";

@implementation YukimoSettingsBridge {
    id _observer;
}

+ (instancetype)shared {
    static YukimoSettingsBridge *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [YukimoSettingsBridge new]; });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        // Forward AppSettingsDataController changes to a Swift-stable notification name.
        __weak __typeof__(self) weakSelf = self;
        _observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:app_settings::notification_name
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * _Nonnull note) {
                NSString *key = note.userInfo[app_settings::notification_info_key];
                NSMutableDictionary *info = [NSMutableDictionary new];
                if (key) info[@"key"] = key;
                [[NSNotificationCenter defaultCenter]
                    postNotificationName:YukimoSettingsChangedNotification
                                  object:weakSelf
                                userInfo:info];
            }];
    }
    return self;
}

- (void)dealloc {
    if (_observer) [[NSNotificationCenter defaultCenter] removeObserver:_observer];
}

- (YukimoTheme)theme {
    auto t = [[[AppDataController sharedInstance] getSettingsController] getTheme];
    switch (t) {
        case app_settings::Appearance::Theme::Light:  return YukimoThemeLight;
        case app_settings::Appearance::Theme::Dark:   return YukimoThemeDark;
        case app_settings::Appearance::Theme::System: return YukimoThemeSystem;
    }
    return YukimoThemeSystem;
}

- (void)setTheme:(YukimoTheme)theme {
    app_settings::Appearance::Theme t;
    switch (theme) {
        case YukimoThemeLight:  t = app_settings::Appearance::Theme::Light;  break;
        case YukimoThemeDark:   t = app_settings::Appearance::Theme::Dark;   break;
        case YukimoThemeSystem: t = app_settings::Appearance::Theme::System; break;
    }
    [[[AppDataController sharedInstance] getSettingsController] setTheme:t];
}

#pragma mark - Playback

- (NSInteger)defaultQualityHeight {
    NSString *raw = [[[AppDataController sharedInstance] getSettingsController] getPrefferedQuality];
    if (raw.length == 0) return 720;
    if ([raw caseInsensitiveCompare:@"auto"] == NSOrderedSame) return 0;
    NSInteger value = [raw integerValue];
    return value > 0 ? value : 720;
}

- (void)setDefaultQualityHeight:(NSInteger)height {
    NSString *raw = height == 0 ? @"Auto" : [@(height) stringValue];
    [[[AppDataController sharedInstance] getSettingsController] setPrefferedQuality:raw];
}

- (BOOL)autoNextEpisode {
    return [[[AppDataController sharedInstance] getSettingsController] getAutoNextVideo];
}

- (void)setAutoNextEpisode:(BOOL)value {
    [[[AppDataController sharedInstance] getSettingsController] setAutoNextVideo:value];
}

- (BOOL)rememberSource {
    return [[[AppDataController sharedInstance] getSettingsController] setRememberSource];
}

- (void)setRememberSource:(BOOL)value {
    [[[AppDataController sharedInstance] getSettingsController] setRememberSource:value];
}

@end
