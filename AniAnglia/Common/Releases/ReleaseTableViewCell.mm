//
//  ReleaseTableViewCell.mm
//
//  Compact list row used in release listings.
//
//  Layout: 64×96 (2:3) poster on the leading edge, then a vertical stack
//  with title (callout-semibold, 2 lines), a meta line ("★ 8.5 · 12/12 ep")
//  and an optional description preview (subheadline, 2 lines max).
//
//  Public API is unchanged: identifier, getBadgeColor:, setImageUrl:,
//  setTitle:, setDescription:, setEpCount:totalEpCount:, setRating:.
//

#import "ReleaseTableViewCell.h"
#import "LoadableView.h"
#import "AppColor.h"
#import "StringCvt.h"

static CGFloat const kPosterWidth  = 88;
static CGFloat const kPosterHeight = 132;  // 2:3 ratio — wider for premium feel

@interface ReleaseTableViewCell ()
@property(nonatomic, retain) LoadableImageView* image_view;
@property(nonatomic, retain) UILabel* title_label;
@property(nonatomic, retain) UILabel* meta_label;          // "★ 8.5 · 12/12 ep"
@property(nonatomic, retain) UILabel* description_label;

@property(nonatomic) double current_rating;
@property(nonatomic) NSUInteger ep_count;
@property(nonatomic) NSUInteger ep_total;
@end

@implementation ReleaseTableViewCell

+(NSString*)getIdentifier { return @"ReleaseTableViewCell"; }

// Kept for compatibility — used by other cell types to color rating badges.
+(UIColor*)getBadgeColor:(double)rating {
    if (rating >= 4)  return [AppColorProvider successColor];
    if (rating >= 3)  return [AppColorProvider idleColor];
    if (rating > 0)   return [AppColorProvider alertColor];
    return UIColor.systemGray2Color;
}

-(instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)reuse_identifier {
    self = [super initWithStyle:style reuseIdentifier:reuse_identifier];
    if (!self) return nil;
    [self setup];
    return self;
}

-(void)setup {
    self.backgroundColor = UIColor.clearColor;

    _image_view = [LoadableImageView new];
    _image_view.layer.cornerRadius = AppRadiusMedium;
    _image_view.layer.cornerCurve = kCACornerCurveContinuous;
    _image_view.clipsToBounds = YES;
    _image_view.contentMode = UIViewContentModeScaleAspectFill;
    _image_view.backgroundColor = [AppColorProvider posterPlaceholderColor];

    // Soft shadow under the poster — matches grid cell aesthetic for visual
    // consistency between list / grid display modes.
    _image_view.layer.shadowColor   = UIColor.blackColor.CGColor;
    _image_view.layer.shadowOpacity = 0.0; // shadow lives on a wrapper container, see below
    _image_view.layer.masksToBounds = YES;

    _title_label = [UILabel new];
    _title_label.font = [UIFont app_fontForStyle:AppTextStyleSubheadline weight:UIFontWeightSemibold];
    _title_label.textColor = [AppColorProvider textColor];
    _title_label.numberOfLines = 2;
    _title_label.adjustsFontForContentSizeCategory = YES;

    // Monospaced digits keep "★ 8.5 · 12/12 эп" from jumping width as content
    // loads. Same Caption1 style is used by the grid cell rating chip.
    _meta_label = [UILabel new];
    _meta_label.font = [UIFont app_monospacedDigitFontForStyle:AppTextStyleCaption1 weight:UIFontWeightSemibold];
    _meta_label.textColor = [AppColorProvider textSecondaryColor];
    _meta_label.numberOfLines = 1;
    _meta_label.adjustsFontForContentSizeCategory = YES;

    _description_label = [UILabel new];
    _description_label.font = [UIFont app_fontForStyle:AppTextStyleFootnote];
    _description_label.textColor = [AppColorProvider textTertiaryColor];
    _description_label.numberOfLines = 2;
    _description_label.adjustsFontForContentSizeCategory = YES;

    [self.contentView addSubview:_image_view];

    UIStackView* text_stack = [[UIStackView alloc] initWithArrangedSubviews:@[_title_label, _meta_label, _description_label]];
    text_stack.axis = UILayoutConstraintAxisVertical;
    text_stack.spacing = AppSpacing4;
    text_stack.alignment = UIStackViewAlignmentLeading;
    [self.contentView addSubview:text_stack];

    _image_view.translatesAutoresizingMaskIntoConstraints = NO;
    text_stack.translatesAutoresizingMaskIntoConstraints = NO;

    UILayoutGuide* margins = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_image_view.topAnchor       constraintEqualToAnchor:margins.topAnchor],
        [_image_view.leadingAnchor   constraintEqualToAnchor:margins.leadingAnchor],
        [_image_view.bottomAnchor    constraintEqualToAnchor:margins.bottomAnchor],
        [_image_view.widthAnchor     constraintEqualToConstant:kPosterWidth],
        [_image_view.heightAnchor    constraintEqualToConstant:kPosterHeight],

        [text_stack.leadingAnchor    constraintEqualToAnchor:_image_view.trailingAnchor constant:AppSpacing12],
        [text_stack.trailingAnchor   constraintEqualToAnchor:margins.trailingAnchor],
        [text_stack.centerYAnchor    constraintEqualToAnchor:_image_view.centerYAnchor],
        [text_stack.topAnchor        constraintGreaterThanOrEqualToAnchor:_image_view.topAnchor],
        [text_stack.bottomAnchor     constraintLessThanOrEqualToAnchor:_image_view.bottomAnchor]
    ]];

    self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

#pragma mark - Content

-(void)setImageUrl:(NSURL*)image_url       { [_image_view tryLoadImageWithURL:image_url]; }
-(void)setTitle:(NSString*)title           { _title_label.text = title; }
-(void)setDescription:(NSString*)description { _description_label.text = description; _description_label.hidden = description.length == 0; }

-(void)setEpCount:(NSUInteger)ep_count totalEpCount:(NSUInteger)total_ep_count {
    _ep_count = ep_count;
    _ep_total = total_ep_count;
    [self updateMetaLabel];
}

-(void)setRating:(double)rating {
    _current_rating = rating;
    [self updateMetaLabel];
}

// Combine rating + episode count into a single discreet meta line.
//   "★ 8.5 · 12/12 ep"   or   "12/12 ep"   if no rating yet.
-(void)updateMetaLabel {
    NSMutableString* meta = [NSMutableString new];

    if (_current_rating > 0) {
        double rounded = round(_current_rating * 10) / 10.0;
        [meta appendFormat:@"★ %@", [@(rounded) stringValue]];
    }

    if (_ep_count > 0 || _ep_total > 0) {
        if (meta.length > 0) [meta appendString:@"  ·  "];
        NSString* total = _ep_total != 0 ? [@(_ep_total) stringValue] : @"?";
        [meta appendFormat:@"%@/%@ %@",
            [@(_ep_count) stringValue], total,
            @"эп."];
    }

    _meta_label.text = meta;
    _meta_label.hidden = meta.length == 0;
}

@end
