//
//  ReleasesCollectionViewController.mm
//
//  Grid (or horizontal carousel) of release poster cells.
//
//  Cell: 2:3 poster with a small rating chip ("★ 8.5") and a list-status
//  pill anchored at the top corners, followed by a 2-line footnote title
//  underneath. No oversized badges, no awkward partial corner radii.
//
//  Public API on both `ReleaseCollectionViewCell` and
//  `ReleasesCollectionViewController` is unchanged.
//

#import "ReleasesCollectionViewController.h"
#import "LoadableView.h"
#import "AppColor.h"
#import "ReleaseTableViewCell.h"
#import "StringCvt.h"
#import "ReleaseViewController.h"
#import "ProfileListsView.h"

static CGFloat const kGridLineSpacing = 20;     // vertical gap between rows
static CGFloat const kGridItemSpacing = 12;     // horizontal gap between items
static CGFloat const kGridSectionInsetX = 16;   // matches Apple's standard layout margin
static CGFloat const kCellLabelHeight = 56;     // title 2 lines (Subheadline-Semibold) + padding

#pragma mark - Padded chip label

/// UILabel subclass with real edge insets, so intrinsicContentSize accounts
/// for horizontal padding without us hacking whitespace into the text.
@interface ChipLabel : UILabel
@property(nonatomic) UIEdgeInsets contentInsets;
@end

@implementation ChipLabel
-(void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, _contentInsets)];
}
-(CGSize)intrinsicContentSize {
    CGSize s = [super intrinsicContentSize];
    s.width  += _contentInsets.left + _contentInsets.right;
    s.height += _contentInsets.top  + _contentInsets.bottom;
    return s;
}
@end


@interface ReleaseCollectionViewCell ()
@property(nonatomic, retain) LoadableImageView* image_view;
@property(nonatomic, retain) UILabel* title_label;
@property(nonatomic, retain) ChipLabel* rating_badge;
@property(nonatomic, retain) ChipLabel* list_status_badge;
@end

@interface ReleasesCollectionViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching, UICollectionViewDelegateFlowLayout>
@property(nonatomic) UICollectionViewScrollDirection axis;
@property(nonatomic) NSInteger axis_item_count;
@property(nonatomic, retain) ReleasesPageableDataProvider* data_provider;
@property(nonatomic, retain) UICollectionView* collection_view;
@property(nonatomic, retain) LoadableView*     loadable_view;
@property(nonatomic, retain) UIStackView*      empty_state_stack;
@end


#pragma mark - ReleaseCollectionViewCell

@implementation ReleaseCollectionViewCell

+(NSString*)getIdentifier { return @"ReleaseCollectionViewCell"; }

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    [self setup];
    return self;
}

-(void)setup {
    _image_view = [LoadableImageView new];
    _image_view.clipsToBounds = YES;
    _image_view.layer.cornerRadius = AppRadiusMedium;
    _image_view.layer.cornerCurve = kCACornerCurveContinuous;
    _image_view.contentMode = UIViewContentModeScaleAspectFill;
    _image_view.backgroundColor = [AppColorProvider posterPlaceholderColor];

    // Same Subheadline-Semibold as the list row — keeps titles legible in
    // 3-up grids and matches whatever screen the user just came from.
    _title_label = [UILabel new];
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _title_label.textColor = [AppColorProvider textColor];
    _title_label.numberOfLines = 2;
    _title_label.adjustsFontForContentSizeCategory = YES;

    // Rating chip in the top-trailing corner. Monospaced digits + Caption1
    // size matches the list row meta line for cross-screen consistency.
    _rating_badge = [self makeChip];
    _rating_badge.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleCaption1 weight:UIFontWeightBold];
    _rating_badge.hidden = YES;

    _list_status_badge = [self makeChip];
    _list_status_badge.font = [UIFont app_fontForStyle:AppTextStyleCaption1 weight:UIFontWeightSemibold];
    _list_status_badge.hidden = YES;

    [self.contentView addSubview:_image_view];
    [_image_view addSubview:_rating_badge];
    [_image_view addSubview:_list_status_badge];
    [self.contentView addSubview:_title_label];

    _image_view.translatesAutoresizingMaskIntoConstraints = NO;
    _title_label.translatesAutoresizingMaskIntoConstraints = NO;
    _rating_badge.translatesAutoresizingMaskIntoConstraints = NO;
    _list_status_badge.translatesAutoresizingMaskIntoConstraints = NO;

    [NSLayoutConstraint activateConstraints:@[
        // Poster — edge to edge of the cell, 2:3 ratio.
        [_image_view.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor],
        [_image_view.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_image_view.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_image_view.heightAnchor   constraintEqualToAnchor:_image_view.widthAnchor multiplier:(3.0/2.0)],

        // Rating chip — top-trailing, inset 6pt. Width / height intrinsic.
        [_rating_badge.topAnchor      constraintEqualToAnchor:_image_view.topAnchor constant:AppSpacing6],
        [_rating_badge.trailingAnchor constraintEqualToAnchor:_image_view.trailingAnchor constant:-AppSpacing6],

        // List-status chip — top-leading.
        [_list_status_badge.topAnchor     constraintEqualToAnchor:_image_view.topAnchor constant:AppSpacing6],
        [_list_status_badge.leadingAnchor constraintEqualToAnchor:_image_view.leadingAnchor constant:AppSpacing6],

        // Title — directly under the poster, two lines max.
        [_title_label.topAnchor      constraintEqualToAnchor:_image_view.bottomAnchor constant:AppSpacing8],
        [_title_label.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_title_label.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_title_label.bottomAnchor   constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor]
    ]];
}

// Subtle rounded chip — tinted background with a soft border for readability
// over busy posters. Same shape conventions across both badges.
-(ChipLabel*)makeChip {
    ChipLabel* l = [ChipLabel new];
    l.contentInsets = UIEdgeInsetsMake(3, 8, 3, 8);
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = UIColor.whiteColor;
    l.layer.cornerRadius = 7;
    l.layer.cornerCurve = kCACornerCurveContinuous;
    l.clipsToBounds = YES;
    return l;
}

#pragma mark - Content

-(void)setImageUrl:(NSURL*)image_url { [_image_view tryLoadImageWithURL:image_url]; }

-(void)setTitle:(NSString*)title { _title_label.text = title; }

-(void)setSetEpisodeCount:(NSString*)episode_count {
    // The original API folded the episode count into the title area. In the
    // modern grid we keep titles clean and drop secondary meta — released
    // count is already visible on the detail screen and noisy in a grid.
    (void)episode_count;
}

-(void)setRating:(double)rating {
    if (rating <= 0) {
        _rating_badge.hidden = YES;
        return;
    }
    double rounded = round(rating * 10) / 10.0;
    _rating_badge.text = [NSString stringWithFormat:@"★ %@", [@(rounded) stringValue]];
    _rating_badge.backgroundColor = [ReleaseTableViewCell getBadgeColor:rating];
    _rating_badge.hidden = NO;
    [_rating_badge invalidateIntrinsicContentSize];
}

-(void)setListStatus:(anixart::Profile::ListStatus)list_status {
    if (list_status == anixart::Profile::ListStatus::NotWatching) {
        _list_status_badge.hidden = YES;
        return;
    }
    _list_status_badge.text = [ProfileListsView getListStatusName:list_status];
    _list_status_badge.backgroundColor = [ProfileListsView getColorForListStatus:list_status];
    _list_status_badge.hidden = NO;
    [_list_status_badge invalidateIntrinsicContentSize];
}

@end


#pragma mark - ReleasesCollectionViewController

@implementation ReleasesCollectionViewController

-(instancetype)initWithAxis:(UICollectionViewScrollDirection)axis {
    self = [super init];
    _axis = axis;
    _axis_item_count = 3;   // Default 3-up grid — Apple TV / App Store density.
    return self;
}

-(instancetype)initWithPages:(anixart::Pageable<anixart::Release>::UPtr)pages axis:(UICollectionViewScrollDirection)axis {
    self = [self initWithAxis:axis];
    _data_provider = [[ReleasesPageableDataProvider alloc] initWithPages:std::move(pages)];
    _data_provider.delegate = self;
    return self;
}

-(instancetype)initWithReleasesPageableDataProvider:(ReleasesPageableDataProvider*)provider axis:(UICollectionViewScrollDirection)axis {
    self = [self initWithAxis:axis];
    _data_provider = provider;
    _data_provider.delegate = self;
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [self setupViews];

    if (_data_provider) {
        [_loadable_view startLoading];
        [_data_provider loadCurrentPageIfNeeded];
    }
}

-(void)setupViews {
    UICollectionViewFlowLayout* layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = _axis;
    layout.minimumLineSpacing = kGridLineSpacing;
    layout.minimumInteritemSpacing = kGridItemSpacing;
    layout.sectionInset = UIEdgeInsetsMake(AppSpacing16, kGridSectionInsetX, AppSpacing16, kGridSectionInsetX);

    _collection_view = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collection_view.backgroundColor = UIColor.clearColor;
    [_collection_view registerClass:ReleaseCollectionViewCell.class forCellWithReuseIdentifier:[ReleaseCollectionViewCell getIdentifier]];
    _collection_view.dataSource = self;
    _collection_view.delegate   = self;
    _collection_view.prefetchDataSource = self;
    _collection_view.alwaysBounceVertical = (_axis == UICollectionViewScrollDirectionVertical);
    _collection_view.showsHorizontalScrollIndicator = NO;

    _loadable_view = [LoadableView new];

    // Native empty state: SF Symbol + secondary label.
    UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightRegular];
    UIImageView* empty_icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:cfg]];
    empty_icon.tintColor = [AppColorProvider textShyColor];

    UILabel* empty_label = [UILabel new];
    empty_label.text = @"Ничего не найдено";
    empty_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    empty_label.textColor = [AppColorProvider textSecondaryColor];
    empty_label.textAlignment = NSTextAlignmentCenter;

    _empty_state_stack = [[UIStackView alloc] initWithArrangedSubviews:@[empty_icon, empty_label]];
    _empty_state_stack.axis = UILayoutConstraintAxisVertical;
    _empty_state_stack.spacing = AppSpacing8;
    _empty_state_stack.alignment = UIStackViewAlignmentCenter;
    _empty_state_stack.hidden = YES;

    [self.view addSubview:_collection_view];
    [self.view addSubview:_loadable_view];
    [self.view addSubview:_empty_state_stack];

    _collection_view.translatesAutoresizingMaskIntoConstraints = NO;
    _loadable_view.translatesAutoresizingMaskIntoConstraints = NO;
    _empty_state_stack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_collection_view.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_collection_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_collection_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_collection_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        [_loadable_view.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_loadable_view.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],

        [_empty_state_stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_empty_state_stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_empty_state_stack.leadingAnchor  constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:AppSpacing24],
        [_empty_state_stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-AppSpacing24]
    ]];
}

#pragma mark - Public

-(void)setHeaderView:(UIView*)header_view { (void)header_view; /* not implemented */ }

-(void)setPages:(anixart::Pageable<anixart::Release>::UPtr)pages {
    [_data_provider setPages:std::move(pages)];
}

-(void)setReleasesPageableDataProvider:(ReleasesPageableDataProvider*)provider {
    _data_provider = provider;
    if (_data_provider) {
        _data_provider.delegate = self;
        [_data_provider loadCurrentPageIfNeeded];
        [self reloadData];
    }
}

-(void)reload  { [_data_provider reload]; }
-(void)refresh { [_data_provider refresh]; }
-(void)reloadData {
    [_collection_view reloadData];
}

-(void)setAxisItemCount:(NSInteger)axis_item_count {
    _axis_item_count = MAX(1, axis_item_count);
    [_collection_view reloadData];
}

#pragma mark - Collection data source / layout

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)collection_view { return 1; }
-(NSInteger)collectionView:(UICollectionView*)collection_view numberOfItemsInSection:(NSInteger)section {
    return _data_provider ? [_data_provider getItemsCount] : 0;
}

-(UICollectionViewCell*)collectionView:(UICollectionView*)collection_view cellForItemAtIndexPath:(NSIndexPath*)index_path {
    ReleaseCollectionViewCell* cell = [collection_view dequeueReusableCellWithReuseIdentifier:[ReleaseCollectionViewCell getIdentifier] forIndexPath:index_path];
    anixart::Release::Ptr release = [_data_provider getReleaseAtIndex:index_path.row];
    [cell setImageUrl:[NSURL URLWithString:TO_NSSTRING(release->image_url)]];
    [cell setTitle:TO_NSSTRING(release->title_ru)];
    [cell setRating:release->grade];
    [cell setListStatus:release->profile_list_status];
    return cell;
}

-(CGSize)collectionView:(UICollectionView*)collection_view
                 layout:(UICollectionViewLayout*)layout
sizeForItemAtIndexPath:(NSIndexPath*)index_path {
    UICollectionViewFlowLayout* flow = (UICollectionViewFlowLayout*)layout;

    if (_axis == UICollectionViewScrollDirectionHorizontal) {
        // Horizontal carousels — poster takes full height minus label,
        // then 2:3 aspect picks the width.
        CGFloat available_height = collection_view.bounds.size.height
            - flow.sectionInset.top - flow.sectionInset.bottom;
        CGFloat poster_height = MAX(0, available_height - kCellLabelHeight);
        CGFloat poster_width  = poster_height * (2.0 / 3.0);
        return CGSizeMake(poster_width, available_height);
    }

    // Vertical grid — divide content area by axis_item_count.
    CGFloat horizontal_inset = flow.sectionInset.left + flow.sectionInset.right;
    CGFloat spacing_total    = flow.minimumInteritemSpacing * (_axis_item_count - 1);
    CGFloat content_width    = collection_view.bounds.size.width - horizontal_inset - spacing_total;
    CGFloat item_width       = floor(content_width / _axis_item_count);
    CGFloat poster_height    = item_width * 1.5;     // 2:3
    return CGSizeMake(item_width, poster_height + kCellLabelHeight);
}

#pragma mark - Selection / context menu

-(UIContextMenuConfiguration*)collectionView:(UICollectionView*)cv
       contextMenuConfigurationForItemAtIndexPath:(NSIndexPath*)index_path
                                            point:(CGPoint)point {
    return [_data_provider getContextMenuConfigurationForItemAtIndex:index_path.row];
}

-(void)collectionView:(UICollectionView*)cv didSelectItemAtIndexPath:(NSIndexPath*)index_path {
    anixart::Release::Ptr release = [_data_provider getReleaseAtIndex:index_path.row];
    [self.navigationController pushViewController:[[ReleaseViewController alloc] initWithReleaseID:release->id] animated:YES];
}

#pragma mark - Prefetching

-(void)collectionView:(UICollectionView*)cv prefetchItemsAtIndexPaths:(NSArray<NSIndexPath*>*)index_paths {
    if ([_data_provider isEnd]) return;
    NSUInteger item_count = [cv numberOfItemsInSection:0];
    for (NSIndexPath* path in index_paths) {
        if (path.row >= (NSInteger)item_count - 1) {
            [_data_provider loadNextPage];
            return;
        }
    }
}

#pragma mark - PageableDataProviderDelegate

-(void)didUpdateDataForPageableDataProvider:(PageableDataProvider*)provider {
    [self reloadData];
}

-(void)pageableDataProvider:(PageableDataProvider*)provider didLoadPageAtIndex:(NSInteger)page_index {
    [_loadable_view endLoading];
    NSInteger count = (NSInteger)[_data_provider getItemsCount];
    _empty_state_stack.hidden = count != 0;
    [self reloadData];

    if (self.onDidLoadFirstPage) {
        // Fire once and detach — parent screens use this for one-time setup
        // (hiding empty rails) and don't want a callback on every pagination.
        void (^cb)(NSInteger) = self.onDidLoadFirstPage;
        self.onDidLoadFirstPage = nil;
        cb(count);
    }
}

@end
