//
//  OnboardingOverlayView.m
//  QuuppaTagDemo  v3.0
//

#import "OnboardingOverlayView.h"

static NSString * const kOnboardingDoneKey = @"quuppa_onboardingCompleted";

// ── String table ─────────────────────────────────────────────────────────────

static NSString *OBLoc(NSString *key, BOOL chinese) {
    static NSDictionary *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{
            @"skip":     @[@"Skip",         @"跳过"],
            @"next":     @[@"Next",         @"下一步"],
            @"start":    @[@"Get Started",  @"开始使用"],
            // Slide 0
            @"t0": @[@"Turn your iPhone into a Quuppa Tag",
                     @"将 iPhone 变为 Quuppa 位置标签"],
            @"b0": @[@"The Quuppa Intelligent Locating System uses BLE signals from your "
                      "device to determine its precise indoor position in real time.",
                     @"Quuppa 智能定位系统通过接收设备的蓝牙信号，实时计算室内精确位置。"],
            // Slide 1
            @"t1": @[@"Set your Tag ID",    @"设置标签 ID"],
            @"b1": @[@"Each device needs a unique 6-byte hex identifier.\n"
                      "Generate one randomly or type your own to match your Quuppa system.",
                     @"每台设备需要一个唯一的 6 字节十六进制标识符。\n"
                      "可以随机生成，也可以手动输入以匹配您的 Quuppa 系统配置。"],
            // Slide 2
            @"t2": @[@"Choose your Scene",  @"选择场景"],
            @"b2": @[@"Different environments need different signal settings.\n"
                      "Pick the preset that best matches how you will be moving.",
                     @"不同场景需要不同的信号参数。\n"
                      "请根据您的移动方式选择最合适的预设。"],
        };
    });
    NSArray *pair = table[key];
    if (!pair) return key;
    return pair[chinese ? 1 : 0];
}


// ── OnboardingOverlayView ─────────────────────────────────────────────────────

@interface OnboardingOverlayView ()
@property (nonatomic) BOOL chinese;
@property (nonatomic, copy) OnboardingCompletionBlock completion;
@property (nonatomic) NSInteger currentSlide;

// UI
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) UIScrollView  *scrollView;
@property (nonatomic, strong) UIButton      *skipButton;
@property (nonatomic, strong) UIButton      *nextButton;
@end

@implementation OnboardingOverlayView

// ── Factory ───────────────────────────────────────────────────────────────────

+ (void)presentIfNeededInView:(UIView *)parentView
                      chinese:(BOOL)chinese
                   completion:(OnboardingCompletionBlock)completion {
    BOOL done = [[NSUserDefaults standardUserDefaults] boolForKey:kOnboardingDoneKey];
    if (done) {
        if (completion) completion();
        return;
    }

    OnboardingOverlayView *overlay = [[OnboardingOverlayView alloc] initWithFrame:parentView.bounds
                                                                          chinese:chinese
                                                                       completion:completion];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.alpha = 0;
    [parentView addSubview:overlay];

    [UIView animateWithDuration:0.35 animations:^{ overlay.alpha = 1; }];
}

+ (void)resetOnboarding {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOnboardingDoneKey];
}

// ── Init ──────────────────────────────────────────────────────────────────────

- (instancetype)initWithFrame:(CGRect)frame
                      chinese:(BOOL)chinese
                   completion:(OnboardingCompletionBlock)completion {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _chinese    = chinese;
    _completion = [completion copy];
    _currentSlide = 0;
    [self buildUI];
    return self;
}

// ── UI construction ───────────────────────────────────────────────────────────

- (void)buildUI {
    UIColor *bg    = [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:0.97];
    UIColor *text1 = [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1.0];
    UIColor *text2 = [UIColor colorWithRed:0.40 green:0.40 blue:0.44 alpha:1.0];
    self.backgroundColor = bg;

    // Page control
    self.pageControl = [[UIPageControl alloc] init];
    self.pageControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.pageControl.numberOfPages = 3;
    self.pageControl.currentPage = 0;
    self.pageControl.pageIndicatorTintColor = [UIColor colorWithRed:0.22 green:0.22 blue:0.26 alpha:1.0];
    self.pageControl.currentPageIndicatorTintColor = [UIColor systemBlueColor];
    [self addSubview:self.pageControl];

    // Horizontal paging scroll view
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.scrollEnabled = NO;  // We drive paging programmatically
    self.scrollView.bounces = NO;
    [self addSubview:self.scrollView];

    // Build 3 slide views
    NSArray *titles = @[OBLoc(@"t0", _chinese), OBLoc(@"t1", _chinese), OBLoc(@"t2", _chinese)];
    NSArray *bodies  = @[OBLoc(@"b0", _chinese), OBLoc(@"b1", _chinese), OBLoc(@"b2", _chinese)];

    for (NSInteger i = 0; i < 3; i++) {
        UIView *slide = [self makeSlide:i title:titles[i] body:bodies[i]
                              textColor:text1 subtextColor:text2];
        [self.scrollView addSubview:slide];
    }

    // Skip button
    self.skipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.skipButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.skipButton setTitle:OBLoc(@"skip", _chinese) forState:UIControlStateNormal];
    self.skipButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [self.skipButton setTitleColor:text2 forState:UIControlStateNormal];
    [self.skipButton addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.skipButton];

    // Next / Get Started button
    self.nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.nextButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextButton.backgroundColor = [UIColor systemBlueColor];
    self.nextButton.layer.cornerRadius = 22;
    [self.nextButton setTitle:OBLoc(@"next", _chinese) forState:UIControlStateNormal];
    self.nextButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.nextButton];

    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.pageControl.topAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:20],
        [self.pageControl.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],

        [self.scrollView.topAnchor constraintEqualToAnchor:self.pageControl.bottomAnchor constant:8],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.skipButton.topAnchor constant:-20],

        [self.skipButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:32],
        [self.skipButton.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-24],
        [self.skipButton.heightAnchor constraintEqualToConstant:44],

        [self.nextButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
        [self.nextButton.bottomAnchor constraintEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.nextButton.widthAnchor constraintEqualToConstant:160],
        [self.nextButton.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (UIView *)makeSlide:(NSInteger)idx
                title:(NSString *)title
                 body:(NSString *)body
            textColor:(UIColor *)tc
         subtextColor:(UIColor *)sc {
    UIView *v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:v];

    // Illustration area
    UIView *illus = [self makeIllustration:idx];
    illus.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:illus];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = title;
    titleLbl.font = [UIFont systemFontOfSize:24 weight:UIFontWeightHeavy];
    titleLbl.textColor = tc;
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.numberOfLines = 2;
    titleLbl.adjustsFontSizeToFitWidth = YES;
    titleLbl.minimumScaleFactor = 0.8;
    [v addSubview:titleLbl];

    UILabel *bodyLbl = [[UILabel alloc] init];
    bodyLbl.translatesAutoresizingMaskIntoConstraints = NO;
    bodyLbl.text = body;
    bodyLbl.font = [UIFont systemFontOfSize:15];
    bodyLbl.textColor = sc;
    bodyLbl.textAlignment = NSTextAlignmentCenter;
    bodyLbl.numberOfLines = 0;
    bodyLbl.lineBreakMode = NSLineBreakByWordWrapping;
    [v addSubview:bodyLbl];

    // Slide constraints — will be resolved once we know scrollView bounds
    // Use autoresizingMask trick: slide width = self.bounds.size.width
    // We use a tag to position slides programmatically in layoutSubviews
    v.tag = idx;

    [NSLayoutConstraint activateConstraints:@[
        [illus.topAnchor constraintEqualToAnchor:v.topAnchor constant:30],
        [illus.centerXAnchor constraintEqualToAnchor:v.centerXAnchor],
        [illus.heightAnchor constraintEqualToConstant:160],
        [illus.widthAnchor constraintEqualToConstant:220],

        [titleLbl.topAnchor constraintEqualToAnchor:illus.bottomAnchor constant:28],
        [titleLbl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:28],
        [titleLbl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-28],

        [bodyLbl.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:14],
        [bodyLbl.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:28],
        [bodyLbl.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-28],
    ]];

    return v;
}

// Simple placeholder illustrations for each onboarding step
- (UIView *)makeIllustration:(NSInteger)idx {
    UIView *container = [[UIView alloc] init];
    container.layer.cornerRadius = 24;
    container.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0];

    switch (idx) {
        case 0: { // Quuppa Q logo with concentric rings
            UIView *ring1 = [self ringViewOfSize:140 borderWidth:1.0];
            UIView *ring2 = [self ringViewOfSize:100 borderWidth:1.5];
            UIView *ring3 = [self ringViewOfSize:60  borderWidth:2.0];
            for (UIView *r in @[ring1, ring2, ring3]) {
                r.center = CGPointMake(110, 80);
                [container addSubview:r];
            }
            break;
        }
        case 1: { // Mock Tag ID display
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, 180, 50)];
            lbl.text = @"AB:CD:EF:12:34:56";
            lbl.font = [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightBold];
            lbl.textColor = [UIColor systemBlueColor];
            lbl.textAlignment = NSTextAlignmentCenter;
            lbl.layer.cornerRadius = 10;
            lbl.layer.borderWidth = 1;
            lbl.layer.borderColor = [UIColor colorWithRed:0.15 green:0.35 blue:0.65 alpha:1.0].CGColor;
            lbl.backgroundColor = [UIColor colorWithRed:0.04 green:0.12 blue:0.24 alpha:1.0];
            [container addSubview:lbl];
            break;
        }
        case 2: { // Mini 2×2 preset grid
            NSArray *letters = @[@"S",@"W",@"R",@"V"];
            NSArray *colors  = @[[UIColor systemBlueColor],[UIColor systemGreenColor],
                                 [UIColor systemOrangeColor],[UIColor systemRedColor]];
            for (NSInteger i = 0; i < 4; i++) {
                NSInteger col = i % 2, row = i / 2;
                UIView *cell = [[UIView alloc] initWithFrame:CGRectMake(34+col*78, 20+row*66, 64, 56)];
                cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
                cell.layer.cornerRadius = 10;
                cell.layer.borderWidth = 1;
                cell.layer.borderColor = (i == 0)
                    ? [UIColor systemBlueColor].CGColor
                    : [UIColor colorWithRed:0.22 green:0.22 blue:0.26 alpha:1.0].CGColor;
                UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(10, 9, 24, 24)];
                badge.text = letters[i];
                badge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
                badge.textColor = (i == 0) ? [UIColor whiteColor]
                    : [UIColor colorWithRed:0.5 green:0.5 blue:0.55 alpha:1.0];
                badge.textAlignment = NSTextAlignmentCenter;
                badge.backgroundColor = (i == 0) ? colors[i]
                    : [UIColor colorWithRed:0.18 green:0.18 blue:0.21 alpha:1.0];
                badge.layer.cornerRadius = 6;
                badge.layer.masksToBounds = YES;
                [cell addSubview:badge];
                [container addSubview:cell];
            }
            break;
        }
    }
    return container;
}

- (UIView *)ringViewOfSize:(CGFloat)size borderWidth:(CGFloat)bw {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    v.layer.cornerRadius = size / 2;
    v.layer.borderWidth  = bw;
    v.layer.borderColor  = [UIColor colorWithRed:0.1 green:0.45 blue:0.9 alpha:0.6].CGColor;
    return v;
}

// ── Layout: position slides inside scrollView ─────────────────────────────────

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat w = self.scrollView.bounds.size.width;
    CGFloat h = self.scrollView.bounds.size.height;
    if (w == 0 || h == 0) return;

    NSArray *slides = self.scrollView.subviews;
    for (UIView *slide in slides) {
        NSInteger idx = slide.tag;
        slide.frame = CGRectMake(idx * w, 0, w, h);
    }
    self.scrollView.contentSize = CGSizeMake(w * 3, h);
    // Keep scroll position in sync after rotation
    [self.scrollView setContentOffset:CGPointMake(_currentSlide * w, 0) animated:NO];
}


// ── Actions ───────────────────────────────────────────────────────────────────

- (void)nextTapped {
    if (_currentSlide < 2) {
        _currentSlide++;
        self.pageControl.currentPage = _currentSlide;
        CGFloat w = self.scrollView.bounds.size.width;
        [self.scrollView setContentOffset:CGPointMake(_currentSlide * w, 0) animated:YES];
        // Last slide → change button label
        if (_currentSlide == 2) {
            [self.nextButton setTitle:OBLoc(@"start", _chinese) forState:UIControlStateNormal];
        }
    } else {
        [self finish];
    }
}

- (void)finish {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kOnboardingDoneKey];
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL done) {
        [self removeFromSuperview];
        if (self.completion) self.completion();
    }];
}

@end
