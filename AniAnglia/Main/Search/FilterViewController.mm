//
//  FilterViewController.mm
//
//  Release-search filter screen.
//
//  Apple Settings-style grouped table. Each row shows the filter name and
//  its current value; tapping pushes a checkmark picker (single- or multi-
//  select) that writes back into `_filter_request`. A "Сбросить" button in
//  the nav bar wipes the request; "Применить" at the bottom kicks off the
//  search and pushes a `ReleasesViewController` with the results.
//

#import "FilterViewController.h"
#import "AppColor.h"
#import "LibanixartApi.h"
#import "StringCvt.h"
#import "ReleasesViewController.h"
#import "ReleasesPageableDataProvider.h"
#import "ProfileListsView.h"

#import <vector>
#import <optional>
#import <chrono>


#pragma mark - FilterPickerViewController

/// Generic checkmark picker — used for every filter row. Selecting an item
/// invokes the on-pick block; `multi` controls whether multiple items can be
/// selected at once.
@interface FilterPickerViewController : UITableViewController
@property(nonatomic, copy) NSArray<NSString*>* items;
@property(nonatomic) BOOL multi;
@property(nonatomic, copy) NSMutableIndexSet* selected_indices;
@property(nonatomic, copy) void(^onSelectionChanged)(NSIndexSet* selected);
-(instancetype)initWithTitle:(NSString*)title
                       items:(NSArray<NSString*>*)items
              initialSelected:(NSIndexSet*)initialSelected
                         multi:(BOOL)multi
                       onPick:(void(^)(NSIndexSet*))onPick;
@end

@implementation FilterPickerViewController

-(instancetype)initWithTitle:(NSString*)title
                       items:(NSArray<NSString*>*)items
              initialSelected:(NSIndexSet*)initialSelected
                         multi:(BOOL)multi
                       onPick:(void(^)(NSIndexSet*))onPick {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (!self) return nil;
    self.title = title;
    _items = [items copy];
    _multi = multi;
    _selected_indices = initialSelected ? [initialSelected mutableCopy] : [NSMutableIndexSet new];
    _onSelectionChanged = [onPick copy];
    return self;
}

-(void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    self.tableView.backgroundColor = UIColor.clearColor;
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"row"];
}

-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)section { return _items.count; }

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"row" forIndexPath:ip];
    UIListContentConfiguration* content = cell.defaultContentConfiguration;
    content.text = _items[ip.row];
    content.textProperties.font = [UIFont app_fontForStyle:AppTextStyleBody];
    content.textProperties.color = [AppColorProvider textColor];
    cell.contentConfiguration = content;
    cell.accessoryType = [_selected_indices containsIndex:ip.row]
        ? UITableViewCellAccessoryCheckmark
        : UITableViewCellAccessoryNone;
    cell.tintColor = [AppColorProvider primaryColor];
    cell.backgroundColor = [AppColorProvider foregroundColor1];
    return cell;
}

-(void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    NSInteger i = ip.row;
    if (_multi) {
        if ([_selected_indices containsIndex:i]) [_selected_indices removeIndex:i];
        else                                     [_selected_indices addIndex:i];
        [tv reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
        if (_onSelectionChanged) _onSelectionChanged(_selected_indices);
        return;
    }
    [_selected_indices removeAllIndexes];
    [_selected_indices addIndex:i];
    if (_onSelectionChanged) _onSelectionChanged(_selected_indices);
    [self.navigationController popViewControllerAnimated:YES];
}

@end


#pragma mark - FilterRow

/// Filter row identity. The table view controller switches on this enum to
/// supply the row's current value, accessory, and tap handler — keeps state
/// access direct without weak-self gymnastics.
typedef NS_ENUM(NSInteger, FilterRowID) {
    FilterRowStatus,
    FilterRowCategory,
    FilterRowSeason,
    FilterRowGenres,
    FilterRowGenresExcludeMode,
    FilterRowCountry,
    FilterRowStudio,
    FilterRowEpisodeCount,
    FilterRowEpisodeDuration,
    FilterRowTypes,
    FilterRowAgeRatings,
    FilterRowListExclusions,
    FilterRowSort
};

@interface FilterRow : NSObject
@property(nonatomic, copy) NSString* title;
@property(nonatomic) FilterRowID identifier;
+(instancetype)title:(NSString*)title id:(FilterRowID)identifier;
@end

@implementation FilterRow
+(instancetype)title:(NSString*)title id:(FilterRowID)identifier {
    FilterRow* r = [FilterRow new];
    r.title = title;
    r.identifier = identifier;
    return r;
}
@end


#pragma mark - FilterViewController

@interface FilterViewController () <UITableViewDataSource, UITableViewDelegate> {
    anixart::requests::FilterRequest _filter_request;
    std::vector<anixart::EpisodeType::Ptr> _episode_types;
}
@property(nonatomic, strong) LibanixartApi*    api_proxy;
@property(nonatomic, retain) UITableView*      table_view;
@property(nonatomic, retain) UIButton*         apply_button;
@property(nonatomic, retain) NSArray<NSString*>* section_titles;
@property(nonatomic, retain) NSArray<NSArray<FilterRow*>*>* rows_by_section;
@end


@implementation FilterViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    _api_proxy = [LibanixartApi sharedInstance];
    self.view.backgroundColor = [AppColorProvider backgroundColor];
    self.title = @"Фильтр";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"Сбросить"
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(onResetTapped)];

    [self buildRows];
    [self setupTable];
    [self setupApplyButton];
    [self loadEpisodeTypes];
}

#pragma mark - Setup

-(void)setupTable {
    _table_view = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _table_view.dataSource = self;
    _table_view.delegate = self;
    _table_view.backgroundColor = UIColor.clearColor;
    _table_view.rowHeight = UITableViewAutomaticDimension;
    _table_view.estimatedRowHeight = 48;
    [_table_view registerClass:UITableViewCell.class forCellReuseIdentifier:@"value"];

    [self.view addSubview:_table_view];
    _table_view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_table_view.topAnchor      constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [_table_view.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_table_view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
}

-(void)setupApplyButton {
    UIView* bar = [UIView new];
    bar.backgroundColor = [AppColorProvider backgroundColor];

    _apply_button = [UIButton buttonWithType:UIButtonTypeSystem];
    [_apply_button setTitle:@"Применить" forState:UIControlStateNormal];
    [_apply_button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _apply_button.titleLabel.font = [UIFont app_fontForStyle:AppTextStyleHeadline];
    _apply_button.backgroundColor = [AppColorProvider primaryColor];
    _apply_button.layer.cornerRadius = AppRadiusLarge;
    _apply_button.layer.cornerCurve = kCACornerCurveContinuous;
    [_apply_button addTarget:self action:@selector(onApplyTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:bar];
    [bar addSubview:_apply_button];

    bar.translatesAutoresizingMaskIntoConstraints = NO;
    _apply_button.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor       constraintEqualToAnchor:_table_view.bottomAnchor],
        [bar.leadingAnchor   constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor  constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.bottomAnchor    constraintEqualToAnchor:self.view.bottomAnchor],

        [_apply_button.topAnchor      constraintEqualToAnchor:bar.topAnchor constant:AppSpacing8],
        [_apply_button.bottomAnchor   constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-AppSpacing8],
        [_apply_button.leadingAnchor  constraintEqualToAnchor:bar.leadingAnchor constant:AppSpacing16],
        [_apply_button.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-AppSpacing16],
        [_apply_button.heightAnchor   constraintEqualToConstant:50],
    ]];
}

#pragma mark - Rows / sections

-(void)buildRows {
    _section_titles = @[@"Категория", @"Жанры", @"Производство", @"Эпизоды", @"Возраст", @"Списки", @"Сортировка"];
    _rows_by_section = @[
        @[[FilterRow title:@"Статус"               id:FilterRowStatus],
          [FilterRow title:@"Категория"            id:FilterRowCategory],
          [FilterRow title:@"Сезон"                id:FilterRowSeason]],
        @[[FilterRow title:@"Жанры"                id:FilterRowGenres],
          [FilterRow title:@"Исключать выбранные"  id:FilterRowGenresExcludeMode]],
        @[[FilterRow title:@"Страна"               id:FilterRowCountry],
          [FilterRow title:@"Студия"               id:FilterRowStudio]],
        @[[FilterRow title:@"Количество"           id:FilterRowEpisodeCount],
          [FilterRow title:@"Длительность"         id:FilterRowEpisodeDuration],
          [FilterRow title:@"Типы"                 id:FilterRowTypes]],
        @[[FilterRow title:@"Возрастной рейтинг"   id:FilterRowAgeRatings]],
        @[[FilterRow title:@"Исключить списки"     id:FilterRowListExclusions]],
        @[[FilterRow title:@"Сортировка"           id:FilterRowSort]],
    ];
}

#pragma mark - Value / accessory / tap dispatch (no blocks → no retain cycles)

-(NSString*)valueTextForRow:(FilterRowID)rid {
    switch (rid) {
        case FilterRowStatus:
            return _filter_request.status
                ? [ReleasesPageableDataProvider getStatusNameFor:*_filter_request.status]
                : @"Любой";
        case FilterRowCategory:
            return _filter_request.category
                ? [ReleasesPageableDataProvider getCategoryNameFor:*_filter_request.category]
                : @"Любая";
        case FilterRowSeason:
            return _filter_request.season
                ? [ReleasesPageableDataProvider getSeasonNameFor:*_filter_request.season]
                : @"Любой";
        case FilterRowGenres:
            return _filter_request.genres.empty()
                ? @"Любые"
                : [NSString stringWithFormat:@"%lu выбрано", (unsigned long)_filter_request.genres.size()];
        case FilterRowGenresExcludeMode:
            return nil;
        case FilterRowCountry: {
            if (!_filter_request.country) return @"Любая";
            std::string copy = *_filter_request.country;
            return TO_NSSTRING(copy);
        }
        case FilterRowStudio: {
            if (!_filter_request.studio) return @"Любая";
            std::string copy = *_filter_request.studio;
            return TO_NSSTRING(copy);
        }
        case FilterRowEpisodeCount:    return [self episodeCountLabel];
        case FilterRowEpisodeDuration: return [self episodeDurationLabel];
        case FilterRowTypes:
            return _filter_request.types.empty()
                ? @"Любые"
                : [NSString stringWithFormat:@"%lu выбрано", (unsigned long)_filter_request.types.size()];
        case FilterRowAgeRatings:
            return _filter_request.age_ratings.empty()
                ? @"Любой"
                : [NSString stringWithFormat:@"%lu выбрано", (unsigned long)_filter_request.age_ratings.size()];
        case FilterRowListExclusions:
            return _filter_request.profile_list_exclusions.empty()
                ? @"Не исключать"
                : [NSString stringWithFormat:@"%lu выбрано", (unsigned long)_filter_request.profile_list_exclusions.size()];
        case FilterRowSort: return [self sortLabel];
    }
    return nil;
}

-(UIView*)accessoryForRow:(FilterRowID)rid {
    if (rid != FilterRowGenresExcludeMode) return nil;
    UISwitch* sw = [UISwitch new];
    sw.on = _filter_request.is_genres_exclude_mode;
    sw.onTintColor = [AppColorProvider primaryColor];
    [sw addTarget:self action:@selector(onGenresExcludeModeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    return sw;
}

-(void)onGenresExcludeModeSwitchChanged:(UISwitch*)sender {
    _filter_request.is_genres_exclude_mode = sender.on;
}

-(void)handleTap:(FilterRowID)rid {
    switch (rid) {
        case FilterRowStatus:           [self pickStatus]; return;
        case FilterRowCategory:         [self pickCategory]; return;
        case FilterRowSeason:           [self pickSeason]; return;
        case FilterRowGenres:           [self pickGenres]; return;
        case FilterRowGenresExcludeMode: return;     // switch only — no tap
        case FilterRowCountry:          [self pickCountry]; return;
        case FilterRowStudio:           [self pickStudio]; return;
        case FilterRowEpisodeCount:     [self pickEpisodeCount]; return;
        case FilterRowEpisodeDuration:  [self pickEpisodeDuration]; return;
        case FilterRowTypes:            [self pickTypes]; return;
        case FilterRowAgeRatings:       [self pickAgeRatings]; return;
        case FilterRowListExclusions:   [self pickProfileListExclusions]; return;
        case FilterRowSort:             [self pickSort]; return;
    }
}

#pragma mark - UITableViewDataSource / Delegate

-(NSInteger)numberOfSectionsInTableView:(UITableView*)tv { return _rows_by_section.count; }
-(NSInteger)tableView:(UITableView*)tv numberOfRowsInSection:(NSInteger)section { return _rows_by_section[section].count; }
-(NSString*)tableView:(UITableView*)tv titleForHeaderInSection:(NSInteger)section { return _section_titles[section]; }

-(UITableViewCell*)tableView:(UITableView*)tv cellForRowAtIndexPath:(NSIndexPath*)ip {
    FilterRow* row = _rows_by_section[ip.section][ip.row];
    UITableViewCell* cell = [tv dequeueReusableCellWithIdentifier:@"value" forIndexPath:ip];

    UIListContentConfiguration* content = cell.defaultContentConfiguration;
    content.text = row.title;
    content.textProperties.font = [UIFont app_fontForStyle:AppTextStyleBody];
    content.textProperties.color = [AppColorProvider textColor];
    NSString* value = [self valueTextForRow:row.identifier];
    if (value) {
        content.secondaryText = value;
        content.secondaryTextProperties.font = [UIFont app_fontForStyle:AppTextStyleBody];
        content.secondaryTextProperties.color = [AppColorProvider textSecondaryColor];
        content.prefersSideBySideTextAndSecondaryText = YES;
    }
    cell.contentConfiguration = content;
    cell.backgroundColor = [AppColorProvider foregroundColor1];

    UIView* accessory = [self accessoryForRow:row.identifier];
    cell.accessoryView = accessory;
    if (accessory) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

-(void)tableView:(UITableView*)tv didSelectRowAtIndexPath:(NSIndexPath*)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    FilterRow* row = _rows_by_section[ip.section][ip.row];
    [self handleTap:row.identifier];
}

-(void)reloadAll {
    [_table_view reloadData];
}

#pragma mark - Pickers

-(void)pushPickerWithTitle:(NSString*)title
                     items:(NSArray<NSString*>*)items
                  selected:(NSIndexSet*)selected
                     multi:(BOOL)multi
                    onPick:(void(^)(NSIndexSet*))onPick {
    FilterPickerViewController* vc = [[FilterPickerViewController alloc]
        initWithTitle:title items:items initialSelected:selected multi:multi onPick:^(NSIndexSet* sel) {
            onPick(sel);
        }];
    // For single-select pickers we reload the table on push back via VC lifecycle.
    [self.navigationController pushViewController:vc animated:YES];
}

-(NSIndexSet*)singleIndexSet:(NSInteger)i {
    return i >= 0 ? [NSIndexSet indexSetWithIndex:i] : [NSIndexSet new];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadAll];  // refresh values after returning from a picker
}

#pragma mark Status

-(void)pickStatus {
    NSArray<NSString*>* items = @[@"Любой",
        [ReleasesPageableDataProvider getStatusNameFor:anixart::Release::Status::Ongoing],
        [ReleasesPageableDataProvider getStatusNameFor:anixart::Release::Status::Upcoming],
        [ReleasesPageableDataProvider getStatusNameFor:anixart::Release::Status::Finished]];
    NSInteger current = 0;
    if (_filter_request.status) {
        switch (*_filter_request.status) {
            case anixart::Release::Status::Ongoing:  current = 1; break;
            case anixart::Release::Status::Upcoming: current = 2; break;
            case anixart::Release::Status::Finished: current = 3; break;
            default: break;
        }
    }
    [self pushPickerWithTitle:@"Статус" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.status = std::nullopt; break;
            case 1: self->_filter_request.status = anixart::Release::Status::Ongoing; break;
            case 2: self->_filter_request.status = anixart::Release::Status::Upcoming; break;
            case 3: self->_filter_request.status = anixart::Release::Status::Finished; break;
        }
    }];
}

#pragma mark Category

-(void)pickCategory {
    NSArray<NSString*>* items = @[@"Любая",
        [ReleasesPageableDataProvider getCategoryNameFor:anixart::Release::Category::Series],
        [ReleasesPageableDataProvider getCategoryNameFor:anixart::Release::Category::Movies],
        [ReleasesPageableDataProvider getCategoryNameFor:anixart::Release::Category::Ova]];
    NSInteger current = 0;
    if (_filter_request.category) {
        switch (*_filter_request.category) {
            case anixart::Release::Category::Series: current = 1; break;
            case anixart::Release::Category::Movies: current = 2; break;
            case anixart::Release::Category::Ova:    current = 3; break;
            default: break;
        }
    }
    [self pushPickerWithTitle:@"Категория" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.category = std::nullopt; break;
            case 1: self->_filter_request.category = anixart::Release::Category::Series; break;
            case 2: self->_filter_request.category = anixart::Release::Category::Movies; break;
            case 3: self->_filter_request.category = anixart::Release::Category::Ova; break;
        }
    }];
}

#pragma mark Season

-(void)pickSeason {
    NSArray<NSString*>* items = @[@"Любой",
        [ReleasesPageableDataProvider getSeasonNameFor:anixart::Release::Season::Winter],
        [ReleasesPageableDataProvider getSeasonNameFor:anixart::Release::Season::Spring],
        [ReleasesPageableDataProvider getSeasonNameFor:anixart::Release::Season::Summer],
        [ReleasesPageableDataProvider getSeasonNameFor:anixart::Release::Season::Fall]];
    NSInteger current = 0;
    if (_filter_request.season) {
        switch (*_filter_request.season) {
            case anixart::Release::Season::Winter: current = 1; break;
            case anixart::Release::Season::Spring: current = 2; break;
            case anixart::Release::Season::Summer: current = 3; break;
            case anixart::Release::Season::Fall:   current = 4; break;
            default: break;
        }
    }
    [self pushPickerWithTitle:@"Сезон" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.season = std::nullopt; break;
            case 1: self->_filter_request.season = anixart::Release::Season::Winter; break;
            case 2: self->_filter_request.season = anixart::Release::Season::Spring; break;
            case 3: self->_filter_request.season = anixart::Release::Season::Summer; break;
            case 4: self->_filter_request.season = anixart::Release::Season::Fall;   break;
        }
    }];
}

#pragma mark Country

-(void)pickCountry {
    NSArray<NSString*>* items = @[@"Любая", @"Япония", @"Китай"];
    NSInteger current = 0;
    if (_filter_request.country) {
        NSString* cs = TO_NSSTRING(*_filter_request.country);
        if ([cs isEqualToString:@"Япония"]) current = 1;
        else if ([cs isEqualToString:@"Китай"]) current = 2;
    }
    [self pushPickerWithTitle:@"Страна" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.country = std::nullopt; break;
            case 1: self->_filter_request.country = std::string("Япония"); break;
            case 2: self->_filter_request.country = std::string("Китай"); break;
        }
    }];
}

#pragma mark Studio

-(void)pickStudio {
    NSArray<NSString*>* studios = [_api_proxy getStudiosArray] ?: @[];
    NSMutableArray* items = [NSMutableArray arrayWithObject:@"Любая"];
    [items addObjectsFromArray:studios];
    NSInteger current = 0;
    if (_filter_request.studio) {
        NSString* s = TO_NSSTRING(*_filter_request.studio);
        NSUInteger idx = [studios indexOfObject:s];
        if (idx != NSNotFound) current = (NSInteger)(idx + 1);
    }
    [self pushPickerWithTitle:@"Студия" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        if (i == 0) { self->_filter_request.studio = std::nullopt; return; }
        self->_filter_request.studio = TO_STDSTRING(studios[i - 1]);
    }];
}

#pragma mark Episode count

-(void)pickEpisodeCount {
    NSArray<NSString*>* items = @[@"Любое", @"1–12", @"13–24", @"25–100", @"101+"];
    NSInteger current = [self episodeCountIndex];
    [self pushPickerWithTitle:@"Количество эпизодов" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.episodes_count_from = std::nullopt; self->_filter_request.episodes_count_to = std::nullopt; break;
            case 1: self->_filter_request.episodes_count_from = std::nullopt; self->_filter_request.episodes_count_to = 12; break;
            case 2: self->_filter_request.episodes_count_from = 13;           self->_filter_request.episodes_count_to = 24; break;
            case 3: self->_filter_request.episodes_count_from = 25;           self->_filter_request.episodes_count_to = 100; break;
            case 4: self->_filter_request.episodes_count_from = 101;          self->_filter_request.episodes_count_to = std::nullopt; break;
        }
    }];
}

-(NSInteger)episodeCountIndex {
    auto f = _filter_request.episodes_count_from, t = _filter_request.episodes_count_to;
    if (!f && !t) return 0;
    if (!f && t == 12) return 1;
    if (f == 13 && t == 24) return 2;
    if (f == 25 && t == 100) return 3;
    if (f == 101 && !t) return 4;
    return 0;
}

-(NSString*)episodeCountLabel {
    NSArray<NSString*>* names = @[@"Любое", @"1–12", @"13–24", @"25–100", @"101+"];
    return names[[self episodeCountIndex]];
}

#pragma mark Episode duration

-(void)pickEpisodeDuration {
    NSArray<NSString*>* items = @[@"Любая", @"до 10 мин", @"до 30 мин", @"30 мин и более"];
    NSInteger current = [self episodeDurationIndex];
    [self pushPickerWithTitle:@"Длительность эпизода" items:items selected:[self singleIndexSet:current] multi:NO onPick:^(NSIndexSet* sel) {
        NSInteger i = sel.firstIndex;
        switch (i) {
            case 0: self->_filter_request.episode_duration_from = std::nullopt; self->_filter_request.episode_duration_to = std::nullopt; break;
            case 1: self->_filter_request.episode_duration_from = std::nullopt; self->_filter_request.episode_duration_to = std::chrono::minutes(10); break;
            case 2: self->_filter_request.episode_duration_from = std::nullopt; self->_filter_request.episode_duration_to = std::chrono::minutes(30); break;
            case 3: self->_filter_request.episode_duration_from = std::chrono::minutes(30); self->_filter_request.episode_duration_to = std::nullopt; break;
        }
    }];
}

-(NSInteger)episodeDurationIndex {
    auto f = _filter_request.episode_duration_from, t = _filter_request.episode_duration_to;
    if (!f && !t) return 0;
    if (!f && t == std::chrono::minutes(10)) return 1;
    if (!f && t == std::chrono::minutes(30)) return 2;
    if (f == std::chrono::minutes(30) && !t) return 3;
    return 0;
}

-(NSString*)episodeDurationLabel {
    NSArray<NSString*>* names = @[@"Любая", @"до 10 мин", @"до 30 мин", @"30 мин и более"];
    return names[[self episodeDurationIndex]];
}

#pragma mark Genres

-(void)pickGenres {
    NSArray<NSString*>* genres = [_api_proxy getGenresArray] ?: @[];
    NSMutableIndexSet* selected = [NSMutableIndexSet new];
    for (const auto& g : _filter_request.genres) {
        NSString* gs = TO_NSSTRING(g);
        NSUInteger idx = [genres indexOfObject:gs];
        if (idx != NSNotFound) [selected addIndex:idx];
    }
    [self pushPickerWithTitle:@"Жанры" items:genres selected:selected multi:YES onPick:^(NSIndexSet* sel) {
        self->_filter_request.genres.clear();
        [sel enumerateIndexesUsingBlock:^(NSUInteger i, BOOL* _) {
            self->_filter_request.genres.push_back(TO_STDSTRING(genres[i]));
        }];
    }];
}

#pragma mark Types

-(void)pickTypes {
    NSMutableArray<NSString*>* items = [NSMutableArray array];
    std::vector<anixart::EpisodeTypeID> ids;
    for (const auto& t : _episode_types) { [items addObject:TO_NSSTRING(t->name)]; ids.push_back(t->id); }

    NSMutableIndexSet* selected = [NSMutableIndexSet new];
    for (const auto& tid : _filter_request.types) {
        for (size_t i = 0; i < ids.size(); ++i) if (ids[i] == tid) { [selected addIndex:i]; break; }
    }
    [self pushPickerWithTitle:@"Типы эпизодов" items:items selected:selected multi:YES onPick:^(NSIndexSet* sel) {
        self->_filter_request.types.clear();
        [sel enumerateIndexesUsingBlock:^(NSUInteger i, BOOL* _) {
            self->_filter_request.types.push_back(ids[i]);
        }];
    }];
}

#pragma mark Age ratings

-(void)pickAgeRatings {
    using AR = anixart::Release::AgeRating;
    std::vector<AR> all = { AR::G, AR::PG6, AR::PG12, AR::R16, AR::R18 };
    NSMutableArray<NSString*>* items = [NSMutableArray array];
    for (auto a : all) [items addObject:[ReleasesPageableDataProvider getAgeRatingNameFor:a]];

    NSMutableIndexSet* selected = [NSMutableIndexSet new];
    for (auto a : _filter_request.age_ratings) {
        for (size_t i = 0; i < all.size(); ++i) if (all[i] == a) { [selected addIndex:i]; break; }
    }
    [self pushPickerWithTitle:@"Возрастной рейтинг" items:items selected:selected multi:YES onPick:^(NSIndexSet* sel) {
        self->_filter_request.age_ratings.clear();
        [sel enumerateIndexesUsingBlock:^(NSUInteger i, BOOL* _) {
            self->_filter_request.age_ratings.push_back(all[i]);
        }];
    }];
}

#pragma mark Profile list exclusions

-(void)pickProfileListExclusions {
    using L = anixart::Profile::List;
    std::vector<L> all = { L::Favorite, L::Watching, L::Plan, L::Watched, L::HoldOn, L::Dropped };
    NSMutableArray<NSString*>* items = [NSMutableArray array];
    for (auto l : all) [items addObject:[ProfileListsView getListName:l]];

    NSMutableIndexSet* selected = [NSMutableIndexSet new];
    for (auto l : _filter_request.profile_list_exclusions) {
        for (size_t i = 0; i < all.size(); ++i) if (all[i] == l) { [selected addIndex:i]; break; }
    }
    [self pushPickerWithTitle:@"Исключить списки" items:items selected:selected multi:YES onPick:^(NSIndexSet* sel) {
        self->_filter_request.profile_list_exclusions.clear();
        [sel enumerateIndexesUsingBlock:^(NSUInteger i, BOOL* _) {
            self->_filter_request.profile_list_exclusions.push_back(all[i]);
        }];
    }];
}

#pragma mark Sort

-(void)pickSort {
    using Sort = anixart::requests::FilterRequest::Sort;
    NSArray<NSString*>* items = @[@"По обновлению", @"По рейтингу", @"По году", @"По популярности"];
    Sort current = _filter_request.sort.value_or(Sort::DateUpdate);
    NSInteger idx = 0;
    switch (current) {
        case Sort::DateUpdate: idx = 0; break;
        case Sort::Grade:      idx = 1; break;
        case Sort::Year:       idx = 2; break;
        case Sort::Popular:    idx = 3; break;
    }
    [self pushPickerWithTitle:@"Сортировка" items:items selected:[self singleIndexSet:idx] multi:NO onPick:^(NSIndexSet* sel) {
        switch (sel.firstIndex) {
            case 0: self->_filter_request.sort = Sort::DateUpdate; break;
            case 1: self->_filter_request.sort = Sort::Grade;      break;
            case 2: self->_filter_request.sort = Sort::Year;       break;
            case 3: self->_filter_request.sort = Sort::Popular;    break;
        }
    }];
}

-(NSString*)sortLabel {
    using Sort = anixart::requests::FilterRequest::Sort;
    switch (_filter_request.sort.value_or(Sort::DateUpdate)) {
        case Sort::DateUpdate: return @"По обновлению";
        case Sort::Grade:      return @"По рейтингу";
        case Sort::Year:       return @"По году";
        case Sort::Popular:    return @"По популярности";
    }
    return @"По обновлению";
}

#pragma mark - Actions

-(void)onResetTapped {
    _filter_request = anixart::requests::FilterRequest{};
    [self reloadAll];
}

-(void)onApplyTapped {
    anixart::FilterPages::UPtr pages = _api_proxy.api->search().filter_search(_filter_request, false, 0);
    ReleasesViewController* vc = [[ReleasesViewController alloc] initWithPages:std::move(pages)];
    vc.title = @"Результаты";
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Async data

-(void)loadEpisodeTypes {
    [_api_proxy performAsyncBlock:^BOOL(anixart::Api* api){
        self->_episode_types = api->episodes().get_all_types();
        return YES;
    } withUICompletion:^{
        // No-op visible change; picker reads `_episode_types` directly on push.
    }];
}

@end
