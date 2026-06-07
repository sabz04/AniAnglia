//
//  DiscoverViewController.mm
//
//  Discover tab — yukimo redesign.
//
//  Vertical scroll. From top to bottom:
//    1. Hero carousel — "Интересное" banners with poster backdrop + glass
//       scrim + title/description overlay (16:9, snap-to-page).
//    2. Quick-action pills — Популярное / Расписание / Коллекции / Случайное.
//    3. Recommended rail (horizontal poster carousel).
//    4. Discussing rail.
//    5. Currently-watching rail.
//    6. Week-collections rail.
//    7. Week-comments preview.
//

#import <Foundation/Foundation.h>
#import "DiscoverViewController.h"
#import "ReleaseViewController.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppBackdrop.h"
#import "AppHaptics.h"
#import "LoadableView.h"
#import "FilterViewController.h"
#import "CollectionsCollectionViewController.h"
#import "ReleasesCollectionViewController.h"
#import "ReleasesTableViewController.h"
#import "SegmentedPageViewController.h"
#import "ReleasesPopularPageViewController.h"


#pragma mark - Hero carousel

@class DiscoverHeroCarousel;

@protocol DiscoverHeroCarouselDelegate <NSObject>
-(void)discoverHeroCarousel:(DiscoverHeroCarousel*)carousel didSelectInteresting:(anixart::Interesting::Ptr)interesting;
@end

@interface DiscoverHeroCell : UICollectionViewCell
@property(nonatomic, retain) LoadableImageView* image_view;
@property(nonatomic, retain) UIView*            scrim;
@property(nonatomic, retain) CAGradientLayer*   scrim_layer;
@property(nonatomic, retain) UILabel*           title_label;
@property(nonatomic, retain) UILabel*           description_label;
+(NSString*)getIdentifier;
@end

@implementation DiscoverHeroCell

+(NSString*)getIdentifier { return @"DiscoverHeroCell"; }

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.layer.cornerRadius = AppRadiusXLarge;
    self.layer.cornerCurve  = kCACornerCurveContinuous;
    self.layer.masksToBounds = YES;
    self.backgroundColor = [AppColorProvider posterPlaceholderColor];

    _image_view = [LoadableImageView new];
    _image_view.contentMode = UIViewContentModeScaleAspectFill;
    _image_view.clipsToBounds = YES;
    _image_view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_image_view];

    _scrim = [UIView new];
    _scrim.translatesAutoresizingMaskIntoConstraints = NO;
    _scrim.userInteractionEnabled = NO;
    [self.contentView addSubview:_scrim];

    _scrim_layer = [CAGradientLayer layer];
    _scrim_layer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.70].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.95].CGColor,
    ];
    _scrim_layer.locations = @[@0.0, @0.5, @1.0];
    [_scrim.layer addSublayer:_scrim_layer];

    // Title + description both carry a soft drop shadow so they stay readable
    // against busy posters even when the scrim doesn't fully cover the bottom.
    _title_label = [UILabel new];
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightBold];
    _title_label.textColor = UIColor.whiteColor;
    _title_label.numberOfLines = 2;
    _title_label.adjustsFontForContentSizeCategory = YES;
    _title_label.layer.shadowColor   = UIColor.blackColor.CGColor;
    _title_label.layer.shadowOpacity = 0.75;
    _title_label.layer.shadowRadius  = 6;
    _title_label.layer.shadowOffset  = CGSizeMake(0, 1);

    _description_label = [UILabel new];
    _description_label.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _description_label.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
    _description_label.numberOfLines = 2;
    _description_label.adjustsFontForContentSizeCategory = YES;
    _description_label.layer.shadowColor   = UIColor.blackColor.CGColor;
    _description_label.layer.shadowOpacity = 0.65;
    _description_label.layer.shadowRadius  = 4;
    _description_label.layer.shadowOffset  = CGSizeMake(0, 1);

    UIStackView* text_stack = [[UIStackView alloc] initWithArrangedSubviews:@[_title_label, _description_label]];
    text_stack.axis = UILayoutConstraintAxisVertical;
    text_stack.spacing = AppSpacing4;
    text_stack.alignment = UIStackViewAlignmentLeading;
    text_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:text_stack];

    [NSLayoutConstraint activateConstraints:@[
        [_image_view.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor],
        [_image_view.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_image_view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_image_view.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor],

        [_scrim.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_scrim.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_scrim.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor],
        [_scrim.heightAnchor   constraintEqualToAnchor:self.contentView.heightAnchor multiplier:0.7],

        [text_stack.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor  constant:AppSpacing16],
        [text_stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-AppSpacing16],
        [text_stack.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor   constant:-AppSpacing16],
    ]];
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    _scrim_layer.frame = _scrim.bounds;
}

-(void)configureWithInteresting:(anixart::Interesting::Ptr)interesting {
    NSURL* url = [NSURL URLWithString:TO_NSSTRING(interesting->image_url)];
    [_image_view tryLoadImageWithURL:url];
    _title_label.text = TO_NSSTRING(interesting->title);
    _description_label.text = TO_NSSTRING(interesting->description);
    _description_label.hidden = interesting->description.empty();
}

@end


@interface DiscoverHeroCarousel : UIView <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout> {
    std::vector<anixart::Interesting::Ptr> _items;
}
@property(nonatomic, weak) id<DiscoverHeroCarouselDelegate> delegate;
@property(nonatomic, strong) LibanixartApi* api_proxy;
@property(nonatomic, retain) UICollectionView* collection_view;
-(void)refresh;
@end

@implementation DiscoverHeroCarousel

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    _api_proxy = [LibanixartApi sharedInstance];

    UICollectionViewFlowLayout* layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = AppSpacing12;
    layout.minimumLineSpacing = AppSpacing12;
    layout.sectionInset = UIEdgeInsetsMake(0, AppSpacing16, 0, AppSpacing16);

    _collection_view = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collection_view.backgroundColor = UIColor.clearColor;
    _collection_view.showsHorizontalScrollIndicator = NO;
    _collection_view.decelerationRate = UIScrollViewDecelerationRateFast;
    [_collection_view registerClass:DiscoverHeroCell.class forCellWithReuseIdentifier:[DiscoverHeroCell getIdentifier]];
    _collection_view.dataSource = self;
    _collection_view.delegate   = self;
    _collection_view.translatesAutoresizingMaskIntoConstraints = NO;

    [self addSubview:_collection_view];
    [NSLayoutConstraint activateConstraints:@[
        [_collection_view.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_collection_view.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_collection_view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_collection_view.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
    ]];
    return self;
}

-(void)refresh {
    __block std::vector<anixart::Interesting::Ptr> items;
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        items = api->search().interesting()->get();
        return YES;
    } withUICompletion:^{
        self->_items = std::move(items);
        [self->_collection_view reloadData];
    }];
}

-(NSInteger)collectionView:(UICollectionView*)cv numberOfItemsInSection:(NSInteger)s {
    return (NSInteger)_items.size();
}

-(UICollectionViewCell*)collectionView:(UICollectionView*)cv cellForItemAtIndexPath:(NSIndexPath*)ip {
    DiscoverHeroCell* cell = [cv dequeueReusableCellWithReuseIdentifier:[DiscoverHeroCell getIdentifier] forIndexPath:ip];
    [cell configureWithInteresting:_items[ip.row]];
    return cell;
}

-(CGSize)collectionView:(UICollectionView*)cv
                 layout:(UICollectionViewLayout*)l
sizeForItemAtIndexPath:(NSIndexPath*)ip {
    // Hero cards are 92% of screen width — leaves room for the next card to
    // peek at the trailing edge, classic Apple TV editorial pattern.
    CGFloat w = cv.bounds.size.width * 0.92 - AppSpacing16;
    return CGSizeMake(w, cv.bounds.size.height);
}

-(void)collectionView:(UICollectionView*)cv didSelectItemAtIndexPath:(NSIndexPath*)ip {
    [AppHaptics impactLight];
    [_delegate discoverHeroCarousel:self didSelectInteresting:_items[ip.row]];
}

@end


#pragma mark - Quick-action pill

@interface DiscoverPill : UIControl
@property(nonatomic, copy) NSString* title;
@property(nonatomic, strong) UIImage* icon;
@property(nonatomic, copy, nullable) void(^onTap)(void);
@end

@implementation DiscoverPill {
    UIImageView* _icon_view;
    UILabel*     _label;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    [AppMaterial applyGlassToView:self style:AppMaterialStylePill shape:AppMaterialShapeCapsule];

    _icon_view = [UIImageView new];
    _icon_view.contentMode = UIViewContentModeScaleAspectFit;
    _icon_view.tintColor = [AppColorProvider primaryColor];
    _icon_view.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];

    _label = [UILabel new];
    _label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _label.textColor = [AppColorProvider textColor];
    _label.adjustsFontForContentSizeCategory = YES;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[_icon_view, _label]];
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
-(void)setIcon:(UIImage*)i   { _icon = i; _icon_view.image = i; }

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


#pragma mark - Section rail wrapper

// Header + child VC view, with consistent spacing and a "Все" button.
@interface DiscoverRail : UIView
@property(nonatomic, readonly) UILabel*  title_label;
@property(nonatomic, readonly) UIButton* see_all_button;
@property(nonatomic, copy, nullable) void(^onSeeAll)(void);
-(instancetype)initWithTitle:(NSString*)title contentView:(UIView*)contentView contentHeight:(CGFloat)contentHeight;
@end

@implementation DiscoverRail {
    UILabel*  _title_label;
    UIButton* _see_all_button;
}

-(instancetype)initWithTitle:(NSString*)title contentView:(UIView*)contentView contentHeight:(CGFloat)contentHeight {
    self = [super init];
    if (!self) return nil;

    _title_label = [UILabel new];
    _title_label.text = title;
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightBold];
    _title_label.textColor = [AppColorProvider textColor];
    _title_label.adjustsFontForContentSizeCategory = YES;
    _title_label.translatesAutoresizingMaskIntoConstraints = NO;

    _see_all_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_see_all_button setTitle:NSLocalizedString(@"app.common.named_section.show_all", nil) forState:UIControlStateNormal];
    [_see_all_button setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    _see_all_button.tintColor = [AppColorProvider primaryColor];
    _see_all_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    _see_all_button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _see_all_button.imageView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    _see_all_button.hidden = YES;
    _see_all_button.translatesAutoresizingMaskIntoConstraints = NO;
    [_see_all_button addTarget:self action:@selector(seeAllTapped) forControlEvents:UIControlEventTouchUpInside];

    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_title_label];
    [self addSubview:_see_all_button];
    [self addSubview:contentView];

    [NSLayoutConstraint activateConstraints:@[
        [_title_label.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_title_label.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor constant:AppSpacing20],

        [_see_all_button.centerYAnchor  constraintEqualToAnchor:_title_label.centerYAnchor],
        [_see_all_button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing12],
        [_see_all_button.leadingAnchor  constraintGreaterThanOrEqualToAnchor:_title_label.trailingAnchor constant:AppSpacing8],

        [contentView.topAnchor      constraintEqualToAnchor:_title_label.bottomAnchor constant:AppSpacing12],
        [contentView.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [contentView.heightAnchor   constraintEqualToConstant:contentHeight],
        [contentView.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
    ]];
    return self;
}

-(void)setOnSeeAll:(void (^)(void))onSeeAll {
    _onSeeAll = [onSeeAll copy];
    _see_all_button.hidden = (onSeeAll == nil);
}

-(void)seeAllTapped { if (_onSeeAll) _onSeeAll(); }

-(UILabel*)title_label    { return _title_label; }
-(UIButton*)see_all_button { return _see_all_button; }

@end


#pragma mark - DiscoverViewController

@interface DiscoverViewController () <DiscoverHeroCarouselDelegate>
@property(nonatomic) LibanixartApi* api_proxy;
@property(nonatomic, retain) UIScrollView*  scroll_view;
@property(nonatomic, retain) UIStackView*   content_stack;

@property(nonatomic, retain) DiscoverHeroCarousel* hero_carousel;
@property(nonatomic, retain) UIScrollView*  pills_scroll;

@property(nonatomic, retain) ReleasesCollectionViewController*    recomended_vc;
@property(nonatomic, retain) ReleasesCollectionViewController*    discussing_vc;
@property(nonatomic, retain) ReleasesCollectionViewController*    watching_vc;
@property(nonatomic, retain) CollectionsCollectionViewController* collections_vc;
@end

@implementation DiscoverViewController

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    _api_proxy = [LibanixartApi sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [AppBackdrop installIn:self.view];
    [self setupScroll];
    [self setupHero];
    [self setupQuickActions];
    [self setupRails];
    [self loadAll];
}

-(void)setupScroll {
    _scroll_view = [UIScrollView new];
    _scroll_view.alwaysBounceVertical = YES;
    _scroll_view.showsVerticalScrollIndicator = YES;
    _scroll_view.contentInset = UIEdgeInsetsMake(AppSpacing8, 0, AppSpacing64, 0);
    _scroll_view.backgroundColor = UIColor.clearColor;

    _content_stack = [UIStackView new];
    _content_stack.axis = UILayoutConstraintAxisVertical;
    _content_stack.alignment = UIStackViewAlignmentFill;
    _content_stack.spacing = AppSpacing24;

    [self.view addSubview:_scroll_view];
    [_scroll_view addSubview:_content_stack];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    _content_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll_view.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_scroll_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [_content_stack.topAnchor      constraintEqualToAnchor:_scroll_view.contentLayoutGuide.topAnchor],
        [_content_stack.leadingAnchor  constraintEqualToAnchor:_scroll_view.contentLayoutGuide.leadingAnchor],
        [_content_stack.trailingAnchor constraintEqualToAnchor:_scroll_view.contentLayoutGuide.trailingAnchor],
        [_content_stack.bottomAnchor   constraintEqualToAnchor:_scroll_view.contentLayoutGuide.bottomAnchor],
        [_content_stack.widthAnchor    constraintEqualToAnchor:_scroll_view.frameLayoutGuide.widthAnchor],
    ]];
}

-(void)setupHero {
    _hero_carousel = [DiscoverHeroCarousel new];
    _hero_carousel.delegate = self;
    _hero_carousel.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* container = [UIView new];
    [container addSubview:_hero_carousel];
    [NSLayoutConstraint activateConstraints:@[
        [_hero_carousel.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [_hero_carousel.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [_hero_carousel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_hero_carousel.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
        [_hero_carousel.heightAnchor   constraintEqualToConstant:184],
    ]];
    [_content_stack addArrangedSubview:container];
}

-(void)setupQuickActions {
    _pills_scroll = [UIScrollView new];
    _pills_scroll.showsHorizontalScrollIndicator = NO;
    _pills_scroll.contentInset = UIEdgeInsetsMake(0, AppSpacing16, 0, AppSpacing16);
    _pills_scroll.translatesAutoresizingMaskIntoConstraints = NO;
    _pills_scroll.backgroundColor = UIColor.clearColor;

    UIStackView* stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = AppSpacing8;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [_pills_scroll addSubview:stack];

    NSArray* defs = @[
        @[NSLocalizedString(@"app.discover.popular",     nil), @"flame.fill",              @0],
        @[NSLocalizedString(@"app.discover.schedule",    nil), @"calendar",                @1],
        @[NSLocalizedString(@"app.discover.collections", nil), @"square.stack.3d.up.fill", @2],
        @[NSLocalizedString(@"app.discover.random",      nil), @"shuffle",                 @3],
    ];
    for (NSArray* def in defs) {
        DiscoverPill* p = [DiscoverPill new];
        p.title = def[0];
        p.icon  = [UIImage systemImageNamed:def[1]];
        NSInteger idx = [def[2] integerValue];
        __weak __typeof__(self) ws = self;
        p.onTap = ^{ [ws onPillAt:idx]; };
        [stack addArrangedSubview:p];
    }

    UIView* container = [UIView new];
    [container addSubview:_pills_scroll];
    [NSLayoutConstraint activateConstraints:@[
        [_pills_scroll.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [_pills_scroll.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [_pills_scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_pills_scroll.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
        [_pills_scroll.heightAnchor   constraintEqualToConstant:44],

        [stack.topAnchor      constraintEqualToAnchor:_pills_scroll.topAnchor],
        [stack.leadingAnchor  constraintEqualToAnchor:_pills_scroll.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:_pills_scroll.trailingAnchor],
        [stack.bottomAnchor   constraintEqualToAnchor:_pills_scroll.bottomAnchor],
        [stack.heightAnchor   constraintEqualToAnchor:_pills_scroll.heightAnchor],
    ]];
    [_content_stack addArrangedSubview:container];
}

-(void)setupRails {
    _recomended_vc  = [self makeReleasesRailVC];
    _discussing_vc  = [self makeReleasesRailVC];
    _watching_vc    = [self makeReleasesRailVC];
    _collections_vc = [[CollectionsCollectionViewController alloc] initWithAxis:UICollectionViewScrollDirectionHorizontal];
    _collections_vc.is_container_view_controller = YES;
    [self addChildViewController:_collections_vc];

    DiscoverRail* rec_rail =
        [[DiscoverRail alloc] initWithTitle:NSLocalizedString(@"app.discover.recomended", nil)
                                contentView:_recomended_vc.view
                              contentHeight:240];
    DiscoverRail* dis_rail =
        [[DiscoverRail alloc] initWithTitle:NSLocalizedString(@"app.discover.discussing", nil)
                                contentView:_discussing_vc.view
                              contentHeight:240];
    DiscoverRail* watching_rail =
        [[DiscoverRail alloc] initWithTitle:NSLocalizedString(@"app.discover.watching", nil)
                                contentView:_watching_vc.view
                              contentHeight:240];
    DiscoverRail* coll_rail =
        [[DiscoverRail alloc] initWithTitle:NSLocalizedString(@"app.discover.week_collections", nil)
                                contentView:_collections_vc.view
                              contentHeight:200];

    // Auto-hide a rail when its first page comes back empty — nothing worse
    // than a section header followed by blank space.
    __weak DiscoverRail* w_rec = rec_rail;
    _recomended_vc.onDidLoadFirstPage = ^(NSInteger c) {
        if (c == 0) w_rec.hidden = YES;
    };
    __weak DiscoverRail* w_dis = dis_rail;
    _discussing_vc.onDidLoadFirstPage = ^(NSInteger c) {
        if (c == 0) w_dis.hidden = YES;
    };
    __weak DiscoverRail* w_watching = watching_rail;
    _watching_vc.onDidLoadFirstPage = ^(NSInteger c) {
        if (c == 0) w_watching.hidden = YES;
    };

    __weak __typeof__(self) ws = self;
    coll_rail.onSeeAll = ^{
        [ws.navigationController pushViewController:
            [[CollectionsCollectionViewController alloc] initWithPages:ws.api_proxy.api->collections().all_collections(anixart::Collection::Sort::WeekPopular, 2, 0)
                                                                  axis:UICollectionViewScrollDirectionVertical]
                                                animated:YES];
    };

    [_content_stack addArrangedSubview:rec_rail];
    [_content_stack addArrangedSubview:dis_rail];
    [_content_stack addArrangedSubview:watching_rail];
    [_content_stack addArrangedSubview:coll_rail];
}

-(ReleasesCollectionViewController*)makeReleasesRailVC {
    ReleasesCollectionViewController* vc =
        [[ReleasesCollectionViewController alloc] initWithAxis:UICollectionViewScrollDirectionHorizontal];
    vc.is_container_view_controller = YES;
    [self addChildViewController:vc];
    [vc didMoveToParentViewController:self];
    return vc;
}

-(void)loadAll {
    [_hero_carousel refresh];

    anixart::Api* api = _api_proxy.api;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        try {
            __block anixart::RecomendationsPages::UPtr rec_pages   = api->search().recomendations(0);
            __block anixart::DiscussingPages::UPtr     dis_pages   = api->search().discussing();
            __block anixart::WatchingPages::UPtr       watch_pages = api->search().currently_watching(0);
            __block anixart::CollectionsPages::UPtr    coll_pages  = api->collections().all_collections(anixart::Collection::Sort::WeekPopular, 2, 0);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self.recomended_vc  setReleasesPageableDataProvider:
                    [[ReleasesPageableDataProvider alloc] initWithPages:std::move(rec_pages)]];
                [self.discussing_vc  setReleasesPageableDataProvider:
                    [[ReleasesPageableDataProvider alloc] initWithPages:std::move(dis_pages)]];
                [self.watching_vc    setReleasesPageableDataProvider:
                    [[ReleasesPageableDataProvider alloc] initWithPages:std::move(watch_pages)]];
                [self.collections_vc setDataProvider:
                    [[CollectionsPageableDataProvider alloc] initWithPages:std::move(coll_pages)]];
            });
        } catch (...) {}
    });
}

#pragma mark - Quick actions

-(void)onPillAt:(NSInteger)idx {
    switch (idx) {
        case 0: [self.navigationController pushViewController:[ReleasesPopularPageViewController new] animated:YES]; break;
        case 1: /* schedule — no dedicated endpoint, jump to popular as approximation */
                [self.navigationController pushViewController:[ReleasesPopularPageViewController new] animated:YES]; break;
        case 2: {
            auto pages = _api_proxy.api->collections().all_collections(anixart::Collection::Sort::YearPopular, 1, 0);
            [self.navigationController pushViewController:
                [[CollectionsCollectionViewController alloc] initWithPages:std::move(pages)
                                                                      axis:UICollectionViewScrollDirectionVertical]
                                                animated:YES];
            break;
        }
        case 3: {
            ReleaseViewController* vc = [[ReleaseViewController alloc] initWithRandomRelease];
            vc.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:vc animated:YES];
            break;
        }
    }
}

#pragma mark - Filter

-(IBAction)onFilterBarButtonPressed:(UIBarButtonItem*)sender {
    [self.navigationController pushViewController:[FilterViewController new] animated:YES];
}

#pragma mark - DiscoverHeroCarouselDelegate

-(void)discoverHeroCarousel:(DiscoverHeroCarousel*)carousel didSelectInteresting:(anixart::Interesting::Ptr)interesting {
    if (interesting->type == anixart::Interesting::Type::OpenRelease) {
        [self.navigationController setNavigationBarHidden:NO];
        anixart::ReleaseID release_id = static_cast<anixart::ReleaseID>(std::stoll(interesting->action));
        ReleaseViewController* vc = [[ReleaseViewController alloc] initWithReleaseID:release_id];
        vc.hidesBottomBarWhenPushed = YES;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

@end
