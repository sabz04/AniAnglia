//
//  ReleaseViewController.mm
//
//  Release detail screen — full rewrite.
//
//  Layout (vertical scroll, Apple TV+ / Crunchyroll vibe):
//
//      ┌─ blurred poster background ──────────────────┐
//      │              ┌──────────┐                    │
//      │              │  poster  │                    │
//      │              │ 140×210  │                    │
//      │              └──────────┘                    │
//      │              Название (большое)              │
//      │              Original title (мелким)         │
//      │              ★ 8.5 · 2024 · 12 эп · 24 мин   │
//      └──────────────────────────────────────────────┘
//      [▶ Смотреть]  [♡]  [≡ В планах]               ← actions row
//
//      [Жанр] [Жанр] [Жанр]                          ← genre chips
//
//      Описание...                                    ← expandable
//
//      Студия      Studio Name                        ← info rows
//      Сезон       Лето 2024
//      Страна      Япония
//      Статус      Завершён
//      Эпизоды     12 / 12
//      Длительность 24 мин
//
//      Кадры →   [horizontal carousel]                ← if screenshots
//      Похожие → [horizontal carousel of posters]     ← if related
//
//  Removed from the legacy screen: rating ability and comments block.
//

#import "ReleaseViewController.h"
#import "LibanixartApi.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import <objc/runtime.h>
#import "AppDataController.h"
#import "StringCvt.h"
#import "TypeSelectViewController.h"
#import "LoadableView.h"
#import "TimeCvt.h"
#import "ProfileListsView.h"
#import "ExpandableLabel.h"
#import "ReleasesPageableDataProvider.h"
#import "ReleasesCollectionViewController.h"
#import "ReleaseRelatedTableViewController.h"
#import "ReleasesViewController.h"


#pragma mark - InfoRow

/// One "key:value" line in the info section. Title leading, value trailing,
/// 1pt hairline separator below.
@interface InfoRow : UIView
@property(nonatomic, retain) UILabel* key_label;
@property(nonatomic, retain) UILabel* value_label;
-(instancetype)initWithKey:(NSString*)key value:(NSString*)value;
-(void)setValue:(NSString*)value;
@end

@implementation InfoRow

-(instancetype)initWithKey:(NSString*)key value:(NSString*)value {
    self = [super init];
    if (!self) return nil;
    _key_label = [UILabel new];
    _key_label.text = key;
    _key_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    _key_label.textColor = [AppColorProvider textSecondaryColor];

    _value_label = [UILabel new];
    _value_label.text = value ?: @"—";
    _value_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    _value_label.textColor = [AppColorProvider textColor];
    _value_label.textAlignment = NSTextAlignmentRight;
    _value_label.numberOfLines = 0;

    UIView* sep = [UIView new];
    sep.backgroundColor = [AppColorProvider separatorColor];

    [self addSubview:_key_label];
    [self addSubview:_value_label];
    [self addSubview:sep];

    _key_label.translatesAutoresizingMaskIntoConstraints = NO;
    _value_label.translatesAutoresizingMaskIntoConstraints = NO;
    sep.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_key_label.topAnchor      constraintEqualToAnchor:self.topAnchor constant:AppSpacing12],
        [_key_label.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],

        [_value_label.topAnchor      constraintEqualToAnchor:_key_label.topAnchor],
        [_value_label.leadingAnchor  constraintGreaterThanOrEqualToAnchor:_key_label.trailingAnchor constant:AppSpacing16],
        [_value_label.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

        [sep.topAnchor      constraintEqualToAnchor:_value_label.bottomAnchor constant:AppSpacing12],
        [sep.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [sep.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [sep.heightAnchor   constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],
        [sep.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [self.heightAnchor  constraintGreaterThanOrEqualToAnchor:_key_label.heightAnchor multiplier:1 constant:AppSpacing12 * 2]
    ]];
    return self;
}

-(void)setValue:(NSString*)value { _value_label.text = value.length ? value : @"—"; }
@end


#pragma mark - GenreChip

/// Small chip used to display a genre tag. Same chip aesthetic as the poster
/// rating chip — 6pt corner, real padding via subclassed UILabel.
@interface GenreChip : UILabel
@end

@implementation GenreChip
-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    self.font = [UIFont app_fontForStyle:AppTextStyleFootnote weight:UIFontWeightMedium];
    self.textColor = [AppColorProvider primaryColor];
    self.backgroundColor = [[AppColorProvider primaryColor] colorWithAlphaComponent:0.12];
    self.layer.cornerRadius = AppRadiusSmall;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;
    return self;
}
-(CGSize)intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.width += 20; s.height += 10;
    return s;
}
-(void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, UIEdgeInsetsMake(5, 10, 5, 10))];
}
@end


#pragma mark - ReleaseHeroView

/// Top hero with a blurred-poster background, foreground 2:3 poster, title,
/// original title, and a meta strip. All visible state is rendered from the
/// release once via `-applyRelease:`.
@interface ReleaseHeroView : UIView
@property(nonatomic, retain) LoadableImageView* background_image;
@property(nonatomic, retain) UIVisualEffectView* blur;
@property(nonatomic, retain) UIView* dim_overlay;
@property(nonatomic, retain) LoadableImageView* poster;
@property(nonatomic, retain) UILabel* title_label;
@property(nonatomic, retain) UILabel* orig_title_label;
@property(nonatomic, retain) UILabel* meta_label;
-(void)applyRelease:(anixart::Release::Ptr)release;
@end

@implementation ReleaseHeroView

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    self.clipsToBounds = YES;

    // Layout (Apple TV+ / Letterboxd style):
    //
    //  ┌─ blurred poster backdrop ────────────────────┐
    //  │  ┌────────┐  Название                       │
    //  │  │ poster │  Original title                  │
    //  │  │120×180 │  ★ 8.5 · 2024 · 12 эп · 24 мин   │
    //  │  └────────┘                                  │
    //  └──────────────────────────────────────────────┘

    _background_image = [LoadableImageView new];
    _background_image.contentMode = UIViewContentModeScaleAspectFill;
    _background_image.clipsToBounds = YES;

    _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark]];

    // Cinematic top-to-bottom scrim: clear at top, dark at bottom — meta line
    // sits over deep ink so it stays readable on any poster.
    _dim_overlay = [UIView new];
    _dim_overlay.userInteractionEnabled = NO;
    {
        CAGradientLayer* scrim = [CAGradientLayer layer];
        scrim.colors = @[
            (id)[UIColor colorWithWhite:0.0 alpha:0.20].CGColor,
            (id)[UIColor colorWithWhite:0.0 alpha:0.55].CGColor,
        ];
        scrim.locations = @[@0.0, @1.0];
        [_dim_overlay.layer addSublayer:scrim];
    }

    _poster = [LoadableImageView new];
    _poster.contentMode = UIViewContentModeScaleAspectFill;
    _poster.clipsToBounds = YES;
    _poster.layer.cornerRadius = AppRadiusLarge;
    _poster.layer.cornerCurve = kCACornerCurveContinuous;
    _poster.backgroundColor = [AppColorProvider posterPlaceholderColor];

    // Poster shadow lives on a wrapper so the poster itself can clip its own
    // rounded mask without killing the shadow.
    UIView* poster_shadow_holder = [UIView new];
    poster_shadow_holder.translatesAutoresizingMaskIntoConstraints = NO;
    poster_shadow_holder.layer.shadowColor = UIColor.blackColor.CGColor;
    poster_shadow_holder.layer.shadowOpacity = 0.45;
    poster_shadow_holder.layer.shadowRadius = 18;
    poster_shadow_holder.layer.shadowOffset = CGSizeMake(0, 8);
    [poster_shadow_holder addSubview:_poster];

    _title_label = [UILabel new];
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle2 weight:UIFontWeightBold];
    _title_label.textColor = UIColor.whiteColor;
    _title_label.textAlignment = NSTextAlignmentLeft;
    _title_label.numberOfLines = 3;
    _title_label.adjustsFontForContentSizeCategory = YES;

    _orig_title_label = [UILabel new];
    _orig_title_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    _orig_title_label.textColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    _orig_title_label.textAlignment = NSTextAlignmentLeft;
    _orig_title_label.numberOfLines = 2;
    _orig_title_label.adjustsFontForContentSizeCategory = YES;

    _meta_label = [UILabel new];
    _meta_label.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleFootnote weight:UIFontWeightSemibold];
    _meta_label.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    _meta_label.textAlignment = NSTextAlignmentLeft;
    _meta_label.numberOfLines = 2;
    _meta_label.adjustsFontForContentSizeCategory = YES;

    UIStackView* text_stack = [[UIStackView alloc] initWithArrangedSubviews:@[_title_label, _orig_title_label, _meta_label]];
    text_stack.axis = UILayoutConstraintAxisVertical;
    text_stack.spacing = AppSpacing6;
    text_stack.alignment = UIStackViewAlignmentLeading;
    text_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [text_stack setCustomSpacing:AppSpacing12 afterView:_orig_title_label];

    [self addSubview:_background_image];
    [self addSubview:_blur];
    [self addSubview:_dim_overlay];
    [self addSubview:poster_shadow_holder];
    [self addSubview:text_stack];

    _background_image.translatesAutoresizingMaskIntoConstraints = NO;
    _blur.translatesAutoresizingMaskIntoConstraints = NO;
    _dim_overlay.translatesAutoresizingMaskIntoConstraints = NO;
    _poster.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        [_background_image.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_background_image.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_background_image.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_background_image.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [_blur.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_blur.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_blur.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_blur.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [_dim_overlay.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_dim_overlay.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_dim_overlay.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_dim_overlay.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        // Poster left-aligned, fixed 120×180 with 16pt margins.
        [poster_shadow_holder.topAnchor      constraintEqualToAnchor:self.topAnchor      constant:AppSpacing20],
        [poster_shadow_holder.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor  constant:AppSpacing20],
        [poster_shadow_holder.widthAnchor    constraintEqualToConstant:120],
        [poster_shadow_holder.heightAnchor   constraintEqualToConstant:180],
        [poster_shadow_holder.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor   constant:-AppSpacing20],

        [_poster.topAnchor      constraintEqualToAnchor:poster_shadow_holder.topAnchor],
        [_poster.leadingAnchor  constraintEqualToAnchor:poster_shadow_holder.leadingAnchor],
        [_poster.trailingAnchor constraintEqualToAnchor:poster_shadow_holder.trailingAnchor],
        [_poster.bottomAnchor   constraintEqualToAnchor:poster_shadow_holder.bottomAnchor],

        // Text stack right of the poster, vertically centered.
        [text_stack.leadingAnchor  constraintEqualToAnchor:poster_shadow_holder.trailingAnchor constant:AppSpacing16],
        [text_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-AppSpacing20],
        [text_stack.centerYAnchor  constraintEqualToAnchor:poster_shadow_holder.centerYAnchor],
        [text_stack.topAnchor      constraintGreaterThanOrEqualToAnchor:self.topAnchor    constant:AppSpacing12],
        [text_stack.bottomAnchor   constraintLessThanOrEqualToAnchor:self.bottomAnchor    constant:-AppSpacing12],
    ]];

    // Stash the shadow holder on the layer so we can re-cast the shadow path
    // on layout.
    objc_setAssociatedObject(self, "yk_poster_shadow", poster_shadow_holder, OBJC_ASSOCIATION_ASSIGN);
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    for (CALayer* sub in _dim_overlay.layer.sublayers) {
        if ([sub isKindOfClass:CAGradientLayer.class]) sub.frame = _dim_overlay.bounds;
    }
    UIView* shadow_holder = objc_getAssociatedObject(self, "yk_poster_shadow");
    if (shadow_holder) {
        shadow_holder.layer.shadowPath =
            [UIBezierPath bezierPathWithRoundedRect:shadow_holder.bounds cornerRadius:AppRadiusLarge].CGPath;
    }
}

-(void)applyRelease:(anixart::Release::Ptr)release {
    NSURL* poster_url = [NSURL URLWithString:TO_NSSTRING(release->image_url)];
    [_poster tryLoadImageWithURL:poster_url];
    [_background_image tryLoadImageWithURL:poster_url];

    _title_label.text = TO_NSSTRING(release->title_ru);
    _orig_title_label.text = TO_NSSTRING(release->title_original);
    _orig_title_label.hidden = release->title_original.empty();

    NSMutableArray<NSString*>* parts = [NSMutableArray new];
    if (release->grade > 0) {
        double rounded = round(release->grade * 10) / 10.0;
        [parts addObject:[NSString stringWithFormat:@"★ %@", [@(rounded) stringValue]]];
    }
    if (!release->year.empty()) {
        [parts addObject:TO_NSSTRING(release->year)];
    }
    {
        NSString* category = [ReleasesPageableDataProvider getCategoryNameFor:release->category];
        if (category.length) [parts addObject:category];
    }
    if (release->episodes_total > 0 || release->episodes_released > 0) {
        NSString* total = release->episodes_total > 0 ? [@(release->episodes_total) stringValue] : @"?";
        [parts addObject:[NSString stringWithFormat:@"%d / %@ эп", release->episodes_released, total]];
    }
    if (release->duration.count() > 0) {
        [parts addObject:[NSString stringWithFormat:@"%ld мин", (long)release->duration.count()]];
    }
    _meta_label.text = [parts componentsJoinedByString:@"  ·  "];
}

@end


#pragma mark - PreviewsRail

/// Horizontal scroll of release screenshot previews (16:9 cards).
@interface PreviewsRail : UIView <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property(nonatomic, retain) UICollectionView* cv;
@property(nonatomic) std::vector<std::string> urls;
@end

@interface PreviewsRailCell : UICollectionViewCell
@property(nonatomic, retain) LoadableImageView* image_view;
@end

@implementation PreviewsRailCell
-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    _image_view = [LoadableImageView new];
    _image_view.contentMode = UIViewContentModeScaleAspectFill;
    _image_view.clipsToBounds = YES;
    _image_view.layer.cornerRadius = AppRadiusSmall;
    _image_view.layer.cornerCurve = kCACornerCurveContinuous;
    _image_view.backgroundColor = [AppColorProvider fillColor];
    [self.contentView addSubview:_image_view];
    _image_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_image_view.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor],
        [_image_view.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_image_view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_image_view.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    return self;
}
@end

@implementation PreviewsRail

-(instancetype)init {
    self = [super init];
    if (!self) return nil;
    UICollectionViewFlowLayout* layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.minimumInteritemSpacing = AppSpacing8;
    layout.minimumLineSpacing = AppSpacing8;
    layout.sectionInset = UIEdgeInsetsMake(0, AppSpacing20, 0, AppSpacing20);

    _cv = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _cv.backgroundColor = UIColor.clearColor;
    _cv.showsHorizontalScrollIndicator = NO;
    [_cv registerClass:PreviewsRailCell.class forCellWithReuseIdentifier:@"cell"];
    _cv.dataSource = self;
    _cv.delegate = self;

    [self addSubview:_cv];
    _cv.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_cv.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_cv.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_cv.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_cv.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        // Half the previous height — 16:9 cards at this size still preview
        // legibly and don't dominate the screen.
        [_cv.heightAnchor   constraintEqualToConstant:104]
    ]];
    return self;
}

-(void)setRelease:(anixart::Release::Ptr)release {
    _urls = release->screenshot_image_urls;
    [_cv reloadData];
}

-(NSInteger)collectionView:(UICollectionView*)cv numberOfItemsInSection:(NSInteger)s { return _urls.size(); }

-(UICollectionViewCell*)collectionView:(UICollectionView*)cv cellForItemAtIndexPath:(NSIndexPath*)ip {
    PreviewsRailCell* c = [cv dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:ip];
    NSURL* url = [NSURL URLWithString:TO_NSSTRING(_urls[ip.row])];
    [c.image_view tryLoadImageWithURL:url];
    return c;
}

-(CGSize)collectionView:(UICollectionView*)cv layout:(UICollectionViewLayout*)l sizeForItemAtIndexPath:(NSIndexPath*)ip {
    CGFloat h = cv.bounds.size.height;
    return CGSizeMake(h * (16.0 / 9.0), h);
}

@end


#pragma mark - SectionHeader

@interface SectionHeader : UIView
@property(nonatomic, retain) UILabel* title_label;
@property(nonatomic, retain) UIButton* show_all_button;
-(instancetype)initWithTitle:(NSString*)title showAll:(BOOL)showAll onShowAll:(void(^)(void))onShowAll;
@end

@implementation SectionHeader {
    void(^_show_all_block)(void);
}
-(instancetype)initWithTitle:(NSString*)title showAll:(BOOL)showAll onShowAll:(void(^)(void))onShowAll {
    self = [super init];
    _show_all_block = [onShowAll copy];

    _title_label = [UILabel new];
    _title_label.text = title;
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle3 weight:UIFontWeightSemibold];
    _title_label.textColor = [AppColorProvider textColor];

    _show_all_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_show_all_button setTitle:@"Все" forState:UIControlStateNormal];
    [_show_all_button setImage:[UIImage systemImageNamed:@"chevron.right"] forState:UIControlStateNormal];
    _show_all_button.tintColor = [AppColorProvider primaryColor];
    _show_all_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    _show_all_button.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _show_all_button.imageView.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];
    _show_all_button.hidden = !showAll;
    [_show_all_button addTarget:self action:@selector(onShowAllTapped) forControlEvents:UIControlEventTouchUpInside];

    [self addSubview:_title_label];
    [self addSubview:_show_all_button];

    _title_label.translatesAutoresizingMaskIntoConstraints = NO;
    _show_all_button.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_title_label.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_title_label.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        [_title_label.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],

        [_show_all_button.centerYAnchor constraintEqualToAnchor:_title_label.centerYAnchor],
        [_show_all_button.trailingAnchor constraintEqualToAnchor:self.trailingAnchor]
    ]];
    return self;
}

-(void)onShowAllTapped { if (_show_all_block) _show_all_block(); }
@end


#pragma mark - ReleaseViewController

@interface ReleaseViewController () <LoadableViewDelegate> {
    anixart::Release::Ptr _release;   // ivar — `release` clashes with NSObject selector, hence no @property
}
@property(nonatomic, strong) LibanixartApi* api_proxy;
@property(nonatomic) anixart::ReleaseID release_id;
@property(nonatomic) BOOL is_random_release;
@property(nonatomic, copy) anixart::Release::Ptr(^release_getter)(anixart::Api*);

@property(nonatomic, retain) UIScrollView*    scroll_view;
@property(nonatomic, retain) UIStackView*     content_stack;
@property(nonatomic, retain) LoadableView*    loading_view;
@property(nonatomic, retain) UIRefreshControl* refresh_control;

@property(nonatomic, retain) ReleaseHeroView* hero;
@property(nonatomic, retain) UIButton*        watch_button;
@property(nonatomic, retain) UIButton*        bookmark_button;
@property(nonatomic, retain) UIButton*        list_button;
@property(nonatomic, retain) UIScrollView*    chips_scroll;
@property(nonatomic, retain) UIStackView*     chips_stack;
@property(nonatomic, retain) ExpandableLabel* description_label;
@property(nonatomic, retain) UIStackView*     info_stack;

@property(nonatomic, retain) ReleasesCollectionViewController* related_carousel;
@property(nonatomic, retain) PreviewsRail*    previews_rail;

@property(nonatomic) BOOL ui_inited;
@end

@implementation ReleaseViewController

#pragma mark - Init

-(instancetype)initWithRelease:(anixart::Release::Ptr)release {
    self = [super init];
    _api_proxy = [LibanixartApi sharedInstance];
    _release = release;
    _release_id = release->id;
    return self;
}

-(instancetype)initWithReleaseID:(anixart::ReleaseID)release_id {
    self = [super init];
    _api_proxy = [LibanixartApi sharedInstance];
    _release_id = release_id;
    return self;
}

-(instancetype)initWithRandomRelease {
    self = [super init];
    _api_proxy = [LibanixartApi sharedInstance];
    _is_random_release = YES;
    _release_getter = ^(anixart::Api* api){ return api->releases().random_release(false); };
    return self;
}

-(instancetype)initWithRandomCollectionRelease:(anixart::CollectionID)collection_id {
    self = [super init];
    _api_proxy = [LibanixartApi sharedInstance];
    _is_random_release = YES;
    _release_getter = ^(anixart::Api* api){ return api->releases().random_collection_release(collection_id, false); };
    return self;
}

#pragma mark - Lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    [self setupLoadingChrome];
    if (_release) [self onReleaseLoaded:NO];
    else          [self loadRelease];
}

-(void)setupLoadingChrome {
    _scroll_view = [UIScrollView new];
    _scroll_view.alwaysBounceVertical = YES;
    // The compact horizontal hero is no longer full-bleed, so let UIKit inset
    // the scroll view for the navigation bar — otherwise the poster slides
    // under the bar at rest position.
    _scroll_view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;

    _refresh_control = [UIRefreshControl new];
    [_refresh_control addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];

    _loading_view = [LoadableView new];
    _loading_view.delegate = self;

    [self.view addSubview:_scroll_view];
    [self.view addSubview:_loading_view];

    _scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    _loading_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_scroll_view.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_scroll_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [_loading_view.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loading_view.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
}

#pragma mark - Loading

-(void)loadRelease {
    if (!_refresh_control.refreshing) [_loading_view startLoading];
    if (_release_getter) {
        [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
            self->_release = self->_release_getter(api);
            return NO;
        } completion:^(BOOL errored) { [self onReleaseLoaded:errored]; }];
        return;
    }
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        self->_release = api->releases().get_release(self->_release_id);
        return NO;
    } completion:^(BOOL errored) { [self onReleaseLoaded:errored]; }];
}

-(void)onReleaseLoaded:(BOOL)errored {
    [_loading_view endLoadingWithErrored:errored];
    if (_refresh_control.refreshing) [_refresh_control endRefreshing];
    _scroll_view.hidden = errored;
    if (errored) {
        _scroll_view.refreshControl = nil;
        return;
    }
    _scroll_view.refreshControl = _refresh_control;
    if (!_ui_inited) [self buildContent];
    [self populateContent];
}

-(void)onRefresh { [self loadRelease]; }
-(void)didReloadForLoadableView:(LoadableView*)loadable_view { [self loadRelease]; }

#pragma mark - Content scaffold

-(void)buildContent {
    _ui_inited = YES;

    _content_stack = [UIStackView new];
    _content_stack.axis = UILayoutConstraintAxisVertical;
    _content_stack.alignment = UIStackViewAlignmentFill;
    _content_stack.spacing = AppSpacing20;
    [_scroll_view addSubview:_content_stack];
    _content_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_content_stack.topAnchor      constraintEqualToAnchor:_scroll_view.contentLayoutGuide.topAnchor],
        [_content_stack.leadingAnchor  constraintEqualToAnchor:_scroll_view.contentLayoutGuide.leadingAnchor],
        [_content_stack.trailingAnchor constraintEqualToAnchor:_scroll_view.contentLayoutGuide.trailingAnchor],
        [_content_stack.bottomAnchor   constraintEqualToAnchor:_scroll_view.contentLayoutGuide.bottomAnchor],
        [_content_stack.widthAnchor    constraintEqualToAnchor:_scroll_view.frameLayoutGuide.widthAnchor]
    ]];

    // 1. Hero (full bleed)
    _hero = [ReleaseHeroView new];
    [_content_stack addArrangedSubview:_hero];
    // Hero's internal padding already provides breathing room — pull the next
    // section in closer than the default rhythm.
    [_content_stack setCustomSpacing:AppSpacing16 afterView:_hero];

    // 2. Actions row
    [_content_stack addArrangedSubview:[self buildActionsRow]];

    // 3. Genre chips (lazily filled in populateContent)
    [_content_stack addArrangedSubview:[self buildChipsRow]];

    // 4. Description
    _description_label = [ExpandableLabel new];
    [_content_stack addArrangedSubview:[self wrapMargins:_description_label]];

    // 5. Info rows
    _info_stack = [UIStackView new];
    _info_stack.axis = UILayoutConstraintAxisVertical;
    _info_stack.spacing = 0;
    [_content_stack addArrangedSubview:[self wrapMargins:_info_stack]];

    // 6. Previews / Related — added in populateContent (conditional on data)
}

-(UIView*)wrapMargins:(UIView*)v {
    UIView* container = [UIView new];
    [container addSubview:v];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [v.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [v.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
        [v.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor constant:AppSpacing20],
        [v.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-AppSpacing20],
    ]];
    return container;
}

-(UIView*)buildActionsRow {
    _watch_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_watch_button setTitle:NSLocalizedString(@"app.release.play_button.title", nil) forState:UIControlStateNormal];
    [_watch_button setImage:[UIImage systemImageNamed:@"play.fill"] forState:UIControlStateNormal];
    [_watch_button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _watch_button.tintColor = UIColor.whiteColor;
    _watch_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    _watch_button.backgroundColor = [AppColorProvider primaryColor];
    _watch_button.layer.cornerRadius = AppRadiusLarge;
    _watch_button.layer.cornerCurve = kCACornerCurveContinuous;
    _watch_button.contentEdgeInsets = UIEdgeInsetsMake(0, AppSpacing20, 0, AppSpacing20);
    _watch_button.titleEdgeInsets = UIEdgeInsetsMake(0, AppSpacing8, 0, 0);
    [_watch_button addTarget:self action:@selector(onWatchTapped) forControlEvents:UIControlEventTouchUpInside];

    _bookmark_button = [self makeSecondaryActionButtonWithSymbol:@"bookmark"];
    [_bookmark_button addTarget:self action:@selector(onBookmarkTapped) forControlEvents:UIControlEventTouchUpInside];

    _list_button = [self makeSecondaryActionButtonWithSymbol:@"list.bullet"];
    _list_button.showsMenuAsPrimaryAction = YES;
    [_list_button setMenu:[self buildListMenu]];

    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[_watch_button, _bookmark_button, _list_button]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.spacing = AppSpacing12;
    row.alignment = UIStackViewAlignmentFill;

    [_watch_button setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_bookmark_button setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [_list_button setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [NSLayoutConstraint activateConstraints:@[
        [_watch_button.heightAnchor    constraintEqualToConstant:52],
        [_bookmark_button.widthAnchor  constraintEqualToConstant:52],
        [_bookmark_button.heightAnchor constraintEqualToConstant:52],
        [_list_button.widthAnchor      constraintEqualToConstant:52],
        [_list_button.heightAnchor     constraintEqualToConstant:52],
    ]];
    return [self wrapMargins:row];
}

-(UIButton*)makeSecondaryActionButtonWithSymbol:(NSString*)symbol {
    UIButton* b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    b.tintColor = [AppColorProvider primaryColor];
    // Coral-tinted soft fill — same family as the brand button, but quiet
    // enough not to compete. Glass material is wrong at 52×52: too little
    // area for blur to settle, looks fuzzy and fights UIButton's own layout.
    b.backgroundColor = [AppColorProvider primarySoftColor];
    b.layer.cornerRadius = AppRadiusLarge;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    b.clipsToBounds = YES;
    [b setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold]
                       forImageInState:UIControlStateNormal];
    return b;
}

-(UIView*)buildChipsRow {
    _chips_scroll = [UIScrollView new];
    _chips_scroll.showsHorizontalScrollIndicator = NO;
    _chips_scroll.contentInset = UIEdgeInsetsMake(0, AppSpacing20, 0, AppSpacing20);

    _chips_stack = [UIStackView new];
    _chips_stack.axis = UILayoutConstraintAxisHorizontal;
    _chips_stack.spacing = AppSpacing6;
    _chips_stack.alignment = UIStackViewAlignmentCenter;

    [_chips_scroll addSubview:_chips_stack];
    _chips_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_chips_stack.topAnchor      constraintEqualToAnchor:_chips_scroll.contentLayoutGuide.topAnchor],
        [_chips_stack.leadingAnchor  constraintEqualToAnchor:_chips_scroll.contentLayoutGuide.leadingAnchor],
        [_chips_stack.trailingAnchor constraintEqualToAnchor:_chips_scroll.contentLayoutGuide.trailingAnchor],
        [_chips_stack.bottomAnchor   constraintEqualToAnchor:_chips_scroll.contentLayoutGuide.bottomAnchor],
        [_chips_stack.heightAnchor   constraintEqualToAnchor:_chips_scroll.frameLayoutGuide.heightAnchor]
    ]];

    UIView* container = [UIView new];
    [container addSubview:_chips_scroll];
    _chips_scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_chips_scroll.topAnchor      constraintEqualToAnchor:container.topAnchor],
        [_chips_scroll.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor],
        [_chips_scroll.leadingAnchor  constraintEqualToAnchor:container.leadingAnchor],
        [_chips_scroll.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [_chips_scroll.heightAnchor   constraintEqualToConstant:36]
    ]];
    return container;
}

#pragma mark - Populate

-(void)populateContent {
    self.navigationItem.title = TO_NSSTRING(_release->title_ru);
    [_hero applyRelease:_release];

    [self updateBookmarkButton];
    [_list_button setMenu:[self buildListMenu]];
    [self updateListButton];

    // Chips row stays in the scaffold but is hidden — the Release struct in
    // libanixart doesn't surface genres as a separate field. Show category
    // and (when available) studio as light chips so the row carries weight.
    for (UIView* old in [_chips_stack.arrangedSubviews copy]) {
        [_chips_stack removeArrangedSubview:old];
        [old removeFromSuperview];
    }
    NSMutableArray<NSString*>* chip_titles = [NSMutableArray new];
    NSString* cat = [ReleasesPageableDataProvider getCategoryNameFor:_release->category];
    if (cat.length) [chip_titles addObject:cat];
    NSString* st  = [ReleasesPageableDataProvider getStatusNameFor:_release->status];
    if (st.length)  [chip_titles addObject:st];
    if (_release->season != anixart::Release::Season::Unknown) {
        [chip_titles addObject:[ReleasesPageableDataProvider getSeasonNameFor:_release->season]];
    }
    for (NSString* t in chip_titles) {
        GenreChip* chip = [GenreChip new];
        chip.text = t;
        [_chips_stack addArrangedSubview:chip];
    }
    _chips_scroll.hidden = chip_titles.count == 0;

    // Description
    [_description_label setText:TO_NSSTRING(_release->description)];

    // Info rows — rebuild from scratch each time.
    for (UIView* old in [_info_stack.arrangedSubviews copy]) {
        [_info_stack removeArrangedSubview:old];
        [old removeFromSuperview];
    }
    [self addInfoKey:@"Студия"        value:TO_NSSTRING(_release->studio)];
    NSString* season_str = nil;
    if (_release->season != anixart::Release::Season::Unknown) {
        season_str = [NSString stringWithFormat:@"%@ %@",
            [ReleasesPageableDataProvider getSeasonNameFor:_release->season],
            TO_NSSTRING(_release->year)];
    } else if (!_release->year.empty()) {
        season_str = TO_NSSTRING(_release->year);
    }
    [self addInfoKey:@"Сезон"         value:season_str];
    [self addInfoKey:@"Страна"        value:TO_NSSTRING(_release->country)];
    [self addInfoKey:@"Категория"     value:[ReleasesPageableDataProvider getCategoryNameFor:_release->category]];
    [self addInfoKey:@"Статус"        value:[ReleasesPageableDataProvider getStatusNameFor:_release->status]];

    NSString* total = _release->episodes_total > 0 ? [@(_release->episodes_total) stringValue] : @"?";
    [self addInfoKey:@"Эпизоды"       value:[NSString stringWithFormat:@"%d / %@", _release->episodes_released, total]];
    if (_release->duration.count() > 0) {
        [self addInfoKey:@"Длительность" value:[NSString stringWithFormat:@"%ld мин", (long)_release->duration.count()]];
    }
    if (!_release->director.empty()) [self addInfoKey:@"Режиссёр" value:TO_NSSTRING(_release->director)];
    if (!_release->author.empty())   [self addInfoKey:@"Автор"    value:TO_NSSTRING(_release->author)];

    // Previews carousel — only if there are screenshots.
    if (!_previews_rail && !_release->screenshot_image_urls.empty()) {
        _previews_rail = [PreviewsRail new];
        [_previews_rail setRelease:_release];
        [_content_stack addArrangedSubview:[self sectionWithHeader:@"Кадры" content:_previews_rail showAll:NO onShowAll:nil]];
    } else if (_previews_rail) {
        [_previews_rail setRelease:_release];
    }

    // Related rail — reuse the existing horizontal collection.
    if (!_related_carousel && !_release->related_releases.empty()) {
        ReleasesPageableDataProvider* p = [[ReleasesPageableDataProvider alloc]
            initWithPages:nullptr initialReleases:_release->related_releases];
        _related_carousel = [[ReleasesCollectionViewController alloc]
            initWithReleasesPageableDataProvider:p axis:UICollectionViewScrollDirectionHorizontal];
        [self addChildViewController:_related_carousel];

        __weak __typeof__(self) ws = self;
        UIView* relatedSection = [self sectionWithHeader:@"Похожие" content:_related_carousel.view showAll:YES onShowAll:^{
            __strong __typeof__(ws) ss = ws; if (!ss) return;
            [ss showAllRelated];
        }];
        [_content_stack addArrangedSubview:relatedSection];
        [_related_carousel didMoveToParentViewController:self];
    }
}

-(void)addInfoKey:(NSString*)key value:(NSString*)value {
    InfoRow* row = [[InfoRow alloc] initWithKey:key value:value];
    [_info_stack addArrangedSubview:row];
}

-(UIView*)sectionWithHeader:(NSString*)title content:(UIView*)content showAll:(BOOL)showAll onShowAll:(void(^)(void))onShowAll {
    SectionHeader* header = [[SectionHeader alloc] initWithTitle:title showAll:showAll onShowAll:onShowAll];

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[[self wrapMargins:header], content]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = AppSpacing12;
    // PreviewsRail manages its own height (104); only the related-releases
    // carousel needs a fixed wrapper height (poster + title strip).
    BOOL is_previews_rail = [content isKindOfClass:PreviewsRail.class];
    if (!is_previews_rail
        && [content isKindOfClass:UIView.class]
        && !([content isKindOfClass:UICollectionView.class])) {
        [content.heightAnchor constraintEqualToConstant:228].active = YES;
    }
    return stack;
}

#pragma mark - State updates

-(void)updateBookmarkButton {
    NSString* sym = _release->is_favorite ? @"bookmark.fill" : @"bookmark";
    [_bookmark_button setImage:[UIImage systemImageNamed:sym] forState:UIControlStateNormal];
}

-(void)updateListButton {
    BOOL is_in_list = _release->profile_list_status != anixart::Profile::ListStatus::NotWatching;
    NSString* sym = is_in_list ? @"checkmark" : @"list.bullet";
    [_list_button setImage:[UIImage systemImageNamed:sym] forState:UIControlStateNormal];
}

-(UIMenu*)buildListMenu {
    NSArray<NSNumber*>* statuses = @[
        @((NSInteger)anixart::Profile::ListStatus::Watching),
        @((NSInteger)anixart::Profile::ListStatus::Plan),
        @((NSInteger)anixart::Profile::ListStatus::Watched),
        @((NSInteger)anixart::Profile::ListStatus::HoldOn),
        @((NSInteger)anixart::Profile::ListStatus::Dropped),
        @((NSInteger)anixart::Profile::ListStatus::NotWatching),
    ];
    NSMutableArray<UIAction*>* actions = [NSMutableArray new];
    for (NSNumber* statusNum in statuses) {
        anixart::Profile::ListStatus s = (anixart::Profile::ListStatus)statusNum.integerValue;
        NSString* title = [ProfileListsView getListStatusName:s];
        UIAction* a = [UIAction actionWithTitle:title image:nil identifier:nil handler:^(UIAction* _) {
            [self setListStatus:s];
        }];
        if (_release && _release->profile_list_status == s) a.state = UIMenuElementStateOn;
        [actions addObject:a];
    }
    return [UIMenu menuWithChildren:actions];
}

#pragma mark - Actions

-(void)onWatchTapped {
    [self.navigationController pushViewController:[[TypeSelectViewController alloc] initWithReleaseID:_release->id] animated:YES];
}

-(void)onBookmarkTapped {
    BOOL turn_on = !_release->is_favorite;
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        if (turn_on) api->releases().add_release_to_favorites(self->_release->id);
        else         api->releases().remove_release_from_favorites(self->_release->id);
        return YES;
    } withUICompletion:^{
        self->_release->is_favorite = turn_on;
        [self updateBookmarkButton];
    }];
}

-(void)setListStatus:(anixart::Profile::ListStatus)status {
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        api->releases().add_release_to_profile_list(self->_release->id, status);
        return YES;
    } withUICompletion:^{
        self->_release->profile_list_status = status;
        [self updateListButton];
        [self->_list_button setMenu:[self buildListMenu]];
    }];
}

-(void)showAllRelated {
    if (!_release->related) return;
    auto pages = _api_proxy.api->releases().release_related(_release->related->id, 0);
    ReleasesViewController* vc = [[ReleasesViewController alloc] initWithPages:std::move(pages)];
    vc.title = @"Похожие";
    [self.navigationController pushViewController:vc animated:YES];
}

@end
