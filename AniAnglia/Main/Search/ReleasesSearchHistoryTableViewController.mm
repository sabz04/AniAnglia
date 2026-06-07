//
//  ReleasesSearchHistoryTableViewController.mm
//
//  Recent-searches list shown under the search bar when it gains focus.
//  Modern UITableView (inset-grouped) with native `UIListContentConfiguration`
//  cells, section header "Недавнее", a "Очистить" footer button, and a
//  friendly empty state when the user has no history yet.
//

#import "ReleasesSearchHistoryTableViewController.h"
#import "AppColor.h"
#import "AppDataController.h"

static NSString* const kCellID = @"HistoryCell";

@interface ReleasesSearchHistoryTableViewController ()
@property(nonatomic, retain) AppDataController* app_data_controller;
@property(nonatomic, retain) UITableView*       table_view;
@property(nonatomic, retain) UIStackView*       empty_state;
@end


@implementation ReleasesSearchHistoryTableViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    _app_data_controller = [AppDataController sharedInstance];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    [self setupTable];
    [self setupEmptyState];
    [self updateEmptyStateVisibility];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_table_view reloadData];
    [self updateEmptyStateVisibility];
}

#pragma mark - Setup

-(void)setupTable {
    _table_view = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table_view.delegate = self;
    _table_view.dataSource = self;
    _table_view.backgroundColor = UIColor.clearColor;
    _table_view.rowHeight = UITableViewAutomaticDimension;
    _table_view.estimatedRowHeight = 44;
    [_table_view registerClass:UITableViewCell.class forCellReuseIdentifier:kCellID];

    [self.view addSubview:_table_view];

    _table_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_table_view.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_table_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    if (@available(iOS 15.0, *)) {
        [_table_view.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor].active = YES;
    } else {
        [_table_view.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor].active = YES;
    }
}

-(void)setupEmptyState {
    UIImageSymbolConfiguration* cfg = [UIImageSymbolConfiguration configurationWithPointSize:36 weight:UIImageSymbolWeightRegular];
    UIImageView* icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]];
    icon.tintColor = [AppColorProvider textShyColor];

    UILabel* label = [UILabel new];
    label.text = @"История поиска пуста";
    label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline];
    label.textColor = [AppColorProvider textSecondaryColor];
    label.textAlignment = NSTextAlignmentCenter;

    _empty_state = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    _empty_state.axis = UILayoutConstraintAxisVertical;
    _empty_state.spacing = AppSpacing8;
    _empty_state.alignment = UIStackViewAlignmentCenter;
    _empty_state.hidden = YES;

    [self.view addSubview:_empty_state];
    _empty_state.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_empty_state.centerXAnchor  constraintEqualToAnchor:self.view.centerXAnchor],
        [_empty_state.centerYAnchor  constraintEqualToAnchor:self.view.centerYAnchor constant:-AppSpacing32],
        [_empty_state.leadingAnchor  constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:AppSpacing24],
        [_empty_state.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-AppSpacing24]
    ]];
}

-(void)updateEmptyStateVisibility {
    BOOL has_items = [_app_data_controller getSearchHistoryLength] > 0;
    _empty_state.hidden = has_items;
    _table_view.hidden  = !has_items;
}

#pragma mark - Data source

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tv { return 1; }

-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)section {
    return [_app_data_controller getSearchHistoryLength];
}

-(NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)section {
    return @"Недавнее";
}

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)index_path {
    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:kCellID forIndexPath:index_path];
    UIListContentConfiguration* content = cell.defaultContentConfiguration;
    content.text = [_app_data_controller getSearchHistoryItemAtIndex:index_path.row];
    content.textProperties.font = [UIFont app_fontForStyle:AppTextStyleBody];
    content.textProperties.color = [AppColorProvider textColor];
    content.image = [UIImage systemImageNamed:@"clock"];
    content.imageProperties.tintColor = [AppColorProvider textSecondaryColor];
    content.imageProperties.preferredSymbolConfiguration =
        [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightRegular];
    content.imageToTextPadding = AppSpacing12;
    cell.contentConfiguration = content;
    cell.backgroundColor = [AppColorProvider foregroundColor1];
    return cell;
}

#pragma mark - Footer "Очистить" (only when there are items)

-(UIView*)tableView:(UITableView*)tv viewForFooterInSection:(NSInteger)section {
    if ([_app_data_controller getSearchHistoryLength] == 0) return nil;

    UIButton* clear = [UIButton buttonWithType:UIButtonTypeSystem];
    [clear setTitle:@"Очистить историю" forState:UIControlStateNormal];
    [clear setTitleColor:[AppColorProvider alertColor] forState:UIControlStateNormal];
    clear.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightMedium];
    [clear addAction:[UIAction actionWithHandler:^(UIAction* _) {
        [self confirmClearAll];
    }] forControlEvents:UIControlEventTouchUpInside];

    UIView* container = [UIView new];
    [container addSubview:clear];
    clear.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [clear.topAnchor      constraintEqualToAnchor:container.topAnchor constant:AppSpacing16],
        [clear.bottomAnchor   constraintEqualToAnchor:container.bottomAnchor constant:-AppSpacing8],
        [clear.centerXAnchor  constraintEqualToAnchor:container.centerXAnchor]
    ]];
    return container;
}

-(CGFloat)tableView:(UITableView*)tv heightForFooterInSection:(NSInteger)section {
    return [_app_data_controller getSearchHistoryLength] > 0 ? UITableViewAutomaticDimension : 0;
}

#pragma mark - Selection / actions

-(void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)index_path {
    [tv deselectRowAtIndexPath:index_path animated:YES];
    NSString* item = [_app_data_controller getSearchHistoryItemAtIndex:index_path.row];
    [_app_data_controller addSearchHistoryItem:item];  // bump to top of history
    [_delegate releasesSearchHistoryTableViewController:self didSelectHistoryItem:item];
}

-(UISwipeActionsConfiguration*)tableView:(UITableView*)tv
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath*)index_path {
    NSInteger index = index_path.row;
    UIContextualAction* del = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
        title:nil
        handler:^(UIContextualAction* action, UIView* source_view, void(^completion)(BOOL)) {
            [self->_app_data_controller removeSearchHistoryItemAtIndex:index];
            [tv deleteRowsAtIndexPaths:@[index_path] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self updateEmptyStateVisibility];
            [tv reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
            completion(YES);
        }];
    del.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

-(void)confirmClearAll {
    UIAlertController* sheet = [UIAlertController
        alertControllerWithTitle:@"Очистить историю поиска?"
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Очистить" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* _) {
        while ([self->_app_data_controller getSearchHistoryLength] > 0) {
            [self->_app_data_controller removeSearchHistoryItemAtIndex:0];
        }
        [self->_table_view reloadData];
        [self updateEmptyStateVisibility];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
