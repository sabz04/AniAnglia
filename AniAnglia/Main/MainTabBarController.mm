//
//  MainTabBarController.mm
//
//  Hosts the four primary navigation tabs.
//
//  Visuals lean on the native UITabBarAppearance / UINavigationBarAppearance
//  configured with default-background so iOS renders its own blur material —
//  there are no custom backgroundColor / tintColor overrides on the bars
//  themselves. Only the brand accent (`systemIndigo`) is applied via tintColor.
//

#import "MainTabBarController.h"
#import "MainViewController.h"
#import "DiscoverViewController.h"
#import "ProfileListsPageViewController.h"
#import "ProfileViewController.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "SearchViewController.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "AppDataController.h"
#import "FilterViewController.h"
#import "SettingsViewController.h"
#import "ReleasesViewController.h"
#import "ProfilesTableViewController.h"

#pragma mark - Embedded search controllers (business logic only — unchanged)

@interface ReleasesSearchController : UIViewController <SearchViewControllerDataSource, SearchViewControllerDelegate, ReleasesSearchHistoryTableViewControllerDelegate>
@property(nonatomic, strong) AppDataController* app_data_controller;
@property(nonatomic, strong) LibanixartApi*     api_proxy;
@property(nonatomic, retain) SearchViewController* search_view_controller;
@property(nonatomic, retain) ReleasesViewController* view_controller;
-(instancetype)initWithQuery:(NSString*)query;
-(void)setQuery:(NSString*)query;
@end

@interface ProfilesSearchController : NSObject <SearchViewControllerDataSource, SearchViewControllerDelegate>
@property(nonatomic, strong) AppDataController* app_data_controller;
@property(nonatomic, strong) LibanixartApi*     api_proxy;
@property(nonatomic, retain) SearchViewController* search_view_controller;
@property(nonatomic, retain) ProfilesTableViewController* view_controller;
-(instancetype)initWithQuery:(NSString*)query;
-(void)setQuery:(NSString*)query;
@end

@interface MainTabBarController ()
@property(nonatomic, strong) LibanixartApi*     api_proxy;
@property(nonatomic, strong) AppDataController* app_data_controller;
@property(nonatomic, retain) SearchViewController* main_search_view_controller;
@property(nonatomic, retain) SearchViewController* discover_search_view_controller;
@property(nonatomic, retain) SearchViewController* bookmarks_search_view_controller;
@property(nonatomic, retain) SearchViewController* profile_search_view_controller;
@property(nonatomic, retain) UIBarButtonItem* main_filter_bar_button;
@property(nonatomic, retain) UIBarButtonItem* discover_filter_bar_button;
@property(nonatomic, weak)   UINavigationController* current_history_responder_nav_controller;
@property(nonatomic, weak)   SearchViewController*   current_history_responder_search_view_controller;
@property(nonatomic, retain) ReleasesSearchController* main_releases_search_controller;
@property(nonatomic, retain) ReleasesSearchController* discover_releases_search_controller;
@property(nonatomic, retain) ProfilesSearchController* profiles_search_controller;
@property(nonatomic, retain) UIView* tab_bar_glass_background;
@end


#pragma mark - ReleasesSearchController

@implementation ReleasesSearchController

-(instancetype)initWithQuery:(NSString*)query {
    self = [super init];
    _app_data_controller = [AppDataController sharedInstance];
    _api_proxy           = [LibanixartApi sharedInstance];
    [self setQuery:query];
    return self;
}

-(void)setQuery:(NSString*)query {
    anixart::requests::SearchRequest request;
    request.query = TO_STDSTRING(query);
    auto pages = _api_proxy.api->search().release_search(request, 0);

    _view_controller = [[ReleasesViewController alloc] initWithPages:std::move(pages)];

    _search_view_controller = [[SearchViewController alloc] initWithContentViewController:_view_controller];
    _search_view_controller.search_bar_placeholder = @"Поиск релизов";
    [_search_view_controller setSearchText:query];
    _search_view_controller.data_source = self;
    _search_view_controller.delegate    = self;
}

-(UIViewController*)inlineViewControllerForSearchViewController:(SearchViewController*)svc {
    ReleasesSearchHistoryTableViewController* vc = [ReleasesSearchHistoryTableViewController new];
    vc.delegate = self;
    return vc;
}

-(void)searchViewController:(SearchViewController*)svc didSearchWithQuery:(NSString*)query {
    [_app_data_controller addSearchHistoryItem:query];
    anixart::requests::SearchRequest request;
    request.query = TO_STDSTRING(query);
    [_view_controller setPages:_api_proxy.api->search().release_search(request, 0)];
}

-(void)releasesSearchHistoryTableViewController:(ReleasesHistoryTableViewController*)vc didSelectHistoryItem:(NSString*)item_name {
    [_search_view_controller setSearchText:item_name];
    [_search_view_controller endSearching];
    anixart::requests::SearchRequest request;
    request.query = TO_STDSTRING(item_name);
    [_view_controller setPages:_api_proxy.api->search().release_search(request, 0)];
}

@end


#pragma mark - ProfilesSearchController

@implementation ProfilesSearchController

-(instancetype)initWithQuery:(NSString*)query {
    self = [super init];
    _app_data_controller = [AppDataController sharedInstance];
    _api_proxy           = [LibanixartApi sharedInstance];
    [self setQuery:query];
    return self;
}

-(void)setQuery:(NSString*)query {
    anixart::requests::SearchRequest request;
    request.query = TO_STDSTRING(query);
    auto pages = _api_proxy.api->search().profile_search(request, 0);

    _view_controller = [[ProfilesTableViewController alloc] initWithTableView:[UITableView new] pages:std::move(pages)];

    _search_view_controller = [[SearchViewController alloc] initWithContentViewController:_view_controller];
    _search_view_controller.search_bar_placeholder = @"Поиск профилей";
    [_search_view_controller setSearchText:query];
    _search_view_controller.data_source = self;
    _search_view_controller.delegate    = self;
}

-(UIViewController*)inlineViewControllerForSearchViewController:(SearchViewController*)svc { return nil; }

-(void)searchViewController:(SearchViewController*)svc didSearchWithQuery:(NSString*)query {
    anixart::requests::SearchRequest request;
    request.query = TO_STDSTRING(query);
    [_view_controller setPages:_api_proxy.api->search().profile_search(request, 0)];
}

@end


#pragma mark - MainTabBarController

@implementation MainTabBarController

-(instancetype)init {
    self = [super init];
    _api_proxy           = [LibanixartApi sharedInstance];
    _app_data_controller = [AppDataController sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    [self setupBarButtons];
    [self setupTabs];
    [self applyAppearance];
}

-(void)setupBarButtons {
    UIImage* filter = [UIImage systemImageNamed:@"slider.horizontal.3"];
    _main_filter_bar_button = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"" image:filter identifier:nil handler:^(UIAction* _) {
        [self onMainFilterBarButtonPressed];
    }]];
    _discover_filter_bar_button = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"" image:filter identifier:nil handler:^(UIAction* _) {
        [self onDiscoverFilterBarButtonPressed];
    }]];
}

-(void)setupTabs {
    _main_search_view_controller = [[SearchViewController alloc] initWithContentViewController:[MainViewController new]];
    _main_search_view_controller.data_source = self;
    _main_search_view_controller.delegate    = self;
    _main_search_view_controller.search_bar_placeholder = @"Поиск релизов";
    _main_search_view_controller.right_bar_button = _main_filter_bar_button;
    _main_search_view_controller.title = @"Главная";

    _discover_search_view_controller = [[SearchViewController alloc] initWithContentViewController:[DiscoverViewController new]];
    _discover_search_view_controller.data_source = self;
    _discover_search_view_controller.delegate    = self;
    _discover_search_view_controller.search_bar_placeholder = @"Поиск релизов";
    _discover_search_view_controller.right_bar_button = _discover_filter_bar_button;
    _discover_search_view_controller.title = @"Обзор";

    _bookmarks_search_view_controller = [[SearchViewController alloc] initWithContentViewController:[[ProfileListsPageViewController alloc] initWithMyProfileID]];
    _bookmarks_search_view_controller.data_source = self;
    _bookmarks_search_view_controller.delegate    = self;
    _bookmarks_search_view_controller.search_bar_placeholder = @"Поиск в закладках";
    _bookmarks_search_view_controller.title = @"Закладки";

    _profile_search_view_controller = [[SearchViewController alloc] initWithContentViewController:[[ProfileViewController alloc] initWithMyProfile]];
    _profile_search_view_controller.data_source = self;
    _profile_search_view_controller.delegate    = self;
    _profile_search_view_controller.search_bar_placeholder = @"Поиск профилей";
    _profile_search_view_controller.title = @"Профиль";
    _profile_search_view_controller.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(onSettingsBarButtonPressed:)];

    _main_nav_controller      = [[UINavigationController alloc] initWithRootViewController:_main_search_view_controller];
    _discover_nav_controller  = [[UINavigationController alloc] initWithRootViewController:_discover_search_view_controller];
    _bookmarks_nav_controller = [[UINavigationController alloc] initWithRootViewController:_bookmarks_search_view_controller];
    _profile_nav_controller   = [[UINavigationController alloc] initWithRootViewController:_profile_search_view_controller];

    // Large titles on top-level tabs — Apple HIG. Large title sits above the
    // standard title strip (which hosts the search bar) and collapses on scroll.
    for (UINavigationController* nav in @[_main_nav_controller, _discover_nav_controller, _bookmarks_nav_controller, _profile_nav_controller]) {
        nav.navigationBar.prefersLargeTitles = YES;
        nav.topViewController.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    }

    _main_nav_controller.tabBarItem.title              = @"Главная";
    _main_nav_controller.tabBarItem.image              = [UIImage systemImageNamed:@"house"];
    _main_nav_controller.tabBarItem.selectedImage      = [UIImage systemImageNamed:@"house.fill"];
    _discover_nav_controller.tabBarItem.title          = @"Обзор";
    _discover_nav_controller.tabBarItem.image          = [UIImage systemImageNamed:@"safari"];
    _discover_nav_controller.tabBarItem.selectedImage  = [UIImage systemImageNamed:@"safari.fill"];
    _bookmarks_nav_controller.tabBarItem.title         = @"Закладки";
    _bookmarks_nav_controller.tabBarItem.image         = [UIImage systemImageNamed:@"bookmark"];
    _bookmarks_nav_controller.tabBarItem.selectedImage = [UIImage systemImageNamed:@"bookmark.fill"];
    _profile_nav_controller.tabBarItem.title           = @"Профиль";
    _profile_nav_controller.tabBarItem.image           = [UIImage systemImageNamed:@"person"];
    _profile_nav_controller.tabBarItem.selectedImage   = [UIImage systemImageNamed:@"person.fill"];

    [self setViewControllers:@[
        _main_nav_controller,
        _discover_nav_controller,
        _bookmarks_nav_controller,
        _profile_nav_controller
    ]];
}

// Floating glass tab bar (iOS 26 Liquid Glass with fallback to UIBlurEffect on
// older systems). The stock UITabBar is set fully transparent and we slip a
// rounded glass surface in behind it so the items appear to float over a
// translucent capsule that hugs the content above.
//
// Navigation bars get a matching glass background so the chrome reads as one
// continuous material.
-(void)applyAppearance {
    // Tab bar: transparent stock chrome, floating glass behind it.
    UITabBarAppearance* tab_appearance = [UITabBarAppearance new];
    [tab_appearance configureWithTransparentBackground];
    tab_appearance.backgroundColor = UIColor.clearColor;
    tab_appearance.shadowColor     = UIColor.clearColor;

    // Coral selected / muted unselected — applied to every layout variant.
    UIColor* selectedColor   = [AppColorProvider primaryColor];
    UIColor* unselectedColor = [AppColorProvider textSecondaryColor];
    NSDictionary* selectedAttrs   = @{ NSForegroundColorAttributeName: selectedColor };
    NSDictionary* unselectedAttrs = @{ NSForegroundColorAttributeName: unselectedColor };
    for (UITabBarItemAppearance* a in @[tab_appearance.stackedLayoutAppearance,
                                        tab_appearance.inlineLayoutAppearance,
                                        tab_appearance.compactInlineLayoutAppearance]) {
        a.selected.iconColor   = selectedColor;
        a.selected.titleTextAttributes = selectedAttrs;
        a.normal.iconColor     = unselectedColor;
        a.normal.titleTextAttributes   = unselectedAttrs;
    }
    self.tabBar.standardAppearance = tab_appearance;
    if (@available(iOS 15.0, *)) {
        self.tabBar.scrollEdgeAppearance = tab_appearance;
    }
    self.tabBar.tintColor = selectedColor;

    [self installFloatingGlassBackground];

    // Navigation bars: native material background, coral accent.
    UINavigationBarAppearance* nav_appearance = [UINavigationBarAppearance new];
    [nav_appearance configureWithDefaultBackground];
    for (UINavigationController* nav in @[_main_nav_controller, _discover_nav_controller, _bookmarks_nav_controller, _profile_nav_controller]) {
        nav.navigationBar.standardAppearance   = nav_appearance;
        nav.navigationBar.scrollEdgeAppearance = nav_appearance;
        nav.navigationBar.compactAppearance    = nav_appearance;
        nav.navigationBar.tintColor = selectedColor;
    }
}

// Floating glass capsule that lives inside the UITabBar, behind the buttons.
// Pinned with inset margins so it visually "floats" above content. Updates its
// shape on layout because the tab bar height differs by device class.
-(void)installFloatingGlassBackground {
    if (_tab_bar_glass_background) return;

    // Slide the glass into the tab bar's view hierarchy at the very bottom so
    // tab bar items render on top. Constraints insetting from the bar bounds
    // give the floating look.
    UIView* glass = [AppMaterial glassBackgroundForStyle:AppMaterialStyleNav
                                                   shape:AppMaterialShapeCapsule];
    glass.translatesAutoresizingMaskIntoConstraints = NO;
    glass.userInteractionEnabled = NO;
    [self.tabBar insertSubview:glass atIndex:0];
    _tab_bar_glass_background = glass;

    // Side margins (16) match the screen content rhythm; bottom margin (6)
    // keeps the capsule above the home indicator. Top hugs the tab bar.
    [NSLayoutConstraint activateConstraints:@[
        [glass.leadingAnchor  constraintEqualToAnchor:self.tabBar.leadingAnchor  constant:AppSpacing12],
        [glass.trailingAnchor constraintEqualToAnchor:self.tabBar.trailingAnchor constant:-AppSpacing12],
        [glass.topAnchor      constraintEqualToAnchor:self.tabBar.topAnchor      constant:AppSpacing4],
        [glass.bottomAnchor   constraintEqualToAnchor:self.tabBar.safeAreaLayoutGuide.bottomAnchor constant:-AppSpacing4],
    ]];

    [AppMaterial applyFloatingShadowTo:glass
                            withRadius:AppRadiusXLarge
                            pathBounds:glass.bounds];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_tab_bar_glass_background) {
        // Re-cast shadow path on layout — bounds change with orientation.
        [AppMaterial applyFloatingShadowTo:_tab_bar_glass_background
                                withRadius:_tab_bar_glass_background.layer.cornerRadius
                                pathBounds:_tab_bar_glass_background.bounds];
    }
}

#pragma mark - SearchViewControllerDataSource / Delegate

-(UIViewController*)inlineViewControllerForSearchViewController:(SearchViewController*)svc {
    if (svc == _main_search_view_controller || svc == _discover_search_view_controller) {
        _current_history_responder_nav_controller        = (svc == _main_search_view_controller) ? _main_nav_controller : _discover_nav_controller;
        _current_history_responder_search_view_controller = svc;
        ReleasesSearchHistoryTableViewController* vc = [ReleasesSearchHistoryTableViewController new];
        vc.delegate = self;
        return vc;
    }
    return nil;
}

-(void)searchViewController:(SearchViewController*)svc didSearchWithQuery:(NSString*)query {
    [svc setSearchText:@""];
    if (svc == _main_search_view_controller) {
        [_app_data_controller addSearchHistoryItem:query];
        if (!_main_releases_search_controller) _main_releases_search_controller = [[ReleasesSearchController alloc] initWithQuery:query];
        else                                   [_main_releases_search_controller setQuery:query];
        [self prepareSearchResultsVC:_main_releases_search_controller.search_view_controller withQuery:query forMain:YES];
        [svc.navigationController pushViewController:_main_releases_search_controller.search_view_controller animated:YES];
        return;
    }
    if (svc == _discover_search_view_controller) {
        [_app_data_controller addSearchHistoryItem:query];
        if (!_discover_releases_search_controller) _discover_releases_search_controller = [[ReleasesSearchController alloc] initWithQuery:query];
        else                                       [_discover_releases_search_controller setQuery:query];
        [self prepareSearchResultsVC:_discover_releases_search_controller.search_view_controller withQuery:query forMain:NO];
        [svc.navigationController pushViewController:_discover_releases_search_controller.search_view_controller animated:YES];
        return;
    }
    if (svc == _profile_search_view_controller) {
        if (!_profiles_search_controller) _profiles_search_controller = [[ProfilesSearchController alloc] initWithQuery:query];
        else                              [_profiles_search_controller setQuery:query];
        [svc.navigationController pushViewController:_profiles_search_controller.search_view_controller animated:YES];
        return;
    }
}

-(void)releasesSearchHistoryTableViewController:(ReleasesSearchHistoryTableViewController*)vc didSelectHistoryItem:(NSString*)item_name {
    [_current_history_responder_search_view_controller setSearchText:@""];
    [_current_history_responder_search_view_controller endSearching];

    if (_current_history_responder_search_view_controller == _main_search_view_controller) {
        if (!_main_releases_search_controller) _main_releases_search_controller = [[ReleasesSearchController alloc] initWithQuery:item_name];
        else                                   [_main_releases_search_controller setQuery:item_name];
        [self prepareSearchResultsVC:_main_releases_search_controller.search_view_controller withQuery:item_name forMain:YES];
        [_current_history_responder_search_view_controller.navigationController pushViewController:_main_releases_search_controller.search_view_controller animated:YES];
        return;
    }
    if (_current_history_responder_search_view_controller == _discover_search_view_controller) {
        if (!_discover_releases_search_controller) _discover_releases_search_controller = [[ReleasesSearchController alloc] initWithQuery:item_name];
        else                                       [_discover_releases_search_controller setQuery:item_name];
        [self prepareSearchResultsVC:_discover_releases_search_controller.search_view_controller withQuery:item_name forMain:NO];
        [_current_history_responder_search_view_controller.navigationController pushViewController:_discover_releases_search_controller.search_view_controller animated:YES];
        return;
    }
}

// Fresh nav-bar state for a search-results screen: collapse the large title,
// add a filter button on the trailing edge, set the title to the query so it
// becomes the back-button label on deeper VCs.
-(void)prepareSearchResultsVC:(SearchViewController*)resultsVC withQuery:(NSString*)query forMain:(BOOL)forMain {
    resultsVC.title = query;
    resultsVC.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    if (!resultsVC.right_bar_button) {
        UIImage* filter = [UIImage systemImageNamed:@"slider.horizontal.3"];
        resultsVC.right_bar_button = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"" image:filter identifier:nil handler:^(UIAction* _) {
            if (forMain) [self onMainFilterBarButtonPressed];
            else         [self onDiscoverFilterBarButtonPressed];
        }]];
    }
}

-(void)onMainFilterBarButtonPressed {
    [_main_search_view_controller endSearching];
    [_main_nav_controller pushViewController:[FilterViewController new] animated:YES];
}

-(void)onDiscoverFilterBarButtonPressed {
    [_discover_search_view_controller endSearching];
    [_discover_nav_controller pushViewController:[FilterViewController new] animated:YES];
}

-(IBAction)onSettingsBarButtonPressed:(id)sender {
    UINavigationController* nav = (UINavigationController*)self.selectedViewController;
    [nav pushViewController:[SettingsViewController new] animated:YES];
}

@end
