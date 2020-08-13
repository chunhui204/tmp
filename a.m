//
//  TTVPlayerAdapterViewController.m
//  Article
//
//  Created by 戚宽 on 2019/7/9.
//

#import "TTVPlayerAdapterViewController.h"
#import <TTVPlayerPod/TTVPlayerKitHeader.h>
#import <TTVPlayerPod/TTVFastPlayPart.h>
#import <TTVPlayerPod/TTVFreeZoomingPart.h>
#import "TTVPlayerAdapterViewController+FullScreen.h"
#import "TTVPlayerAdapterViewController+DeviceProperties.h"
#import "TTVPlayerAdapterViewController+Internal.h"
#import "TTVPlayerAdapterViewController+NetworkMonitor.h"
#import "TTVPlayerAdapterViewController+VideoEngine.h"
#import "TTVPlayerAdapterViewController+Controls.h"
//#import "TTVPlayerAdapterViewController+TTVLRecommendPlayManager.h"
#import "TTVPlayerAdapterViewController+TipBarArbiter.h"
#import "TTVPlayerAdapterViewController+FrontPaster.h"
#import "TTVPlayerAdapterViewController+SpecialSell.h"
#import "TTVPlayerAdapterViewController+NetworkMonitor.h"
#import "TTVPlayerAdapterViewController+CacheProgress.h"
#import "TTVPlayerAdapterViewController+Tracker.h"
#import "TTVPlayerAdapterViewController+Danmaku.h"
#import "TTVPlayerTrackerPart.h"
#import "TTVPlayerAdapterViewController+AudioModel.h"
#import <TTNetworkManager/TTNetworkManager.h>
#import "TTSettingsManager+ImmersePlay.h"
#import <Masonry/Masonry.h>
#import "TTVPlayerLogoPart.h"
#import "TTVPlayerFinishPart.h"
#import "TTVPlayerTokenManager.h"
#import "TTVPlayerTrackerPart.h"
#import "TTVEmotionalProgressPart.h"
#import "TTVPlayerAdapterViewController+Internal.h"
#import "TTImmersePlayerPresenter.h"
#import "TTVideoIdleTimeService.h"
#import "TTAudioSessionManager.h"
#import "TTVAdapterElementPart.h"
#import "TTVPlayPart.h"
#import "TTVPlayer+XiGua.h"
#import <Lottie/Lottie.h>
#import "TTUIResponderHelper.h"
#import <XIGSettings/TTVideoFontService.h>
#import <XIGUIKit/UIFont+TTFont.h>
#import "TTVFullInteractivePart.h"
#import "TTVPlayerAdapterViewController+TTVPlayerPasterADProtocolSupport.h"
#import "TTVPlayerAdapterViewController+ResolutionAutoDegrade.h"
#import "TTVPlayerAdapterViewController+ScreenCast.h"
#import "TTVPlayerWatchProgressToastPart.h"
#import "TTVPlayerAddWatchTimeService.h"
#import "TTVPlayerConfigurations.h"
#import "TTVBrightnessManager.h"
#import "TTVVolumeManager.h"
#pragma mark Immerse
#import "TTImmersePlayerViewController.h"
#import "TTImmersePlayerPresenter.h"
#import "TTSettingsManager+ImmersePlay.h"
#import "TTVImmersePlayerCollectionView.h"
#import "TTVPlayerFullScreenManager.h"
#import "TTVideoEngineEventManager.h"
#import "TTVPlayerQosTrackerPart.h"
#import "TTVGestureZoomPart.h"
#import "TTVSettingsConfiguration.h"
#import "TTVADTitlePart.h"
#import "TTVAdapterFinishPart.h"
#import "TTVPreviewPart.h"
#import "NSDictionary+BTDAdditions.h"
#import "TTVPlayerAdapterViewController+WaterMark.h"
#import "TTVPlayerAdapterViewController+EmotionalProgress.h"
#import <TTSettingsManager/TTSettingsManager.h>
#import "TTVVideoSettingsManager.h"
#import "TTVPlayerPreloadManager.h"
#import "TTVLTrackerPart.h"
#import "TTVSettingsConfiguration.h"
#import "XIGVideoProgressCacheManager.h"
#import "TTVLoopingPlayManager.h"
#import "TTVideoEngineModel.h"
#import "TTVPlayerResolutionAutoDegradePart.h"
#import <TTVPlayerPod/TTVResolutionAutoDegradePart.h>
#import <XIGSettings/TTVideoOptimizeSettingsManager.h>
#import "TTVideoResolutionService.h"
#import "TTVPlayerManager.h"
#import "TTVSeriesViewModel.h"

@interface TTVPlayerAdapterView : UIView
@property (nonatomic ,weak)UIView *topView;
@end

@implementation TTVPlayerAdapterView

- (void)willMoveToSuperview:(UIView *)newSuperview{
    //BTDLog(@"===== %@",[NSThread callStackSymbols]);
    [super willMoveToSuperview:newSuperview];
}

- (void)addSubview:(UIView *)view{
    [super addSubview:view];
}

@end

NSString *const kTTPlayerViewControllerPlaybackStateDidChangedNotification = @"kTTPlayerViewControllerPlaybackStateDidChangedNotification";

@interface TTVPlayerAdapterViewController ()<TTVPlayerDelegate, TTVPlayerDoubleTapGestureDelegate>
@property (nonatomic, assign) BOOL readyForDisplay;
@property (nonatomic, strong) LOTAnimationView *animation;
@property (nonatomic, strong) UIView *playerBottomCustomView; //为弹幕提供
@property (nonatomic, strong) NSMutableArray *playbackTimeObserversArray;
@property (nonatomic, strong) NSMutableArray *zeroPointOnePlaybackTimeObserversArray;
@property (nonatomic, assign) int64_t observerLoopCount;
@property (nonatomic, strong) UIImage *watermarkFullImage;
@property (nonatomic, strong) UIImage *watermarkImage;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL hasAddPart;
@property (nonatomic, strong) NSPointerArray *playerDelegates;
#pragma mark Immerse
@property (nonatomic, assign) BOOL canImmersePlay;
@property (nonatomic, strong, nullable) TTImmersePlayerInteracter *immersePlayerInteracter;
@property (nonatomic, strong, nullable) TTImmersePlayerViewController *immersePlayerViewController;
@property (nonatomic, assign) BOOL needMoveContainerViewToImmersePlayerViewController;
@property (nonatomic, assign) BOOL needCloseImmerse;
@property (nonatomic, assign) CGPoint immerseContentOffset;
@property (nonatomic, assign) BOOL needForbidResetImmerse;
@property (nonatomic, assign) BOOL rotateByFullScreenInteractive;
@property (nonatomic, assign) BOOL preShowsTitleShadow;
@property (nonatomic, strong) UIView *containerView;

@property (nonatomic, copy, readwrite) NSString *businessToken;
@property (nonatomic, copy, readwrite) NSString *authToken;
@property (nonatomic, copy, readwrite) NSString *videoTitle;

/// 新播放器为了首帧以及fps性能优化，会在播放器没有完全初始化之前去加载首帧，
/// 此时，播放器的其余功能还未准备完全，使用会无效，需要在完全ready后在去调用播放器的方法
@property (nonatomic, copy) TTVPlayerIsReadyToUse isReadyToUse;

@property (nonatomic, strong) NSMutableArray *readyCallbacks;
@property (nonatomic, assign) BOOL playerReady;

@end

@implementation TTVPlayerAdapterViewController

- (void)dealloc
{
    if (!self.isLongVideo && self.playerVCtrl.looping) {
        [[TTVLoopingPlayManager shared] autoExitLoopingForGid:self.videoID trackParams:[self trackParamsForLoopingPlayExit]];
    }
    self.menuDataSource = nil;
    self.menuDelegate = nil;
    [self innerRemovePlayer];
    [self showScreenCastFloatBallIfNeeded];
    [self removeVideoPreloadModel];
}

- (instancetype)init
{
    return [self initWithImmerseEnable:NO readyToUse:nil];
}

- (instancetype)initWithImmerseEnable:(BOOL)immerseEnable isLongVideo:(BOOL)isLongVideo{
    return [self initWithImmerseEnable:immerseEnable isLongVideo:isLongVideo readyToUse:nil];
}

- (instancetype)initWithImmerseEnable:(BOOL)immerseEnable{
    return [self initWithImmerseEnable:immerseEnable readyToUse:nil];
}

+ (NSString *)longStylePlist{
    return @"TTVPlayerStyle-Long.plist";
}

+ (NSString *)shortStylePlist{
    return @"TTVPlayerStyle-Short.plist";
}

+ (void)preloadPlist{
    [TTVPlayer preloadPlistForName:[[self class] longStylePlist] inBundle:[XIGBizPlayerBundle mainBundle]];
    [TTVPlayer preloadPlistForName:[[self class] shortStylePlist] inBundle:[XIGBizPlayerBundle mainBundle]];
    [TTVPlayer preloadPlistForName:@"TTVPlayerStyle-XGADVideoImmersPlayer" inBundle:[XIGBizPlayerBundle mainBundle]];
}

- (void)addPlayerVCtrl{
    _playerVCtrl = [[TTVPlayer alloc] initWithOwnPlayer:[SSCommonLogic ownPlayerEnabled] configFileName:(self.isLongVideo ? [[self class] longStylePlist] : [[self class] shortStylePlist]) bundle:[XIGBizPlayerBundle mainBundle]];
    _playerVCtrl.enableAudioSession = NO;
    _playerVCtrl.customDoubleGestureDelegate = self;
    _playerVCtrl.delegate = self;
    _playerVCtrl.showPlaybackControlsOnViewFirstLoaded = NO;
    _playerVCtrl.showPlaybackControlsOnVideoFinished = NO;
    _playerVCtrl.playbackTimeCallbackInterval = self.isLongVideo ? 0.1 : 0.5;
    [self resetVideoEngine];
    [_playerVCtrl.playerStore subscribe:self];
    [self addTrackPart];
    [self setupAudioSession];
    [self setupPlayerVideoKeyPathEventLogger];
}

- (void)setupPlayerVideoKeyPathEventLogger {
    if(ttvs_enablePlayerKeyPathTrack()) {
        [self.playerVCtrl startPlayerKeyPathTrack];
    }
    
}

- (void)setupAudioSession {
    [[TTAudioSessionManager sharedInstance] setCategory:AVAudioSessionCategoryPlayback];
    [[TTAudioSessionManager sharedInstance] requireActive:YES scene:self];
}

- (void)addTrackPart{
    TTVPlayerTrackerPart *trackerPart = [[TTVPlayerTrackerPart alloc] init];
    trackerPart.tracker.enable = NO;
    trackerPart.isLongVideo = self.isLongVideo;
    [_playerVCtrl addPart:trackerPart];
    [self playerTracker].playerViewController = self;

    TTVPlayerQosTrackerPart *qosPart = [[TTVPlayerQosTrackerPart alloc] init];
    [_playerVCtrl addPart:qosPart];
    qosPart.qosTracker.viewModel = self.viewModel;
    [self setQosIsLongVideo:self.isLongVideo];

    if (self.isLongVideo) {
        TTVLTrackerPart *ttvlTrackPart = [[TTVLTrackerPart alloc] init];
        [_playerVCtrl addPart:ttvlTrackPart];
    }
    [self checkAddAutoDegradePartIfNeed];
}

/// 检查是否需要添加自动清晰度降级的part
- (void)checkAddAutoDegradePartIfNeed{
    BOOL isAddautoDegradePart = [TTVideoOptimizeSettingsManager isAutoDegaradeResolutionEnable:self.isLongVideo];
    if (!self.isLongVideo && ttvs_videoABRConfig() > 0) { // 短视频开启abr功能时，屏蔽自动降级
        isAddautoDegradePart = NO;
    }
    if (isAddautoDegradePart) {
        //添加清晰度自动降级的part
        TTVPlayerResolutionAutoDegradePart *resolutionAutoDegradePart = [[TTVPlayerResolutionAutoDegradePart alloc] init];
        resolutionAutoDegradePart.viewModel = self.viewModel;
        resolutionAutoDegradePart.isLongVideo = self.isLongVideo;
        self.disableDegradeTip = YES;//关闭之前的降级提醒功能
        //配置卡顿监听策略相关参数
        //取消用户自动降级最大次数后不再提示
        resolutionAutoDegradePart.cancelMaxCounts = [TTVideoOptimizeSettingsManager autoDegaradeTipCancelMaxNum:self.isLongVideo];
        //启动播放卡顿降低分辨率阈值
        resolutionAutoDegradePart.readyPlayLoadingMaxSeconds = [TTVideoOptimizeSettingsManager autoDegaradeLoadMaxtime:self.isLongVideo];
        //播放过程卡顿计入降低分辨率阈值
        resolutionAutoDegradePart.playLoadingMaxSeconds = [TTVideoOptimizeSettingsManager autoDegaradeLoadingMaxtime:self.isLongVideo];
        //播放过程卡顿次数降低分辨率阈值
        resolutionAutoDegradePart.loadingMaxCounts = [TTVideoOptimizeSettingsManager autoDegaradeLoadShowTipMaxNum:self.isLongVideo];
        //统计用户播放卡度的时间周期
        resolutionAutoDegradePart.loadingCycleSeconds = [TTVideoOptimizeSettingsManager autoDegaradeTrackerCycletime:self.isLongVideo];
        //配置每一次自动降级要降几档
        resolutionAutoDegradePart.autoDegradeStep = [TTVideoOptimizeSettingsManager autoDegaradeOnceStep:self.isLongVideo];
        [self.playerVCtrl addPart:resolutionAutoDegradePart];
    }
}

- (void)addPlayerPart{
    [self.playerVCtrl addPart:[[TTVFullInteractivePart alloc] init]];
    [self.playerVCtrl addPart:[[TTVAdapterElementPart alloc] init]];
    [self.playerVCtrl addPart:[[TTVTVPart alloc] init]];
    [TTVideoResolutionService saveProgressWhenResolutionChanged:0.0f];
    
    [self configPlayerResolution];
    
    [self.playerVCtrl addPart:[[TTVADTitlePart alloc] init]];
    [self.playerVCtrl addPart:[[TTVAdapterFinishPart alloc] init]];
    [self.playerVCtrl addPart:[[TTVPlayerWatchProgressToastPart alloc] init]];
    BOOL enablePreview = YES;
    if (!self.isLongVideo) {
        enablePreview = ![TTKitchen getBOOL:kVideoPlayerDisablePreview];
    }
    if (enablePreview) {
        TTVPreviewPart *preview = [[TTVPreviewPart alloc] init];
        preview.previewClass = [TTVPreviewView class];
        [self.playerVCtrl addPart:preview];
    }
    
    if ([self.delegate respondsToSelector:@selector(playerViewController:addExtraPartsWithManager:)]) {
        [self.delegate playerViewController:self addExtraPartsWithManager:self.playerVCtrl];
    }

    if ([TTKitchen getBOOL:kVideoSettingsFreeZoomingEnabled]) {
        TTVFreeZoomingPart *freeZoomingPart = [[TTVFreeZoomingPart alloc] init];
        [self.playerVCtrl addPart:freeZoomingPart];
        freeZoomingPart.minimumScale = [TTKitchen getFloat:kVideoSettingsFreeZoomingMinimumScale];
        freeZoomingPart.maximumScale = [TTKitchen getFloat:kVideoSettingsFreeZoomingMaximumScale];
        freeZoomingPart.rotationEnabled = [TTKitchen getBOOL:kVideoSettingsFreeZoomingRotationEnabled];
    }

    if ([TTKitchen getBOOL:kVideoSettingsEmotionalProgressEnabled]) {
        TTVEmotionalProgressPart *emotionalProgressPart = [[TTVEmotionalProgressPart alloc] init];
        [self.playerVCtrl addPart:emotionalProgressPart];
    }
}

- (void)configPlayer{
    if (!self.hasAddPart) {
        self.hasAddPart = YES;
        [self addPlayerPart];
    }
}

#pragma mark - TTVPlayerDelegate

- (void)playerViewDidLayoutSubviews:(TTVPlayer *)player state:(TTVPlayerState *)state
{
    [player XiGuaStyle];
    if (!player.playerState.controlViewState.showed) {
        return;
    }
    UILabel * titleLable = (UILabel *)[self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_TitleLabel];
    self.titleTagView.hidden = titleLable.hidden;
    if (state.controlViewState.showed) {
        if (titleLable) {
            [self.titleTagView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(titleLable.mas_bottom).offset(2.0f);
                make.left.equalTo(titleLable);
            }];
        }
    }
}

- (void)viewDidLoad:(TTVPlayer *)player state:(TTVPlayerState *)state
{
    [self configPlayer];
    self.showsTitleShadow = YES;
    self.showsPlaybackControls = NO;
    self.playerVCtrl.view.clipsToBounds = YES;
    [self updateTitleLabel];
    [self updateTimeLabel];
    [self.playerVCtrl.playerAction showZoomButton:NO];
    if (self.isLongVideo || self.disableDegradeTip) {
        [self.playerVCtrl.playerAction disableDegradeAction:YES];
        [player.playerAction showCenterButtonOnFull:NO];
    }
    TTVPlayerFinishPart *finishPart = (TTVPlayerFinishPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_PlayerFinish];
    finishPart.shouldShowBackButton = YES;
    finishPart.shouldShowFinishView = NO;

    TTVFullScreenPart *screenPart = (TTVFullScreenPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Full];
    screenPart.disableRotateFromeSuperView = [TTKitchen getBOOL:kVideoPlayerDisableRotateRemoveFromeSuperView];
    
    if (self.isDashSource && !self.isFullScreen && [TTVideoOptimizeSettingsManager isSmallStateOptEnable] && !self.isLongVideo) {
        TTVideoEngineResolutionType resolution = [TTVideoResolutionService defaultResolutionType];
        if (self.videoEngineModel) {
            if (self.videoEngineModel.supportedResolutionTypes.count > 0) {
                resolution =[TTVideoResolutionService suitableResolutionForCurrentVideoResolutions:self.videoEngineModel.supportedResolutionTypes];
            }
        } else if (self.videoInfoModel) {
            if (self.videoInfoModel.playInfo.supportedResolutionTypes.count > 0) {
                resolution =[TTVideoResolutionService suitableResolutionForCurrentVideoResolutions:self.videoInfoModel.playInfo.supportedResolutionTypes];
            }
        }
        screenPart.normalResolution = (TTVPlayerResolutionTypes)resolution;;
        screenPart.needSmallScreenOpt = YES;
    } else {
        screenPart.needSmallScreenOpt = NO;
    }
    
    if (self.canImmersePlay) {
        screenPart.rotateVC = self.immersePlayerViewController;
    }else{
        screenPart.rotateVC = self.playerVCtrl;
    }
    //沉浸式由于退出全屏的时候刷新collectionView导致UI动画不一致，所以放到下个runloop中退出全屏（先刷新collectionView）
    screenPart.exitInNextRunLoop = YES;

    TTVSeekPart *seekPart = (TTVSeekPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Seek];
    seekPart.immersiveSlider.hidden = state.fullScreenState.isFullScreen;
    //配置SeekPart是否启用Engine不回调complete防护
    seekPart.enbaleSeekProtect = [TTKitchen getBOOL:kVideoSettingsSeekProtectOptEnable];
    seekPart.seekProtectTime = [TTKitchen getInt:kVideoSettingsProtectTime];
    seekPart.cancelAreaEnabled = NO;
    seekPart.gesturePolicy = TTVSeekGesturePolicyFixedTimeOffset;
    
    // Fast play gesture is enabled by default.
    if (!TTVPlayerFastPlayGestureEnabled) {
        TTVFastPlayPart *fastPlayPart = (id) [self.playerVCtrl partForKey:TTVPlayerPartKey_FastPlay];
        fastPlayPart.enabled = NO;
    }

    if (self.supportsPortaitFullScreen) {
        [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction supportsPortaitFullScreenAction:YES]];
    }
    [self controlsViewDidLoad:player state:state];
    [self danmakuViewDidLoad:player state:state];
    if (self.isReadyToUse) {
        self.isReadyToUse(self, TTVPlayerWhenIsReadyToUse_ViewDidLoad);
    }
    
    if (!self.supportsPortaitFullScreen) {
        TTVPreviewPart *previewPart = (TTVPreviewPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Preview];
        previewPart.previewDefaultImage = [UIImage xigBizPlayerImageNamed:@"ttv_player_bg.png"];
    }
    //更新水印信息
    [self updateWaterMark];
    //更新自动降级的配置
    if (self.degradeTipBarPriority > 0) {
        TTVResolutionAutoDegradePart *autoDegradePart = (TTVResolutionAutoDegradePart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_ResolutionAutoDegrade];
        autoDegradePart.degradeTipBarPriority = self.degradeTipBarPriority;
    }

    // 更新进度条情感化配置
    [self updateEmotionalProgress];
    
    self.playerReady = YES;
    [self _flushReadyCallbacks];
}

- (void)animatePlayButton:(UIButton *)playButton currentIsPlaying:(BOOL)isPlaying withToPauseJson:(NSString *)toPause toPlayJson:(NSString *)toPlay{
    [self.animation stop];
    LOTAnimationView *animation = nil;
    if (isPlaying) {
        animation = [LOTAnimationView animationNamed:toPause inBundle:[XIGBizPlayerBundle mainBundle]];
    }else{
        animation = [LOTAnimationView animationNamed:toPlay inBundle:[XIGBizPlayerBundle mainBundle]];
    }
    animation.userInteractionEnabled = NO;
    animation.loopAnimation = NO;
    if (animation) {
        [playButton addSubview:animation];
        playButton.imageView.transform = CGAffineTransformMakeScale(0, 0);
        __weak __typeof(animation) weakAnimation = animation;
        [animation playWithCompletion:^(BOOL animationFinished) {
            [weakAnimation removeFromSuperview];
            playButton.imageView.transform = CGAffineTransformIdentity;
        }];
    }
    self.animation = animation;
}

#pragma mark - TTVReduxStateObserver

- (void)subscribedStoreSuccess:(id<TTVReduxStoreProtocol>)store {
    if ([store respondsToSelector:@selector(addObserver:forActionType:)]) {
        [store addObserver:self forActionType:TTVPlayerActionType_PlayBackTimeChanged];
    }
}

- (void)unsubcribedStoreSuccess:(id<TTVReduxStoreProtocol>)store {
    if ([store respondsToSelector:@selector(removeObserver:forActionType:)]) {
        [store removeObserver:self forActionType:TTVPlayerActionType_PlayBackTimeChanged];
    }
}

- (void)stateDidChangedToNew:(TTVPlayerState *)newState lastState:(TTVPlayerState *)lastState store:(NSObject<TTVReduxStoreProtocol> *)store {
    
    if (newState.playbackTime.currentPlaybackTime != lastState.playbackTime.currentPlaybackTime) {
        [self timeObserverCallBack];
        if ([store respondsToSelector:@selector(isNotifyingSpecificObservers)] && store.isNotifyingSpecificObservers) {
            [self controlsStateDidChangedToNew:newState lastState:lastState store:store];
            return;
        }
    }
    [self fullscreenStateDidChangedToNew:newState lastState:lastState store:store];
    [self devicePropertiesStateDidChangedToNew:newState lastState:lastState store:store];
    [self networkMonitorStateDidChangedToNew:newState lastState:lastState store:store];
    [self controlsStateDidChangedToNew:newState lastState:lastState store:store];
    [self danmakuStateDidChangedToNew:newState lastState:lastState store:store];
    TTVFullScreenState *lastFullScreenState = ((TTVPlayerState*)lastState).fullScreenState;
    TTVFullScreenState *newFullScreenState = ((TTVPlayerState*)newState).fullScreenState;
    if (newFullScreenState.isFullScreen != lastFullScreenState.isFullScreen) {
        UIView *miniSlider = [self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_ImmersiveSlider];
        miniSlider.hidden = newFullScreenState.isFullScreen;
        [self updateTitleLabel];
        [self showTitle];
        if (newFullScreenState.isFullScreen) {
            self.preShowsTitleShadow = self.showsTitleShadow;
            self.showsTitleShadow = YES;
        }else{
            self.showsTitleShadow = self.preShowsTitleShadow;
        }
    }
    
    if (newState.controlViewState.moreButtonHidden != lastState.controlViewState.moreButtonHidden && !self.isLongVideo) {
        if (self.screenCastDisable || newState.controlViewState.moreButtonHidden) {
            [self hiddenTVButton];
        } else {
            [self showTVButton];
        }
        [self changeTVButtonImageWithIsFullScreen:newFullScreenState.isFullScreen];
    }

    if (newState.controlViewState.showed != lastState.controlViewState.showed ||
        newState.fullScreenState.isFullScreen != lastState.fullScreenState.isFullScreen) {
        if (self.playerVCtrl.playbackState == TTVPlaybackState_Paused ||
            self.playerVCtrl.playbackState == TTVPlaybackState_Playing) {
            if (newState.fullScreenState.isFullScreen) {
                TTVFullScreenPart *part = (TTVFullScreenPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Full];
                [part setStatusBarHidden:!newState.controlViewState.showed];
            }
        }
        if (newState.fullScreenState.isFullScreen != lastState.fullScreenState.isFullScreen){
            if (!self.isLongVideo) {
                if (newState.fullScreenState.isFullScreen) {
                    [self.playerVCtrl addPartFromConfigForKey:TTVPlayerPartKey_Share];
                }else{
                    [self.playerVCtrl removePartForKey:TTVPlayerPartKey_Share];
                }
            }
        }
    }
    if (newState.finishStatus && ![newState.finishStatus isEqual:lastState.finishStatus]) {
        [self hiddenPlayerView:YES];
        [self playerDidFinishWithStatus:newState.finishStatus];
        self.showsPlaybackControls = NO;
    }
    if (newState.readyForDisplay != lastState.readyForDisplay) {
        self.readyForDisplay = newState.readyForDisplay;
        if (self.isReadyToUse) {
            self.isReadyToUse(self, TTVPlayerWhenIsReadyToUse_IsReadyToPlay);
        }
        @weakify(self);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @strongify(self);
            if (self.isReadyToUse) {
                self.isReadyToUse(self, TTVPlayerWhenIsReadyToUse_AfterReadyToPlay);
            }
        });
        //NOTE:将启动就播放音频的触发时机延迟到首帧展示出来时，防止因为没有首帧，导致音频播放的背景是黑色。
        //添加播放器是否处在音频播放模式判断：（全屏沉浸式、开启连续播放会复用同一个播放器，如果已经处于音频模式下，再次执行会导致切换回视频模式）
        if(self.readyForDisplay && self.openRadioMode && ![self isInAudioMode]) {
            [self isOnlyPlayAudio];
        }
    }
    if (newState.readyToPlay != lastState.readyToPlay) {
        if (newState.readyToPlay) {
            [self hiddenPlayerView:NO];
            if (self.screenCastViewIsShowing) {
                [self pause];
            }
        }
    }
    if (newState.playbackState != lastState.playbackState) {
        switch (newState.playbackState) {
            case TTVPlaybackState_Playing:
                self.observerLoopCount = 0;
                break;
            default:
                break;
        }
        [self.viewModel isPlaybackEnded];
    }
    if (newState.controlViewState.playButtonStatus != lastState.controlViewState.playButtonStatus) {
        BOOL isPlay = newState.controlViewState.playButtonStatus == TTVToggledButtonStatus_Normal;
        BOOL shouldAniated = newState.controlViewState.isClickPlayButton;
        TTVPlayerPlayTriggerActionType type = [self.playerVCtrl.ttvActionInfo[TTVPlayerActionInfo_PlayTriggerType] integerValue];
        if (type != TTVPlayerPlayTriggerActionTypeSystem) {
            shouldAniated = YES;
        }
        if (shouldAniated) {
            if (self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
                UIButton *playBottom = (UIButton *)[self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_PlayBottomToggledButton];
                [self animatePlayButton:playBottom currentIsPlaying:isPlay withToPauseJson:@"play_to_pause.json" toPlayJson:@"pause_to_play.json"];
            }else{
                UIButton *playButton = (UIButton *)[self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_PlayCenterToggledButton];
                [self animatePlayButton:playButton currentIsPlaying:isPlay withToPauseJson:@"play_to_pause_list.json" toPlayJson:@"pause_to_play_list.json"];
            }
        }
    }
    
    if ((newState.seekStatus.panSeekingOutOfSliderInfo.progress != lastState.seekStatus.panSeekingOutOfSliderInfo.progress ||
         newState.seekStatus.panSeekingOutOfSliderInfo.isCancelledOutArea != lastState.seekStatus.panSeekingOutOfSliderInfo.isCancelledOutArea ||
         newState.seekStatus.panSeekingOutOfSliderInfo.gestureState != lastState.seekStatus.panSeekingOutOfSliderInfo.gestureState) && newState.seekStatus.panSeekingOutOfSliderInfo.panDirection == TTVPlayerPanGestureDirection_Horizontal) {
        if (newState.seekStatus.panSeekingOutOfSliderInfo.gestureState == UIGestureRecognizerStateBegan ||
            newState.seekStatus.panSeekingOutOfSliderInfo.gestureState == UIGestureRecognizerStateChanged || newState.seekStatus.panSeekingOutOfSliderInfo.gestureState == UIGestureRecognizerStateCancelled ||
            newState.seekStatus.panSeekingOutOfSliderInfo.gestureState == UIGestureRecognizerStateEnded) {
            UIGestureRecognizerState state = newState.seekStatus.panSeekingOutOfSliderInfo.gestureState;
            if (state != UIGestureRecognizerStateBegan
                && self.delegate
                && [self.delegate respondsToSelector:@selector(playerViewController:seekingToProgress:cancel:end:)]
                && !newState.fullScreenState.isTransitioning) {
                [self.delegate playerViewController:self seekingToProgress:newState.seekStatus.panSeekingOutOfSliderInfo.progress cancel:state == UIGestureRecognizerStateCancelled || newState.seekStatus.panSeekingOutOfSliderInfo.isCancelledOutArea end:state == UIGestureRecognizerStateEnded];
            }
        }
    }
    else if (newState.controlViewState.shareClick != lastState.controlViewState.shareClick) {
        if (newState.controlViewState.shareClick) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(shareActionWithPlayerViewController:)]) {
                [self.delegate shareActionWithPlayerViewController:self];
            }
        }
    }
    else if (newState.startedPlay != lastState.startedPlay){
        if (newState.startedPlay) {
            [self configPlayer];
            [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction showWatchProgressToastWithSecond:(NSInteger)self.startHistoryDuration]];
        }
    }
    else if (newState.fullScreenState.isFullScreen != lastState.fullScreenState.isFullScreen){
        if (newState.fullScreenState.isFullScreen) {
            [self.playerVCtrl addPartFromConfigForKey:TTVPlayerPartKey_Share];
        }else{
            [self.playerVCtrl removePartForKey:TTVPlayerPartKey_Share];
        }
    }else if (newState.audioModeState.turnOn != lastState.audioModeState.turnOn) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(playerViewControllerAudioModelChanged:)]) {
            [self.delegate playerViewControllerAudioModelChanged:newState.audioModeState.turnOn];
        }
        if(newState.audioModeState.turnOn) { //音频模式下：不展示弹幕内容
            self.danmakuAdapter.disableDanmaku = YES;
        }
        else if(self.danmakuAdapter) {
            BOOL expectSwitchOpen = self.danmakuAdapter.expectSwitchOpen;
            self.danmakuAdapter.disableDanmaku = NO;
            if (self.danmakuAdapter.danmakuSwitchOn != expectSwitchOpen) { //音频下使用外部弹幕开关切换弹幕状态，回到视频模式下，外部弹幕开关与弹幕实际开关需要对齐
                [self.danmakuAdapter toggleDanmakuSwitch:expectSwitchOpen];
            }
        }
        if(!newState.audioModeState.turnOn) { //退出音频模式后，需要将openRadioMode标识置为NO，否则连续播放会继续使用音频模式播放。
            self.openRadioMode = NO;
        }
    }else if (newState.resolutionState.progress != lastState.resolutionState.progress) {
        if (TTVResolutionProgress_Begin == newState.resolutionState.progress && !newState.resolutionState.isAutoDegrading && !newState.resolutionState.isMute) {
            TTVideoResolutionService.userChangedResolution = YES;
        }
    }
}

- (BOOL)player:(TTVPlayer*)playerVC didActionDoubleTappedWithState:(TTVPlayerState *)state {
    TTVPlayerPlayTriggerActionType type = TTVPlayerPlayTriggerActionTypePlayerDoubleClick;
    if (state.fullScreenState.isFullScreen) {
        type = TTVPlayerPlayTriggerActionTypeFullPlayerDoubleClick;
    }
    [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction playControlActionWithType:type]];
    return YES;
}

- (BOOL)player:(TTVPlayer *)player shouldAutoRotate:(BOOL)isFull
{
    if (isFull) {
        if (player.isPlaybackEnded) {
            if (self.isLongVideo) {
                return YES;
            }
            return NO;
        }
    }
    if (!self.isVisible) {
        return NO;
    }
    return YES;
}

- (NSString *)playerV2URL:(TTVPlayer *)player path:(NSString *)path
{
    return [[TTNetworkManager shareInstance] getBestHostFromTTNet:@"/vod/get_play_info"];
}

- (void)player:(TTVPlayer *)player requestPlayTokenCompletion:(void (^ __nullable)(NSError *error, NSString *authToken, NSString *bizToken))completion
{
    if ([self.delegate respondsToSelector:@selector(playerViewController:requestPlayTokenCompletion:)]) {
        [self.delegate playerViewController:self requestPlayTokenCompletion:completion];
    }else{
        //短视频
        [TTVPlayerTokenManager requestPlayTokenWithVideoID:player.videoID completion:^(NSError *error, NSString *authToken, NSString *bizToken) {
            if (completion) {
                completion(error ,authToken ,bizToken);
            }
        }];
    }
}

/// 前后台 默认 YES
- (BOOL)playerShouldPlayWhenBecomeActive:(TTVPlayer *)player{
    if ([self.delegate respondsToSelector:@selector(playerViewControllerShouldPlay)]) {
        return [self.delegate playerViewControllerShouldPlay];
    }
    return YES;
}

//- (BOOL)playerShouldPauseWhenResignActive:(TTVPlayer *)player {
//    if (self.playerVCtrl.playerState.audioModeState.enableBackground) {
//        return NO;
//    }
//    return YES;
//}
/////耳机插拔 默认 YES
//- (BOOL)playerShouldPlayWhenAudioSessionRouteChange:(TTVPlayer *)player;
//- (BOOL)playerShouldPauseWhenAudioSessionRouteChange:(TTVPlayer *)player;
/////意外打断 默认 YES
//- (BOOL)playerShouldPlayWhenAudioSessionInterruption:(TTVPlayer *)player;
//- (BOOL)playerShouldPauseWhenAudioSessionInterruption:(TTVPlayer *)player;

- (void)stop {
    [self.playerVCtrl stop];
}

- (void)hiddenPlayerView:(BOOL)hidden{
    //当在视频播放中切换上下一个时，可能由于视频frame变化造成的拉伸变形，故隐藏
    if ([self currentPlaybackTime] != [self duration]) {
        self.playerVCtrl.playerView.alpha = hidden ? 0 : 1;
    }
}

- (void)playerDidFinishWithStatus:(TTVPlayFinishStatus *)status
{
    self.effectivePlay = NO;
    
    NSError *error = status.playError;

    if (error) {

    }else{
        self.viewModel.playStartTime = 0;
    }
    if ([self.delegate respondsToSelector:@selector(playerViewController:didFinishPlayingWithError:)]) {
        [self.delegate playerViewController:self didFinishPlayingWithError:error];
    }
    [[self.playerDelegates allObjects] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj && [obj respondsToSelector:@selector(player:didFinishPlayWithError:)]) {
            [obj player:self didFinishPlayWithError:nil];
        }
    }];
    
    self.startHistoryDuration = 0;
    
    [TTVPlayerAddWatchTimeService addWatchTimeWithAuthorID:self.viewModel.authorID groupID:self.viewModel.gModel.groupID durationTime:(NSInteger)(self.durationWatched * 1000) watchProgress:(NSInteger)(self.currentPlaybackTime * 1000) videoType:self.isLongVideo ? TTVPlayerAddWatchTimeVideoTypeLong : TTVPlayerAddWatchTimeVideoTypeNormal completion:nil];
    
    XIGVideoProgressCache *cache = [XIGVideoProgressCache new];
    cache.playbackTime = self.currentPlaybackTime;
    cache.duration = self.duration;
    cache.videoID = self.videoID;
    [[XIGVideoProgressCacheManager sharedInstance] syncProgressWithObject:cache];
    
    
    self.viewModel.isLoopingPlay = self.playerVCtrl.looping; // finish后更新，保证video_play、video_over成对
    if (!self.isLongVideo && self.playerVCtrl.looping &&
        [status playerFinishedSuccessful] &&
        self.playerVCtrl.playbackTime.duration > 0 &&
        ABS(self.playerVCtrl.playbackTime.duration - self.playerVCtrl.playbackTime.currentPlaybackTime) < 5.f) {
        self.openRadioMode =  [self isInAudioMode] ? YES : NO; //开启单集循环播放时：每一次播放结束检查当前音频状态，根据状态重置openRadioMode值，保证下次播放时能正确设置音频播放还是视频播放。
        if([self currentVideoIsSingleMode] || [self enableTimeTask]) {//开启循环播放，播放结束后，检查是否处于音频模式下的“播放当前”和“定时关闭”模式是，则退出音频模式。
            [self stop];
        }
        [TTVLoopingPlayManager.shared increaseLoopCountForGid:self.videoID];
        // 清除计时
        [self clearLastWatchedDuration];
        [self.accessLog clearEvent];
        
    }
    if(self.disableScrolling){
        return;
    }
    //沉浸式播放下一个
    BOOL enableAudioPlayNext = YES;
    if([self isInAudioMode] && [self enableTimeTask]) {
        BOOL countdownTime = [self currentVideoCountDown] > 0 ? YES : NO;
        enableAudioPlayNext = [self currentVideoIsSingleMode] ? NO : countdownTime;
    }
    BOOL shouldSeriesAutoPlay = [TTVLoopingPlayManager.shared loopingTypeForGid:self.videoID] == TTVLoopingTypeMulti;
    
//    isStoryMode = self.delegate.class == [ttvfeedimmersepagecon]
    if ((shouldSeriesAutoPlay
         || [self.immersePlayerInteracter canAutoPlayNext]) &&
        self.immersePlayerViewController.startImmersePlay &&
        (status.type == TTVPlayFinishStatusType_SystemFinish && status.playError == nil) &&
        //无网络
        error.code != -106 && self.looping != TTVLoopingTypeSingle && enableAudioPlayNext) {
        [self.immersePlayerInteracter playNextIfNeed];
    }
    
}

- (void)setLogoImage:(UIImage *)image{
    TTVPlayerLogoPart *logoPart = (TTVPlayerLogoPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Logo];
    [logoPart setLogoImage:image];
}

- (void)playerDidStopSeeking:(TTVPlayer *)player {
    [[self qosTrackerPart] didStopSeeking];
}

#pragma mark - TTVPlayerProtocol

- (void)addPlaybackTimeHookBlock:(void (^)(NSArray *arguments))block byAspectOption:(AspectOptions)options key:(NSString *)key {
    if (isEmptyString(key)) {
        return;
    }
    void (^copyBlock)(NSArray *) = [block copy];
    if (options == AspectPositionAfter) {
        self.hookPlaybackBlockAfter[key] = copyBlock;
    } else if (options == AspectPositionBefore) {
        self.hookPlaybackBlockBefore[key] = copyBlock;
    }
}

- (void)removePlaybackTimeHookBlockbyAspectOption:(AspectOptions)options key:(NSString *)key {
    if (isEmptyString(key)) {
        return;
    }
    if (options == AspectPositionAfter) {
        [self.hookPlaybackBlockAfter removeObjectForKey:key];
    } else if (options == AspectPositionBefore) {
        [self.hookPlaybackBlockBefore removeObjectForKey:key];
    }
}

- (void)invokeOnReady:(void (^)(void))callback {
    [self.readyCallbacks addObject:callback];
    [self _flushReadyCallbacks];
}

- (UIView *)playerControlView{
    return self.playerVCtrl.controlView;
}

- (UIView *)controlsUnderlayView{
    return self.playerVCtrl.controlUnderlayView;
}

- (instancetype)initWithImmerseEnable:(BOOL)immerseEnable readyToUse:(TTVPlayerIsReadyToUse)isReadyToUse{
    return [self initWithImmerseEnable:immerseEnable isLongVideo:NO readyToUse:isReadyToUse];
}

- (instancetype)initWithImmerseEnable:(BOOL)immerseEnable isLongVideo:(BOOL)isLongVideo readyToUse:(TTVPlayerIsReadyToUse)isReadyToUse{
    self = [super init];
    if (self) {
        if (immerseEnable) {
            self.canImmersePlay = YES;
        }
        _immerseEnable = immerseEnable;
        _readyCallbacks = [NSMutableArray array];
        self.isReadyToUse = isReadyToUse;
        self.localPreferResolution = TTVideoEngineResolutionTypeUnknown;
        self.isLongVideo = isLongVideo;
        BOOL enableEngineLogV3 = [[[TTSettingsManager sharedManager] settingForKey:@"video_player_flag" defaultValue:@{} freeze:NO] tt_boolValueForKey:@"video_player_engine_log_v3"];
        if (enableEngineLogV3) {
            [[TTVideoEngineEventManager sharedManager] setLogVersion:TTEVENT_LOG_VERSION_NEW];
        }else{
            [[TTVideoEngineEventManager sharedManager] setLogVersion:TTEVENT_LOG_VERSION_OLD];
        }
        self.effectivePlay = NO;
        self.effectivePlayDuration = 10;
        self.hookPlaybackBlockAfter = [NSMutableDictionary dictionary];
        self.hookPlaybackBlockBefore = [NSMutableDictionary dictionary];
        
        [self addPlayerVCtrl];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    ///如果外界没有设置，默认YES
    NSNumber *value = objc_getAssociatedObject(self, @selector(enableFullScreen));
    if (!value) {
        self.enableFullScreen = YES;
    }
    self.view.backgroundColor = [UIColor blackColor];
    [self configPlayer];
    [self p_setupImmersePlayerIfNeed];
    [self _buildViewHierarchy];
    [self p_observeSmallScreenNotification];
    [self.playerVCtrl setNeedsUpdateLayout];
//    //NOTE:在播放器配置完，添加到父视图之后再执行play audio action
//    if(self.openRadioMode) {
//        [self isOnlyPlayAudio];
//    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
}

- (UIViewController *)roateVC{
    TTVFullScreenPart *screenPart = (TTVFullScreenPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Full];
    return screenPart.rotateVC;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
        self.isVisible = YES;
        [self.playerVCtrl.playerAction enableAutoRotate:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if (self.isScreenCasting) {
        // 更新投屏 UI
        [self updateScreenCastConfig];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (!self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
        [self.playerVCtrl.playerAction enableAutoRotate:NO];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    if (!self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
        self.isVisible = NO;
    }
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    if (self.playerVCtrl.playerState.fullScreenState.triggerType == TTVPlayerFullScreenTriggerUnknow) {
        if (UIDeviceOrientationIsLandscape([[UIDevice currentDevice] orientation]) && [self isFullScreen]) {
            return UIInterfaceOrientationMaskLandscape;
        }else if (UIDeviceOrientationIsPortrait([[UIDevice currentDevice] orientation])){
            return UIInterfaceOrientationMaskPortrait;
        }
    }
    if (self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
        return UIInterfaceOrientationMaskLandscape;
    }
    return UIInterfaceOrientationMaskPortrait;
//    return [self.playerVCtrl supportedInterfaceOrientations];
}

- (void)updateTitleLabel{
    TTVTitlePart *part = (TTVTitlePart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Title];
    
    if (self.isFullScreen &&
        self.immerseEnable) {
        part.titleLabel.font = [UIFont tt_boldFontOfSize:[TTVideoFontService distinctTitleFontSize]];
    } else {
        part.titleLabel.font = self.isFullScreen ? [UIFont systemFontOfSize:[TTBusinessManager tt_fontSize:19.f] weight:UIFontWeightMedium] : [TTVideoFontService distinctTitleFont];
    }
}

- (UIFont *)fontWithName:(NSString *)fontName fontSize:(CGFloat)fontSize{
    return ([UIFont fontWithName:fontName size:fontSize] ?: [UIFont systemFontOfSize:fontSize]);
}

- (UIFontDescriptor *)timeLabelFontDescriptor {
    UIFont *font = [self fontWithName:@"Helvetica Neue" fontSize:13];
    return [font fontDescriptor];
}

- (void)updateTimeLabel{
    UILabel *timeLabel = (UILabel *)[self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_TimeTotalLabel];
    timeLabel.layer.masksToBounds = NO;
    timeLabel.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.38].CGColor;
    timeLabel.layer.shadowOpacity = 1;
    timeLabel.layer.shadowOffset = CGSizeMake(0, 2);
    timeLabel.layer.shadowRadius = 6;
    timeLabel.font = [UIFont fontWithDescriptor:[self timeLabelFontDescriptor] size:[TTBusinessManager tt_fontSize:13.f]];
    
    UILabel *totalTimeLabel = (UILabel *)[self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_TimeTotalLabel];
    totalTimeLabel.layer.masksToBounds = NO;
    totalTimeLabel.layer.shadowColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.38].CGColor;
    totalTimeLabel.layer.shadowOpacity = 1;
    totalTimeLabel.layer.shadowOffset = CGSizeMake(0, 2);
    totalTimeLabel.layer.shadowRadius = 6;
    totalTimeLabel.font = [UIFont fontWithDescriptor:[self timeLabelFontDescriptor] size:[TTBusinessManager tt_fontSize:13.f]];
}


#pragma mark -
#pragma mark public methods

- (void)setPlayerTitle:(NSString *)title {
    self.videoTitle = title;
    self.playerVCtrl.videoTitle = title;
}

- (void)setPlayerAttributedTitle:(NSAttributedString *)attributedTitle {
    self.playerVCtrl.videoTitle = attributedTitle;
}

- (void)setVideoID:(NSString *)videoID {
    _videoID = videoID;
    self.videoSource = @"vid";
    if (self.settingsBlock) {
        self.settingsBlock(self);
    }
    [self.playerVCtrl setVideoID:self.videoID host:nil commonParameters:nil];
    if (self.isScreenCasting && self.viewModel.aID.integerValue == 0) {
        [self setupScreencastAdapterWithParams:@{@"screenCastEntry" : @"video_switch"}];
    }
}

- (void)setVideoEngineModel:(TTVideoEngineModel *)videoEngineModel {
    _videoEngineModel = videoEngineModel;
    if (!isEmptyString(videoEngineModel.videoInfo.videoID)) {
        _videoID = videoEngineModel.videoInfo.videoID;
    }
    self.videoSource = @"videoEngineModel";
    if (self.settingsBlock) {
        self.settingsBlock(self);
    }
    [self.playerVCtrl setVideoEngineModel:videoEngineModel];
    
    [self configPlayerResolution];
    
    if (self.isScreenCasting && self.viewModel.aID.integerValue == 0) {
        [self setupScreencastAdapterWithParams:@{@"screenCastEntry" : @"video_switch"}];
    }
}

- (void)setVideoInfoModel:(TTVideoEngineVideoInfo *)videoInfoModel {
    _videoInfoModel = videoInfoModel;
    if (!isEmptyString(videoInfoModel.vid)) {
        _videoID = videoInfoModel.vid;
    }
    self.videoSource = @"videoInfo";
    if (self.settingsBlock) {
        self.settingsBlock(self);
    }

    [self.playerVCtrl setVideoInfoModel:videoInfoModel];
    
    [self configPlayerResolution];

    if (self.isScreenCasting && self.viewModel.aID.integerValue == 0) {
        [self setupScreencastAdapterWithParams:@{@"screenCastEntry" : @"video_switch"}];
    }
    
}

- (void)innerRemovePlayer{
    [self.playerVCtrl willMoveToParentViewController:nil];
    [self.playerVCtrl.view removeFromSuperview];
    [self.playerVCtrl removeFromParentViewController];
}

- (void)removeVideoPreloadModel {
    [TTVPlayerPreloadManager removePreloadModel];
}

- (void)removePlayer {
    if (self.playerVCtrl.playerState.fullScreenState.isFullScreen && !self.playerVCtrl.playerState.fullScreenState.isTransitioning) {
        [self setFullScreen:NO animated:NO];
    }
    [self willMoveToParentViewController:nil];
    [self.view removeFromSuperview];
    [self removeFromParentViewController];
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    ///NOTE:如果旋转的是playerVCtrl ,self.view 旋转的过程中frame是保持小屏状态的，此时不要使playerVCtrl的view和self.view同步
    if (!self.playerVCtrl.playerState.fullScreenState.didFullscreen && !self.playerVCtrl.playerState.fullScreenState.isFullScreen) {
        self.playerVCtrl.view.frame = self.view.bounds;
    }
    if (self.immersePlayerViewController.parentViewController == self && (!self.playerVCtrl.playerState.fullScreenState.isFullScreen && !self.playerVCtrl.playerState.fullScreenState.isTransitioning)) {
        self.immersePlayerViewController.viewIfLoaded.frame = self.immersePlayerViewController.viewIfLoaded.superview.bounds;
        self.playerVCtrl.view.frame = self.view.bounds;
    }
    if (self.isScreenCasting) {
        [self updateScreenCastConfig];
    }
}

- (void)setAuthToken:(NSString *)authToken businessToken:(NSString *)businessToken{
    if (![businessToken isEqualToString:_businessToken]) {
        [self clearFullScreenInteractiveSubViews];
    }
    self.authToken = authToken;
    self.businessToken = businessToken;
    [self.playerVCtrl setPlayAuthToken:nil authToken:authToken businessToken:businessToken];
}

- (void)setPlayAuthToken:(NSString *)playAuthToken authToken:(NSString *)authToken businessToken:(NSString *)businessToken {
    if (![businessToken isEqualToString:_businessToken]) {
        [self clearFullScreenInteractiveSubViews];
    }
    self.authToken = authToken;
    self.businessToken = businessToken;
    [self.playerVCtrl setPlayAuthToken:playAuthToken authToken:authToken businessToken:businessToken];
}

- (void)addPlaybackTimeObserverBlock:(dispatch_block_t)aBlock {
    if (aBlock) {
        [self.playbackTimeObserversArray addObject:aBlock];
    }
}

- (void)removeAllPlaybackTimeObserverBlocks {
    [self.playbackTimeObserversArray removeAllObjects];
}

- (void)addZeroPointOnePlaybackTimeObserverBlock:(dispatch_block_t)aBlock {
    if (aBlock) {
        [self.zeroPointOnePlaybackTimeObserversArray addObject:aBlock];
    }
}

- (void)resetEffectivePlay {
    self.effectivePlayDuration = 10;
    self.effectivePlay = NO;
}

- (void)setEffectivePlayDuration:(NSTimeInterval)effectivePlayDuration {
    _effectivePlayDuration = effectivePlayDuration;
    TTVPlayerTrackerPart *part = (TTVPlayerTrackerPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Tracker];
    part.effectivePlayDuration = effectivePlayDuration;
}

#pragma mark -
#pragma mark private methods
- (void)configPlayerResolution {
    // videoinfoModel 带分辨率信息，与端上的配置不一致，可能导致分辨率被覆盖
    TTVideoEngineResolutionType resolution = [TTVideoResolutionService defaultResolutionType];
    if (self.videoInfoModel.playInfo.supportedResolutionTypes.count > 0) {
        resolution =[TTVideoResolutionService suitableResolutionForCurrentVideoResolutions:self.videoInfo.supportedResolutionTypes];
    }
    TTVFullScreenPart *screenPart = (TTVFullScreenPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_Full];
    if (self.isDashSource && !self.isFullScreen && [TTVideoOptimizeSettingsManager isSmallStateOptEnable] && !self.isLongVideo && TTVideoEngineResolutionTypeAuto != resolution && ttvs_videoABRConfig() == 0) {
        screenPart.needSmallScreenOpt = YES;
        screenPart.normalResolution = (TTVPlayerResolutionTypes)resolution;
        TTVideoEngineResolutionType smallStateResolution = [TTVideoOptimizeSettingsManager smallStateResolution];
        // 小屏分辨率比默认的小
        if (smallStateResolution < resolution) {
            resolution = smallStateResolution;
        }
    } else {
        screenPart.needSmallScreenOpt = NO;
    }
    
    [self configResolution:resolution];
    // 短视频强插自动档位
    if (!self.isLongVideo) {
        [self.playerVCtrl.playerAction enableFakeAutoResolution:ttvs_videoABRConfig() > 0];
        if ([TTVideoResolutionService autoModeEnable]) {
            [self.playerVCtrl.playerAction changeToFakeAutoResolutionMuted:YES];
        }
    }
}

- (void)timeObserverCallBack{
    self.observerLoopCount += 1;
    if ((self.observerLoopCount % 5 == 0 && self.playerVCtrl.playbackTimeCallbackInterval == 0.1) || self.playerVCtrl.playbackTimeCallbackInterval == 0.5 || self.playbackState == TTVideoEnginePlaybackStateStopped || self.playbackState == TTVideoEnginePlaybackStateError) {
        if  (!self.effectivePlay && self.durationWatched > self.effectivePlayDuration) {
            self.effectivePlay = YES;
        }
        
        if (self.playbackTimeObserversArray.count) {
            for (dispatch_block_t block in [self.playbackTimeObserversArray copy]) {
                if (block) {
                    block();
                }
            }
        }
        if (self.immerseEnable &&
            self.immersePlayerViewController.startImmersePlay) {
            [self.immersePlayerInteracter updatePlaybackTime:self.currentPlaybackTime duration:self.duration];
        }
    }
    for (dispatch_block_t block in [self.zeroPointOnePlaybackTimeObserversArray copy]) {
        if (block) {
            block();
        }
    }
}

- (void)removeTimeObserver{
    [self.playerVCtrl removeTimeObserver];
}

- (TTVideoEngineInfoModel *)videoInfo{
    return self.playerVCtrl.videoInfo;
}

- (UIView *)containerView {
    if (!_containerView) {
        _containerView = [[UIView alloc] init];
    }
    return _containerView;
}

- (void)didFetchedVideoModel:(TTVideoEngineModel *)videoModel {
    [self player:self.playerVCtrl didFetchedVideoModel:videoModel];
    if (!self.isLocalVideo) {
        [self configPlayerResolution];
    }
}

- (void)addPlayerAdapterDelegate:(id<TTVPlayerAdapterDelegate>)playerDelegate {
    if ([playerDelegate conformsToProtocol:@protocol(TTVPlayerAdapterDelegate)]) {
        [self.playerDelegates addPointer:(__bridge void * _Nullable)(playerDelegate)];
        [self.playerDelegates compact];
    }
}

- (void)_flushReadyCallbacks {
    if (self.playerReady) {
        [self.readyCallbacks enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ((void(^)(void)) obj)();
        }];
        [self.readyCallbacks removeAllObjects];
    }
}
- (void)_updateHUDLayouts {
    CGFloat topInset = 0;
    
    if (self.fullScreenState != TTPlayerFullScreenState_None) {
        UIView *titleLabel = [self.playerVCtrl partControlForKey:TTVPlayerPartControlKey_TitleLabel];
        if (titleLabel && !CGSizeEqualToSize(titleLabel.size, CGSizeZero)) {
            CGPoint globalCenter = [titleLabel.superview convertPoint:titleLabel.center
                                                               toView:self.playerVCtrl.view];
            topInset = globalCenter.y - 42;
        }
    }
    
    [TTVBrightnessManager shared].HUDTopInset = topInset;
    [TTVVolumeManager shared].HUDTopInset = topInset;
}

- (void)willResignActive {
    [TTVPlayerAddWatchTimeService addWatchTimeWithAuthorID:self.viewModel.authorID groupID:self.viewModel.gModel.groupID durationTime:(NSInteger)(self.durationWatched * 1000) watchProgress:(NSInteger)(self.currentPlaybackTime * 1000) videoType:self.isLongVideo ? TTVPlayerAddWatchTimeVideoTypeLong : TTVPlayerAddWatchTimeVideoTypeNormal completion:nil];
}

#pragma mark -
#pragma mark TTVideoPlayerDelegate
- (void)player:(TTVPlayer *)player didFetchedVideoModel:(TTVideoEngineModel *)videoModel {
    [[self qosTrackerPart] didFetchedVideoModel:videoModel];
    if (self.delegate && [self.delegate respondsToSelector:@selector(playerViewController:didFetchedVideoModel:)]) {
        [self.delegate playerViewController:(UIViewController<TTPlayerViewControllerProtocol> *)self didFetchedVideoModel:videoModel];
    }
}

- (void)player:(TTVPlayer *)player playbackStateDidChanged:(TTVPlaybackState)playbackState {
    //监听 playbackState，当 开始play 的时候更新 总时长 和 controlView播放状态
    if (!TTVPlayerManager.shared.hasPlayingPlayer) {
        [[TTVideoIdleTimeService sharedService] lockScreen:YES later:YES];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kTTPlayerViewControllerPlaybackStateDidChangedNotification object:self];
    switch (playbackState) {
        case TTVideoEnginePlaybackStatePlaying:
        {
            [[TTVideoIdleTimeService sharedService] lockScreen:NO];
        }
            break;
        case TTVideoEnginePlaybackStatePaused:
            break;
        case TTVideoEnginePlaybackStateStopped:
            break;
        default:
            break;
    }
}

- (void)playerPrepared:(TTVPlayer *)player{
    self.controlsTimeDuration = player.playbackTime.duration;
    if ([self.delegate respondsToSelector:@selector(playerViewControllerPrepared:)]) {
        [self.delegate playerViewControllerPrepared:(UIViewController<TTPlayerViewControllerProtocol> *)self];
    }
}

- (void)playerReadyToDisplay:(TTVPlayer *)player {
    [[self.playerDelegates allObjects] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj && [obj respondsToSelector:@selector(playerEngineReadyToDisPlay:)]) {
            [obj playerEngineReadyToDisPlay:self];
        }
    }];
    if (!self.isLongVideo) {
        TTVSeriesViewModel *viewModel = objc_getAssociatedObject(self, "TTVSeriesViewModel");
        if(viewModel){
            NSString *seriesId = [viewModel.pseriesId stringValue];
            [TTVLoopingPlayManager.shared assignVideoId:self.videoID SeriesId:seriesId];
            TTVLoopingType loopingType = [TTVLoopingPlayManager.shared loopingTypeForGid:self.videoID];
            self.looping = loopingType;
        [TTVLoopingPlayManager.shared setLoopingType:loopingType forGid:self.videoID trackParams:nil trackDataSource:self byClick:NO];
        }
    }
}

- (void)playerReadyToPlay:(TTVPlayer *)player {
    [[self.playerDelegates allObjects] enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj && [obj respondsToSelector:@selector(playerReadyToPlay:)]) {
            [obj playerReadyToPlay:self];
        }
    }];
}

- (void)playerCloseAysncFinish:(TTVPlayer *)player{
    if ([self.delegate respondsToSelector:@selector(playerViewControllerCloseAysncFinish:)]) {
        [self.delegate playerViewControllerCloseAysncFinish:(UIViewController<TTPlayerViewControllerProtocol> *)self];
    }
}

- (void)playerStalledExcludeSeek:(TTVPlayer *)player{
    if ([self.delegate respondsToSelector:@selector(playerViewControllerBeginStall:)]) {
        [self.delegate playerViewControllerBeginStall:(UIViewController<TTPlayerViewControllerProtocol> *)self];
    }
}

- (TTImageInfosModel *)audioCoverModel:(TTVPlayer *)player {
    if ([self.delegate respondsToSelector:@selector(audioCoverModel)]) {
        return [self.delegate audioCoverModel];
    }
    return nil;
}

- (BOOL)shouldShowFakeShadowViewUnderAudioCover:(TTVPlayer *)player {
    if(!self.isLongVideo) { //长视频音频模式下，封面图不需要展示阴影
        return YES;
    }
    return NO;
}

- (BOOL)remoteControlEnablePre:(TTVPlayer *)player {
    if ([self.delegate respondsToSelector:@selector(remoteControlEnablePre)]) {
        return [self.delegate remoteControlEnablePre];
    }
    return NO;
}

- (BOOL)remoteControlEnableNext:(TTVPlayer *)player {
    if ([self.delegate respondsToSelector:@selector(remoteControlEnableNext)]) {
        return [self.delegate remoteControlEnableNext];
    }
    return NO;
}

- (void)remoteControlClickPre:(TTVPlayer *)player {
    if ([self.delegate respondsToSelector:@selector(remoteControlClickPre)]) {
        [self.delegate remoteControlClickPre];
    }
}

- (void)remoteControlClickNext:(TTVPlayer *)player {
    if ([self.delegate respondsToSelector:@selector(remoteControlClickNext)]) {
        [self.delegate remoteControlClickNext];
    }
}

- (UIView *)hostOverlayContainerViewForPlayer:(TTVPlayer *)player {
    return self.immersePlayerViewController.viewIfLoaded;
}

#pragma mark -
#pragma mark setters getters

- (void)setShowsTitleShadow:(BOOL)showsTitleShadow{
    if (showsTitleShadow != _showsTitleShadow) {
        _showsTitleShadow = showsTitleShadow;
        [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction showTitleShadowAction:showsTitleShadow]];
    }
}

- (void)setNeedWatermark:(BOOL)needWatermark{
    if (_needWatermark != needWatermark) {
        _needWatermark = needWatermark;
        if (needWatermark) {
            [self.playerVCtrl addPartFromConfigForKey:TTVPlayerPartKey_WaterMark];
        }else{
            [self.playerVCtrl removePartForKey:TTVPlayerPartKey_WaterMark];
        }
    }
}

- (void)setShowsPlaybackControls:(BOOL)showsPlaybackControls{
    [self.playerVCtrl.playerAction showControlView:showsPlaybackControls];
}

- (UIView *)contentOverlayView {
    return self.playerVCtrl.containerView;
}

- (UIView *)playerBottomCustomView {
    return self.playerVCtrl.containerView.playbackControlView.bottomBar;
}

- (NSMutableArray *)playbackTimeObserversArray {
    if (!_playbackTimeObserversArray) {
        _playbackTimeObserversArray = [NSMutableArray array];
    }
    return _playbackTimeObserversArray;
}

- (NSMutableArray *)zeroPointOnePlaybackTimeObserversArray {
    if (!_zeroPointOnePlaybackTimeObserversArray) {
        _zeroPointOnePlaybackTimeObserversArray = [NSMutableArray array];
    }
    return _zeroPointOnePlaybackTimeObserversArray;
}

- (NSPointerArray *)playerDelegates {
    if (!_playerDelegates) {
        _playerDelegates = [NSPointerArray weakObjectsPointerArray];
    }
    
    return _playerDelegates;
}

- (BOOL)zoomIn{
    return self.playerVCtrl.playerState.gestureZoomState.zoomed;
}

- (void)setZoomIn:(BOOL)zoomIn {
    [self.playerVCtrl.playerAction zoom:zoomIn isAuto:YES];
}

- (void)setZoomIn:(BOOL)zoomIn isAuto:(BOOL)isAuto{
    [self.playerVCtrl.playerAction zoom:zoomIn isAuto:isAuto];
}

- (void)clearZoomState {
    TTVFreeZoomingPart *part = (TTVFreeZoomingPart *)[self.playerVCtrl partForKey:TTVPlayerPartKey_FreeZooming];
    [part clearFullscreenZoomingMode];
}

#pragma mark Immerse

- (void)_buildViewHierarchy {
    if (self.canImmersePlay) {
        [self.immersePlayerViewController willMoveToParentViewController:self];
        [self addChildViewController:self.immersePlayerViewController];
        [self.view addSubview:self.immersePlayerViewController.view];
        [self.immersePlayerViewController didMoveToParentViewController:self];
        
        [self.playerVCtrl willMoveToParentViewController:self.immersePlayerViewController];
        [self.immersePlayerViewController addChildViewController:self.playerVCtrl];
        [self.immersePlayerViewController.view addSubview:self.containerView];
        [self.containerView addSubview:self.playerVCtrl.view];
        [self.playerVCtrl didMoveToParentViewController:self.immersePlayerViewController];
        self.immersePlayerViewController.view.frame = self.view.bounds;
        self.containerView.frame = self.immersePlayerViewController.view.bounds;
        self.playerVCtrl.view.frame = self.view.bounds; self.immersePlayerViewController.view.autoresizesSubviews = YES;
        self.playerVCtrl.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.containerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    } else {
        [self.view addSubview:self.containerView];
        [self.playerVCtrl willMoveToParentViewController:self];
        [self addChildViewController:self.playerVCtrl];
        [self.containerView addSubview:self.playerVCtrl.view];
        [self.playerVCtrl didMoveToParentViewController:self];
        self.playerVCtrl.view.frame = self.view.bounds;
        self.containerView.frame = self.view.bounds;
        self.playerVCtrl.view.autoresizesSubviews = YES;
        self.containerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
}

- (void)setImmerseEnable:(BOOL)immerseEnable {
    if (!self.canImmersePlay) {
        return;
    }
    BOOL oldValue = self.immerseEnable;
    _immerseEnable = immerseEnable;
    if (oldValue != immerseEnable) {
        [self p_closeImmerse];
    }
}

- (TTImmersePlayerInteracter *)immersePlayerInteracter {
    if (!self.immerseEnable) {
        return nil;
    }
    if (!_immersePlayerInteracter) {
        _immersePlayerInteracter = [[TTImmersePlayerInteracter alloc] init];
    }
    return _immersePlayerInteracter;
}

- (void)p_setupImmersePlayerIfNeed {
    if (self.canImmersePlay) {
        self.immersePlayerViewController = [[TTImmersePlayerViewController alloc] init];
        self.immersePlayerInteracter = self.immersePlayerInteracter;
        TTImmersePlayerPresenter *presenter = [[TTImmersePlayerPresenter alloc] init];
        presenter.displayer = self.immersePlayerViewController;
        self.immersePlayerViewController.interactor = self.immersePlayerInteracter;
        self.immersePlayerInteracter.context = self.immersePlayerViewController.context;
        presenter.context = self.immersePlayerViewController.context;
        self.immersePlayerInteracter.presenter = presenter;
        self.immersePlayerViewController.playerViewController = self;
    }
}

- (void)p_observeSmallScreenNotification{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_smallScreen:) name:kVideoPlayerNeedSmallScreenNotification object:nil];
}
#pragma mark -
#pragma mark private methods
- (void)p_smallScreen:(NSNotification *)notification{
    if (notification) {
        self.rotateByFullScreenInteractive = YES;
        self.immerseContentOffset = self.immersePlayerViewController.collectionView.contentOffset;
        [self cacheProgress];
        [self restoreCachedProgress];
    }
    NSDictionary *userInfo = notification.userInfo;
    dispatch_block_t completion = userInfo[kVideoPlayerSmallCompletionKey];
    
    [self p_rotateToSmallScreenWithCompletion:completion];
    
    BOOL cleanInteractiveSubViews = [userInfo[kVideoPlayerCleanInteractiveViewKey] boolValue];
    if (cleanInteractiveSubViews) {
        [self clearFullScreenInteractiveSubViews];
    }
}

- (void)p_rotateToSmallScreenWithCompletion:(dispatch_block_t)completion{
    if (self.isFullScreen) {
        void(^realCompletion)(BOOL) = ^(BOOL finish){
            if (completion) {
                completion();
            }
        };
        [self setFullScreen:NO animated:YES completion:realCompletion];
    }
    [self.playerVCtrl pause];
}

- (void)setAuthorInfo:(NSDictionary *)userInfo{
    [self.fullInteractivePart setAuthorInfo:userInfo];
}

- (void)p_closeImmerse {
    if (!self.canImmersePlay || !self.immersePlayerViewController) {
        return;
    }
    if (self.isTransitioning) {
        self.needCloseImmerse = YES;
    } else {
        [self.immersePlayerViewController setStartImmersePlay:NO withCompleteBlock:nil];
        [self removeGestureDelegate:self.immersePlayerViewController];
        self.needMoveContainerViewToImmersePlayerViewController = NO;
        if (self.canImmersePlay) {
            [self.immersePlayerViewController willMoveToParentViewController:self];
            [self addChildViewController:self.immersePlayerViewController];
            [self.view addSubview:self.immersePlayerViewController.view];
            [self.view sendSubviewToBack:self.immersePlayerViewController.view];
            [self.immersePlayerViewController didMoveToParentViewController:self];
        }
        [self.view setNeedsLayout];
    }
}

- (void)playerWillEnterFullscreen:(TTVPlayer *)player {
    self.immerseEnable = self.supportsPortaitFullScreen ? NO : self.immerseEnable;
    
    [self.playerVCtrl setNeedsLayout];
    [self.playerVCtrl setNeedsUpdateLayout];

    if (self.immerseEnable) {
        [self prepareToEnterFullScreenImmersion];
        [self enterFullScreenImmersion];
    }
    self.needForbidResetImmerse = NO;
}

- (void)playerDidEnterFullscreen:(TTVPlayer *)player {
    if ([TTKitchen getBOOL:kVideoSettingsFreeZoomingEnabled]) {
        TTVGestureZoomPart *gestureZoom = (id) [player partForKey:TTVPlayerPartKey_GestureZoom];
        gestureZoom.enabled = NO;
    }
    
    [self _updateHUDLayouts];
}

- (void)playerWillExitFullscreen:(TTVPlayer *)player {
    [self.playerVCtrl setNeedsLayout];
    [self.playerVCtrl setNeedsUpdateLayout];
    if (self.immerseEnable) {
        if (!self.rotateByFullScreenInteractive) {
            [self.immersePlayerViewController setStartImmersePlay:NO withCompleteBlock:nil];
            [self removeGestureDelegate:self.immersePlayerViewController];
        }
        self.needMoveContainerViewToImmersePlayerViewController = NO;
        [self.immersePlayerViewController.collectionView.collectionViewLayout invalidateLayout];
    }
    if (self.immerseEnable && self.containerView.superview != self.immersePlayerViewController.view) {
        [self.immersePlayerViewController.view addSubview:self.containerView];
        self.containerView.frame = self.immersePlayerViewController.view.bounds;
    }
    
    [self _updateHUDLayouts];
}

- (void)playerDidExitFullscreen:(TTVPlayer *)player {
    if (self.immerseEnable) {
        if (self.immersePlayerViewController.view && self.containerView.superview != self.immersePlayerViewController.view) {
            [self.immersePlayerViewController.view addSubview:self.containerView];
            self.containerView.frame = self.immersePlayerViewController.view.bounds;
            [self.view setNeedsLayout];
        }
    }
    if (self.needCloseImmerse) {
        [self p_closeImmerse];
        self.needCloseImmerse = NO;
    }
}

- (NSInteger)priorityKey{
    return TTVReduxReducerPriorityIndex(TTVReducerPriorityIndex_Low);
}

#pragma mark - Immersion

- (void)prepareToEnterFullScreenImmersion {
    self.needMoveContainerViewToImmersePlayerViewController = YES;
    self.needForbidResetImmerse = self.rotateByFullScreenInteractive;
    
    if (self.rotateByFullScreenInteractive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.immersePlayerViewController adjustCollectionViewOffset:self.immerseContentOffset];
        });
    }
    self.rotateByFullScreenInteractive = NO;
}

- (void)enterFullScreenImmersion {
    if (self.needMoveContainerViewToImmersePlayerViewController) {
        self.needMoveContainerViewToImmersePlayerViewController = NO;
        if (self.needForbidResetImmerse) {
            [self.immersePlayerViewController attachPlayerFromFullScreenReturned];
        }
        
        if(!self.needForbidResetImmerse && [self.immersePlayerViewController setStartImmersePlay:YES withCompleteBlock:nil]) {
            [self.immersePlayerInteracter loadContentWithCompleteBlock:nil];
            [self addGestureDelegate:self.immersePlayerViewController];
        }
    }
    [self.immersePlayerViewController.collectionView.collectionViewLayout invalidateLayout];
}

@end

@implementation TTVPlayerAdapterViewController(TTPlayerViewControllerProtocol)
#warning TODO 需要在videoEngine的videoEngineReadyToDisPlay回调中补齐调用playerEngineReadyToDisPlay
@end

#import "TTVSeriesPlayerWrapper.h"
#import "TTVSeriesViewModel.h"
@implementation TTVPlayerAdapterViewController (LoopingPlay)

- (NSDictionary *)trackParamsForLoopingPlayBegin {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"category_name"] = self.viewModel.categoryID;
    params[@"group_id"] = self.viewModel.gModel.groupID;
    params[@"fullscreen"] = self.isFullScreen ? @"fullscreen":@"nofullscreen";
    CGFloat progress = 0.f;
    if (self.duration > 0) {
        progress = (self.playerVCtrl.playbackTime.currentPlaybackTime * 100.f / self.duration);
    }
    NSString *progressStr = [NSString stringWithFormat:@"%.1f", MAX(progress, 0)];
    params[@"percent"] = progressStr;
    
    TTVSeriesViewModel *seriesViewModel = [TTVSeriesPlayerWrapper seriesViewModelForPlayer:self];
    if (seriesViewModel) {
        params[@"album_id"] = seriesViewModel.pseriesId;
        params[@"album_num"] = seriesViewModel.seriesTotal;
    }
    return params;
}

- (NSDictionary *)trackParamsForLoopingPlayExit {
    return [self trackParamsForLoopingPlayBegin];
}

@end
