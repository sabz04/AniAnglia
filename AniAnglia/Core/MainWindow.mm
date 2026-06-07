//
//  MainWindow.m
//  AniAnglia
//
//  Created by Toilettrauma on 05.04.2025.
//

#import <Foundation/Foundation.h>
#import "MainWindow.h"
#import "AppDataController.h"
#import "AuthViewController.h"
#import "MainTabBarController.h"
// Yukimo SwiftUI redesign — exposes +[YukimoHostFactory makeRootViewController].
// The generated Swift interface header lives next to derived sources and is on
// the header search path automatically when SWIFT_INSTALL_OBJC_HEADER=YES.
#import "AniAnglia-Swift.h"

@interface MainWindow ()
@end

@implementation MainWindow

-(instancetype)initWithWindowScene:(UIWindowScene*)scene {
    self = [super initWithWindowScene:scene];
    
    [self setRootViewController:[self getFirstRootViewController]];
    
    AppSettingsDataController* settings_controller = [[AppDataController sharedInstance] getSettingsController];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSettingsValueChanged:) name:(app_settings::notification_name) object:nil];
    [self setAppTheme:[settings_controller getTheme]];
    
    return self;
}
-(UIViewController*)getFirstRootViewController {
    // Yukimo redesign: a SwiftUI root that internally decides between
    // splash → onboarding/auth → main shell based on session state.
    // Legacy AuthViewController / MainTabBarController are no longer
    // entry points; they remain on disk to keep the build green during
    // the staged migration.
    return [YukimoHostFactory makeRootViewController];
}

-(void)setRootViewController:(UIViewController*)root_view_controller {
    root_view_controller.modalPresentationStyle = UIModalPresentationFullScreen;
    [super setRootViewController:root_view_controller];
}

-(void)onSettingsValueChanged:(NSNotification*)notification {
    NSString* name = notification.userInfo[app_settings::notification_info_key];
    if (![name isEqualToString:(app_settings::Appearance::theme)]) {
        return;
    }
    
    NSNumber* value = notification.userInfo[app_settings::notification_info_value];
    app_settings::Appearance::Theme theme = static_cast<app_settings::Appearance::Theme>([value integerValue]);
    [self setAppTheme:theme];
}
-(void)setAppTheme:(app_settings::Appearance::Theme)theme {
    switch (theme) {
        case app_settings::Appearance::Theme::System:
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
            break;
        case app_settings::Appearance::Theme::Light:
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
            break;
        case app_settings::Appearance::Theme::Dark:
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
            break;
    }
}

@end
