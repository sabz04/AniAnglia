//
//  CollectionViewController.m
//  AniAnglia
//
//  Created by Toilettrauma on 18.04.2025.
//

#import <Foundation/Foundation.h>
#import "CollectionViewController.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppBackdrop.h"
#import "AppHaptics.h"
#import "StringCvt.h"
#import "ReleasesTableViewController.h"
#import "LoadableView.h"
#import "ExpandableLabel.h"
#import "ProfileListsView.h"
#import "TimeCvt.h"
#import "CommentsTableViewController.h"
#import "ReleaseViewController.h"
#import "CommentRepliesViewController.h"
#import "ProfileViewController.h"
#import "NamedSectionView.h"

@class CollectionTableHeaderView;
@class CollectionTableAuthorView;

@protocol CollectionTableAuthorViewDelegate <NSObject>
-(void)didAuthorAvatarPressedForCollectionTableAuthorView:(CollectionTableAuthorView*)collection_table_author_view;
@end

@protocol CollectionTableHeaderViewDelegate <NSObject>
-(void)didAuthorAvatarPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view;
-(void)didDescriptionExpandPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view;
-(void)didBookmarkPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view;
-(void)didCommentsPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view;
-(void)didRandomPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view;
@end

@interface CollectionReleasesTableViewController : ReleasesTableViewController
@property(nonatomic, copy) void(^on_refresh_handler)();

@end

@interface CollectionTableHeaderListsView : UIView

@end

@interface CollectionTableAuthorView : UIView {
    anixart::Collection::Ptr _collection;
}
@property(nonatomic, weak) id<CollectionTableAuthorViewDelegate> delegate;
@property(nonatomic, retain) UIButton* avatar_button;
@property(nonatomic, retain) LoadableImageView* avatar_view;
@property(nonatomic, retain) UILabel* username_label;

-(instancetype)initWithCollection:(anixart::Collection::Ptr)collection;
@end

@interface CollectionTableHeaderView : UIView <CollectionTableAuthorViewDelegate, ExpandableLabelDelegate> {
    anixart::CollectionGetInfo::Ptr _collection_get_info;
    anixart::Collection::Ptr _collection;
}
@property(nonatomic, weak) id<CollectionTableHeaderViewDelegate> delegate;
@property(nonatomic, retain) UIStackView* content_stack_view;
@property(nonatomic, retain) LoadableImageView* image_view;
@property(nonatomic, retain) UILabel* title_label;
@property(nonatomic, retain) UILabel* created_date_label;
@property(nonatomic, retain) UILabel* updated_date_label;
@property(nonatomic, retain) UIStackView* actions_stack_view;
@property(nonatomic, retain) UIButton* bookmark_button;
@property(nonatomic, retain) UIButton* comments_button;
@property(nonatomic, retain) CollectionTableAuthorView* author_view;
@property(nonatomic, retain) ExpandableLabel* description_label;
@property(nonatomic, retain) ProfileListsView* lists_view;
@property(nonatomic, retain) NamedSectionView* lists_section_view;
@property(nonatomic, retain) UIButton* random_button;

-(instancetype)initWithCollectionGetInfo:(anixart::CollectionGetInfo::Ptr)collection_get_info;

-(void)updateBookmarkButton;
@end

@interface CollectionViewController () <CollectionTableHeaderViewDelegate, CommentsTableViewControllerDelegate> {
    anixart::CollectionID _collection_id;
    anixart::Collection::Ptr _collection;
    anixart::CollectionGetInfo::Ptr _collection_get_info;
}
@property(nonatomic, strong) LibanixartApi* api_proxy;
@property(nonatomic, retain) LoadableView* loadable_view;
@property(nonatomic, retain) CollectionTableHeaderView* header_view;
@property(nonatomic, retain) CollectionReleasesTableViewController* releases_view_controller;
@property(nonatomic) BOOL is_ui_inited;

@end

@implementation CollectionReleasesTableViewController

-(void)refresh {
    if (_on_refresh_handler) {
        _on_refresh_handler();
    }
    [super refresh];
}

@end

@implementation CollectionTableAuthorView

-(instancetype)init {
    self = [super init];
    
    [self setup];
    [self setupLayout];
    
    return self;
}

-(instancetype)initWithCollection:(anixart::Collection::Ptr)collection {
    self = [self init];
    
    [self setCollection:collection];
    
    return self;
}

-(void)setup {
    // Compact author row: 40pt circular avatar + eyebrow ("Автор") above the
    // username — Apple Music / Letterboxd convention. Whole row is tappable
    // and pushes the author's profile.
    _avatar_button = [UIButton new];
    [_avatar_button addTarget:self action:@selector(onAvatarPressed:) forControlEvents:UIControlEventTouchUpInside];
    _avatar_button.clipsToBounds = YES;
    _avatar_button.layer.cornerRadius = 20;
    _avatar_button.translatesAutoresizingMaskIntoConstraints = NO;

    _avatar_view = [LoadableImageView new];
    _avatar_view.contentMode = UIViewContentModeScaleAspectFill;
    _avatar_view.userInteractionEnabled = NO;
    _avatar_view.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel* eyebrow = [UILabel new];
    eyebrow.text = NSLocalizedString(@"app.release.general.author_info.author", nil);
    eyebrow.font = [UIFont app_fontForStyle:AppTextStyleCaption1 weight:UIFontWeightSemibold];
    eyebrow.textColor = [AppColorProvider textTertiaryColor];

    _username_label = [UILabel new];
    _username_label.textAlignment = NSTextAlignmentLeft;
    _username_label.numberOfLines = 1;
    _username_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _username_label.textColor = [AppColorProvider textColor];

    UIStackView* text_stack = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, _username_label]];
    text_stack.axis = UILayoutConstraintAxisVertical;
    text_stack.spacing = 0;
    text_stack.alignment = UIStackViewAlignmentLeading;
    text_stack.translatesAutoresizingMaskIntoConstraints = NO;
    text_stack.userInteractionEnabled = NO;

    [self addSubview:_avatar_button];
    [_avatar_button addSubview:_avatar_view];
    [self addSubview:text_stack];

    [NSLayoutConstraint activateConstraints:@[
        [_avatar_button.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_avatar_button.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_avatar_button.heightAnchor   constraintEqualToConstant:40],
        [_avatar_button.widthAnchor    constraintEqualToAnchor:_avatar_button.heightAnchor],
        [_avatar_button.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

        [_avatar_view.topAnchor      constraintEqualToAnchor:_avatar_button.topAnchor],
        [_avatar_view.leadingAnchor  constraintEqualToAnchor:_avatar_button.leadingAnchor],
        [_avatar_view.trailingAnchor constraintEqualToAnchor:_avatar_button.trailingAnchor],
        [_avatar_view.bottomAnchor   constraintEqualToAnchor:_avatar_button.bottomAnchor],

        [text_stack.leadingAnchor  constraintEqualToAnchor:_avatar_button.trailingAnchor constant:AppSpacing12],
        [text_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [text_stack.centerYAnchor  constraintEqualToAnchor:_avatar_button.centerYAnchor],
    ]];

    _avatar_view.backgroundColor = [AppColorProvider posterPlaceholderColor];
}

-(void)setupLayout {
    // Colors are set inline; this method kept as a no-op so existing trait
    // callers don't trip an unrecognized-selector.
}

-(void)refresh {
    _username_label.text = TO_NSSTRING(_collection->creator->username);
    
    NSURL* avatar_url = [NSURL URLWithString:TO_NSSTRING(_collection->creator->avatar_url)];
    [_avatar_view tryLoadImageWithURL:avatar_url];
}

-(void)setCollection:(anixart::Collection::Ptr)collection {
    _collection = collection;
    [self refresh];
}

-(IBAction)onAvatarPressed:(UIButton*)sender {
    [_delegate didAuthorAvatarPressedForCollectionTableAuthorView:self];
}

@end

@implementation CollectionTableHeaderView

-(instancetype)init {
    self = [super init];
    
    [self setup];
    [self setupLayout];
    
    return self;
}

-(instancetype)initWithCollectionGetInfo:(anixart::CollectionGetInfo::Ptr)collection_get_info {
    self = [self init];
    
    [self setCollectionGetInfo:collection_get_info];
    
    return self;
}

// yukimo collection header — cover image (16:9) with bottom-up scrim + title
// overlay, author row, action row (coral "Случайное" CTA + ghost bookmark /
// comments), and a left-aligned description. ProfileListsView is rendered
// below as a stats summary.
-(void)setup {
    self.layoutMargins = UIEdgeInsetsZero;

    // === Cover hero ===
    UIView* hero_container = [UIView new];
    hero_container.translatesAutoresizingMaskIntoConstraints = NO;
    hero_container.clipsToBounds = YES;
    hero_container.layer.cornerRadius = AppRadiusXLarge;
    hero_container.layer.cornerCurve = kCACornerCurveContinuous;
    hero_container.backgroundColor = [AppColorProvider posterPlaceholderColor];

    _image_view = [LoadableImageView new];
    _image_view.clipsToBounds = YES;
    _image_view.contentMode = UIViewContentModeScaleAspectFill;
    _image_view.translatesAutoresizingMaskIntoConstraints = NO;

    UIView* scrim = [UIView new];
    scrim.translatesAutoresizingMaskIntoConstraints = NO;
    scrim.userInteractionEnabled = NO;
    CAGradientLayer* scrim_layer = [CAGradientLayer layer];
    scrim_layer.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.65].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.90].CGColor,
    ];
    scrim_layer.locations = @[@0.0, @0.55, @1.0];
    [scrim.layer addSublayer:scrim_layer];
    // Tag so layoutSubviews can find it later.
    scrim.tag = 9001;

    _title_label = [UILabel new];
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleTitle2 weight:UIFontWeightBold];
    _title_label.textAlignment = NSTextAlignmentLeft;
    _title_label.numberOfLines = 3;
    _title_label.textColor = UIColor.whiteColor;
    _title_label.adjustsFontForContentSizeCategory = YES;
    _title_label.translatesAutoresizingMaskIntoConstraints = NO;
    _title_label.layer.shadowColor   = UIColor.blackColor.CGColor;
    _title_label.layer.shadowOpacity = 0.6;
    _title_label.layer.shadowRadius  = 6;
    _title_label.layer.shadowOffset  = CGSizeMake(0, 1);

    [hero_container addSubview:_image_view];
    [hero_container addSubview:scrim];
    [hero_container addSubview:_title_label];

    // === Author row ===
    _author_view = [CollectionTableAuthorView new];
    _author_view.delegate = self;
    _author_view.translatesAutoresizingMaskIntoConstraints = NO;

    // === Dates row (compact secondary text) ===
    _created_date_label = [UILabel new];
    _created_date_label.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _created_date_label.textColor = [AppColorProvider textTertiaryColor];
    _created_date_label.numberOfLines = 1;

    _updated_date_label = [UILabel new];
    _updated_date_label.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _updated_date_label.textColor = [AppColorProvider textTertiaryColor];
    _updated_date_label.numberOfLines = 1;

    UIStackView* dates_stack = [[UIStackView alloc] initWithArrangedSubviews:@[_created_date_label, _updated_date_label]];
    dates_stack.axis = UILayoutConstraintAxisVertical;
    dates_stack.spacing = AppSpacing2;
    dates_stack.alignment = UIStackViewAlignmentLeading;
    dates_stack.translatesAutoresizingMaskIntoConstraints = NO;

    // === Action row: coral CTA "Случайное" + glass bookmark + glass comments ===
    _random_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_random_button setTitle:NSLocalizedString(@"app.collection.random.title", nil) forState:UIControlStateNormal];
    [_random_button setImage:[UIImage systemImageNamed:@"shuffle"] forState:UIControlStateNormal];
    [_random_button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _random_button.tintColor = UIColor.whiteColor;
    _random_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline weight:UIFontWeightSemibold];
    _random_button.backgroundColor = [AppColorProvider primaryColor];
    _random_button.layer.cornerRadius = AppRadiusLarge;
    _random_button.layer.cornerCurve = kCACornerCurveContinuous;
    _random_button.contentEdgeInsets = UIEdgeInsetsMake(0, AppSpacing20, 0, AppSpacing20);
    _random_button.titleEdgeInsets   = UIEdgeInsetsMake(0, AppSpacing8, 0, 0);
    [_random_button addTarget:self action:@selector(onRandomButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    _bookmark_button = [self makeSecondaryActionWithSymbol:@"bookmark"];
    [_bookmark_button addTarget:self action:@selector(onBookmarkButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    _comments_button = [self makeSecondaryActionWithSymbol:@"message"];
    [_comments_button addTarget:self action:@selector(onCommentsButtonPressed:) forControlEvents:UIControlEventTouchUpInside];

    _actions_stack_view = [[UIStackView alloc] initWithArrangedSubviews:@[_random_button, _bookmark_button, _comments_button]];
    _actions_stack_view.axis = UILayoutConstraintAxisHorizontal;
    _actions_stack_view.spacing = AppSpacing12;
    _actions_stack_view.alignment = UIStackViewAlignmentFill;
    _actions_stack_view.translatesAutoresizingMaskIntoConstraints = NO;
    [_random_button setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [_bookmark_button setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    [_comments_button setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    // === Description ===
    _description_label = [ExpandableLabel new];
    _description_label.delegate = self;
    _description_label.translatesAutoresizingMaskIntoConstraints = NO;

    // === Stats / lists ===
    _lists_view = [ProfileListsView new];
    _lists_section_view = [[NamedSectionView alloc] initWithName:NSLocalizedString(@"app.collection.lists", nil) view:_lists_view];
    _lists_section_view.translatesAutoresizingMaskIntoConstraints = NO;

    // === Main stack ===
    _content_stack_view = [[UIStackView alloc] initWithArrangedSubviews:@[
        hero_container, _author_view, dates_stack, _actions_stack_view,
        _description_label, _lists_section_view,
    ]];
    _content_stack_view.axis = UILayoutConstraintAxisVertical;
    _content_stack_view.alignment = UIStackViewAlignmentFill;
    _content_stack_view.spacing = AppSpacing16;
    [_content_stack_view setCustomSpacing:AppSpacing20 afterView:_actions_stack_view];
    _content_stack_view.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_content_stack_view];

    [NSLayoutConstraint activateConstraints:@[
        [_content_stack_view.topAnchor      constraintEqualToAnchor:self.topAnchor    constant:AppSpacing16],
        [_content_stack_view.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_content_stack_view.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_content_stack_view.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor constant:-AppSpacing20],

        // Cover hero
        [hero_container.heightAnchor constraintEqualToAnchor:hero_container.widthAnchor multiplier:9.0/16.0],
        [_image_view.topAnchor       constraintEqualToAnchor:hero_container.topAnchor],
        [_image_view.leadingAnchor   constraintEqualToAnchor:hero_container.leadingAnchor],
        [_image_view.trailingAnchor  constraintEqualToAnchor:hero_container.trailingAnchor],
        [_image_view.bottomAnchor    constraintEqualToAnchor:hero_container.bottomAnchor],
        [scrim.leadingAnchor         constraintEqualToAnchor:hero_container.leadingAnchor],
        [scrim.trailingAnchor        constraintEqualToAnchor:hero_container.trailingAnchor],
        [scrim.bottomAnchor          constraintEqualToAnchor:hero_container.bottomAnchor],
        [scrim.heightAnchor          constraintEqualToAnchor:hero_container.heightAnchor multiplier:0.65],
        [_title_label.leadingAnchor  constraintEqualToAnchor:hero_container.leadingAnchor  constant:AppSpacing16],
        [_title_label.trailingAnchor constraintEqualToAnchor:hero_container.trailingAnchor constant:-AppSpacing16],
        [_title_label.bottomAnchor   constraintEqualToAnchor:hero_container.bottomAnchor   constant:-AppSpacing16],

        // Action row buttons height
        [_random_button.heightAnchor   constraintEqualToConstant:52],
        [_bookmark_button.widthAnchor  constraintEqualToConstant:52],
        [_bookmark_button.heightAnchor constraintEqualToConstant:52],
        [_comments_button.widthAnchor  constraintEqualToConstant:52],
        [_comments_button.heightAnchor constraintEqualToConstant:52],
    ]];
}

-(UIButton*)makeSecondaryActionWithSymbol:(NSString*)symbol {
    UIButton* b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    b.tintColor = [AppColorProvider primaryColor];
    b.backgroundColor = [AppColorProvider primarySoftColor];
    b.layer.cornerRadius = AppRadiusLarge;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    [b setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightSemibold]
                       forImageInState:UIControlStateNormal];
    return b;
}

// Re-position the scrim's CAGradientLayer when the hero resizes.
-(void)layoutSubviews {
    [super layoutSubviews];
    UIView* hero = nil;
    for (UIView* v in _content_stack_view.arrangedSubviews) {
        if ([v viewWithTag:9001]) { hero = v; break; }
    }
    UIView* scrim = [hero viewWithTag:9001];
    if (scrim.layer.sublayers.firstObject) {
        scrim.layer.sublayers.firstObject.frame = scrim.bounds;
    }
}

-(void)setupLayout { /* All colors set inline above. */ }

-(void)refresh {
    _title_label.text = TO_NSSTRING(_collection->title);

    _created_date_label.text = [NSString stringWithFormat:@"%@: %@",
        NSLocalizedString(@"app.collection.created.start", nil),
        [NSDateFormatter localizedStringFromDate:anix_time_point_to_nsdate(_collection->creation_date)
                                       dateStyle:NSDateFormatterMediumStyle
                                       timeStyle:NSDateFormatterNoStyle]];

    _updated_date_label.text = [NSString stringWithFormat:@"%@: %@",
        NSLocalizedString(@"app.collection.updated.start", nil),
        [NSDateFormatter localizedStringFromDate:anix_time_point_to_nsdate(_collection->last_update_date)
                                       dateStyle:NSDateFormatterMediumStyle
                                       timeStyle:NSDateFormatterNoStyle]];

    [self updateBookmarkButton];
    [_author_view setCollection:_collection];
    [_description_label setText:TO_NSSTRING(_collection->description)];
    [_lists_view setFromCollectionGetInfo:_collection_get_info];

    NSURL* image_url = [NSURL URLWithString:TO_NSSTRING(_collection->image_url)];
    [_image_view tryLoadImageWithURL:image_url];
}

-(void)updateBookmarkButton {
    NSString* sym = _collection->is_favorite ? @"bookmark.fill" : @"bookmark";
    [_bookmark_button setImage:[UIImage systemImageNamed:sym] forState:UIControlStateNormal];
}

-(void)setCollectionGetInfo:(anixart::CollectionGetInfo::Ptr)collection_get_info {
    _collection_get_info = collection_get_info;
    _collection = collection_get_info->collection;
    
    [self refresh];
}

-(IBAction)onBookmarkButtonPressed:(UIButton*)sender {
    [_delegate didBookmarkPressedForCollectionTableHeaderView:self];
}
-(IBAction)onCommentsButtonPressed:(UIButton*)sender {
    [_delegate didCommentsPressedForCollectionTableHeaderView:self];
}
-(IBAction)onRandomButtonPressed:(UIButton*)sender {
    [_delegate didRandomPressedForCollectionTableHeaderView:self];
}

-(void)didAuthorAvatarPressedForCollectionTableAuthorView:(CollectionTableAuthorView*)collection_table_author_view {
    [_delegate didAuthorAvatarPressedForCollectionTableHeaderView:self];
}

-(void)didExpandPressedForExpandableLabel:(ExpandableLabel*)expandable_label {
    [_delegate didDescriptionExpandPressedForCollectionTableHeaderView:self];
}

@end

@implementation CollectionViewController

-(instancetype)initWithCollectionID:(anixart::CollectionID)collection_id {
    self = [super init];
    
    _api_proxy = [LibanixartApi sharedInstance];
    _collection_id = collection_id;
    _is_ui_inited = NO;
    
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [self preSetup];
    [self preSetupLayout];
    
    [self loadCollection];
}

-(void)preSetup {
    _loadable_view = [LoadableView new];
    
    [self.view addSubview:_loadable_view];
    
    _loadable_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_loadable_view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_loadable_view.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_loadable_view.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_loadable_view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
}

-(void)setup {
    __weak auto weak_self = self;
    
    _header_view = [[CollectionTableHeaderView alloc] initWithCollectionGetInfo:_collection_get_info];
    _header_view.delegate = self;
    
    _releases_view_controller = [[CollectionReleasesTableViewController alloc] initWithTableView:[UITableView new] pages:_api_proxy.api->collections().collection_releases(_collection->id, 0)];
    _releases_view_controller.on_refresh_handler = ^{
        [weak_self onRefresh];
    };
    [self addChildViewController:_releases_view_controller];
    [_releases_view_controller setHeaderView:_header_view];
    
    [self.view addSubview:_releases_view_controller.view];
    
    _header_view.translatesAutoresizingMaskIntoConstraints = NO;
    _releases_view_controller.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_releases_view_controller.view.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_releases_view_controller.view.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [_releases_view_controller.view.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [_releases_view_controller.view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        
        [_header_view.topAnchor constraintGreaterThanOrEqualToAnchor:_releases_view_controller.view.topAnchor],
        [_header_view.leadingAnchor constraintEqualToAnchor:_releases_view_controller.view.layoutMarginsGuide.leadingAnchor],
        [_header_view.trailingAnchor constraintEqualToAnchor:_releases_view_controller.view.layoutMarginsGuide.trailingAnchor],
        [_header_view.bottomAnchor constraintLessThanOrEqualToAnchor:_releases_view_controller.view.bottomAnchor],
    ]];
    
    [_releases_view_controller didMoveToParentViewController:self];
    
    _is_ui_inited = YES;
}

-(void)preSetupLayout {
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [AppBackdrop installIn:self.view];
}

-(void)setupLayout {
    
}

-(void)loadCollection {
    [_loadable_view startLoading];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        self->_collection_get_info = api->collections().get_collection(self->_collection_id);
        self->_collection = self->_collection_get_info->collection;
        return NO;
    } completion:^(BOOL errored) {
        [self onCollectionLoaded:errored];
    }];
}

-(void)onCollectionLoaded:(BOOL)errored {
    [self->_loadable_view endLoading];
    
    if (!_is_ui_inited) {
        [self setup];
        [self setupLayout];
    }
    [_header_view setCollectionGetInfo:_collection_get_info];
}

-(void)didBookmarkPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view {
    BOOL to_set_bookmarked = !_collection->is_favorite;
    
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api) {
        if (to_set_bookmarked) {
            api->collections().add_collection_to_favorites(self->_collection->id);
        } else {
            api->collections().remove_collection_from_favorites(self->_collection->id);
        }
        return YES;
    } withUICompletion:^{
        self->_collection->is_favorite = to_set_bookmarked;
        [self->_header_view updateBookmarkButton];
    }];
}
-(void)didCommentsPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view {
    CommentsTableViewController* comments_view_controller = [[CommentsTableViewController alloc] initWithTableView:[UITableView new] pages:_api_proxy.api->collections().collection_comments(_collection->id, anixart::Comment::Sort::Newest, 0)];
    comments_view_controller.delegate = self;
    [self.navigationController pushViewController:comments_view_controller animated:YES];
}
-(void)didRandomPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view {
    [self.navigationController pushViewController:[[ReleaseViewController alloc] initWithRandomCollectionRelease:_collection->id] animated:YES];
}

-(void)didReplyPressedForCommentsTableView:(UITableView *)table_view comment:(anixart::Comment::Ptr)comment {
    [self.navigationController pushViewController:[[CommentRepliesViewController alloc] initWithReplyToComment:comment] animated:YES];
}

-(void)didAuthorAvatarPressedForCollectionTableHeaderView:(CollectionTableHeaderView *)collection_table_header_view {
    [self.navigationController pushViewController:[[ProfileViewController alloc] initWithProfileID:_collection->creator->id] animated:YES];
}

-(void)didDescriptionExpandPressedForCollectionTableHeaderView:(CollectionTableHeaderView*)collection_table_header_view {
    [self.view layoutIfNeeded];
    [_releases_view_controller setHeaderView:_header_view];
}

-(void)onRefresh {
    [self loadCollection];
}

@end
