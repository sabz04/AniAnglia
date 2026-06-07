//
//  SegmentedPageViewController.mm
//
//  Scrolling tab bar paired with a swipeable page controller.
//  Inspired by Apple News / App Store: text labels with an animated
//  underline that tracks the active page.
//
//  Public API is unchanged: -setPageViewControllers:, -setSegmentTitles:.
//

#import "SegmentedPageViewController.h"
#import "AppColor.h"

static CGFloat const kTabBarHeight  = 44;
static CGFloat const kTabPaddingX   = 16;     // padding around each tab label
static CGFloat const kUnderlineH    = 2;

@interface SegmentedPageViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate>
@property(nonatomic, retain) UIScrollView*      tab_scroll_view;
@property(nonatomic, retain) UIView*            tab_content_view;
@property(nonatomic, retain) UIView*            underline_view;
@property(nonatomic, retain) UIView*            tab_separator;
@property(nonatomic, retain) UIPageViewController* page_view_controller;
@property(nonatomic, retain) NSMutableArray<UIButton*>* tab_buttons;
@property(nonatomic, retain) NSArray<UIViewController*>* page_view_controllers;
@property(nonatomic, retain) NSArray<NSString*>*         segment_titles;
@property(nonatomic) NSInteger current_index;
@property(nonatomic, retain) NSLayoutConstraint* underline_leading;
@property(nonatomic, retain) NSLayoutConstraint* underline_width;
@end

@implementation SegmentedPageViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    _tab_buttons = [NSMutableArray array];
    [self setupViews];
    [self rebuildTabs];
    [self initialPagePresentation];
}

#pragma mark - Setup

-(void)setupViews {
    _tab_scroll_view = [UIScrollView new];
    _tab_scroll_view.showsHorizontalScrollIndicator = NO;
    _tab_scroll_view.alwaysBounceHorizontal = NO;
    _tab_scroll_view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;

    _tab_content_view = [UIView new];
    [_tab_scroll_view addSubview:_tab_content_view];

    _underline_view = [UIView new];
    _underline_view.backgroundColor = [AppColorProvider primaryColor];
    _underline_view.layer.cornerRadius = kUnderlineH / 2.0;
    [_tab_content_view addSubview:_underline_view];

    _tab_separator = [UIView new];
    _tab_separator.backgroundColor = [AppColorProvider separatorColor];

    _page_view_controller = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll
                                                            navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal
                                                                          options:nil];
    _page_view_controller.dataSource = self;
    _page_view_controller.delegate   = self;
    [self addChildViewController:_page_view_controller];
    [_page_view_controller didMoveToParentViewController:self];

    [self.view addSubview:_tab_scroll_view];
    [self.view addSubview:_tab_separator];
    [self.view addSubview:_page_view_controller.view];

    _tab_scroll_view.translatesAutoresizingMaskIntoConstraints = NO;
    _tab_content_view.translatesAutoresizingMaskIntoConstraints = NO;
    _underline_view.translatesAutoresizingMaskIntoConstraints = NO;
    _tab_separator.translatesAutoresizingMaskIntoConstraints = NO;
    _page_view_controller.view.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_tab_scroll_view.topAnchor      constraintEqualToAnchor:safe.topAnchor],
        [_tab_scroll_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_tab_scroll_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_tab_scroll_view.heightAnchor   constraintEqualToConstant:kTabBarHeight],

        [_tab_content_view.topAnchor      constraintEqualToAnchor:_tab_scroll_view.topAnchor],
        [_tab_content_view.bottomAnchor   constraintEqualToAnchor:_tab_scroll_view.bottomAnchor],
        [_tab_content_view.leadingAnchor  constraintEqualToAnchor:_tab_scroll_view.contentLayoutGuide.leadingAnchor],
        [_tab_content_view.trailingAnchor constraintEqualToAnchor:_tab_scroll_view.contentLayoutGuide.trailingAnchor],
        [_tab_content_view.heightAnchor   constraintEqualToAnchor:_tab_scroll_view.heightAnchor],
        // Tabs prefer not to scroll if everything fits on screen.
        [_tab_content_view.widthAnchor    constraintGreaterThanOrEqualToAnchor:_tab_scroll_view.frameLayoutGuide.widthAnchor],

        [_underline_view.bottomAnchor    constraintEqualToAnchor:_tab_content_view.bottomAnchor],
        [_underline_view.heightAnchor    constraintEqualToConstant:kUnderlineH],

        [_tab_separator.topAnchor        constraintEqualToAnchor:_tab_scroll_view.bottomAnchor],
        [_tab_separator.leadingAnchor    constraintEqualToAnchor:self.view.leadingAnchor],
        [_tab_separator.trailingAnchor   constraintEqualToAnchor:self.view.trailingAnchor],
        [_tab_separator.heightAnchor     constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [_page_view_controller.view.topAnchor      constraintEqualToAnchor:_tab_separator.bottomAnchor],
        [_page_view_controller.view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_page_view_controller.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_page_view_controller.view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    _underline_leading = [_underline_view.leadingAnchor constraintEqualToAnchor:_tab_content_view.leadingAnchor constant:kTabPaddingX];
    _underline_width   = [_underline_view.widthAnchor   constraintEqualToConstant:0];
    [NSLayoutConstraint activateConstraints:@[_underline_leading, _underline_width]];
}

#pragma mark - Public

-(void)setPageViewControllers:(NSArray<UIViewController*>*)page_view_controllers {
    _page_view_controllers = page_view_controllers;
    _current_index = 0;
    [self initialPagePresentation];
}

-(void)setSegmentTitles:(NSArray<NSString*>*)segment_titles {
    _segment_titles = segment_titles;
    [self rebuildTabs];
}

#pragma mark - Tabs

-(void)rebuildTabs {
    for (UIButton* b in _tab_buttons) [b removeFromSuperview];
    [_tab_buttons removeAllObjects];
    if (_segment_titles.count == 0 || !_tab_content_view) return;

    UIButton* previous = nil;
    for (NSInteger i = 0; i < (NSInteger)_segment_titles.count; ++i) {
        NSString* title = _segment_titles[i];

        UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = i;
        button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
        button.titleLabel.adjustsFontForContentSizeCategory = YES;
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:[AppColorProvider textSecondaryColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(onTabButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.contentEdgeInsets = UIEdgeInsetsMake(0, kTabPaddingX, 0, kTabPaddingX);

        [_tab_content_view addSubview:button];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor    constraintEqualToAnchor:_tab_content_view.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:_tab_content_view.bottomAnchor],
        ]];
        if (previous == nil) {
            [button.leadingAnchor constraintEqualToAnchor:_tab_content_view.leadingAnchor].active = YES;
        } else {
            [button.leadingAnchor constraintEqualToAnchor:previous.trailingAnchor].active = YES;
        }
        [_tab_buttons addObject:button];
        previous = button;
    }
    if (previous) {
        [previous.trailingAnchor constraintEqualToAnchor:_tab_content_view.trailingAnchor].active = YES;
    }

    // First-pass selection visuals + underline placement after layout.
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [self updateSelectionAtIndex:_current_index animated:NO];
}

-(void)initialPagePresentation {
    if (_page_view_controllers.count == 0 || !_page_view_controller) return;
    NSInteger idx = MIN(_current_index, (NSInteger)_page_view_controllers.count - 1);
    [_page_view_controller setViewControllers:@[_page_view_controllers[idx]]
                                    direction:UIPageViewControllerNavigationDirectionForward
                                     animated:NO
                                   completion:nil];
    _current_index = idx;
    [self updateSelectionAtIndex:idx animated:NO];
}

-(void)onTabButtonTapped:(UIButton*)sender {
    NSInteger to = sender.tag;
    if (to == _current_index || to >= (NSInteger)_page_view_controllers.count) return;

    UIPageViewControllerNavigationDirection dir = to > _current_index
        ? UIPageViewControllerNavigationDirectionForward
        : UIPageViewControllerNavigationDirectionReverse;
    NSInteger from = _current_index;
    _current_index = to;
    [self updateSelectionAtIndex:to animated:YES];

    __weak __typeof__(self) weak_self = self;
    [_page_view_controller setViewControllers:@[_page_view_controllers[to]]
                                    direction:dir
                                     animated:YES
                                   completion:^(BOOL finished) {
        // Rebuild data source so UIPageViewController recomputes neighbours
        // around the new position (matches the previous behaviour).
        __typeof__(self) strong_self = weak_self;
        if (!strong_self) return;
        strong_self.page_view_controller.dataSource = nil;
        strong_self.page_view_controller.dataSource = strong_self;
        (void)from;
    }];
}

// Selected = primary color label + visible underline; others = secondary text.
-(void)updateSelectionAtIndex:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index >= (NSInteger)_tab_buttons.count) return;

    for (NSInteger i = 0; i < (NSInteger)_tab_buttons.count; ++i) {
        UIButton* b = _tab_buttons[i];
        BOOL selected = (i == index);
        [b setTitleColor:selected ? [AppColorProvider primaryColor] : [AppColorProvider textSecondaryColor]
                forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline
                                              weight:selected ? UIFontWeightSemibold : UIFontWeightMedium];
    }

    UIButton* target = _tab_buttons[index];
    // Underline tracks the visible title width — exclude padding for a tight feel.
    CGSize title_size = [target.titleLabel intrinsicContentSize];
    CGFloat width = MAX(20, title_size.width);
    CGFloat x = CGRectGetMinX(target.frame) + (CGRectGetWidth(target.frame) - width) / 2.0;

    _underline_leading.constant = x;
    _underline_width.constant   = width;

    void(^apply)(void) = ^{
        [self.tab_content_view layoutIfNeeded];
    };
    if (animated) {
        [UIView animateWithDuration:AppDurationFast delay:0 options:UIViewAnimationOptionCurveEaseOut animations:apply completion:nil];
    } else {
        apply();
    }

    // Keep the active tab visible inside the horizontal scroll view.
    CGRect visible = target.frame;
    visible.origin.x -= AppSpacing16;
    visible.size.width += AppSpacing32;
    [_tab_scroll_view scrollRectToVisible:visible animated:animated];
}

#pragma mark - UIPageViewControllerDataSource / Delegate

-(UIViewController*)pageViewController:(UIPageViewController*)pvc
    viewControllerBeforeViewController:(UIViewController*)vc {
    NSInteger i = [_page_view_controllers indexOfObject:vc];
    if (i == NSNotFound || i <= 0) return nil;
    return _page_view_controllers[i - 1];
}
-(UIViewController*)pageViewController:(UIPageViewController*)pvc
     viewControllerAfterViewController:(UIViewController*)vc {
    NSInteger i = [_page_view_controllers indexOfObject:vc];
    if (i == NSNotFound || i + 1 >= (NSInteger)_page_view_controllers.count) return nil;
    return _page_view_controllers[i + 1];
}

-(void)pageViewController:(UIPageViewController*)pvc
       didFinishAnimating:(BOOL)finished
  previousViewControllers:(NSArray*)prev
      transitionCompleted:(BOOL)completed {
    if (!(finished && completed) || pvc.viewControllers.count == 0) return;
    NSInteger idx = [_page_view_controllers indexOfObject:pvc.viewControllers.firstObject];
    if (idx == NSNotFound || idx == _current_index) return;
    _current_index = idx;
    [self updateSelectionAtIndex:idx animated:YES];
}

@end
