//
//  LoadingSkeletonView.mm
//

#import "LoadingSkeletonView.h"
#import "AppColor.h"

@implementation LoadingSkeletonView {
    CAGradientLayer* _gradient;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.clipsToBounds = YES;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.backgroundColor = [AppColorProvider posterPlaceholderColor];

    _gradient = [CAGradientLayer layer];
    _gradient.startPoint = CGPointMake(0, 0.5);
    _gradient.endPoint   = CGPointMake(1, 0.5);
    [self.layer addSublayer:_gradient];
    [self refreshGradientColors];
    return self;
}

-(void)layoutSubviews {
    [super layoutSubviews];
    _gradient.frame = self.bounds;
}

-(void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self startAnimating];
    else             [self stopAnimating];
}

-(void)startAnimating {
    if ([_gradient animationForKey:@"shimmer"]) return;
    CABasicAnimation* anim = [CABasicAnimation animationWithKeyPath:@"locations"];
    anim.fromValue = @[@(-1.0), @(-0.5), @(0.0)];
    anim.toValue   = @[@( 1.0), @( 1.5), @( 2.0)];
    anim.duration  = 1.4;
    anim.repeatCount = HUGE_VALF;
    [_gradient addAnimation:anim forKey:@"shimmer"];
}

-(void)stopAnimating {
    [_gradient removeAnimationForKey:@"shimmer"];
}

-(void)refreshGradientColors {
    UIColor* base = [AppColorProvider posterPlaceholderColor];
    UIColor* hot  = [base colorWithAlphaComponent:0.0];
    UIColor* mid  = [UIColor colorWithWhite:1.0 alpha:0.15];
    _gradient.colors = @[(id)hot.CGColor, (id)mid.CGColor, (id)hot.CGColor];
    _gradient.locations = @[@0.0, @0.5, @1.0];
}

-(void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    self.backgroundColor = [AppColorProvider posterPlaceholderColor];
    [self refreshGradientColors];
}

@end
