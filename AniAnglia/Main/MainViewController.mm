//
//  MainViewController.mm
//
//  Home tab — yukimo redesign.
//
//  Vertical scroll. From top to bottom:
//    1. Hero card — large poster backdrop + glass CTA panel for the top-ranked
//       title returned by the popular filter.
//    2. Quick-action pill bar — Популярное / Расписание / Коллекции / Фильтр /
//       Случайное. Glass capsules that float over the content.
//    3. Editorial rails — horizontal carousels (Топ / Онгоинги / Анонсы /
//       Фильмы / OVA) reused from `ReleasesCollectionViewController`.
//

#import "MainViewController.h"
#import "AppBackdrop.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppHaptics.h"
#import "LibanixartApi.h"
#import "LoadableView.h"
#import "ReleaseViewController.h"
#import "ReleasesViewController.h"
#import "ReleasesCollectionViewController.h"
#import "CollectionsCollectionViewController.h"
#import "FilterViewController.h"
#import "RatingBadge.h"
#import "StringCvt.h"


#pragma mark - Filter-pages factory

namespace {

using FilterFactory = std::function<anixart::FilterPages::UPtr(void)>;

FilterFactory makeFactory(anixart::Api* api,
                          std::optional<anixart::Release::Status> status,
                          std::optional<anixart::Release::Category> category,
                          std::optional<anixart::requests::FilterRequest::Sort> sort) {
    return [api, status, category, sort]() {
        anixart::requests::FilterRequest request;
        request.status = status;
        request.category = category;
        if (sort) request.sort = *sort;
        return api->search().filter_search(request, false, 0);
    };
}

}


#pragma mark - HeroCard

@interface HeroCard : UIControl
@property(nonatomic, copy, nullable) void (^onWatchTapped)(void);
-(void)configureWithRelease:(anixart::Release::Ptr)release;
@end

@implementation HeroCard {
    LoadableImageView* _backdrop;
    UIView*            _scrim;
    CAGradientLayer*   _scrimLayer;
    UIView*            _glassPanel;
    UILabel*           _titleLabel;
    UILabel*           _metaLabel;
    RatingBadge*       _ratingBadge;
    UIButton*          _watchButton;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.layer.cornerRadius  = AppRadiusXXLarge;
    self.layer.cornerCurve   = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
    self.backgroundColor = [AppColorProvider posterPlaceholderColor];

    _backdrop = [LoadableImageView new];
    _backdrop.contentMode = UIViewContentModeScaleAspectFill;
    _backdrop.clipsToBounds = YES;
    _backdrop.translatesAutoresizingMaskIntoConstraints = NO;
    _backdrop.isAccessibilityElement = NO;
    [self addSubview:_backdrop];

    _scrim = [UIView new];
    _scrim.translatesAutoresizingMaskIntoConstraints = NO;
    _scrim.userInteractionEnabled = NO;
    [self addSubview:_scrim];

    _scrimLayer = [CAGradientLayer layer];
    _scrimLayer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.85].CGColor,
    ];
    _scrimLayer.locations = @[@0.0, @0.55, @1.0];
    [_scrim.layer addSublayer:_scrimLayer];

    _glassPanel = [AppMaterial glassBackgroundForStyle:AppMaterialStyleSheet shape:AppMaterialShapeCard];
    _glassPanel.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_glassPanel];

    // Add label content into the glass surface's contentView so it inherits
    // vibrancy on iOS 26 Liquid Glass and never gets clipped by the corner mask.
    UIView* panelContent = [_glassPanel respondsToSelector:@selector(contentView)]
        ? [_glassPanel performSelector:@selector(contentView)]
        : _glassPanel;

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightBold];
    _titleLabel.textColor = [AppColorProvider textOnGlassColor];
    _titleLabel.numberOfLines = 2;
    _titleLabel.adjustsFontForContentSizeCategory = YES;

    _metaLabel = [UILabel new];
    _metaLabel.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _metaLabel.textColor = [AppColorProvider textOnGlassColor];
    _metaLabel.alpha = 0.85;
    _metaLabel.adjustsFontForContentSizeCategory = YES;

    _ratingBadge = [RatingBadge new];
    _ratingBadge.translatesAutoresizingMaskIntoConstraints = NO;

    _watchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_watchButton setTitle:NSLocalizedString(@"app.release.play_button.title", nil) forState:UIControlStateNormal];
    [_watchButton setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    _watchButton.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    _watchButton.tintColor = [AppColorProvider textOnPrimaryColor];
    _watchButton.backgroundColor = [AppColorProvider primaryColor];
    _watchButton.layer.cornerRadius = AppRadiusPill;
    _watchButton.layer.cornerCurve  = kCACornerCurveContinuous;
    _watchButton.contentEdgeInsets  = UIEdgeInsetsMake(AppSpacing8, AppSpacing16, AppSpacing8, AppSpacing16);
    _watchButton.imageEdgeInsets    = UIEdgeInsetsMake(0, 0, 0, AppSpacing4);
    _watchButton.titleEdgeInsets    = UIEdgeInsetsMake(0, AppSpacing4, 0, 0);
    [_watchButton addTarget:self action:@selector(onWatchPressed) forControlEvents:UIControlEventTouchUpInside];

    UIStackView* leftStack = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _metaLabel]];
    leftStack.axis = UILayoutConstraintAxisVertical;
    leftStack.spacing = AppSpacing4;
    leftStack.translatesAutoresizingMaskIntoConstraints = NO;
    [panelContent addSubview:leftStack];
    [panelContent addSubview:_watchButton];
    _watchButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:_ratingBadge];

    [NSLayoutConstraint activateConstraints:@[
        [_backdrop.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_backdrop.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_backdrop.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_backdrop.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [_scrim.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_scrim.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_scrim.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        [_scrim.heightAnchor   constraintEqualToAnchor:self.heightAnchor multiplier:0.7],

        [_ratingBadge.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing12],
        [_ratingBadge.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],

        [_glassPanel.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing12],
        [_glassPanel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],
        [_glassPanel.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing12],

        [leftStack.leadingAnchor constraintEqualToAnchor:panelContent.leadingAnchor constant:AppSpacing16],
        [leftStack.topAnchor     constraintEqualToAnchor:panelContent.topAnchor     constant:AppSpacing12],
        [leftStack.bottomAnchor  constraintEqualToAnchor:panelContent.bottomAnchor  constant:-AppSpacing12],

        [_watchButton.leadingAnchor  constraintEqualToAnchor:leftStack.trailingAnchor    constant:AppSpacing12],
        [_watchButton.trailingAnchor constraintEqualToAnchor:panelContent.trailingAnchor constant:-AppSpacing12],
        [_watchButton.centerYAnchor  constraintEqualToAnchor:panelContent.centerYAnchor],
        [_watchButton.heightAnchor   constraintGreaterThanOrEqualToConstant:44],
    ]];

    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    _scrimLayer.frame = _scrim.bounds;
}

-(void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:AppDurationFast
                          delay:0
         usingSpringWithDamping:AppSpringDampingTaut
          initialSpringVelocity:0
                        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.985, 0.985) : CGAffineTransformIdentity;
    } completion:nil];
}

-(void)configureWithRelease:(anixart::Release::Ptr)release {
    if (!release) return;
    NSString* title = [NSString stringWithUTF8String:release->title_ru.c_str()];
    if (title.length == 0) title = [NSString stringWithUTF8String:release->title_original.c_str()];
    _titleLabel.text = title;

    NSString* category = @"";
    switch (release->category) {
        case anixart::Release::Category::Series: category = NSLocalizedString(@"app.release.category.series", nil); break;
        case anixart::Release::Category::Movies: category = NSLocalizedString(@"app.release.category.movies", nil); break;
        case anixart::Release::Category::Ova:    category = NSLocalizedString(@"app.release.category.ova",    nil); break;
        default: break;
    }
    NSString* year = release->year.length() > 0
        ? [NSString stringWithUTF8String:release->year.c_str()]
        : @"";
    NSMutableArray* parts = [NSMutableArray new];
    if (category.length) [parts addObject:category];
    if (year.length)     [parts addObject:year];
    _metaLabel.text = [parts componentsJoinedByString:@" • "];

    [_ratingBadge setRating:(float)release->grade];

    NSURL* posterUrl = [NSURL URLWithString:[NSString stringWithUTF8String:release->image_url.c_str()]];
    [_backdrop tryLoadImageWithURL:posterUrl];

    self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title, _metaLabel.text];
}

-(void)onWatchPressed {
    [AppHaptics impactMedium];
    if (_onWatchTapped) _onWatchTapped();
}

@end


#pragma mark - QuickActionPill

@interface QuickActionPill : UIControl
@property(nonatomic, copy) NSString* title;
@property(nonatomic, strong) UIImage* icon;
@property(nonatomic, copy, nullable) void (^onTap)(void);
@end

@implementation QuickActionPill {
    UIImageView* _iconView;
    UILabel*     _label;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    [AppMaterial applyGlassToView:self style:AppMaterialStylePill shape:AppMaterialShapeCapsule];

    _iconView = [UIImageView new];
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _iconView.tintColor = [AppColorProvider primaryColor];
    _iconView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];

    _label = [UILabel new];
    _label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _label.textColor = [AppColorProvider textColor];
    _label.adjustsFontForContentSizeCategory = YES;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[_iconView, _label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = AppSpacing6;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.userInteractionEnabled = NO;
    [self addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing12],
        [stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],
        [stack.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing8],
        [stack.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing8],
        [self.heightAnchor    constraintGreaterThanOrEqualToConstant:38],
    ]];
    [self addTarget:self action:@selector(onPressed) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

-(void)setTitle:(NSString*)t { _title = [t copy]; _label.text = t; self.accessibilityLabel = t; }
-(void)setIcon:(UIImage*)i   { _icon = i; _iconView.image = i; }

-(void)setHighlighted:(BOOL)h {
    [super setHighlighted:h];
    [UIView animateWithDuration:AppDurationFast animations:^{
        self.transform = h ? CGAffineTransformMakeScale(0.94, 0.94) : CGAffineTransformIdentity;
    }];
}

-(void)onPressed {
    [AppHaptics selection];
    if (_onTap) _onTap();
}

@end


#pragma mark - ReleaseRail

@interface ReleaseRail : UIView
@property(nonatomic, readonly) ReleasesCollectionViewController* carousel;
@property(nonatomic, readonly) UIButton* see_all_button;
-(instancetype)initWithTitle:(NSString*)title;
@end

@implementation ReleaseRail {
    UILabel*  _title_label;
    UIButton* _see_all_button;
    ReleasesCollectionViewController* _carousel;
}

-(instancetype)initWithTitle:(NSString*)title {
    self = [super init];
    if (!self) return nil;

    _title_label = [UILabel new];
    _title_label.text = title;
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightBold];
    _title_label.textColor = [AppColorProvider textColor];
    _title_label.adjustsFontForContentSizeCategory = YES;

    _see_all_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_see_all_button setTitle:@"Все" forState:UIControlStateNormal];
    [_see_all_button setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    _see_all_button.tintColor = [AppColorProvider primaryColor];
    _see_all_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    _see_all_button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _see_all_button.imageView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];

    _carousel = [[ReleasesCollectionViewController alloc] initWithAxis:UICollectionViewScrollDirectionHorizontal];

    [self addSubview:_title_label];
    [self addSubview:_see_all_button];
    [self addSubview:_carousel.view];

    _title_label.translatesAutoresizingMaskIntoConstraints = NO;
    _see_all_button.translatesAutoresizingMaskIntoConstraints = NO;
    _carousel.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_title_label.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_title_label.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:AppSpacing16],

        [_see_all_button.centerYAnchor constraintEqualToAnchor:_title_label.centerYAnchor],
        [_see_all_button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],
        [_see_all_button.leadingAnchor  constraintGreaterThanOrEqualToAnchor:_title_label.trailingAnchor constant:AppSpacing8],

        [_carousel.view.topAnchor      constraintEqualToAnchor:_title_label.bottomAnchor constant:AppSpacing8],
        [_carousel.view.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_carousel.view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_carousel.view.heightAnchor   constraintEqualToConstant:228],
        [_carousel.view.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor]
    ]];
    return self;
}

-(ReleasesCollectionViewController*)carousel { return _carousel; }
-(UIButton*)see_all_button { return _see_all_button; }

@end


#pragma mark - MainViewController

@interface MainViewController ()
@property(nonatomic, retain) LibanixartApi* api_proxy;
@property(nonatomic, retain) UIScrollView*  scroll_view;
@property(nonatomic, retain) UIStackView*   rails_stack;
@property(nonatomic, retain) NSMutableArray<ReleaseRail*>* rails;
@property(nonatomic, retain) HeroCard*      hero_card;
@property(nonatomic, retain) UIScrollView*  pills_scroll_view;
@property(nonatomic, retain) ReleaseRail*   continue_rail;
@end

@implementation MainViewController {
    std::vector<FilterFactory> _factories;
    // C++ ivar — we hold the featured release shared_ptr for the lifetime of
    // the controller so the watch-button handler can read its id without
    // depending on Obj-C boxing tricks.
    anixart::Release::Ptr _featured_release;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [AppBackdrop installIn:self.view];
    self.title = NSLocalizedString(@"app.main_tab_bar.main_tab.title", nil);

    _api_proxy = [LibanixartApi sharedInstance];
    _rails = [NSMutableArray new];

    [self setupScroll];
    [self setupHero];
    [self setupQuickActions];
    [self setupRails];
    [self setupContinueWatching];
    [self loadHero];
    [self loadContinueWatching];
}

#pragma mark - Continue Watching

// "Continue Watching" rail — Crunchyroll convention. Placed *under* the "Top"
// rail so the user first sees what's hot, then their personal queue. Data
// source: user's "Watching" list. Hidden when empty (logged-out / no progress).
-(void)setupContinueWatching {
    _continue_rail = [[ReleaseRail alloc] initWithTitle:NSLocalizedString(@"app.profile.list_status.watching", nil)];
    [self addChildViewController:_continue_rail.carousel];

    // Insert just AFTER the first rail (which is "Top") — hero is at index 0,
    // pills at 1, Top rail at 2. So Continue goes at index 3.
    NSInteger insert_index = MIN((NSInteger)_rails_stack.arrangedSubviews.count, 3);
    [_rails_stack insertArrangedSubview:_continue_rail atIndex:insert_index];
    [_continue_rail.carousel didMoveToParentViewController:self];

    // Hide by default — show only if we get real data back.
    _continue_rail.hidden = YES;

    __weak ReleaseRail* wr = _continue_rail;
    _continue_rail.carousel.onDidLoadFirstPage = ^(NSInteger c) {
        wr.hidden = (c == 0);
    };

    // No "Все" target for Continue Watching — tap a card to resume.
    _continue_rail.see_all_button.hidden = YES;
}

-(void)loadContinueWatching {
    anixart::Api* api = _api_proxy.api;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        try {
            __block anixart::ProfileListPages::UPtr pages =
                api->releases().my_profile_list(anixart::Profile::ListStatus::Watching,
                                                anixart::Profile::ListSort::Ascending,
                                                0);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.continue_rail.carousel setReleasesPageableDataProvider:
                    [[ReleasesPageableDataProvider alloc] initWithPages:std::move(pages)]];
            });
        } catch (...) {
            // Auth missing / 401 / etc — rail stays hidden, no UI noise.
        }
    });
}

#pragma mark - Setup

-(void)setupScroll {
    _scroll_view = [UIScrollView new];
    _scroll_view.alwaysBounceVertical = YES;
    _scroll_view.showsVerticalScrollIndicator = YES;
    _scroll_view.contentInset = UIEdgeInsetsMake(AppSpacing8, 0, AppSpacing64, 0);

    _rails_stack = [UIStackView new];
    _rails_stack.axis = UILayoutConstraintAxisVertical;
    _rails_stack.spacing = AppSpacing24;
    _rails_stack.alignment = UIStackViewAlignmentFill;

    [self.view addSubview:_scroll_view];
    [_scroll_view addSubview:_rails_stack];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    _rails_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll_view.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_scroll_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [_rails_stack.topAnchor      constraintEqualToAnchor:_scroll_view.contentLayoutGuide.topAnchor],
        [_rails_stack.leadingAnchor  constraintEqualToAnchor:_scroll_view.contentLayoutGuide.leadingAnchor],
        [_rails_stack.trailingAnchor constraintEqualToAnchor:_scroll_view.contentLayoutGuide.trailingAnchor],
        [_rails_stack.bottomAnchor   constraintEqualToAnchor:_scroll_view.contentLayoutGuide.bottomAnchor],
        [_rails_stack.widthAnchor    constraintEqualToAnchor:_scroll_view.frameLayoutGuide.widthAnchor],
    ]];
}

-(void)setupHero {
    _hero_card = [HeroCard new];
    _hero_card.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* heroContainer = [UIView new];
    [heroContainer addSubview:_hero_card];
    [NSLayoutConstraint activateConstraints:@[
        [_hero_card.topAnchor      constraintEqualToAnchor:heroContainer.topAnchor],
        [_hero_card.leadingAnchor  constraintEqualToAnchor:heroContainer.leadingAnchor  constant:AppSpacing16],
        [_hero_card.trailingAnchor constraintEqualToAnchor:heroContainer.trailingAnchor constant:-AppSpacing16],
        [_hero_card.bottomAnchor   constraintEqualToAnchor:heroContainer.bottomAnchor],
        // 16:11 — generous, premium ratio, similar to Apple TV hero.
        [_hero_card.heightAnchor   constraintEqualToAnchor:_hero_card.widthAnchor multiplier:11.0/16.0],
    ]];

    __weak __typeof__(self) weakSelf = self;
    _hero_card.onWatchTapped = ^{ [weakSelf openHeroRelease]; };
    [_hero_card addTarget:self action:@selector(openHeroRelease) forControlEvents:UIControlEventTouchUpInside];

    [_rails_stack addArrangedSubview:heroContainer];
}

-(void)setupQuickActions {
    _pills_scroll_view = [UIScrollView new];
    _pills_scroll_view.showsHorizontalScrollIndicator = NO;
    _pills_scroll_view.contentInset = UIEdgeInsetsMake(0, AppSpacing16, 0, AppSpacing16);
    _pills_scroll_view.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView* pillStack = [UIStackView new];
    pillStack.axis = UILayoutConstraintAxisHorizontal;
    pillStack.spacing = AppSpacing8;
    pillStack.alignment = UIStackViewAlignmentCenter;
    pillStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_pills_scroll_view addSubview:pillStack];

    NSArray* defs = @[
        @[NSLocalizedString(@"app.discover.popular",     nil), @"flame.fill",             @0],
        @[NSLocalizedString(@"app.discover.schedule",    nil), @"calendar",               @1],
        @[NSLocalizedString(@"app.discover.collections", nil), @"square.stack.3d.up.fill",@2],
        @[NSLocalizedString(@"app.discover.filter",      nil), @"slider.horizontal.3",    @3],
        @[NSLocalizedString(@"app.discover.random",      nil), @"shuffle",                @4],
    ];
    for (NSArray* def in defs) {
        QuickActionPill* p = [QuickActionPill new];
        p.title = def[0];
        p.icon  = [UIImage systemImageNamed:def[1]];
        NSInteger idx = [def[2] integerValue];
        __weak __typeof__(self) weakSelf = self;
        p.onTap = ^{ [weakSelf onQuickActionAt:idx]; };
        [pillStack addArrangedSubview:p];
    }

    UIView* container = [UIView new];
    [container addSubview:_pills_scroll_view];
    [NSLayoutConstraint activateConstraints:@[
        [_pills_scroll_view.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [_pills_scroll_view.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [_pills_scroll_view.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_pills_scroll_view.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
        [_pills_scroll_view.heightAnchor   constraintEqualToConstant:44],

        [pillStack.topAnchor      constraintEqualToAnchor:_pills_scroll_view.topAnchor],
        [pillStack.leadingAnchor  constraintEqualToAnchor:_pills_scroll_view.leadingAnchor],
        [pillStack.trailingAnchor constraintEqualToAnchor:_pills_scroll_view.trailingAnchor],
        [pillStack.bottomAnchor   constraintEqualToAnchor:_pills_scroll_view.bottomAnchor],
        [pillStack.heightAnchor   constraintEqualToAnchor:_pills_scroll_view.heightAnchor],
    ]];

    [_rails_stack addArrangedSubview:container];
}

-(void)setupRails {
    anixart::Api* api = _api_proxy.api;
    using Sort = anixart::requests::FilterRequest::Sort;

    NSArray<NSString*>* titles = @[
        NSLocalizedString(@"app.pages.releases.actual",   nil),
        NSLocalizedString(@"app.pages.releases.ongoing",  nil),
        NSLocalizedString(@"app.pages.releases.upcoming", nil),
        NSLocalizedString(@"app.pages.releases.movies",   nil),
        NSLocalizedString(@"app.pages.releases.ova",      nil),
    ];
    _factories = {
        makeFactory(api, std::nullopt,                       std::nullopt,                       Sort::Popular),
        makeFactory(api, anixart::Release::Status::Ongoing,  std::nullopt,                       std::nullopt),
        makeFactory(api, anixart::Release::Status::Upcoming, std::nullopt,                       std::nullopt),
        makeFactory(api, std::nullopt,                       anixart::Release::Category::Movies, std::nullopt),
        makeFactory(api, std::nullopt,                       anixart::Release::Category::Ova,    std::nullopt),
    };

    for (NSInteger i = 0; i < (NSInteger)titles.count; ++i) {
        ReleaseRail* rail = [[ReleaseRail alloc] initWithTitle:titles[i]];
        [self addChildViewController:rail.carousel];
        [_rails_stack addArrangedSubview:rail];
        [rail.carousel didMoveToParentViewController:self];

        FilterFactory factory = _factories[i];
        NSString* rail_title = titles[i];
        [rail.see_all_button addAction:[UIAction actionWithHandler:^(UIAction* _) {
            [self showFullList:factory title:rail_title];
        }] forControlEvents:UIControlEventTouchUpInside];

        [_rails addObject:rail];
    }

    [self loadAllRails];
}

-(void)loadAllRails {
    for (NSInteger i = 0; i < (NSInteger)_rails.count; ++i) {
        ReleaseRail* rail = _rails[i];
        const FilterFactory factory = _factories[i];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            __block anixart::FilterPages::UPtr pages = factory();
            dispatch_async(dispatch_get_main_queue(), ^{
                [rail.carousel setReleasesPageableDataProvider:
                    [[ReleasesPageableDataProvider alloc] initWithPages:std::move(pages)]];
            });
        });
    }
}

#pragma mark - Hero

-(void)loadHero {
    anixart::Api* api = _api_proxy.api;
    // Hop to a background queue, build a fresh pages object, pull the first
    // page synchronously, and hop back to apply.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        anixart::requests::FilterRequest req;
        req.sort = anixart::requests::FilterRequest::Sort::Popular;
        try {
            anixart::FilterPages::UPtr pages = api->search().filter_search(req, false, 0);
            anixart::Release::Ptr featured;
            if (pages) {
                auto first_page = pages->get();
                if (!first_page.empty()) featured = first_page.front();
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_featured_release = featured;
                if (featured) [self.hero_card configureWithRelease:featured];
            });
        } catch (...) {
            // Hero is non-critical — swallow and leave the placeholder up.
        }
    });
}

-(void)openHeroRelease {
    if (!_featured_release) return;
    ReleaseViewController* vc = [[ReleaseViewController alloc] initWithReleaseID:_featured_release->id];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Quick actions

-(void)onQuickActionAt:(NSInteger)idx {
    switch (idx) {
        case 0: [self openPopular];     break;
        case 1: [self openSchedule];    break;
        case 2: [self openCollections]; break;
        case 3: [self openFilter];      break;
        case 4: [self openRandom];      break;
    }
}

-(void)openPopular {
    using Sort = anixart::requests::FilterRequest::Sort;
    auto factory = makeFactory(_api_proxy.api, std::nullopt, std::nullopt, Sort::Popular);
    [self showFullList:factory title:NSLocalizedString(@"app.discover.popular", nil)];
}

-(void)openSchedule {
    // No dedicated schedule endpoint; jump to the ongoing list as the closest signal.
    auto factory = makeFactory(_api_proxy.api,
                               anixart::Release::Status::Ongoing,
                               std::nullopt,
                               std::nullopt);
    [self showFullList:factory title:NSLocalizedString(@"app.discover.schedule", nil)];
}

-(void)openCollections {
    LibanixartApi* api_proxy = _api_proxy;
    UINavigationController* nav = self.navigationController;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        try {
            anixart::requests::SearchRequest req;
            // `__block` + std::move into the nested block — UPtr can't be
            // copy-captured by an Obj-C block.
            __block anixart::CollectionsPages::UPtr pages =
                api_proxy.api->search().collection_search(req, 0);
            dispatch_async(dispatch_get_main_queue(), ^{
                CollectionsCollectionViewController* vc =
                    [[CollectionsCollectionViewController alloc] initWithPages:std::move(pages)
                                                                          axis:UICollectionViewScrollDirectionVertical];
                vc.title = NSLocalizedString(@"app.discover.collections", nil);
                vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
                [nav pushViewController:vc animated:YES];
            });
        } catch (...) {}
    });
}

-(void)openFilter {
    FilterViewController* vc = [FilterViewController new];
    [self.navigationController pushViewController:vc animated:YES];
}

-(void)openRandom {
    ReleaseViewController* vc = [[ReleaseViewController alloc] initWithRandomRelease];
    vc.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Navigation

-(void)showFullList:(FilterFactory)factory title:(NSString*)title {
    auto pages = factory();
    ReleasesViewController* vc = [[ReleasesViewController alloc] initWithPages:std::move(pages)];
    vc.title = title;
    vc.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
