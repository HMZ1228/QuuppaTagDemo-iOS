//
//  ViewController.m  (v3.0)
//  QuuppaTagDemo
//
//  ─── v3 additions over v2 ────────────────────────────────────────────────────
//  • OnboardingOverlayView  — 3-step first-launch walkthrough
//  • TagHistoryManager      — persists last 10 Tag IDs; restored in UI
//  • QRCodeGenerator        — CoreImage QR code; presented in a modal sheet
//  • UIImpactFeedbackGenerator — haptic on every primary action
//  • Background BLE advertising (requires bluetooth-peripheral UIBackgroundMode
//    declared in Info.plist — already included)
//  • Share sheet via UIActivityViewController on the QR screen
//  • LIVE indicator (pulsing dot) in the logo area when broadcasting
//  • Battery-impact bars (1–4, colour-coded) on preset cards
//  ────────────────────────────────────────────────────────────────────────────

#import "ViewController.h"
#import "QuuppaLogoUiView.h"
#import "TagHistoryManager.h"
#import "OnboardingOverlayView.h"
#import "QRCodeGenerator.h"
#include "crc-8.h"

@import CoreLocation;
@import CoreBluetooth;
@import Security;

// ── Constants ────────────────────────────────────────────────────────────────

static NSString * const kBeaconID       = @"com.quuppa.quuppaTagDemo";
static NSString * const kKeyUUID        = @"UUIDString";
static NSString * const kKeyTagID       = @"tagID";
static NSString * const kKeyPreset      = @"scenePreset";
static NSString * const kKeyLang        = @"useChinese";

// ── Scene preset ─────────────────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, QTagPreset) {
    QTagPresetStationary = 0,
    QTagPresetWalking    = 1,
    QTagPresetRunning    = 2,
    QTagPresetVehicle    = 3,
};

typedef struct {
    NSInteger measuredPower;   // dBm hint for Quuppa locators
    double    displayHz;       // informational label only
    NSInteger batteryBars;     // 1–4 (used for UI indicator)
} QPresetConfig;

static const QPresetConfig kPresets[4] = {
    { 86, 1.0,  1 },   // Stationary  — Quuppa spec reference value
    { 75, 3.0,  2 },   // Walking
    { 69, 5.0,  3 },   // Running
    { 60, 10.0, 4 },   // Vehicle
};

// Battery-bar active colours per preset
static UIColor *BarColor(NSInteger presetIndex) {
    switch (presetIndex) {
        case 0: return [UIColor systemBlueColor];
        case 1: return [UIColor systemGreenColor];
        case 2: return [UIColor systemOrangeColor];
        case 3: return [UIColor systemRedColor];
        default: return [UIColor systemBlueColor];
    }
}

// ── Localisation ──────────────────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, QLKey) {
    QLAppTitle, QLTagID, QLCopy, QLCopied, QLRandom, QLManual, QLCancel, QLApply,
    QLScenePreset, QLStationary, QLWalking, QLRunning, QLVehicle,
    QLStartBroadcast, QLStopBroadcast, QLStatusIdle, QLStatusBroadcasting,
    QLAlertBTTitle, QLAlertBTMsg, QLAlertNoIDTitle, QLAlertNoIDMsg,
    QLAlertBadIDTitle, QLAlertBadIDMsg,
    QLHistory, QLClearHistory, QLQRTitle, QLQRHint, QLShare, QLOK,
};

static NSString *L(QLKey k, BOOL zh) {
    static NSArray *T;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ T = @[
        @[@"QuuppaTag",            @"Quuppa 标签"],
        @[@"TAG ID",               @"标签 ID"],
        @[@"Copy",                 @"复制"],
        @[@"Copied",               @"已复制"],
        @[@"Random",               @"随机生成"],
        @[@"Manual",               @"手动输入"],
        @[@"Cancel",               @"取消"],
        @[@"Apply",                @"确定"],
        @[@"SCENE PRESET",         @"场景预设"],
        @[@"Stationary",           @"静止"],
        @[@"Walking",              @"步行"],
        @[@"Running",              @"跑步"],
        @[@"Vehicle",              @"驾驶"],
        @[@"Start Broadcasting",   @"开始广播"],
        @[@"Stop Broadcasting",    @"停止广播"],
        @[@"Tap to broadcast as a Quuppa tag", @"点击开始广播 Quuppa 信号"],
        @[@"Broadcasting · Quuppa locators tracking this device", @"广播中 · Quuppa 定位器正在追踪"],
        @[@"Bluetooth Required",   @"需要开启蓝牙"],
        @[@"Enable Bluetooth in Settings to use this device as a Quuppa beacon.",
          @"请在"设置"中开启蓝牙，以将此设备用作 Quuppa 信标。"],
        @[@"Tag ID Not Set",       @"尚未设置标签 ID"],
        @[@"Tap "Random" or "Manual" to set a Tag ID first.",
          @"请先点击"随机生成"或"手动输入"设置标签 ID。"],
        @[@"Invalid Tag ID",       @"标签 ID 无效"],
        @[@"Please enter exactly 12 hexadecimal characters (0–9, A–F).",
          @"请输入恰好 12 位十六进制字符（0–9，A–F）。"],
        @[@"Recent IDs",           @"最近使用"],
        @[@"Clear History",        @"清除历史"],
        @[@"Tag QR Code",          @"标签二维码"],
        @[@"Scan to share this Tag ID", @"扫码分享此标签 ID"],
        @[@"Share",                @"分享"],
        @[@"OK",                   @"确定"],
    ]; });
    return T[k][zh ? 1 : 0];
}


// ── ViewController ────────────────────────────────────────────────────────────

static CBPeripheralManager *sPeripheral = nil;
static CLBeaconRegion      *sRegion     = nil;

@interface ViewController () <CBPeripheralManagerDelegate>

// State
@property (nonatomic) BOOL       chinese;
@property (nonatomic) QTagPreset currentPreset;
@property (nonatomic) BOOL       broadcasting;
@property (nonatomic) BOOL       showingManualInput;
@property (nonatomic) BOOL       historyExpanded;

// Haptics
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactLight;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactMedium;

// Layout containers
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView       *contentView;

// Header
@property (nonatomic, strong) UILabel  *titleLabel;
@property (nonatomic, strong) UIButton *langButton;

// Logo / rings
@property (nonatomic, strong) QuuppaLogoUiView *logoView;
@property (nonatomic, strong) UIView           *liveIndicatorDot;
@property (nonatomic, strong) UILabel          *liveLabel;
@property (nonatomic, strong) NSArray<UIView *>*ringViews;   // 3 rings

// Tag ID card
@property (nonatomic, strong) UIView      *idCard;
@property (nonatomic, strong) UILabel     *idCardTitle;
@property (nonatomic, strong) UILabel     *idValueLabel;
@property (nonatomic, strong) UIButton    *copyButton;
@property (nonatomic, strong) UIButton    *qrButton;
@property (nonatomic, strong) UIButton    *historyButton;
// History dropdown
@property (nonatomic, strong) UIView      *historyDropdown;
@property (nonatomic, strong) UILabel     *historyTitle;
@property (nonatomic, strong) UIStackView *historyStack;
// Manual input
@property (nonatomic, strong) UIView      *manualContainer;
@property (nonatomic, strong) UITextField *manualField;
@property (nonatomic, strong) UIButton    *cancelManualBtn;
@property (nonatomic, strong) UIButton    *applyManualBtn;
// Action row
@property (nonatomic, strong) UIButton    *randomButton;
@property (nonatomic, strong) UIButton    *manualButton;

// Scene presets
@property (nonatomic, strong) UILabel              *presetSectionLabel;
@property (nonatomic, strong) NSArray<UIView *>    *presetCards;
@property (nonatomic, strong) NSArray<UIView *>    *presetBadges;
@property (nonatomic, strong) NSArray<UILabel *>   *presetBadgeLabels;
@property (nonatomic, strong) NSArray<UILabel *>   *presetNameLabels;
@property (nonatomic, strong) NSArray<NSArray<UIView *>*> *presetBarArrays; // [card][4 bars]

// Broadcast
@property (nonatomic, strong) UIButton *broadcastButton;
@property (nonatomic, strong) UIView   *statusRow;
@property (nonatomic, strong) UIView   *statusDot;
@property (nonatomic, strong) UILabel  *statusLabel;

@end

@implementation ViewController

// ── Lifecycle ────────────────────────────────────────────────────────────────

- (void)viewDidLoad {
    [super viewDidLoad];

    // Haptics
    _impactLight  = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    _impactMedium = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [_impactLight  prepare];
    [_impactMedium prepare];

    // Restore preferences
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:kKeyLang]) {
        _chinese = [ud boolForKey:kKeyLang];
    } else {
        _chinese = [[[NSLocale preferredLanguages].firstObject ?: @""] hasPrefix:@"zh"];
    }
    _currentPreset = (QTagPreset)[[ud objectForKey:kKeyPreset] ?: @0 integerValue];
    if (_currentPreset < 0 || _currentPreset > 3) _currentPreset = QTagPresetStationary;

    [self buildUI];
    [self applyLanguage];
    [self applyPreset:_currentPreset animated:NO];
    [self refreshIDDisplay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Init Bluetooth manager once
    if (!sPeripheral) {
        sPeripheral = [[CBPeripheralManager alloc]
                       initWithDelegate:self
                       queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
                       options:@{ CBPeripheralManagerOptionShowPowerAlertKey: @YES }];
    } else {
        sPeripheral.delegate = self;
    }
    if (sPeripheral.isAdvertising) {
        _broadcasting = YES;
        dispatch_async(dispatch_get_main_queue(), ^{ [self refreshBroadcastState]; });
    }

    // Show onboarding on first launch
    [OnboardingOverlayView presentIfNeededInView:self.view
                                         chinese:_chinese
                                      completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    sPeripheral.delegate = nil;
}

// ── UI construction ───────────────────────────────────────────────────────────

- (void)buildUI {
    self.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:1.0];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    self.contentView = [[UIView alloc] init];
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentView];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [self.contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [self.contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [self.contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [self.contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],
    ]];

    [self buildHeader];
    [self buildLogoArea];
    [self buildIDCard];
    [self buildPresetSection];
    [self buildBroadcastSection];
}

- (void)buildHeader {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightHeavy];
    self.titleLabel.textColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1.0];
    [self.contentView addSubview:self.titleLabel];

    self.langButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.langButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.langButton.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.11 alpha:1.0];
    self.langButton.layer.cornerRadius = 14;
    self.langButton.layer.borderWidth  = 0.5;
    self.langButton.layer.borderColor  = [UIColor colorWithRed:0.22 green:0.22 blue:0.26 alpha:1.0].CGColor;
    self.langButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.langButton setTitleColor:[UIColor colorWithRed:0.6 green:0.6 blue:0.65 alpha:1.0]
                          forState:UIControlStateNormal];
    self.langButton.contentEdgeInsets = UIEdgeInsetsMake(6, 14, 6, 14);
    [self.langButton addTarget:self action:@selector(toggleLanguage)
              forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.langButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:20],
        [self.langButton.centerYAnchor constraintEqualToAnchor:self.titleLabel.centerYAnchor],
        [self.langButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-20],
    ]];
}

- (void)buildLogoArea {
    UIView *logoContainer = [[UIView alloc] init];
    logoContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:logoContainer];

    // Animated rings (3 concentric)
    NSMutableArray<UIView *> *rings = [NSMutableArray array];
    CGFloat ringDiameters[] = { 64, 96, 128 };
    for (int i = 0; i < 3; i++) {
        UIView *r = [[UIView alloc] init];
        r.translatesAutoresizingMaskIntoConstraints = NO;
        r.layer.cornerRadius = ringDiameters[i] / 2;
        r.layer.borderWidth  = (i == 0) ? 1.5 : (i == 1) ? 1.0 : 0.5;
        r.layer.borderColor  = [UIColor systemBlueColor].CGColor;
        r.alpha = 0;
        [logoContainer addSubview:r];
        [rings addObject:r];
        [NSLayoutConstraint activateConstraints:@[
            [r.centerXAnchor constraintEqualToAnchor:logoContainer.centerXAnchor],
            [r.centerYAnchor constraintEqualToAnchor:logoContainer.centerYAnchor],
            [r.widthAnchor constraintEqualToConstant:ringDiameters[i]],
            [r.heightAnchor constraintEqualToConstant:ringDiameters[i]],
        ]];
    }
    self.ringViews = [rings copy];

    // Quuppa Q logo
    self.logoView = [[QuuppaLogoUiView alloc] init];
    self.logoView.translatesAutoresizingMaskIntoConstraints = NO;
    self.logoView.logoColor = [UIColor colorWithRed:0.73 green:0.73 blue:0.76 alpha:1.0];
    [logoContainer addSubview:self.logoView];

    // LIVE indicator
    self.liveIndicatorDot = [[UIView alloc] init];
    self.liveIndicatorDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveIndicatorDot.backgroundColor = [UIColor systemGreenColor];
    self.liveIndicatorDot.layer.cornerRadius = 4;
    self.liveIndicatorDot.alpha = 0;
    [logoContainer addSubview:self.liveIndicatorDot];

    self.liveLabel = [[UILabel alloc] init];
    self.liveLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.liveLabel.text = @"LIVE";
    self.liveLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightHeavy];
    self.liveLabel.textColor = [UIColor systemGreenColor];
    self.liveLabel.letterSpacing = 0.5;
    self.liveLabel.alpha = 0;
    [logoContainer addSubview:self.liveLabel];

    [NSLayoutConstraint activateConstraints:@[
        [logoContainer.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:8],
        [logoContainer.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [logoContainer.widthAnchor constraintEqualToConstant:160],
        [logoContainer.heightAnchor constraintEqualToConstant:160],

        [self.logoView.centerXAnchor constraintEqualToAnchor:logoContainer.centerXAnchor],
        [self.logoView.centerYAnchor constraintEqualToAnchor:logoContainer.centerYAnchor],
        [self.logoView.widthAnchor constraintEqualToConstant:80],
        [self.logoView.heightAnchor constraintEqualToConstant:90],

        [self.liveIndicatorDot.topAnchor constraintEqualToAnchor:logoContainer.topAnchor constant:14],
        [self.liveIndicatorDot.trailingAnchor constraintEqualToAnchor:logoContainer.trailingAnchor constant:-14],
        [self.liveIndicatorDot.widthAnchor constraintEqualToConstant:8],
        [self.liveIndicatorDot.heightAnchor constraintEqualToConstant:8],

        [self.liveLabel.centerYAnchor constraintEqualToAnchor:self.liveIndicatorDot.centerYAnchor],
        [self.liveLabel.trailingAnchor constraintEqualToAnchor:self.liveIndicatorDot.leadingAnchor constant:-4],
    ]];
}

- (void)buildIDCard {
    UIColor *cardBG  = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:1.0];
    UIColor *border  = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    UIColor *dimText = [UIColor colorWithRed:0.35 green:0.35 blue:0.40 alpha:1.0];

    self.idCard = [[UIView alloc] init];
    self.idCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.idCard.backgroundColor = cardBG;
    self.idCard.layer.cornerRadius = 16;
    self.idCard.layer.borderWidth  = 0.5;
    self.idCard.layer.borderColor  = border.CGColor;
    [self.contentView addSubview:self.idCard];

    // Section label
    self.idCardTitle = [[UILabel alloc] init];
    self.idCardTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.idCardTitle.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
    self.idCardTitle.textColor = dimText;
    [self.idCard addSubview:self.idCardTitle];

    // ID value
    self.idValueLabel = [[UILabel alloc] init];
    self.idValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.idValueLabel.font = [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightBold];
    self.idValueLabel.textColor = [UIColor systemBlueColor];
    self.idValueLabel.adjustsFontSizeToFitWidth = YES;
    self.idValueLabel.minimumScaleFactor = 0.7;
    [self.idCard addSubview:self.idValueLabel];

    // Icon buttons row (copy | qr | history)
    self.copyButton    = [self iconButton:@"doc.on.doc"    action:@selector(copyTagID)];
    self.qrButton      = [self iconButton:@"qrcode"        action:@selector(showQRCode)];
    self.historyButton = [self iconButton:@"clock"         action:@selector(toggleHistory)];
    [self.idCard addSubview:self.copyButton];
    [self.idCard addSubview:self.qrButton];
    [self.idCard addSubview:self.historyButton];

    // History dropdown
    self.historyDropdown = [[UIView alloc] init];
    self.historyDropdown.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyDropdown.hidden = YES;
    [self.idCard addSubview:self.historyDropdown];

    self.historyTitle = [[UILabel alloc] init];
    self.historyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyTitle.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
    self.historyTitle.textColor = dimText;
    [self.historyDropdown addSubview:self.historyTitle];

    self.historyStack = [[UIStackView alloc] init];
    self.historyStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.historyStack.axis = UILayoutConstraintAxisVertical;
    self.historyStack.spacing = 2;
    [self.historyDropdown addSubview:self.historyStack];

    // Manual input container
    self.manualContainer = [[UIView alloc] init];
    self.manualContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.manualContainer.hidden = YES;
    [self.idCard addSubview:self.manualContainer];

    self.manualField = [[UITextField alloc] init];
    self.manualField.translatesAutoresizingMaskIntoConstraints = NO;
    self.manualField.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.13 alpha:1.0];
    self.manualField.layer.cornerRadius = 10;
    self.manualField.layer.borderWidth  = 0.5;
    self.manualField.layer.borderColor  = border.CGColor;
    self.manualField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.manualField.textColor = [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:1.0];
    self.manualField.keyboardType = UIKeyboardTypeASCIICapable;
    self.manualField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.manualField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.manualField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,10,1)];
    self.manualField.leftViewMode = UITextFieldViewModeAlways;
    [self.manualContainer addSubview:self.manualField];

    self.cancelManualBtn = [self smallTextButton:@selector(cancelManualEntry)
                                       title:@"Cancel"
                                        fill:[UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0]
                                        tint:[UIColor colorWithRed:0.55 green:0.55 blue:0.60 alpha:1.0]];
    self.applyManualBtn = [self smallTextButton:@selector(applyManualEntry)
                                      title:@"Apply"
                                       fill:[UIColor systemBlueColor]
                                       tint:[UIColor whiteColor]];
    [self.manualContainer addSubview:self.cancelManualBtn];
    [self.manualContainer addSubview:self.applyManualBtn];

    // Action buttons
    self.randomButton = [self actionButton:@selector(generateRandomID) accent:YES];
    self.manualButton = [self actionButton:@selector(showManualEntry)  accent:NO];
    [self.idCard addSubview:self.randomButton];
    [self.idCard addSubview:self.manualButton];

    // ── Internal layout
    [NSLayoutConstraint activateConstraints:@[
        // Card anchor (top relative to logo is set in buildPresetSection after logo)
        [self.idCard.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.idCard.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        // Section label
        [self.idCardTitle.topAnchor constraintEqualToAnchor:self.idCard.topAnchor constant:12],
        [self.idCardTitle.leadingAnchor constraintEqualToAnchor:self.idCard.leadingAnchor constant:14],

        // Icon buttons (right-aligned, same row as section label)
        [self.historyButton.centerYAnchor constraintEqualToAnchor:self.idCardTitle.centerYAnchor],
        [self.historyButton.trailingAnchor constraintEqualToAnchor:self.idCard.trailingAnchor constant:-8],
        [self.qrButton.centerYAnchor constraintEqualToAnchor:self.idCardTitle.centerYAnchor],
        [self.qrButton.trailingAnchor constraintEqualToAnchor:self.historyButton.leadingAnchor constant:-2],
        [self.copyButton.centerYAnchor constraintEqualToAnchor:self.idCardTitle.centerYAnchor],
        [self.copyButton.trailingAnchor constraintEqualToAnchor:self.qrButton.leadingAnchor constant:-2],

        // ID value
        [self.idValueLabel.topAnchor constraintEqualToAnchor:self.idCardTitle.bottomAnchor constant:5],
        [self.idValueLabel.leadingAnchor constraintEqualToAnchor:self.idCard.leadingAnchor constant:14],
        [self.idValueLabel.trailingAnchor constraintEqualToAnchor:self.idCard.trailingAnchor constant:-14],

        // History dropdown
        [self.historyDropdown.topAnchor constraintEqualToAnchor:self.idValueLabel.bottomAnchor constant:8],
        [self.historyDropdown.leadingAnchor constraintEqualToAnchor:self.idCard.leadingAnchor constant:14],
        [self.historyDropdown.trailingAnchor constraintEqualToAnchor:self.idCard.trailingAnchor constant:-14],

        [self.historyTitle.topAnchor constraintEqualToAnchor:self.historyDropdown.topAnchor],
        [self.historyTitle.leadingAnchor constraintEqualToAnchor:self.historyDropdown.leadingAnchor],

        [self.historyStack.topAnchor constraintEqualToAnchor:self.historyTitle.bottomAnchor constant:5],
        [self.historyStack.leadingAnchor constraintEqualToAnchor:self.historyDropdown.leadingAnchor],
        [self.historyStack.trailingAnchor constraintEqualToAnchor:self.historyDropdown.trailingAnchor],
        [self.historyStack.bottomAnchor constraintEqualToAnchor:self.historyDropdown.bottomAnchor],

        // Manual input container
        [self.manualContainer.topAnchor constraintEqualToAnchor:self.historyDropdown.bottomAnchor constant:8],
        [self.manualContainer.leadingAnchor constraintEqualToAnchor:self.idCard.leadingAnchor constant:14],
        [self.manualContainer.trailingAnchor constraintEqualToAnchor:self.idCard.trailingAnchor constant:-14],
        [self.manualContainer.heightAnchor constraintEqualToConstant:84],

        [self.manualField.topAnchor constraintEqualToAnchor:self.manualContainer.topAnchor],
        [self.manualField.leadingAnchor constraintEqualToAnchor:self.manualContainer.leadingAnchor],
        [self.manualField.trailingAnchor constraintEqualToAnchor:self.manualContainer.trailingAnchor],
        [self.manualField.heightAnchor constraintEqualToConstant:42],

        [self.cancelManualBtn.topAnchor constraintEqualToAnchor:self.manualField.bottomAnchor constant:6],
        [self.cancelManualBtn.leadingAnchor constraintEqualToAnchor:self.manualContainer.leadingAnchor],
        [self.cancelManualBtn.trailingAnchor constraintEqualToAnchor:self.manualContainer.centerXAnchor constant:-4],
        [self.cancelManualBtn.heightAnchor constraintEqualToConstant:36],

        [self.applyManualBtn.topAnchor constraintEqualToAnchor:self.manualField.bottomAnchor constant:6],
        [self.applyManualBtn.leadingAnchor constraintEqualToAnchor:self.manualContainer.centerXAnchor constant:4],
        [self.applyManualBtn.trailingAnchor constraintEqualToAnchor:self.manualContainer.trailingAnchor],
        [self.applyManualBtn.heightAnchor constraintEqualToConstant:36],

        // Action button row
        [self.randomButton.topAnchor constraintEqualToAnchor:self.manualContainer.bottomAnchor constant:8],
        [self.randomButton.leadingAnchor constraintEqualToAnchor:self.idCard.leadingAnchor constant:14],
        [self.randomButton.trailingAnchor constraintEqualToAnchor:self.idCard.centerXAnchor constant:-4],
        [self.randomButton.heightAnchor constraintEqualToConstant:38],
        [self.randomButton.bottomAnchor constraintEqualToAnchor:self.idCard.bottomAnchor constant:-12],

        [self.manualButton.topAnchor constraintEqualToAnchor:self.randomButton.topAnchor],
        [self.manualButton.leadingAnchor constraintEqualToAnchor:self.idCard.centerXAnchor constant:4],
        [self.manualButton.trailingAnchor constraintEqualToAnchor:self.idCard.trailingAnchor constant:-14],
        [self.manualButton.heightAnchor constraintEqualToConstant:38],
    ]];
}

- (void)buildPresetSection {
    // Find the logo container to anchor below it
    UIView *logoContainer = self.ringViews.firstObject.superview;

    // Anchor idCard below logoContainer
    [NSLayoutConstraint activateConstraints:@[
        [self.idCard.topAnchor constraintEqualToAnchor:logoContainer.bottomAnchor constant:12],
    ]];

    self.presetSectionLabel = [[UILabel alloc] init];
    self.presetSectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.presetSectionLabel.font = [UIFont monospacedSystemFontOfSize:9.5 weight:UIFontWeightRegular];
    self.presetSectionLabel.textColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.40 alpha:1.0];
    [self.contentView addSubview:self.presetSectionLabel];

    NSMutableArray<UIView *>    *cards    = [NSMutableArray array];
    NSMutableArray<UIView *>    *badges   = [NSMutableArray array];
    NSMutableArray<UILabel *>   *badgeLbls= [NSMutableArray array];
    NSMutableArray<UILabel *>   *names    = [NSMutableArray array];
    NSMutableArray<NSArray *>   *barArrs  = [NSMutableArray array];

    NSArray *letters = @[@"S", @"W", @"R", @"V"];

    for (NSInteger i = 0; i < 4; i++) {
        UIView *card = [self presetCardAtIndex:i
                                        letter:letters[i]
                                        badges:badges
                                    badgeLbls:badgeLbls
                                         names:names
                                       barArrs:barArrs];
        [self.contentView addSubview:card];
        [cards addObject:card];
    }
    self.presetCards      = [cards copy];
    self.presetBadges     = [badges copy];
    self.presetBadgeLabels= [badgeLbls copy];
    self.presetNameLabels = [names copy];
    self.presetBarArrays  = [barArrs copy];

    const CGFloat kGap  = 8, kSide = 16;
    [NSLayoutConstraint activateConstraints:@[
        [self.presetSectionLabel.topAnchor constraintEqualToAnchor:self.idCard.bottomAnchor constant:18],
        [self.presetSectionLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSide],

        [cards[0].topAnchor constraintEqualToAnchor:self.presetSectionLabel.bottomAnchor constant:8],
        [cards[0].leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:kSide],
        [cards[0].trailingAnchor constraintEqualToAnchor:self.contentView.centerXAnchor constant:-kGap/2],

        [cards[1].topAnchor constraintEqualToAnchor:cards[0].topAnchor],
        [cards[1].leadingAnchor constraintEqualToAnchor:self.contentView.centerXAnchor constant:kGap/2],
        [cards[1].trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-kSide],
        [cards[1].heightAnchor constraintEqualToAnchor:cards[0].heightAnchor],

        [cards[2].topAnchor constraintEqualToAnchor:cards[0].bottomAnchor constant:kGap],
        [cards[2].leadingAnchor constraintEqualToAnchor:cards[0].leadingAnchor],
        [cards[2].trailingAnchor constraintEqualToAnchor:cards[0].trailingAnchor],
        [cards[2].heightAnchor constraintEqualToAnchor:cards[0].heightAnchor],

        [cards[3].topAnchor constraintEqualToAnchor:cards[2].topAnchor],
        [cards[3].leadingAnchor constraintEqualToAnchor:cards[1].leadingAnchor],
        [cards[3].trailingAnchor constraintEqualToAnchor:cards[1].trailingAnchor],
        [cards[3].heightAnchor constraintEqualToAnchor:cards[0].heightAnchor],
    ]];
}

- (UIView *)presetCardAtIndex:(NSInteger)i letter:(NSString *)letter
                       badges:(NSMutableArray *)badges badgeLbls:(NSMutableArray *)badgeLbls
                        names:(NSMutableArray *)names barArrs:(NSMutableArray *)barArrs {

    UIColor *cardBG = [UIColor colorWithRed:0.07 green:0.07 blue:0.08 alpha:1.0];
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = cardBG;
    card.layer.cornerRadius = 14;
    card.layer.borderWidth  = 1.5;
    card.layer.borderColor  = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0].CGColor;
    card.tag = i;
    card.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(presetCardTapped:)];
    [card addGestureRecognizer:tap];

    // Badge
    UIView *badge = [[UIView alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.layer.cornerRadius = 8;
    badge.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    [card addSubview:badge];

    UILabel *badgeLbl = [[UILabel alloc] init];
    badgeLbl.translatesAutoresizingMaskIntoConstraints = NO;
    badgeLbl.text = letter;
    badgeLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
    badgeLbl.textColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.40 alpha:1.0];
    badgeLbl.textAlignment = NSTextAlignmentCenter;
    [badge addSubview:badgeLbl];

    // Battery bars (4)
    UIStackView *barStack = [[UIStackView alloc] init];
    barStack.translatesAutoresizingMaskIntoConstraints = NO;
    barStack.axis = UILayoutConstraintAxisHorizontal;
    barStack.spacing = 2;
    barStack.alignment = UIStackViewAlignmentBottom;
    [card addSubview:barStack];

    NSMutableArray<UIView *> *bars = [NSMutableArray array];
    CGFloat barHeights[] = { 6, 9, 11, 13 };
    for (NSInteger b = 0; b < 4; b++) {
        UIView *bar = [[UIView alloc] init];
        bar.translatesAutoresizingMaskIntoConstraints = NO;
        bar.layer.cornerRadius = 1;
        bar.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
        [barStack addArrangedSubview:bar];
        [NSLayoutConstraint activateConstraints:@[
            [bar.widthAnchor constraintEqualToConstant:3],
            [bar.heightAnchor constraintEqualToConstant:barHeights[b]],
        ]];
        [bars addObject:bar];
    }
    [barArrs addObject:[bars copy]];

    // Name label
    UILabel *nameLbl = [[UILabel alloc] init];
    nameLbl.translatesAutoresizingMaskIntoConstraints = NO;
    nameLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    nameLbl.textColor = [UIColor colorWithRed:0.45 green:0.45 blue:0.50 alpha:1.0];
    [card addSubview:nameLbl];

    // Detail label
    UILabel *detailLbl = [[UILabel alloc] init];
    detailLbl.translatesAutoresizingMaskIntoConstraints = NO;
    detailLbl.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
    detailLbl.textColor = [UIColor colorWithRed:0.28 green:0.28 blue:0.32 alpha:1.0];
    detailLbl.text = [NSString stringWithFormat:@"%.0f Hz · %ld dBm",
                      kPresets[i].displayHz, (long)kPresets[i].measuredPower];
    [card addSubview:detailLbl];

    [NSLayoutConstraint activateConstraints:@[
        [badge.topAnchor constraintEqualToAnchor:card.topAnchor constant:10],
        [badge.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:10],
        [badge.widthAnchor constraintEqualToConstant:30],
        [badge.heightAnchor constraintEqualToConstant:30],

        [badgeLbl.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [badgeLbl.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],

        [barStack.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor],
        [barStack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-10],

        [nameLbl.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:7],
        [nameLbl.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:10],
        [nameLbl.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-8],

        [detailLbl.topAnchor constraintEqualToAnchor:nameLbl.bottomAnchor constant:2],
        [detailLbl.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:10],
        [detailLbl.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-10],
    ]];

    [badges addObject:badge];
    [badgeLbls addObject:badgeLbl];
    [names addObject:nameLbl];
    return card;
}

- (void)buildBroadcastSection {
    UIView *lastCard = self.presetCards[2]; // bottom-left card anchors broadcast btn

    self.broadcastButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.broadcastButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.broadcastButton.backgroundColor = [UIColor systemBlueColor];
    self.broadcastButton.layer.cornerRadius = 16;
    self.broadcastButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.broadcastButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.broadcastButton addTarget:self action:@selector(toggleBroadcast)
                   forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.broadcastButton];

    self.statusRow = [[UIView alloc] init];
    self.statusRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.statusRow];

    self.statusDot = [[UIView alloc] init];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.layer.cornerRadius = 3;
    self.statusDot.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.28 alpha:1.0];
    [self.statusRow addSubview:self.statusDot];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.44 alpha:1.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.statusRow addSubview:self.statusLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.broadcastButton.topAnchor constraintEqualToAnchor:lastCard.bottomAnchor constant:20],
        [self.broadcastButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.broadcastButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.broadcastButton.heightAnchor constraintEqualToConstant:56],

        [self.statusRow.topAnchor constraintEqualToAnchor:self.broadcastButton.bottomAnchor constant:10],
        [self.statusRow.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [self.statusRow.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-32],

        [self.statusDot.leadingAnchor constraintEqualToAnchor:self.statusRow.leadingAnchor],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.statusRow.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:6],
        [self.statusDot.heightAnchor constraintEqualToConstant:6],

        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:6],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.statusRow.trailingAnchor],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusRow.centerYAnchor],
    ]];
}


// ── Button / view factories ───────────────────────────────────────────────────

- (UIButton *)iconButton:(NSString *)sfSymbol action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:15
                                                                                      weight:UIImageSymbolWeightRegular];
    UIImage *img = [UIImage systemImageNamed:sfSymbol withConfiguration:cfg];
    [b setImage:img forState:UIControlStateNormal];
    b.tintColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [b.widthAnchor constraintEqualToConstant:36].active = YES;
    [b.heightAnchor constraintEqualToConstant:36].active = YES;
    return b;
}

- (UIButton *)smallTextButton:(SEL)action title:(NSString *)t fill:(UIColor *)fill tint:(UIColor *)tint {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.backgroundColor = fill;
    b.layer.cornerRadius = 10;
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [b setTitle:t forState:UIControlStateNormal];
    [b setTitleColor:tint forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (UIButton *)actionButton:(SEL)action accent:(BOOL)accent {
    UIColor *tint = accent ? [UIColor systemBlueColor]
                           : [UIColor colorWithRed:0.55 green:0.55 blue:0.60 alpha:1.0];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    b.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.12 alpha:1.0];
    b.layer.cornerRadius = 10;
    b.layer.borderWidth  = 0.5;
    b.layer.borderColor  = [UIColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0].CGColor;
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [b setTitleColor:tint forState:UIControlStateNormal];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}


// ── Language ──────────────────────────────────────────────────────────────────

- (void)toggleLanguage {
    [_impactLight impactOccurred];
    _chinese = !_chinese;
    [[NSUserDefaults standardUserDefaults] setBool:_chinese forKey:kKeyLang];
    [self applyLanguage];
}

- (void)applyLanguage {
    self.titleLabel.text = L(QLAppTitle, _chinese);
    [self.langButton setTitle:(_chinese ? @"EN" : @"中文") forState:UIControlStateNormal];
    self.idCardTitle.text = L(QLTagID, _chinese);
    self.manualField.placeholder = _chinese ? @"例如 112233445566" : @"e.g.  112233445566";
    [self.cancelManualBtn setTitle:L(QLCancel, _chinese) forState:UIControlStateNormal];
    [self.applyManualBtn  setTitle:L(QLApply,  _chinese) forState:UIControlStateNormal];
    [self.randomButton setTitle:L(QLRandom, _chinese) forState:UIControlStateNormal];
    [self.manualButton setTitle:L(QLManual, _chinese) forState:UIControlStateNormal];
    self.historyTitle.text = L(QLHistory, _chinese);
    self.presetSectionLabel.text = L(QLScenePreset, _chinese);

    QLKey presetKeys[4] = { QLStationary, QLWalking, QLRunning, QLVehicle };
    for (NSInteger i = 0; i < 4; i++) {
        self.presetNameLabels[i].text = L(presetKeys[i], _chinese);
    }
    [self refreshBroadcastState];
}


// ── Preset ────────────────────────────────────────────────────────────────────

- (void)presetCardTapped:(UITapGestureRecognizer *)tap {
    [_impactLight impactOccurred];
    [self applyPreset:tap.view.tag animated:YES];
    if (_broadcasting) [self updateAdvertisedRegion:YES];
}

- (void)applyPreset:(QTagPreset)preset animated:(BOOL)animated {
    _currentPreset = preset;
    [[NSUserDefaults standardUserDefaults] setObject:@(preset) forKey:kKeyPreset];

    void (^update)(void) = ^{
        for (NSInteger i = 0; i < 4; i++) {
            BOOL sel = (i == preset);
            UIColor *activeBorder = sel ? [UIColor systemBlueColor]
                : [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
            self.presetCards[i].layer.borderColor = activeBorder.CGColor;

            self.presetBadges[i].backgroundColor = sel ? BarColor(i)
                : [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
            self.presetBadgeLabels[i].textColor = sel ? [UIColor whiteColor]
                : [UIColor colorWithRed:0.35 green:0.35 blue:0.40 alpha:1.0];
            self.presetNameLabels[i].textColor = sel
                ? [UIColor colorWithRed:0.88 green:0.88 blue:0.90 alpha:1.0]
                : [UIColor colorWithRed:0.45 green:0.45 blue:0.50 alpha:1.0];

            NSArray<UIView *> *bars = self.presetBarArrays[i];
            NSInteger activeBars = kPresets[i].batteryBars;
            for (NSInteger b = 0; b < 4; b++) {
                bars[b].backgroundColor = (sel && b < activeBars)
                    ? BarColor(i)
                    : [UIColor colorWithRed:0.15 green:0.15 blue:0.18 alpha:1.0];
            }
        }
    };

    animated ? [UIView animateWithDuration:0.2 animations:update] : update();
}


// ── Tag ID ────────────────────────────────────────────────────────────────────

- (void)refreshIDDisplay {
    NSString *tagID = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyTagID];
    if (tagID.length == 12) {
        NSMutableString *f = [NSMutableString string];
        for (NSInteger i = 0; i < 6; i++) {
            if (i) [f appendString:@":"];
            [f appendString:[tagID substringWithRange:NSMakeRange(i*2, 2)].uppercaseString];
        }
        self.idValueLabel.text = f;
    } else {
        self.idValueLabel.text = _chinese ? @"-- 未设置 --" : @"-- NOT SET --";
    }
    [self refreshHistoryList];
}

- (void)generateRandomID {
    [_impactMedium impactOccurred];
    uint8_t bytes[6];
    if (SecRandomCopyBytes(kSecRandomDefault, 6, bytes) != errSecSuccess) {
        for (int i = 0; i < 6; i++) bytes[i] = (uint8_t)(arc4random() % 256);
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:12];
    for (int i = 0; i < 6; i++) [hex appendFormat:@"%02X", bytes[i]];
    [self persistAndDisplayTagID:hex];
}

- (void)showManualEntry {
    [_impactLight impactOccurred];
    _showingManualInput = YES;
    NSString *existing = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyTagID];
    self.manualField.text = existing ?: @"";
    self.manualContainer.hidden = NO;
    [self.manualField becomeFirstResponder];
}

- (void)cancelManualEntry {
    _showingManualInput = NO;
    self.manualContainer.hidden = YES;
    [self.manualField resignFirstResponder];
}

- (void)applyManualEntry {
    NSString *raw = self.manualField.text ?: @"";
    NSMutableString *hexOnly = [NSMutableString string];
    for (NSUInteger i = 0; i < raw.length; i++) {
        unichar c = [raw characterAtIndex:i];
        if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))
            [hexOnly appendFormat:@"%C", c];
    }
    if (hexOnly.length != 12) {
        // Flash field red
        self.manualField.layer.borderColor = [UIColor systemRedColor].CGColor;
        self.manualField.layer.borderWidth = 1.5;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            self.manualField.layer.borderColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0].CGColor;
            self.manualField.layer.borderWidth  = 0.5;
        });
        UIAlertController *a = [UIAlertController
                                alertControllerWithTitle:L(QLAlertBadIDTitle, _chinese)
                                message:L(QLAlertBadIDMsg, _chinese)
                                preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:L(QLOK, _chinese) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }
    [self persistAndDisplayTagID:hexOnly.uppercaseString];
    [self cancelManualEntry];
}

- (void)copyTagID {
    [_impactLight impactOccurred];
    NSString *tagID = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyTagID];
    if (!tagID) return;
    [UIPasteboard generalPasteboard].string = tagID;
    // Brief tint feedback
    self.copyButton.tintColor = [UIColor systemGreenColor];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.copyButton.tintColor = [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    });
}

- (void)persistAndDisplayTagID:(NSString *)tagID {
    unsigned char buf[8];
    buf[0] = 0x15; buf[1] = 0x1A;
    for (int i = 0; i < 6; i++) {
        unsigned int v = 0;
        [[NSScanner scannerWithString:[tagID substringWithRange:NSMakeRange(i*2,2)]] scanHexInt:&v];
        buf[i+2] = (uint8_t)v;
    }
    uint8_t crc = crc8(buf, 8);
    NSString *uuid = [NSString stringWithFormat:
                      @"%02X%02X%02X%02X-%02X%02X-%02X%02X-67F7-DB34C4038E5C",
                      buf[1],buf[2],buf[3],buf[4],buf[5],buf[6],buf[7],crc];

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:uuid  forKey:kKeyUUID];
    [ud setObject:tagID forKey:kKeyTagID];
    [ud synchronize];

    [[TagHistoryManager shared] addTagID:tagID];
    [self refreshIDDisplay];
    if (_broadcasting) [self updateAdvertisedRegion:YES];
}


// ── History ───────────────────────────────────────────────────────────────────

- (void)toggleHistory {
    [_impactLight impactOccurred];
    _historyExpanded = !_historyExpanded;
    self.historyDropdown.hidden = !_historyExpanded;
    self.historyButton.tintColor = _historyExpanded
        ? [UIColor systemBlueColor]
        : [UIColor colorWithRed:0.40 green:0.40 blue:0.45 alpha:1.0];
    if (_historyExpanded) [self refreshHistoryList];
}

- (void)refreshHistoryList {
    for (UIView *v in self.historyStack.arrangedSubviews) {
        [self.historyStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    NSArray<NSString *> *recent = [[TagHistoryManager shared] recentTagIDs];
    if (!recent.count) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = _chinese ? @"暂无历史记录" : @"No history yet";
        empty.font = [UIFont systemFontOfSize:12];
        empty.textColor = [UIColor colorWithRed:0.35 green:0.35 blue:0.40 alpha:1.0];
        [self.historyStack addArrangedSubview:empty];
        return;
    }

    NSString *currentTagID = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyTagID];
    for (NSString *tagID in recent) {
        UIButton *row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        NSAttributedString *title = [[NSAttributedString alloc]
                                     initWithString:tagID
                                     attributes:@{
            NSFontAttributeName: [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium],
            NSForegroundColorAttributeName: [tagID isEqualToString:currentTagID]
                ? [UIColor systemBlueColor]
                : [UIColor colorWithRed:0.60 green:0.60 blue:0.65 alpha:1.0],
        }];
        [row setAttributedTitle:title forState:UIControlStateNormal];
        row.tag = [recent indexOfObject:tagID];
        [row addTarget:self action:@selector(historyRowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.historyStack addArrangedSubview:row];
        [row.heightAnchor constraintEqualToConstant:32].active = YES;
    }
}

- (void)historyRowTapped:(UIButton *)sender {
    [_impactLight impactOccurred];
    NSArray *recent = [[TagHistoryManager shared] recentTagIDs];
    if (sender.tag < (NSInteger)recent.count) {
        [self persistAndDisplayTagID:recent[sender.tag]];
    }
    [self toggleHistory];
}


// ── QR Code ───────────────────────────────────────────────────────────────────

- (void)showQRCode {
    [_impactLight impactOccurred];
    NSString *tagID = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyTagID];
    if (!tagID) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:L(QLAlertNoIDTitle, _chinese)
                                                                   message:L(QLAlertNoIDMsg, _chinese)
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:L(QLOK, _chinese) style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        return;
    }

    UIImage *qr = [QRCodeGenerator imageForString:tagID
                                        pointSize:240
                                  foregroundColor:[UIColor colorWithRed:0.07 green:0.07 blue:0.09 alpha:1.0]
                                  backgroundColor:[UIColor whiteColor]];
    if (!qr) return;

    // QR display view controller
    UIViewController *qrVC = [[UIViewController alloc] init];
    qrVC.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:1.0];
    qrVC.modalPresentationStyle = UIModalPresentationFormSheet;
    if (@available(iOS 15, *)) {
        UISheetPresentationController *sheet = qrVC.sheetPresentationController;
        sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent];
        sheet.prefersGrabberVisible = YES;
    }

    UIImageView *qrView = [[UIImageView alloc] initWithImage:qr];
    qrView.translatesAutoresizingMaskIntoConstraints = NO;
    qrView.layer.cornerRadius = 12;
    qrView.layer.masksToBounds = YES;
    qrView.contentMode = UIViewContentModeScaleAspectFit;
    [qrVC.view addSubview:qrView];

    UILabel *titleLbl = [[UILabel alloc] init];
    titleLbl.translatesAutoresizingMaskIntoConstraints = NO;
    titleLbl.text = L(QLQRTitle, _chinese);
    titleLbl.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    titleLbl.textColor = [UIColor colorWithRed:0.93 green:0.93 blue:0.95 alpha:1.0];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    [qrVC.view addSubview:titleLbl];

    UILabel *idLbl = [[UILabel alloc] init];
    idLbl.translatesAutoresizingMaskIntoConstraints = NO;
    idLbl.text = tagID;
    idLbl.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightBold];
    idLbl.textColor = [UIColor systemBlueColor];
    idLbl.textAlignment = NSTextAlignmentCenter;
    [qrVC.view addSubview:idLbl];

    UIButton *shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    shareBtn.translatesAutoresizingMaskIntoConstraints = NO;
    shareBtn.backgroundColor = [UIColor systemBlueColor];
    shareBtn.layer.cornerRadius = 14;
    [shareBtn setTitle:L(QLShare, _chinese) forState:UIControlStateNormal];
    shareBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [shareBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    NSString *capturedTagID = tagID;
    UIImage  *capturedQR    = qr;
    [shareBtn addAction:[UIAction actionWithHandler:^(UIAction *a) {
        UIActivityViewController *av = [[UIActivityViewController alloc]
            initWithActivityItems:@[capturedTagID, capturedQR]
            applicationActivities:nil];
        [qrVC presentViewController:av animated:YES completion:nil];
    }] forControlEvents:UIControlEventTouchUpInside];
    [qrVC.view addSubview:shareBtn];

    UILabel *hintLbl = [[UILabel alloc] init];
    hintLbl.translatesAutoresizingMaskIntoConstraints = NO;
    hintLbl.text = L(QLQRHint, _chinese);
    hintLbl.font = [UIFont systemFontOfSize:12];
    hintLbl.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.44 alpha:1.0];
    hintLbl.textAlignment = NSTextAlignmentCenter;
    [qrVC.view addSubview:hintLbl];

    [NSLayoutConstraint activateConstraints:@[
        [titleLbl.topAnchor constraintEqualToAnchor:qrVC.view.safeAreaLayoutGuide.topAnchor constant:24],
        [titleLbl.leadingAnchor constraintEqualToAnchor:qrVC.view.leadingAnchor constant:20],
        [titleLbl.trailingAnchor constraintEqualToAnchor:qrVC.view.trailingAnchor constant:-20],

        [qrView.topAnchor constraintEqualToAnchor:titleLbl.bottomAnchor constant:16],
        [qrView.centerXAnchor constraintEqualToAnchor:qrVC.view.centerXAnchor],
        [qrView.widthAnchor constraintEqualToConstant:220],
        [qrView.heightAnchor constraintEqualToConstant:220],

        [idLbl.topAnchor constraintEqualToAnchor:qrView.bottomAnchor constant:14],
        [idLbl.leadingAnchor constraintEqualToAnchor:qrVC.view.leadingAnchor constant:20],
        [idLbl.trailingAnchor constraintEqualToAnchor:qrVC.view.trailingAnchor constant:-20],

        [hintLbl.topAnchor constraintEqualToAnchor:idLbl.bottomAnchor constant:4],
        [hintLbl.leadingAnchor constraintEqualToAnchor:qrVC.view.leadingAnchor constant:20],
        [hintLbl.trailingAnchor constraintEqualToAnchor:qrVC.view.trailingAnchor constant:-20],

        [shareBtn.topAnchor constraintEqualToAnchor:hintLbl.bottomAnchor constant:20],
        [shareBtn.leadingAnchor constraintEqualToAnchor:qrVC.view.leadingAnchor constant:20],
        [shareBtn.trailingAnchor constraintEqualToAnchor:qrVC.view.trailingAnchor constant:-20],
        [shareBtn.heightAnchor constraintEqualToConstant:50],
    ]];

    [self presentViewController:qrVC animated:YES completion:nil];
}


// ── Broadcast ─────────────────────────────────────────────────────────────────

- (void)toggleBroadcast {
    [_impactMedium impactOccurred];
    if (_broadcasting) {
        _broadcasting = NO;
        [self.logoView stopAnim];
        [self updateAdvertisedRegion:NO];
    } else {
        if ([self updateAdvertisedRegion:YES]) {
            _broadcasting = YES;
            [self.logoView startAnim];
        }
    }
    [self refreshBroadcastState];
}

- (void)refreshBroadcastState {
    if (_broadcasting) {
        self.broadcastButton.backgroundColor = [UIColor systemRedColor];
        [self.broadcastButton setTitle:L(QLStopBroadcast, _chinese) forState:UIControlStateNormal];
        self.statusLabel.text = L(QLStatusBroadcasting, _chinese);
        self.statusLabel.textColor = [UIColor systemBlueColor];
        self.statusDot.backgroundColor = [UIColor systemGreenColor];
        self.liveIndicatorDot.alpha = 1;
        self.liveLabel.alpha = 1;
        [self animateLiveDot];
        [self animateRings:YES];
    } else {
        self.broadcastButton.backgroundColor = [UIColor systemBlueColor];
        [self.broadcastButton setTitle:L(QLStartBroadcast, _chinese) forState:UIControlStateNormal];
        self.statusLabel.text = L(QLStatusIdle, _chinese);
        self.statusLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.44 alpha:1.0];
        self.statusDot.backgroundColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.28 alpha:1.0];
        self.liveIndicatorDot.alpha = 0;
        self.liveLabel.alpha = 0;
        [self animateRings:NO];
    }
}

- (void)animateRings:(BOOL)on {
    NSArray<NSNumber *> *delays = @[@0, @0.6, @1.2];
    for (NSInteger i = 0; i < 3; i++) {
        UIView *ring = self.ringViews[i];
        if (on) {
            ring.alpha = 0;
            [UIView animateWithDuration:0.5 delay:[delays[i] doubleValue]
                                options:0 animations:^{ ring.alpha = 1; } completion:nil];
            CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            anim.fromValue = @0.95; anim.toValue = @1.06;
            anim.duration = 2.2; anim.autoreverses = YES;
            anim.repeatCount = HUGE_VALF;
            anim.beginTime = CACurrentMediaTime() + [delays[i] doubleValue];
            [ring.layer addAnimation:anim forKey:@"pulse"];
        } else {
            [UIView animateWithDuration:0.3 animations:^{ ring.alpha = 0; }
             completion:^(BOOL d){ [ring.layer removeAllAnimations]; }];
        }
    }
}

- (void)animateLiveDot {
    [UIView animateWithDuration:0.8
                          delay:0
                        options:(UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat)
                     animations:^{ self.liveIndicatorDot.alpha = 0.2; }
                     completion:nil];
}

- (BOOL)updateAdvertisedRegion:(BOOL)start {
    if (sPeripheral.state < CBManagerStatePoweredOn) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:L(QLAlertBTTitle, self->_chinese)
                                                                       message:L(QLAlertBTMsg, self->_chinese)
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:L(QLOK, self->_chinese) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
        return NO;
    }
    [sPeripheral stopAdvertising];
    if (!start) return NO;

    NSString *uuidStr = [[NSUserDefaults standardUserDefaults] stringForKey:kKeyUUID];
    if (!uuidStr) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *a = [UIAlertController alertControllerWithTitle:L(QLAlertNoIDTitle, self->_chinese)
                                                                       message:L(QLAlertNoIDMsg, self->_chinese)
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:L(QLOK, self->_chinese) style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:a animated:YES completion:nil];
        });
        return NO;
    }

    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
    if (!uuid) { NSLog(@"[Quuppa] Bad UUID: %@", uuidStr); return NO; }

    sRegion = [[CLBeaconRegion alloc] initWithUUID:uuid major:2986 minor:38704 identifier:kBeaconID];
    NSDictionary *data = [sRegion peripheralDataWithMeasuredPower:@(kPresets[_currentPreset].measuredPower)];
    if (data) {
        [sPeripheral startAdvertising:data];
        NSLog(@"[Quuppa] Advertising preset=%ld power=%ld uuid=%@",
              (long)_currentPreset, (long)kPresets[_currentPreset].measuredPower, uuidStr);
    }
    return YES;
}

// ── CBPeripheralManagerDelegate ───────────────────────────────────────────────

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    // Handled at point-of-use in updateAdvertisedRegion:
}

@end
