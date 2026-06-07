//
//  TypeSelectViewController.mm
//
//  Voice-over / subtitle track picker.
//
//  yukimo redesign: iOS-style inset-grouped table with a segmented filter
//  banner (All / Dubs / Subs) above the rows. The filter is heuristic — we
//  inspect the type name for "субтит" (Russian) or "subtitle" (English) to
//  classify; everything else is treated as a voice-over.
//

#import "TypeSelectViewController.h"
#import "LibanixartApi.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppBackdrop.h"
#import "AppHaptics.h"
#import "StringCvt.h"
#import "SourceSelectViewController.h"
#import "LoadableView.h"

#pragma mark - TypeViewCell

@interface TypeViewCell : UITableViewCell
@property(nonatomic, retain) UILabel*      name_label;
@property(nonatomic, retain) UILabel*      ep_count_label;
@property(nonatomic, retain) UILabel*      view_count_label;
@property(nonatomic, retain) UIImageView*  view_image_view;
+(NSString*)getIndentifier;
-(void)setName:(NSString*)name;
-(void)setEpCount:(NSString*)ep_count;
-(void)setViewCount:(NSString*)view_count;
@end

@implementation TypeViewCell

+(NSString*)getIndentifier { return @"TypeViewCell"; }

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuse {
    self = [super initWithStyle:style reuseIdentifier:reuse];
    if (!self) return nil;
    [self build];
    return self;
}

-(void)build {
    self.backgroundColor = [AppColorProvider surfaceElevatedColor];
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.selectedBackgroundView = ({
        UIView* v = [UIView new];
        v.backgroundColor = [AppColorProvider primarySoftColor];
        v;
    });

    _name_label = [UILabel new];
    _name_label.font = [UIFont app_fontForStyle:AppTextStyleBody weight:UIFontWeightSemibold];
    _name_label.textColor = [AppColorProvider textColor];
    _name_label.adjustsFontForContentSizeCategory = YES;
    _name_label.numberOfLines = 1;

    _ep_count_label = [UILabel new];
    _ep_count_label.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleFootnote weight:UIFontWeightRegular];
    _ep_count_label.textColor = [AppColorProvider textSecondaryColor];
    _ep_count_label.adjustsFontForContentSizeCategory = YES;

    _view_image_view = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"eye"]];
    _view_image_view.tintColor = [AppColorProvider textTertiaryColor];
    _view_image_view.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightSemibold];

    _view_count_label = [UILabel new];
    _view_count_label.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleFootnote weight:UIFontWeightRegular];
    _view_count_label.textColor = [AppColorProvider textTertiaryColor];
    _view_count_label.adjustsFontForContentSizeCategory = YES;
    _view_count_label.textAlignment = NSTextAlignmentRight;

    UIStackView* leftStack = [[UIStackView alloc] initWithArrangedSubviews:@[_name_label, _ep_count_label]];
    leftStack.axis = UILayoutConstraintAxisVertical;
    leftStack.spacing = AppSpacing2;
    leftStack.alignment = UIStackViewAlignmentLeading;

    UIStackView* rightStack = [[UIStackView alloc] initWithArrangedSubviews:@[_view_image_view, _view_count_label]];
    rightStack.axis = UILayoutConstraintAxisHorizontal;
    rightStack.spacing = AppSpacing4;
    rightStack.alignment = UIStackViewAlignmentCenter;

    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[leftStack, rightStack]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = AppSpacing12;
    row.distribution = UIStackViewDistributionFill;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [leftStack setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
    [rightStack setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    [self.contentView addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor  constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
        [row.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor    constant:AppSpacing8],
        [row.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-AppSpacing8],
    ]];
}

-(void)setName:(NSString*)name           { _name_label.text = name; }
-(void)setEpCount:(NSString*)ep_count    { _ep_count_label.text = ep_count; }
-(void)setViewCount:(NSString*)view_count{ _view_count_label.text = view_count; }

@end


#pragma mark - TypeSelectViewController

typedef NS_ENUM(NSInteger, TypeFilter) {
    TypeFilterAll = 0,
    TypeFilterDubs,
    TypeFilterSubs,
};

@interface TypeSelectViewController () {
    anixart::ReleaseID _release_id;
    std::vector<anixart::EpisodeType::Ptr> _types_all;
    std::vector<anixart::EpisodeType::Ptr> _types_filtered;
}
@property(nonatomic, retain) LibanixartApi*       api_proxy;
@property(nonatomic, retain) UITableView*         table_view;
@property(nonatomic, retain) UISegmentedControl*  filter_control;
@property(nonatomic, retain) LoadableView*        loadable_view;
@end

@implementation TypeSelectViewController

-(instancetype)initWithReleaseID:(anixart::ReleaseID)release_id {
    self = [super init];
    if (!self) return nil;
    _release_id = release_id;
    _api_proxy = [LibanixartApi sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [AppBackdrop installIn:self.view];
    self.navigationItem.title = NSLocalizedString(@"app.type_select.nav_item.title", "");

    _loadable_view = [LoadableView new];
    _loadable_view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_loadable_view];
    [NSLayoutConstraint activateConstraints:@[
        [_loadable_view.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [_loadable_view.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
    ]];

    [self loadTypes];
}

-(void)setup {
    _filter_control = [[UISegmentedControl alloc] initWithItems:@[@"Все", @"Озвучки", @"Субтитры"]];
    _filter_control.selectedSegmentIndex = TypeFilterAll;
    [_filter_control addTarget:self action:@selector(onFilterChanged) forControlEvents:UIControlEventValueChanged];

    _table_view = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_table_view registerClass:TypeViewCell.class forCellReuseIdentifier:[TypeViewCell getIndentifier]];
    _table_view.dataSource = self;
    _table_view.delegate   = self;
    // Clear table so AppBackdrop shows through behind the grouped cells.
    _table_view.backgroundColor = UIColor.clearColor;
    _table_view.estimatedRowHeight = 60;
    _table_view.rowHeight = UITableViewAutomaticDimension;

    UIView* header = [UIView new];
    [header addSubview:_filter_control];
    _filter_control.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_filter_control.leadingAnchor  constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
        [_filter_control.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
        [_filter_control.topAnchor      constraintEqualToAnchor:header.topAnchor    constant:AppSpacing12],
        [_filter_control.bottomAnchor   constraintEqualToAnchor:header.bottomAnchor constant:-AppSpacing12],
    ]];

    [self.view addSubview:_table_view];
    _table_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_table_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_table_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table_view.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Header height — measured after layout pass so the segmented control sits
    // at its intrinsic size.
    [header setNeedsLayout];
    [header layoutIfNeeded];
    CGSize fitting = [header systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    header.frame = CGRectMake(0, 0, _table_view.bounds.size.width, fitting.height);
    _table_view.tableHeaderView = header;

    [self applyFilter];
}

-(void)loadTypes {
    [_loadable_view startLoading];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        self->_types_all = api->episodes().get_release_types(self->_release_id);
        return NO;
    } completion:^(BOOL errored) {
        [self->_loadable_view endLoadingWithErrored:errored];
        if (!errored) [self setup];
    }];
}

#pragma mark - Filtering

// Heuristic: subtitle types have either "субтит" (ru) or "subtitle" (en) in
// their name. Everything else is treated as a voice-over (dub).
static BOOL yk_typeIsSubtitle(const std::string& name) {
    std::string lower(name);
    for (char& c : lower) c = (char)tolower((unsigned char)c);
    if (lower.find("subtitle") != std::string::npos) return YES;
    NSString* s = [NSString stringWithUTF8String:name.c_str()];
    return [s.lowercaseString containsString:@"субтит"];
}

-(void)applyFilter {
    _types_filtered.clear();
    TypeFilter filter = (TypeFilter)_filter_control.selectedSegmentIndex;
    for (auto& t : _types_all) {
        BOOL isSub = yk_typeIsSubtitle(t->name);
        if (filter == TypeFilterAll)                  _types_filtered.push_back(t);
        else if (filter == TypeFilterDubs && !isSub)  _types_filtered.push_back(t);
        else if (filter == TypeFilterSubs &&  isSub)  _types_filtered.push_back(t);
    }
    [_table_view reloadData];
}

-(void)onFilterChanged {
    [AppHaptics selection];
    [self applyFilter];
}

#pragma mark - UITableViewDataSource / Delegate

-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s { return _types_filtered.size(); }

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    TypeViewCell* cell = [tv dequeueReusableCellWithIdentifier:[TypeViewCell getIndentifier] forIndexPath:ip];
    anixart::EpisodeType::Ptr& type = _types_filtered[ip.row];
    [cell setName:TO_NSSTRING(type->name)];
    [cell setEpCount:[NSString stringWithFormat:@"%lld %@", type->episodes_count, NSLocalizedString(@"app.type_select.cell.ep_count.name", "")]];
    [cell setViewCount:[AbbreviateNumberFormatter stringFromNumber:type->view_count]];
    return cell;
}

-(void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [AppHaptics impactLight];
    anixart::EpisodeType::Ptr& type = _types_filtered[ip.row];
    SourceSelectViewController* next =
        [[SourceSelectViewController alloc] initWithReleaseID:_release_id
                                                       typeID:type->id
                                                     typeName:TO_NSSTRING(type->name)];
    [self.navigationController pushViewController:next animated:YES];
}

@end
