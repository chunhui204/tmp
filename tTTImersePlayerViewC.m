//
//  TTPlayerFullScreenMoreMenuView.m
//  Article
//
//  Created by bifangao on 2019/7/12.
//

#import "TTPlayerFullScreenMoreMenuView.h"
#import <TTBaseLib/UIImageAdditions.h>
//#import "TTVLPlayerDownloadView.h"
#import "TTVAlbumUtil.h"
#import "TTIndicatorView.h"
#import "NetworkUtilities.h"
#import <XIGUIKit/TTAnimationButton.h>
#import "TTAnimationButton+AnimationTitle.h"
#import "TTVAlbum+Extension.h"
#import "TTSettingsManager.h"
#import "TTVLongVideoHeaders.h"
#import "UIImage+TTVLImage.h"
#import "TTPlayerFunctionMainSwitch.h"
#import <objc/runtime.h>
#import <XIGUIKit/UIFont+TTFont.h>
#import "UIImage+TTVHelper.h"
#import "TTVSettingsConfiguration.h"
#import <ByteDanceKit/UIDevice+BTDAdditions.h>
#import "TTVLoopingPlayManager.h"

@interface TTPlayerFullScreenMoreMenuItem : NSObject
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, getter=isHidden) BOOL hidden;
@end

@implementation TTPlayerFullScreenMoreMenuItem

- (void)setHidden:(BOOL)hidden {
    self.button.hidden = hidden;
    self.label.hidden = hidden;
}

- (BOOL)isHidden {
    return self.button.isHidden && self.label.isHidden;
}

@end

@interface TTPlayerFullScreenMoreMenuView ()
@property (nonatomic, assign) CGFloat itemSpaceX; // 水平间距
@property (nonatomic, strong) NSMutableArray<TTPlayerFullScreenMoreMenuItem *> *moreMenuItems;
@property (nonatomic, strong) TTPlayerFullScreenMoreMenuItem *audioPlayItem;
@property (nonatomic, strong) TTPlayerFullScreenMoreMenuItem *videoDownloadItem;
@property (nonatomic, strong) TTPlayerFullScreenMoreMenuItem *danmakuSettingItem;
@property (nonatomic, strong) TTPlayerFullScreenMoreMenuItem *dislikeItem;

@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UIButton *downloadBtn;
@property (nonatomic, strong) UIButton *collectNormalBtn;
@property (nonatomic, strong) TTAnimationButton *collectBtn;
@property (nonatomic, strong) UIButton *shareBtn;
@property (nonatomic, strong) UILabel *collectLabel;
@property (nonatomic, strong) UIButton *noEdgeBtn;
@property (nonatomic, strong) UILabel *noEdgeBtnLabel;
@property (nonatomic, strong) UIButton *audioPlayBtn;
@property (nonatomic, strong) UILabel *audioPlayBtnLabel;
@property (nonatomic, strong) UIButton *videoDownloadBtn;
@property (nonatomic, strong) UILabel *videoDownloadBtnLabel;
@property (nonatomic, strong) UIButton *danmakuSettingButton;
@property (nonatomic, strong) UIButton *eiBtn;
@property (nonatomic, strong) UILabel *shareLabel;
@property (nonatomic, strong) UILabel *danmakuSettingLabel;
@property (nonatomic, strong) UILabel *eiBtnLabel;
@property (nonatomic, strong) UIView *sepLine;
@property (nonatomic, strong) UIImageView *volumeLowImageView;
@property (nonatomic, strong) UIImageView *volumeHighImageView;
@property (nonatomic, strong) UIImageView *brightnessLowImageView;
@property (nonatomic, strong) UIImageView *brightnessHighImageView;
@property (nonatomic, strong) TTPlayerLoopSettingView *loopSettingView;

@end

@implementation TTPlayerFullScreenMoreMenuView

#define PaddingX 30
#define PaddingY 28
#define itemSpaceY 30
#define ButtonSize 24
- (void)layoutButton:(UIButton *)button label:(UILabel *)label withIndex:(NSInteger)index {
    NSInteger row = index / 5;
    NSInteger column = index % 5;
    CGFloat rate = [UIDevice btd_isScreenWidthLarge320] ? 1.f : 0.9f;
    button.frame = CGRectMake(PaddingX + column * (ButtonSize + self.itemSpaceX),
                              PaddingY * rate + row * (ButtonSize + 6 + 18 + 26 * rate),
                              ButtonSize,
                              ButtonSize);
    [label sizeToFit];
    label.height = 18;
    label.centerX = button.centerX;
    label.top = button.bottom + 6;
}

- (UIButton *)buttonWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -20, -10);
    if (title) {
        [button setTitle:title forState:UIControlStateNormal];
    }
    if (image) {
        [button setImage:image forState:UIControlStateNormal];
    }
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UILabel *)labelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:13.f weight:UIFontWeightRegular];
    label.textColor = [UIColor tt_W4_color];
    label.textAlignment = NSTextAlignmentCenter;
    return label;
}

- (TTPlayerFullScreenMoreMenuItem *)addMoreMenuItem:(UIButton *)button label:(UILabel *)label {
    if (button) {
        [self addSubview:button];
    }
    if (label) {
        [self addSubview:label];
    }
    TTPlayerFullScreenMoreMenuItem *item = [[TTPlayerFullScreenMoreMenuItem alloc] init];
    item.button = button;
    item.label = label;
    [self.moreMenuItems addObject:item];
    return item;
}

#pragma mark - life cycle
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:.87f];
        self.scrollEnabled = YES;
        _itemSpaceX = (CGRectGetWidth(frame) - PaddingX * 2 - ButtonSize * 5) / 4;
        _moreMenuItems = [NSMutableArray array];
        if (@available(iOS 11.0, *)) {
            self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        
        // 分享
        UIButton *shareBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_fullscreen_share"] action:@selector(shareAction:)];
        UILabel *shareLabel = [self labelWithText:@"分享"];
        [self addMoreMenuItem:shareBtn label:shareLabel];
        self.shareBtn = shareBtn;
        self.shareLabel = shareLabel;
        
        // 收藏
        TTAnimationButton *collectBtn = [TTAnimationButton buttonWithType:UIButtonTypeCustom];
        collectBtn.backgroundColor = [UIColor clearColor];
        collectBtn.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -20, -10);
        collectBtn.explosionRate = 50;
        collectBtn.imageNormalColor = [UIColor tt_silver5Color];
        collectBtn.imageSelectedColor = [UIColor tt_yellow1Color];
        [collectBtn setImage:[UIImage xigBizPlayerImageNamed:@"player_uncollect"] forState:UIControlStateNormal];
        [collectBtn setImage:[UIImage xigBizPlayerImageNamed:@"player_collected"] forState:UIControlStateSelected];
        [collectBtn addTarget:self action:@selector(collectAction:) forControlEvents:UIControlEventTouchUpInside];
        self.collectBtn = collectBtn;
        [self addSubview:collectBtn];
        self.collectBtn.hidden = YES;
        // 动画按钮会为按钮图片区域填充颜色，此处非选中态要求图片镂空显示，所以添加一个按钮显示非选中态，选中态及选中动画使用animationButton
        UIButton *collectNormalBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_uncollect"] action:@selector(collectAction:)];
        [collectNormalBtn setImage:[UIImage xigBizPlayerImageNamed:@"player_collected"] forState:UIControlStateSelected];
        UILabel *collectLabel = [self labelWithText:@"收藏"];
        collectLabel.highlightedTextColor = [UIColor colorWithRed:254.0/255.0 green:148.0/255.0 blue:0/255.0 alpha:1];
        [self addMoreMenuItem:collectNormalBtn label:collectLabel];
        self.collectNormalBtn = collectNormalBtn;
        self.collectLabel = collectLabel;
        [collectBtn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(collectNormalBtn);
        }];
        
        // 下载
        UIButton *downloadBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_download"] action:@selector(downloadAction:)];
        UILabel *downloadLabel = [self labelWithText:@"缓存"];
        [self addMoreMenuItem:downloadBtn label:downloadLabel];
        self.downloadBtn = downloadBtn;
        
        // 弹幕设置
        UIButton *danmakuSettingButton = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_danmaku_setting"] action:@selector(danmakuSettingTouchUpInside:)];
        UILabel *danmakuSettingLabel = [self labelWithText:@"弹幕设置"];
        self.danmakuSettingItem = [self addMoreMenuItem:danmakuSettingButton label:danmakuSettingLabel];
        self.danmakuSettingButton = danmakuSettingButton;
        self.danmakuSettingLabel = danmakuSettingLabel;
        
        // 不感兴趣
        UIButton *noInterestBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_fullscreen_dislike"] action:@selector(dislikeBtnAction:)];
        UILabel *noInterestLabel = [self labelWithText:@"不感兴趣"];
        self.dislikeItem = [self addMoreMenuItem:noInterestBtn label:noInterestLabel];
        
        // 举报
        UIButton *reportBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_fullscreen_report"] action:@selector(reportBtnAction:)];
        UILabel *reportLabel = [self labelWithText:@"举报"];
        [self addMoreMenuItem:reportBtn label:reportLabel];
        
        // 满屏
        UIButton *noEdgeBtn = [self buttonWithTitle:nil image:[UIImage xigBizPlayerImageNamed:@"player_fullscreen_zoomIn"] action:@selector(noEdgeAction:)];
        [noEdgeBtn setImage:[[UIImage xigBizPlayerImageNamed:@"player_fullscreen_zoomIn"] ttv_imageWithTintColor:[UIColor tt_R1_color]] forState:UIControlStateSelected];
        UILabel *noEdgeBtnLabel = [self labelWithText:@"满屏"];
        noEdgeBtnLabel.highlightedTextColor = [UIColor tt_R1_color];
        [self addMoreMenuItem:noEdgeBtn label:noEdgeBtnLabel];
        self.noEdgeBtn = noEdgeBtn;
        self.noEdgeBtnLabel = noEdgeBtnLabel;
        
        //音频播放按钮
        UIButton *audioPlayBtn = [self buttonWithTitle:nil image:[UIImage imageNamed:@"audioModePlay22"] action:@selector(audioModePlayAction:)];
        [audioPlayBtn setImage:[[UIImage imageNamed:@"audioPlayModeSel"] ttv_imageWithTintColor:[UIColor tt_R1_color]] forState:UIControlStateSelected];
        UILabel *audioPlayBtnLabel = [self labelWithText:@"音频播放"];
        audioPlayBtnLabel.highlightedTextColor = [UIColor tt_R1_color];
        self.audioPlayItem = [self addMoreMenuItem:audioPlayBtn label:audioPlayBtnLabel];
        self.audioPlayItem.hidden = !ttvs_enableAudioPlayMode();
        self.audioPlayBtn = audioPlayBtn;
        self.audioPlayBtnLabel = audioPlayBtnLabel;
        
        //播放反馈
        UIButton *feedbackBtn = [self buttonWithTitle:nil image:[UIImage imageNamed:@"video_feedback_btn"] action:@selector(feedBackAction:)];
        UILabel *feedbackBtnLabel = [self labelWithText:@"播放反馈"];;
        [self addMoreMenuItem:feedbackBtn label:feedbackBtnLabel];
        
        //保存到相册
        NSDictionary *shareposterConfig = [[TTSettingsManager sharedManager] settingForKey:@"ug_share_config" defaultValue:@{} freeze:NO];
        BOOL isShowSharePanelDownload = [shareposterConfig btd_intValueForKey:@"share_panel_video_download_switch_position" default:0];
        if(!isShowSharePanelDownload){
            //未把保存到相册放到分享逻辑里
            UIButton *videoDownloadBtn = [self buttonWithTitle:nil image:[UIImage imageNamed:@"audio_download_enable"] action:@selector(videoDownloadAction:)];
            UILabel *videoDownloadBtnLabel = [self labelWithText:@"保存到相册"];
            videoDownloadBtnLabel.highlightedTextColor = [UIColor tt_R1_color];
            self.videoDownloadItem = [self addMoreMenuItem:videoDownloadBtn label:videoDownloadBtnLabel];

            self.videoDownloadItem.hidden = ![shareposterConfig btd_intValueForKey:@"share_panel_video_download_enable" default:0];
            self.videoDownloadBtn = videoDownloadBtn;
            self.videoDownloadBtnLabel = videoDownloadBtnLabel;
        }
        
        //视频debug信息
        if ([TTMacroManager isInHouse]) {
            UIButton *eiBtn = [self buttonWithTitle:@"EI" image:nil action:@selector(eiBtnAction:)];
            [eiBtn setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
            UILabel *eiBtnLabel = [self labelWithText:@"EI"];
            [self addMoreMenuItem:eiBtn label:eiBtnLabel];
            self.eiBtn = eiBtn;
            self.eiBtnLabel = eiBtnLabel;
        }
        
        self.sepLine = [[UIView alloc] init];
        self.sepLine.backgroundColor = UIColorWithRGBA(216, 216, 216, 0.12);
        [self addSubview:self.sepLine];

        if (TTVLoopingPlayManager.shared.enable) {
            TTPlayerLoopSettingView *loopSettingView = [[TTPlayerLoopSettingView alloc] initWithFrame:CGRectZero];
            [self addSubview:loopSettingView];
            self.loopSettingView = loopSettingView;
        }
        
        // 声音
        self.volumeLowImageView = [[UIImageView alloc] init];
        self.volumeLowImageView.image = [UIImage xigBizPlayerImageNamed:@"player_volume_weak"];
        [self addSubview:self.volumeLowImageView];
        
        self.volumeHighImageView = [[UIImageView alloc] init];
        self.volumeHighImageView.image = [UIImage xigBizPlayerImageNamed:@"player_volume_strong"];
        [self addSubview:self.volumeHighImageView];
        
        self.volumeSlider = [[UISlider alloc] init];
        self.volumeSlider.maximumValue = 1.f;
        self.volumeSlider.minimumTrackTintColor = [UIColor redColor];
        self.volumeSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.f alpha:.1f];
        [self.volumeSlider addTarget:self action:@selector(volumeDidChanged:) forControlEvents:UIControlEventValueChanged];
        [self.volumeSlider addTarget:self action:@selector(volumeEndChanged:) forControlEvents:UIControlEventTouchUpInside];
        [self.volumeSlider setThumbImage:[UIImage imageWithSize:CGSizeMake(16, 16) cornerRadius:8 backgroundColor:[UIColor whiteColor]] forState:UIControlStateNormal];
        [self.volumeSlider setThumbImage:[UIImage imageWithSize:CGSizeMake(16, 16) cornerRadius:8 backgroundColor:[UIColor whiteColor]] forState:UIControlStateHighlighted];
        self.volumeSlider.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -10);
        [self addSubview:self.volumeSlider];
        
        // 亮度
        self.brightnessLowImageView = [[UIImageView alloc] init];
        self.brightnessLowImageView.image = [UIImage xigBizPlayerImageNamed:@"player_brightness_weak"];
        [self addSubview:self.brightnessLowImageView];
        [self.brightnessLowImageView sizeToFit];
        
        self.brightnessHighImageView = [[UIImageView alloc] init];
        self.brightnessHighImageView.image = [UIImage xigBizPlayerImageNamed:@"player_brightness_strong"];
        [self.brightnessHighImageView sizeToFit];
        [self addSubview:self.brightnessHighImageView];
        
        self.brightnessSlider = [[UISlider alloc] init];
        self.brightnessSlider.maximumValue = 1.f;
        self.brightnessSlider.minimumTrackTintColor = [UIColor redColor];
        self.brightnessSlider.maximumTrackTintColor = [UIColor colorWithWhite:1.f alpha:.1f];
        [self.brightnessSlider addTarget:self action:@selector(brightnessDidChanged:) forControlEvents:UIControlEventValueChanged];
        [self.brightnessSlider addTarget:self action:@selector(brightnessEndChanged:) forControlEvents:UIControlEventTouchUpInside];
        [self.brightnessSlider setThumbImage:[UIImage imageWithSize:CGSizeMake(16, 16) cornerRadius:8 backgroundColor:[UIColor whiteColor]] forState:UIControlStateNormal];
        [self.brightnessSlider setThumbImage:[UIImage imageWithSize:CGSizeMake(16, 16) cornerRadius:8 backgroundColor:[UIColor whiteColor]] forState:UIControlStateHighlighted];
        self.brightnessSlider.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -10);
        [self addSubview:self.brightnessSlider];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSArray<TTPlayerFullScreenMoreMenuItem *> *visiableItems = [self.moreMenuItems btd_filter:^BOOL(TTPlayerFullScreenMoreMenuItem * _Nonnull obj) {
        return !obj.hidden;
    }];
    [visiableItems enumerateObjectsUsingBlock:^(TTPlayerFullScreenMoreMenuItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self layoutButton:obj.button label:obj.label withIndex:idx];
    }];
    
    CGFloat rate = [UIDevice btd_isScreenWidthLarge320] ? 1.f : 0.9f;
    
    CGFloat sepLinTop = visiableItems.lastObject.label.bottom + 28 * rate;
    self.sepLine.frame = CGRectMake(0, sepLinTop, self.width, [UIDevice btd_onePixel]);

    CGFloat left = PaddingX;
    CGFloat y = self.sepLine.bottom;
    if (self.loopSettingView) {
        self.loopSettingView.left = 0;
        self.loopSettingView.top = y;
        self.loopSettingView.width = self.width;
        self.loopSettingView.height = 60 * rate;
        y = self.loopSettingView.centerY + 40 * rate;
    } else {
        y += 40 * rate;
    }
    
    // 声音
    self.volumeLowImageView.frame = CGRectMake(left, y, 24, 24);
    self.volumeHighImageView.frame = CGRectMake(self.width - left - 24, self.volumeLowImageView.top, 24, 24);
    CGFloat sliderWidth = self.width - (self.volumeLowImageView.right + 14) * 2;
    self.volumeSlider.size = CGSizeMake(sliderWidth, 16);
    self.volumeSlider.centerX = self.width/2;
    self.volumeSlider.centerY = self.volumeLowImageView.centerY;
    
    // 亮度
    self.brightnessLowImageView.frame = CGRectMake(self.volumeLowImageView.left, self.volumeLowImageView.bottom + 28 * rate, 24, 24);
    self.brightnessHighImageView.frame = CGRectMake(self.width - left - 24, self.brightnessLowImageView.top, 24, 24);
    self.brightnessSlider.size = CGSizeMake(sliderWidth, 16);
    self.brightnessSlider.centerX = self.width/2;
    self.brightnessSlider.centerY = self.brightnessLowImageView.centerY;
    
    self.contentSize = CGSizeMake(0, self.brightnessLowImageView.bottom + PaddingY);
}

- (void)setIsZoomming:(BOOL)isZoomming
{
    _isZoomming = isZoomming;
    self.noEdgeBtn.selected = isZoomming;
    self.noEdgeBtnLabel.highlighted = self.noEdgeBtn.selected;
}

- (void)setIsEIShowing:(BOOL)isEIShowing {
    _isEIShowing = isEIShowing;
    self.eiBtn.selected = isEIShowing;
}

- (void)setDisableZoomming:(BOOL)disableZoomming
{
    _disableZoomming = disableZoomming;
    [[TTVAlbumUtil sharedInstance] setButton:self.noEdgeBtn disabled:disableZoomming action:^{
        if (disableZoomming) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持满屏" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
        }
    }];
}

- (void)setCollected:(BOOL)collected{
    _collected = collected;
    [self refreshButtonState];
}

- (void)setDisableDownload:(BOOL)disableDownload{
    _disableDownload = disableDownload;
    [self refreshButtonState];
}

- (void)setLoopingType:(NSInteger)loopingType {
    self.loopSettingView.loopingType = loopingType;
}

- (void)setLoopingTypeChanged:(void (^)(NSInteger))loopingTypeChanged {
    self.loopSettingView.loopingTypeChanged = loopingTypeChanged;
}

- (void)setDisableDanmakuSetting:(BOOL)disableDanmakuSetting {
    _disableDanmakuSetting = disableDanmakuSetting;
    self.danmakuSettingItem.hidden = disableDanmakuSetting;
    [self setNeedsLayout];
}

- (void)setDisableDislike:(BOOL)disableDislike {
    _disableDislike = disableDislike;
    self.dislikeItem.hidden = disableDislike;
    [self setNeedsLayout];
}

- (void)refreshButtonState {
    //禁止收藏
    BOOL disableFav = NO;
    
    //如果收藏了,收藏状态要&1
    self.collectBtn.disableAnimation = YES;
    self.collectBtn.selected = self.collected;
    self.collectBtn.hidden = !self.collectBtn.selected;
    self.collectNormalBtn.hidden = self.collectBtn.selected;
    self.collectBtn.disableAnimation = NO;
    self.collectLabel.text = self.collectBtn.selected ? @"已收藏" : @"收藏";
    self.collectLabel.highlighted = self.collectBtn.selected;
    [self.collectLabel sizeToFit];
    self.collectLabel.height = 18;
    self.collectLabel.centerX = self.collectBtn.centerX;
    self.collectLabel.top = self.collectBtn.bottom + 6;
    
    [[TTVAlbumUtil sharedInstance] setButton:self.collectBtn disabled:(disableFav && !self.collected) action:^{
        if (disableFav) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持收藏" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
        }
    }];
    
    [[TTVAlbumUtil sharedInstance] setButton:self.collectNormalBtn disabled:(disableFav && !(self.collected)) action:^{
        if (disableFav) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持收藏" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
        }
    }];
    
    //禁止缓存
    BOOL disableDownload = self.disableDownload;
    UIImage *image = disableDownload ? [UIImage xigBizPlayerImageNamed:@"player_ban_download"] : [UIImage xigBizPlayerImageNamed:@"player_download"];
    [self.downloadBtn setImage:image forState:UIControlStateNormal];
    
    UIImage *downloadImage = disableDownload ? [UIImage imageNamed:@"audio_download_disable"] : [UIImage imageNamed:@"audio_download_enable"];
    [self.videoDownloadBtn setImage:downloadImage forState:UIControlStateNormal];
    
    //TODO: 短视频好像没有这个逻辑?
    //禁止分享
    BOOL disableShare = NO;
    
    [[TTVAlbumUtil sharedInstance] setButton:self.shareBtn disabled:disableShare action:^{
        if (disableShare) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持分享" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
            return;
        }
    }];
    //刷新audioPlayBtn 状态
    self.audioPlayBtn.selected = self.audioPlayBtnIsSelected;
    self.audioPlayBtnLabel.highlighted = self.audioPlayBtn.selected;
    
}

#pragma mark - event response
- (void)skipSwitchClick:(id)sender {
//    if (self.switchDidChanged) {
//        self.switchDidChanged(self.skipSwitch.isOn);
//    }
}

- (void)volumeDidChanged:(id)sender {
    if (self.volumeDidChanged) {
        self.volumeDidChanged(self.volumeSlider.value);
    }
}

- (void)volumeEndChanged:(id)sender {
    if (self.volumeEndChanged) {
        self.volumeEndChanged(self.volumeSlider.value);
    }
}

- (void)brightnessDidChanged:(id)sender {
    if (self.brightnessDidChanged) {
        self.brightnessDidChanged(self.brightnessSlider.value);
    }
}

- (void)brightnessEndChanged:(id)sender{
    if (self.brightnessEndChanged) {
        self.brightnessEndChanged(self.brightnessSlider.value);
    }
}

- (void)downloadAction:(id)sender {
    if (self.downloadAction) {
        self.downloadAction();
    }
}

- (void)videoDownloadAction:(id)sender {
    if (self.videoDownloadAction) {
        self.videoDownloadAction();
    }
}

- (void)noEdgeAction:(id)sender {
    self.noEdgeBtn.selected = !self.noEdgeBtn.selected;
    self.noEdgeBtnLabel.highlighted = self.noEdgeBtn.selected;
    if (self.zoomBtnAction) {
        self.zoomBtnAction(self.noEdgeBtn.selected);
    }
}

- (void)eiBtnAction:(id)sender {
    self.eiBtn.selected = !self.eiBtn.selected;
    self.eiBtnLabel.highlighted = self.eiBtn.selected;
    if (self.eiAction) {
        self.eiAction(self.eiBtn.selected);
    }
}

- (void)audioModePlayAction:(id)sender {
    self.audioPlayBtn.selected = !self.audioPlayBtn.selected;
    self.audioPlayBtnLabel.highlighted = self.audioPlayBtn.selected;
    if(self.audioModePlayAction){
        self.audioModePlayAction();
    }
    if(!self.disableZoomming) { //只有视频允许进行满屏处理时，才需要结合音频模式进行设置。
        [[TTVAlbumUtil sharedInstance] setButton:self.noEdgeBtn disabled:self.audioPlayBtn.selected action:^{ }];
    }
}

- (void) feedBackAction:(id)sender {
    if(self.videoReportAction) {
        self.videoReportAction();
    }
}

- (void)collectAction:(id)sender {
    //无网不请求，也不更改收藏状态，和短视频一致
    if (!TTNetworkConnected()) {
        [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"没有网络" indicatorImage:[UIImage themedImageNamed:@"close_popup_textpage"] autoDismiss:YES dismissHandler:nil];
        return;
    }
    
    self.collectBtn.selected = !self.collectBtn.selected;
    self.collectLabel.text = self.collectBtn.selected ? @"已收藏" : @"收藏";
    self.collectLabel.highlighted = self.collectBtn.selected;
    [self.collectLabel sizeToFit];
    self.collectLabel.height = 18;
    self.collectLabel.centerX = self.collectBtn.centerX;
    
    self.collectBtn.hidden = !self.collectBtn.selected;
    self.collectNormalBtn.hidden = self.collectBtn.selected;
    
    // 取消收藏后
    BOOL disableFav = NO;
    [[TTVAlbumUtil sharedInstance] setButton:self.collectBtn disabled:disableFav action:^{
        if (disableFav) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持收藏" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
        }
    }];
    
    [[TTVAlbumUtil sharedInstance] setButton:self.collectNormalBtn disabled:disableFav action:^{
        if (disableFav) {
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"本视频暂不支持收藏" indicatorImage:nil autoDismiss:YES dismissHandler:nil];
        }
    }];
    
    if (self.collectAction) {
        self.collectAction(self.collectBtn.selected);
    }
}

- (void)shareAction:(id)sender {
    if (self.shareAction) {
        self.shareAction();
    }
}

- (void)danmakuSettingTouchUpInside:(UIButton *)button {
    if (self.danmakuSettingAction) {
        self.danmakuSettingAction();
    }
}

static char kPlayerFunctionMainSwitchStoreBrightnessStateKey;
static char kPlayerFunctionMainSwitchStoreVolumeStateKey;
- (void)setIsPresented:(BOOL)isPresented {
    _isPresented = isPresented;
    if (isPresented) {
        objc_setAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreBrightnessStateKey, @([TTPlayerFunctionMainSwitch sharedInstance].enableBrightnessView), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreVolumeStateKey, @([TTPlayerFunctionMainSwitch sharedInstance].enableVolumeView), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [TTPlayerFunctionMainSwitch sharedInstance].enableBrightnessView = NO;
        [TTPlayerFunctionMainSwitch sharedInstance].enableVolumeView = NO;
    } else {
        NSNumber *storeBrightnessView = objc_getAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreBrightnessStateKey);
        if ([storeBrightnessView isKindOfClass:[NSNumber class]]) {
            [TTPlayerFunctionMainSwitch sharedInstance].enableBrightnessView = [storeBrightnessView boolValue];
        }
        NSNumber *storeVolumeView = objc_getAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreVolumeStateKey);
        if ([storeVolumeView isKindOfClass:[NSNumber class]]) {
            [TTPlayerFunctionMainSwitch sharedInstance].enableVolumeView = [storeVolumeView boolValue];
        }
        objc_setAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreBrightnessStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject([TTPlayerFunctionMainSwitch sharedInstance], &kPlayerFunctionMainSwitchStoreVolumeStateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

#pragma mark - public method
- (void)setSwitchOn:(BOOL)isOn volumeProgress:(CGFloat)volumeProgress brightnessProgress:(CGFloat)brightnessProgress {
//    self.skipSwitch.on = isOn;
    self.volumeSlider.value = volumeProgress;
    self.brightnessSlider.value = brightnessProgress;
}

- (void)updateVolumeProgress:(CGFloat)volumeProgress {
    if (!self.volumeSlider.isTracking) {
        self.volumeSlider.value = volumeProgress;
    }
}

- (void)dislikeBtnAction:(id)sender{
    if (self.dislikeAction) {
        self.dislikeAction();
    }
}

- (void)reportBtnAction:(id)sender{
    if (self.reportAction) {
        self.reportAction();
    }
}

- (void)hideEIButton:(BOOL)hidden {
    self.eiBtn.hidden = hidden;
    self.eiBtnLabel.hidden = hidden;
}

- (void)setAudioPlayBtnIsSelected:(BOOL)audioPlayBtnIsSelected {
    _audioPlayBtnIsSelected = audioPlayBtnIsSelected;
    self.audioPlayBtn.selected = _audioPlayBtnIsSelected;
    self.audioPlayBtnLabel.highlighted = self.audioPlayBtn.selected;
    if(audioPlayBtnIsSelected) {
        [[TTVAlbumUtil sharedInstance] setButton:self.noEdgeBtn disabled:audioPlayBtnIsSelected action:^{ }];
    }
}

- (void)setHasSeries:(BOOL)hasSeries{
    _hasSeries = hasSeries;
    self.loopSettingView.hasSeries = hasSeries;
}

@end

@interface TTPlayerLoopSettingView ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) NSArray<UIButton *> *selectionItemBtns;

@end

@implementation TTPlayerLoopSettingView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"循环播放:";
        _titleLabel.textColor = [UIColor tt_W4_color];
        _titleLabel.font = [UIFont systemFontOfSize:13.f weight:UIFontWeightRegular];
        [_titleLabel sizeToFit];
        [self addSubview:_titleLabel];
        
        NSArray *list = @[@"不循环", @"单集循环"];
        NSMutableArray *buttonArray = [NSMutableArray array];
        [list enumerateObjectsUsingBlock:^(NSString *title, NSUInteger idx, BOOL * _Nonnull stop) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            [button setTitle:title forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
            button.titleLabel.font = [UIFont systemFontOfSize:13.f weight:UIFontWeightSemibold];
            [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
            button.hitTestEdgeInsets = UIEdgeInsetsMake(-12, -12, -12, -12);
            button.tag = idx;
            [button sizeToFit];
            [self addSubview:button];
            [buttonArray addObject:button];
        }];
        self.selectionItemBtns = [buttonArray copy];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat rate = [UIDevice btd_isScreenWidthLarge320] ? 1.0f:0.9f;
    self.titleLabel.left = 24;
    self.titleLabel.centerY = self.height / 2;
    UIView *preView = self.titleLabel;
    for (UIView *view in self.selectionItemBtns) {
        if (!view.hidden) {
            view.left = preView.right + 32 * rate;
            view.centerY = self.height / 2;
            preView = view;
        }
    }
}

- (void)onClick:(UIButton *)sender {
    self.loopingType = sender.tag;
    if (self.loopingTypeChanged) {
        self.loopingTypeChanged(sender.tag);
    }
}

- (void)setLoopingType:(NSInteger)loopingType {
    _loopingType = loopingType;
    for (UIButton *btn in self.selectionItemBtns) {
        btn.selected = (btn.tag == loopingType);
        btn.userInteractionEnabled = !btn.selected;
        btn.titleLabel.font = btn.selected ? [UIFont systemFontOfSize:13.f weight:UIFontWeightSemibold]:[UIFont systemFontOfSize:13.f weight:UIFontWeightRegular];
    }
}

- (void)setHasSeries:(BOOL)hasSeries{
    _hasSeries = hasSeries;
    if(hasSeries){
        NSString* title = @"合集循环";
        NSMutableArray* itemButtons = [self.selectionItemBtns mutableCopy];
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
        button.titleLabel.font = [UIFont systemFontOfSize:13.f weight:UIFontWeightSemibold];
        [button addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
        button.hitTestEdgeInsets = UIEdgeInsetsMake(-12, -12, -12, -12);
        button.tag = itemButtons.count;
        [button sizeToFit];
        [self addSubview:button];
        [itemButtons addObject:button];
        self.selectionItemBtns = [itemButtons copy];
    }
}

@end
