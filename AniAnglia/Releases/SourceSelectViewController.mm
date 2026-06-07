//
//  SourceSelectViewController.mm
//
//  yukimo redesign: inset-grouped table with a glass-styled banner header
//  showing the chosen voice-over name. Selection pushes EpisodeSelectVC.
//

#import "SourceSelectViewController.h"
#import "LibanixartApi.h"
#import "AppColor.h"
#import "AppMaterial.h"
#import "AppBackdrop.h"
#import "AppHaptics.h"
#import "StringCvt.h"
#import "EpisodeSelectViewController.h"
#import "LoadableView.h"

#pragma mark - SourceViewCell

@interface SourceViewCell : UITableViewCell
@property(nonatomic, retain) UILabel* name_label;
+(NSString*)getIndentifier;
-(void)setName:(NSString*)name;
@end

@implementation SourceViewCell

+(NSString*)getIndentifier { return @"SourceViewCell"; }

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuse {
    self = [super initWithStyle:style reuseIdentifier:reuse];
    if (!self) return nil;
    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    self.backgroundColor = [AppColorProvider surfaceElevatedColor];
    self.selectedBackgroundView = ({
        UIView* v = [UIView new];
        v.backgroundColor = [AppColorProvider primarySoftColor];
        v;
    });

    _name_label = [UILabel new];
    _name_label.font = [UIFont app_fontForStyle:AppTextStyleBody weight:UIFontWeightSemibold];
    _name_label.textColor = [AppColorProvider textColor];
    _name_label.adjustsFontForContentSizeCategory = YES;
    _name_label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_name_label];
    [NSLayoutConstraint activateConstraints:@[
        [_name_label.topAnchor      constraintEqualToAnchor:self.contentView.topAnchor    constant:AppSpacing12],
        [_name_label.bottomAnchor   constraintEqualToAnchor:self.contentView.bottomAnchor constant:-AppSpacing12],
        [_name_label.leadingAnchor  constraintEqualToAnchor:self.contentView.layoutMarginsGuide.leadingAnchor],
        [_name_label.trailingAnchor constraintEqualToAnchor:self.contentView.layoutMarginsGuide.trailingAnchor],
    ]];
    return self;
}

-(void)setName:(NSString*)name { _name_label.text = name; }

@end


#pragma mark - SourceSelectViewController

@interface SourceSelectViewController () {
    anixart::ReleaseID _release_id;
    anixart::EpisodeTypeID _type_id;
    std::vector<anixart::EpisodeSource::Ptr> _sources;
}
@property(nonatomic, retain) NSString*       type_name;
@property(nonatomic, retain) LibanixartApi*  api_proxy;
@property(nonatomic, retain) UITableView*    table_view;
@property(nonatomic, retain) LoadableView*   loadable_view;
@end

@implementation SourceSelectViewController

-(instancetype)initWithReleaseID:(anixart::ReleaseID)release_id
                          typeID:(anixart::EpisodeTypeID)type_id
                        typeName:(NSString*)type_name {
    self = [super init];
    if (!self) return nil;
    _release_id = release_id;
    _type_id    = type_id;
    _type_name  = type_name;
    _api_proxy  = [LibanixartApi sharedInstance];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [AppBackdrop installIn:self.view];
    self.navigationItem.title = NSLocalizedString(@"app.source_select.nav_item.title", "");

    _loadable_view = [LoadableView new];
    _loadable_view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_loadable_view];
    [NSLayoutConstraint activateConstraints:@[
        [_loadable_view.centerYAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.centerYAnchor],
        [_loadable_view.centerXAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.centerXAnchor],
    ]];

    [self loadSources];
}

-(void)setup {
    _table_view = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_table_view registerClass:SourceViewCell.class forCellReuseIdentifier:[SourceViewCell getIndentifier]];
    _table_view.dataSource = self;
    _table_view.delegate   = self;
    _table_view.backgroundColor = UIColor.clearColor;
    _table_view.estimatedRowHeight = 60;
    _table_view.rowHeight = UITableViewAutomaticDimension;

    UIView* header = [UIView new];

    UILabel* eyebrow = [UILabel new];
    eyebrow.text = NSLocalizedString(@"app.type_select.nav_item.title", "");
    eyebrow.font = [UIFont app_fontForStyle:AppTextStyleCaption1 weight:UIFontWeightSemibold];
    eyebrow.textColor = [AppColorProvider textTertiaryColor];

    UILabel* title = [UILabel new];
    title.text = _type_name;
    title.font = [UIFont app_fontForStyle:AppTextStyleTitle2 weight:UIFontWeightBold];
    title.textColor = [AppColorProvider textColor];
    title.numberOfLines = 0;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[eyebrow, title]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = AppSpacing4;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor      constraintEqualToAnchor:header.topAnchor    constant:AppSpacing8],
        [stack.leadingAnchor  constraintEqualToAnchor:header.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:header.layoutMarginsGuide.trailingAnchor],
        [stack.bottomAnchor   constraintEqualToAnchor:header.bottomAnchor constant:-AppSpacing12],
    ]];

    [self.view addSubview:_table_view];
    _table_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_table_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_table_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_table_view.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table_view.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    [header setNeedsLayout];
    [header layoutIfNeeded];
    CGSize fit = [header systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    header.frame = CGRectMake(0, 0, _table_view.bounds.size.width, fit.height);
    _table_view.tableHeaderView = header;
}

-(void)loadSources {
    [_loadable_view startLoading];
    [_api_proxy asyncCall:^BOOL(anixart::Api* api) {
        self->_sources = api->episodes().get_release_sources(self->_release_id, self->_type_id);
        return NO;
    } completion:^(BOOL errored) {
        [self->_loadable_view endLoadingWithErrored:errored];
        if (!errored) [self setup];
    }];
}

-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)s { return _sources.size(); }

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    SourceViewCell* cell = [tv dequeueReusableCellWithIdentifier:[SourceViewCell getIndentifier] forIndexPath:ip];
    anixart::EpisodeSource::Ptr& source = _sources[ip.row];
    [cell setName:TO_NSSTRING(source->name)];
    return cell;
}

-(void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    [AppHaptics impactLight];
    anixart::EpisodeSource::Ptr& source = _sources[ip.row];
    EpisodeSelectViewController* next =
        [[EpisodeSelectViewController alloc] initWithReleaseID:_release_id
                                                        typeID:_type_id
                                                      typeName:_type_name
                                                      sourceID:source->id
                                                    sourceName:TO_NSSTRING(source->name)];
    [self.navigationController pushViewController:next animated:NO];
}

@end
