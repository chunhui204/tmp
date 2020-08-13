//
//  TTImmersePlayerViewController.m
//  Article
//
//  Created by yangshaobo on 2019/4/17.
//

#import "TTImmersePlayerViewController.h"
#import <IGListKit/IGListKit.h>
#import "TTImmersePlayerVideoSectionController.h"
#import "TTImmersePlayerSectionControllerProtocol.h"
#import "TTImmersePlayerEmptySectionController.h"
#import "TTImmersePlayerPlaySectionControllerProtocol.h"
#import <TTBaseLib/NSMutableArray+BDTSafeAdditions.h>
#import "UIViewController+TTViewIfLoaded.h"
#import "TTImmersePlayerPromptView.h"
#import "UIView+TTPrompt.h"
#import <ReactiveObjC/ReactiveObjC.h>
#import <TTUIWidget/TTIndicatorView.h>
#import "TTImmersePlayerCountdownTip.h"
#import "TTImmerseCollectionViewLayout.h"
#import "TTImmersePlayerViewController+TTImmerseImpr.h"
#import "TTImmersePlayerViewController+TTPromptShowCount.h"
#import "TTImmersePlayerViewController+VolumeBrightness.h"
#import "TTVPlayerAdapter.h"
#import "TTImmerseContext+TTImmerseStayImmerseLinkTrack.h"
#import "TTVPlayerFullScreenManager.h"
#import "TTSettingsManager+ImmersePlay.h"
#import "TTVImmersePlayerCollectionView.h"
#import "TTVADStreamRecordManager.h"
#import "TTVFeedImmerseSectionTracker.h"
#import "TTVImmersePlayerNewPromptView.h"
#import "TTPlayerFullScreenMoreMenuViewProtocol.h"
#import "TTVPlayerFullScreenManager.h"
#import "TTVSettingsConfiguration.h"
#import "TTVPlayerPreloadManager.h"
#import "TTVVideoSettingsManager.h"
#import <BDCatower/TTCatowerAdviserManger.h>
#import <BDCatower/TTCatowerVideoAdviser.h>
#import <XIGService/TTVideoFPSMonitor.h>
#import <TTQualityStat/TTQualityStat.h>
#import <XIGSettings/SSCommonLogic.h>
#import "TTPlayerFullScreenCommentView.h"
#import <XIGTracker/XIGTrackerUtil.h>


#define kAlphaViewTag 45

NSString * const TTImmersePlayerViewControllerHadShownPromptAnimation = @"TTImmersePlayerViewControllerHadShownPromptAnimation";
NSString * const TTImmersePlayerViewControllerNewStylePromptKey = @"TTImmersePlayerViewControllerNewStylePromptKey";

@interface TTImmersePlayerViewController () <IGListAdapterDataSource, IGListAdapterDelegate, UIScrollViewDelegate, TTImmersePlayerContextListener, UICollectionViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong, null_resettable) TTImmersePlayerViewModel *viewModel;
@property (nonatomic, strong, null_resettable) TTVImmersePlayerCollectionView *collectionView;
@property (nonatomic, strong, null_resettable) IGListAdapter *listAdapter;
@property (nonatomic, strong, null_resettable) IGListAdapterUpdater *updater;
@property (nonatomic, strong, null_resettable) TTVPlayerAdapterViewController *generatePlayerViewController;
@property (nonatomic, assign) BOOL privateStartImmersePlay;
@property (nonatomic, assign) BOOL startImmersePlay;
@property (nonatomic, strong, null_resettable) TTImmersePlayerPromptView *promptView;
@property (nonatomic, strong, null_resettable) TTVImmersePlayerNewPromptView *anotherPromptView;
@property (nonatomic, strong, null_resettable) TTImmersePlayerCountdownTip *countdownTip;
@property (nonatomic, assign) BOOL needShowPromptAnimation;
@property (nonatomic, assign) BOOL needWaitADToFinish; ///< 是否需要等待前贴广告结束
@property (nonatomic, assign) BOOL toastShowing;
@property (nonatomic, strong, nullable) RACDisposable *readyForDisplayDispose;
@property (nonatomic, assign) BOOL playNextNeedLoadMore;
@property (nonatomic, assign) BOOL addedPlaybackBlock;
@property (nonatomic, assign) BOOL needAdjustContentOffset;
@property (nonatomic, assign) CGPoint offsetToAdjust;
@property (nonatomic, strong) UIPanGestureRecognizer *promptPanGestureRecognizer;
@property (nonatomic, assign) BOOL panStateChanged;
@property (nonatomic, strong) UITapGestureRecognizer *finishCountTapGest;
@property (nonatomic, strong) UIPanGestureRecognizer *finishCountPanGest;
@property (nonatomic, strong) UITapGestureRecognizer *promptViewTapGest;
@property (nonatomic, strong) id firstObj;
@property (nonatomic, copy) void(^performBatchUpdatesCompleteBlock)(void);
@property (nonatomic, strong) NSIndexPath *prevIndexPathAtCenter;
@property (nonatomic, strong) NSIndexPath *willDisplayIndexPath;
@property (nonatomic, strong) TTVFeedImmerseSectionTracker *immerseSectionTracker;
@property (nonatomic, copy) TTVBrightnessViewDismissCompletion originalDismissCompletion;
@property (nonatomic, assign) BOOL inCountDownTimes; ///< 当前播放视频已播放至末尾切换倒计时阶段
@property (nonatomic, assign) BOOL playerMorePanelShowing;
@property (nonatomic, assign) BOOL playerPseriesFloatViewShowing;
@property (nonatomic, assign) BOOL volumeChanged;
@property (nonatomic, assign) BOOL brightnessChanged;
@property (nonatomic, copy) dispatch_block_t pendingScrollToNextBlock;

@property (nonatomic, strong) TTVideoFPSMonitor *fpsMonitor;

@end

@implementation TTImmersePlayerViewController

@synthesize context = _context;

- (void)dealloc {
    [self ttv_endRecord];
}

- (instancetype)init {
    if (self = [super init]) {
        self.enableAdjustFromSide = [TTSettingsManager sharedManager].tt_enableAdjustFromSide;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self p_configVolumeChange];
    [self p_setupNotification];
    [self p_setupGestureIfNeed];
    [self p_setupView];
    [self p_addCollectionView];
    [self p_setupCollectionView];
    [self ttv_beginRecord];
    [self p_addBrightnessHook];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [self p_removeBrightnessHook];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.collectionView.frame = (CGRect) {
        .size = self.tt_viewIfLoaded.bounds.size,
    };
    self.promptView.frame = self.collectionView.bounds;
    self.anotherPromptView.frame = self.collectionView.bounds;
    self.collectionView.sideViewWidth = [self.anotherPromptView sideViewWidth];
}

- (void)viewWillLayoutSubviews{
    [super viewWillLayoutSubviews];
}

- (BOOL)volumeChangedTriggeredByUser {
    return self.promptPanGestureRecognizer && self.promptPanGestureRecognizer.state == UIGestureRecognizerStateChanged;
}

#pragma mark - Set Get

- (UIPanGestureRecognizer *)finishCountPanGest {
    if (!_finishCountPanGest) {
        _finishCountPanGest = [[UIPanGestureRecognizer alloc] init];
        [_finishCountPanGest addTarget:self action:@selector(p_finishPanGest:)];
        _finishCountPanGest.delaysTouchesBegan = NO;
        _finishCountPanGest.delaysTouchesEnded = NO;
        _finishCountPanGest.cancelsTouchesInView = NO;
        _finishCountPanGest.delegate = self;
        _finishCountPanGest.enabled = NO;
    }
    return _finishCountPanGest;
}

- (UITapGestureRecognizer *)finishCountTapGest {
    if (!_finishCountTapGest) {
        _finishCountTapGest = [[UITapGestureRecognizer alloc] init];
        [_finishCountTapGest addTarget:self action:@selector(p_finishTapGest:)];
        _finishCountTapGest.delaysTouchesBegan = NO;
        _finishCountTapGest.delaysTouchesEnded = NO;
        _finishCountTapGest.cancelsTouchesInView = NO;
        _finishCountTapGest.delegate = self;
        _finishCountTapGest.enabled = NO;
    }
    return _finishCountTapGest;
}

- (UITapGestureRecognizer *)promptViewTapGest {
    if (!_promptViewTapGest) {
        _promptViewTapGest = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(p_promptViewTapGest:)];
        _promptViewTapGest.delegate = self;
    }
    return _promptViewTapGest;
}

- (TTImmersePlayerViewModel *)viewModel {
    if (!_viewModel) {
        _viewModel = [[TTImmersePlayerViewModel alloc] init];
    }
    return _viewModel;
}

- (TTImmersePlayerPromptView *)promptView {
    if (!_promptView) {
        _promptView = [[TTImmersePlayerPromptView alloc] init];
        _promptView.userInteractionEnabled = NO;
    }
    return _promptView;
}

- (TTVImmersePlayerNewPromptView *)anotherPromptView {
    if (!_anotherPromptView) {
        _anotherPromptView = [[TTVImmersePlayerNewPromptView alloc] init];
    }
    return _anotherPromptView;
}


- (void)setPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController{
    if (_playerViewController != playerViewController) {
        _playerViewController = playerViewController;
        RAC(self, collectionView.shouldNotScroll) = [RACObserve(self, playerViewController.disableScrollViewScroll) takeUntil:_playerViewController.rac_willDeallocSignal];
        RAC(self, collectionView.shouldNotScrollWithTwoFinger) = [RACObserve(self, playerViewController.disableScrollViewScrollWithTwoFinger) takeUntil:_playerViewController.rac_willDeallocSignal];
        [self p_addFullScreenObserverWithPlayer:_playerViewController];
    }
}

- (TTVPlayerAdapterViewController *)generatePlayerViewController {
    if (!_generatePlayerViewController) {
        _generatePlayerViewController = [self p_generatePlayerViewController];
        [self p_addFullScreenObserverWithPlayer:_generatePlayerViewController];
    }
    return _generatePlayerViewController;
}

- (TTVImmersePlayerCollectionView *)collectionView {
    if (!_collectionView) {
        TTImmerseCollectionViewLayout *flowLayout = [[TTImmerseCollectionViewLayout alloc] init];
        flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        flowLayout.minimumLineSpacing = 0;
        flowLayout.minimumInteritemSpacing = 0;
        _collectionView = [[TTVImmersePlayerCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
        _collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _collectionView.alwaysBounceVertical = NO;
        if (@available(iOS 11.0, *)) {
            _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }
        @weakify(self);
        _collectionView.performBatchUpdatesCompleteBlock = ^{
            @strongify(self);
            if (self.performBatchUpdatesCompleteBlock) {
                self.performBatchUpdatesCompleteBlock();
            }
        };
    }
    return _collectionView;
}
- (IGListAdapter *)listAdapter {
    if (!_listAdapter) {
        _listAdapter =
            [[IGListAdapter alloc]
             initWithUpdater:self.updater
             viewController:self
             workingRangeSize:2];
    }
    return _listAdapter;
}

- (IGListAdapterUpdater *)updater {
    if (!_updater) {
        _updater = [[IGListAdapterUpdater alloc] init];
    }
    return _updater;
}

- (TTImmerseContext *)context {
    if (!_context) {
        _context = [[TTImmerseContext alloc] init];
        [_context addListener:self forKey:@keypath(self.context, currentPlayerModel)];
        [_context addListener:self forKey:@keypath(self.context, enableScroll)];
    }
    return _context;
}

- (TTImmersePlayerCountdownTip *)countdownTip {
    if (!_countdownTip) {
        _countdownTip = [[TTImmersePlayerCountdownTip alloc] init];
    }
    return _countdownTip;
}

#pragma mark - Util

- (void)p_prepareLayoutCollectionView {
    [[self.collectionView collectionViewLayout] invalidateLayout];
    [self.collectionView layoutIfNeeded];
    [[self.collectionView collectionViewLayout] prepareLayout];
    self.collectionView.contentSize = [self.collectionView collectionViewLayout].collectionViewContentSize;
}

- (void)p_handleLoadPrevWithViewModel:(TTImmersePlayerViewModel *)viewModel {
    if (![viewModel isKindOfClass:TTImmersePlayerLoadPrevViewModel.class]) {
        self.firstObj = self.listAdapter.objects.firstObject;
        [self p_prepareLayoutCollectionView];
        return;
    }
    [[self.collectionView collectionViewLayout] invalidateLayout];
    [self.collectionView layoutIfNeeded];
    BOOL changeBounds = NO;
    if (self.firstObj == nil) {
        self.firstObj = self.listAdapter.objects.firstObject;
    } else {
        if ([self.collectionView numberOfSections] > 0 && [self.collectionView numberOfItemsInSection:0] > 0) {
            NSUInteger index = NSNotFound;
            NSUInteger i = 0;
            for (TTImmerseModel *model in [self.listAdapter.objects copy]) {
                if ([model isKindOfClass:TTImmerseModel.class] && [self.firstObj isKindOfClass:TTImmerseModel.class] && [model.groupId isEqualToString:((TTImmerseModel *)self.firstObj).groupId]) {
                    index = i;
                    break;
                }
                i ++;
            }
            if (index == NSNotFound) {
                self.firstObj = self.listAdapter.objects.firstObject;
            } else {
                [self.collectionView.collectionViewLayout prepareLayout];
                UICollectionViewLayoutAttributes *attr1 = [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
                UICollectionViewLayoutAttributes *attr2 = [self.collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
                changeBounds = fabs(attr2.frame.origin.y - attr1.frame.origin.y) > 0.1;
                CGRect bounds = CGRectOffset(self.collectionView.bounds, 0, attr2.frame.origin.y - attr1.frame.origin.y);
                self.collectionView.contentSize = [self.collectionView.collectionViewLayout collectionViewContentSize];
                [self.collectionView setContentOffset:bounds.origin animated:NO];
                self.firstObj = self.listAdapter.objects.firstObject;
            }
        }
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView layoutIfNeeded];
        
        if (changeBounds) {
            [self p_updateCurrentSectionController];
        }
        // 增加触发loadmore后的自动预加载
        if ([SSCommonLogic preloadVideoEnabled]) {
            [self startPreload];
        }
    }
}

- (void)p_finishPanGest:(UITapGestureRecognizer *)pan {
    switch (pan.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateChanged: {
            TTImmersePlayerTriggleFinishCountRequest *request = [[TTImmersePlayerTriggleFinishCountRequest alloc] init];
            [self.interactor doWithRequest:request];
        }
            break;
        default:
            break;
    }
}

- (void)p_finishTapGest:(UITapGestureRecognizer *)tap {
    switch (tap.state) {
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateChanged: {
            TTImmersePlayerTriggleFinishCountRequest *request = [[TTImmersePlayerTriggleFinishCountRequest alloc] init];
            [self.interactor doWithRequest:request];
        }
            break;
        default:
            break;
    }
}

- (void)p_promptViewTapGest:(UITapGestureRecognizer *)tap {
    if (self.anotherPromptView.superview) {
        [self.anotherPromptView dismissAnimated:YES];
    }
}

- (void)p_configVolumeChange {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    @weakify(self);
    [[[RACObserve(session, outputVolume) takeUntil:self.rac_willDeallocSignal] skip:1] subscribeNext:^(id  _Nullable x) {
        @strongify(self);
        TTImmersePlayerTriggleFinishCountRequest *request = [[TTImmersePlayerTriggleFinishCountRequest alloc] init];
        [self.interactor doWithRequest:request];
    }];
}



- (void)p_setupView {
    self.automaticallyAdjustsScrollViewInsets = NO;
}

- (void)p_setupNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_willResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(p_didBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)p_willResignActive:(NSNotification *)noti {
    if (self.privateStartImmersePlay) {
        self.context.ttv_pauseTimeBegin = [[NSDate date] timeIntervalSince1970];
    } else {
        self.context.ttv_pauseTimeBegin = 0;
    }
    [self p_removePromptAnimationIfNeed];
    [self.immerseSectionTracker suspend];
}

- (void)p_didBecomeActive:(NSNotification *)noti {
    if (self.privateStartImmersePlay && ABS(self.context.ttv_pauseTimeBegin) > 0.01) {
        self.context.ttv_pauseTime += [[NSDate date] timeIntervalSince1970] - self.context.ttv_pauseTimeBegin;
    }
    if (self.volumeChangedWhenNotActive || self.brightnessChangedWhenNotActive) {
        WeakSelf;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            StrongSelf;
            [self showAdjustPromptIfNeed];
        });
    }
    [self.immerseSectionTracker resume];
    
    if (self.pendingScrollToNextBlock) {
        self.pendingScrollToNextBlock();
        self.pendingScrollToNextBlock = nil;
    }
}

- (void)p_addCollectionView {
    [self.tt_viewIfLoaded addSubview:self.collectionView];
}

- (void)p_addFullScreenObserverWithPlayer:(TTVPlayerAdapterViewController *)playerViewController{
    @weakify(self);
    [RACObserve(playerViewController, fullScreenObserverState.fullScreenObserver) subscribeNext:^(NSNumber *x) {
        @strongify(self);
        if (![x boolValue]) {
            self.prevIndexPathAtCenter = self.willDisplayIndexPath;
            if (self.volumeBrightnessChangedInMorePanel) {
                self.volumeBrightnessChangedInMorePanel = NO;
            }
        }else{
            self.prevIndexPathAtCenter = nil;
        }
    }];
}

+ (NSArray *)p_buildSectionControllers {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:1];
    [array addObject:[TTImmersePlayerVideoSectionController class]];
    return array;
}

+ (BOOL)p_canConfigModel:(id)model filterPortait:(BOOL)filterPortait {
    NSArray *sectionControllersClass = [self p_buildSectionControllers];
    for (Class cls in sectionControllersClass) {
        if ([cls conformsToProtocol:@protocol(TTImmersePlayerSectionControllerProtocol)] &&
            [cls isSubclassOfClass:[IGListSectionController class]]) {
            Class<TTImmersePlayerSectionControllerProtocol> sectionControllerCls = cls;
            if ([sectionControllerCls respondsToSelector:@selector(canConfigModel:filterPortait:)]) {
                if ([sectionControllerCls canConfigModel:model filterPortait:filterPortait]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

- (void)setPlayerConfig:(TTVPlayerAdapterViewController *)player{
    player.showControlsTitle = YES;
    player.showsTitleShadow = YES;
}

- (TTVPlayerAdapterViewController *)p_generatePlayerViewController {
    @weakify(self);
    TTVPlayerAdapterViewController *playerViewController = [TTVPlayerAdapter createPlayerIsReadyToUse:^(TTVPlayerAdapterViewController *player, TTVPlayerWhenIsReadyToUse when) {
        @strongify(self);
        switch (when) {
            case TTVPlayerWhenIsReadyToUse_ViewDidLoad:
                [self setPlayerConfig:player];
                break;
                
            default:
                break;
        }
    }];
    TTImmersePlayerModel *playerModel = (TTImmersePlayerModel *)self.context.currentPlayerModel;
    BOOL isAd = (playerModel.orginalModel.tt_adId.longLongValue > 0);
    playerViewController.enableSeekPreview = !isAd;
    return playerViewController;
}

- (void)p_setupCollectionView {
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.listAdapter.collectionView = self.collectionView;
    self.listAdapter.collectionViewDelegate = self;
    self.listAdapter.dataSource = self;
    self.listAdapter.delegate = self;
    self.listAdapter.scrollViewDelegate = self;
}

- (BOOL)p_canConfigModel:(id)model filterPortait:(BOOL)filterPortait {
    return [[self class] p_canConfigModel:model filterPortait:filterPortait];
}

- (void)p_addBrightnessHook {
    TTVBrightnessViewDismissCompletion original = [TTVBrightnessManager shared].completionBlock;
    self.originalDismissCompletion = original;
   
    WeakSelf;
    TTVBrightnessViewDismissCompletion customCompletion = ^{
        !original ?: original();
        StrongSelf;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showAdjustPromptIfNeed];
        });
    };
    [TTVBrightnessManager shared].completionBlock = customCompletion;
}

- (void)p_removeBrightnessHook {
    [TTVBrightnessManager shared].completionBlock = self.originalDismissCompletion;
}

- (TTVPlayerAdapterViewController *)p_usedPlayer {
    if (self.playerViewController) {
        return self.playerViewController;
    } else {
        return self.generatePlayerViewController;
    }
}

- (void)p_observePlayerIfNeed:(TTVPlayerAdapterViewController *)player {
    if (self.readyForDisplayDispose) {
        [self.readyForDisplayDispose dispose];
        self.readyForDisplayDispose = nil;
    }
    if (!player) {
        return;
    }
    @weakify(self, player)
    self.readyForDisplayDispose = [RACObserve(player, readyForDisplay) subscribeNext:^(NSNumber *readyForDisplay) {
        @strongify(self, player)
        if ([readyForDisplay boolValue]) {
            NSNumber *videoLength = [NSNumber numberWithDouble:floor(player.duration * 1000)];
            [[TTQualityStat shareStat] onSceneFinishBySuccess:@"ShortVideo.HorizontalImmersionLoading" identifier:nil detailScene:nil description:[[TTQualityDescription alloc]initWithExtra:@{@"video_length": videoLength}]];
            if (self.needShowPromptAnimation) {
                self.needShowPromptAnimation = NO;
                [self p_showPromptAnimationIfNeedIsFirstTime:YES];
            }
        }
    }];
    if (!self.addedPlaybackBlock) {
        [player addPlaybackTimeObserverBlock:^{
            @strongify(self, player)
            
            NSTimeInterval currentPlaybackTimeNum = player.currentPlaybackTime;
            CGFloat percent = 0;
            if (player.duration > 0.01) {
                percent = currentPlaybackTimeNum / player.duration;
            }
            if (percent * 100 > self.ttv_showPromptPercent) {
                [self p_showPromptAnimationIfNeedIsFirstTime:NO];
            }
        }];
        self.addedPlaybackBlock = YES;
    }
    [[RACObserve(self, needWaitADToFinish) distinctUntilChanged] subscribeNext:^(NSNumber *needWaitADToFinish) {
        @strongify(self)
        if (![needWaitADToFinish boolValue]) {
            [self p_showPromptAnimationIfNeedFirstTime];
        }
    }];
}

- (void)p_showPromptAnimationIfNeedIsFirstTime:(BOOL)firstTime {
    if (firstTime) {
        [self p_showPromptAnimationIfNeedFirstTime];
    } else {
        [self p_showPromptAnimationIfNeedByPlayTime];
    }
}

- (void)p_showPromptAnimationIfNeedByPlayTime {
    if ([self ttv_shouldShowPrompt]) {
        if (!self.context.startImmersePlay) {
            return;
        }
        [self p_showPromptAnimationByFirstTime:NO];
        [self ttv_showedPrompt];
    }
}

- (void)p_showPromptAnimationIfNeedFirstTime {
    //1.判断是否显示过引导，显示过则直接退出
    if ([[NSUserDefaults standardUserDefaults] boolForKey:TTImmersePlayerViewControllerHadShownPromptAnimation]) {
        return;
    }
    //如果第一个Cell没有显示出来则记住需要PromptAnimation
    if (![self p_usedPlayer].readyForDisplay ||
        [self.collectionView numberOfSections] == 0 ||
        [self.collectionView numberOfItemsInSection:0] == 0) {
        self.needShowPromptAnimation = YES;
        return;
    }
    
    //3.做Prompt动画
    [self p_showPromptAnimationByFirstTime:YES];
    [self ttv_showedPrompt];
}

- (BOOL)ttv_shouldShowPromptAnimation{
    if (!self.tt_viewIfLoaded) {
        return NO;
    }
    if (self.needWaitADToFinish) {
        return NO;
    }
    if (![self p_usedPlayer].isFullScreen) {
        return NO;
    }
    if (self.collectionView.tt_isPromptAnimating) {
        return NO;
    } else if ([self.promptView pop_animationForKey:@"alphaStep1Animation"]) {
        return NO;
    } else if ([self.promptView pop_animationForKey:@"alphaStep2Animation"]) {
        return NO;
    }
    if (self.enableAdjustFromSide) {
        if (self.anotherPromptView.isScrollPromptAnimating || self.anotherPromptView.isAdjustPromptAnimating) {
            return NO;
        }
    }
    return YES;
}

- (void)p_showPromptAnimationByFirstTime:(BOOL)firstTime {
    NSAssert(self.tt_viewIfLoaded, @"controller没有Load，不能展示prompt动画");
    if (![self ttv_shouldShowPromptAnimation]) {
        return;
    }
    NSString *guideType = @"first_guide";
    if (!firstTime) {
        guideType = @"repeated_guide";
    }
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"guide_type"] = guideType;
    [TTTracker eventV3:@"landscape_guide_show" params:params];
    
    [self.promptView removeFromSuperview];
    [self p_usedPlayer].blockMonitoring = YES;
    [self.collectionView addSubview:self.promptView];
    
    self.promptView.frame = self.collectionView.bounds;

    self.promptView.alpha = 0.f;
    [self.collectionView bringSubviewToFront:self.promptView];

    if ([self p_usedPlayer].controlsShowing) {
        [[self p_usedPlayer] hidePlayerControlsIfNeeded];
    }
    POPBasicAnimation *alphaStep1Animation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
    alphaStep1Animation.fromValue = @(0);
    alphaStep1Animation.toValue = @(1);
    if (firstTime) {
        alphaStep1Animation.duration = 0.35;
    } else {
        alphaStep1Animation.duration = 0.2;
    }
    @weakify(self);
    [self.promptView prepareAnimate];
    [self.promptView layoutIfNeeded];
    alphaStep1Animation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        @strongify(self);
        if (!finished) {
            [self.promptView removeFromSuperview];
            [self p_usedPlayer].blockMonitoring = NO;
            return;
        }
        if (self.promptView.superview == self.collectionView) {
            [self.collectionView bringSubviewToFront:self.promptView];
        } else {
            [self.promptView removeFromSuperview];
            [self p_usedPlayer].blockMonitoring = NO;
            return;
        }
        self.promptView.alpha = 1;
        if (firstTime) {
            self.collectionView.pagingEnabled = NO;
            [self.collectionView
             tt_promptAnimationWithKeyPath:kPOPViewBounds
             fromValue:[NSValue valueWithCGRect:self.collectionView.bounds]
             toValue:[NSValue valueWithCGRect:(CGRect) {
                .size = self.collectionView.bounds.size,
                .origin.y = self.collectionView.bounds.origin.y + self.promptView.superview.bounds.size.height / 5.f,
                .origin.x = self.collectionView.bounds.origin.x,
            }]];
        } else {
            [self.promptView startAnimateWithDuration:0.6 alphaDuration:0.3 times:3];
        }
    };
    
    POPBasicAnimation *alphaStep2Animation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
    alphaStep2Animation.fromValue = @(1);
    alphaStep2Animation.toValue = @(0);
    
    alphaStep2Animation.duration = firstTime ? 0.35 : 0.2;
    if (firstTime) {
        alphaStep2Animation.beginTime = CACurrentMediaTime() + kUIViewPromptAnimationDuration + 0.5;
    } else {
        alphaStep2Animation.beginTime = CACurrentMediaTime() + 0.9 * 3 + 0.2;
    }
    alphaStep2Animation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
        @strongify(self);
        self.collectionView.pagingEnabled = YES;
        [self.promptView stopAnimate];
        [self.promptView removeFromSuperview];
        [self.playerViewController setPanGestureEnable:YES];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TTImmersePlayerViewControllerHadShownPromptAnimation];
        [self p_usedPlayer].blockMonitoring = NO;
        [self p_usedPlayer].showWaterMark = YES;
    };
    [self p_usedPlayer].showWaterMark = NO;
    [self.promptView pop_addAnimation:alphaStep1Animation forKey:@"alphaStep1Animation"];
    [self.promptView pop_addAnimation:alphaStep2Animation forKey:@"alphaStep2Animation"];
}

- (void)p_removePromptAnimationIfNeed {
    if (self.promptView.superview == self.collectionView ||
        [self.collectionView tt_isPromptAnimating]) {
        [self.promptView pop_removeAllAnimations];
        [self.collectionView tt_removePromptAnimation];
        self.collectionView.pagingEnabled = YES;
        [self.promptView stopAnimate];
        [self.promptView removeFromSuperview];
        [self.playerViewController setPanGestureEnable:YES];
        [self p_usedPlayer].blockMonitoring = NO;
    }
    if (self.anotherPromptView.superview) {
        [self.anotherPromptView dismissAnimated:NO];
    }
}

/**
以下情况不允许展示音量亮度调节引导及新滑动引导:
Settings enable_adjust_from_side开关为NO
当前非全屏状态
正在展示音量亮度调节引导
应用处于后台
正在展示旧滑动引导样式
播放器处于锁定状态
正在输入弹幕
正在展示清晰度选择面板
正在展示播放速率选择面板
正在展示更多面板
正在展示弹幕设置面板
正在展示全屏互动(包括评论列表及键盘)
正在展示前贴广告
正在展示合集选集面板
当前视频播放到倒计时阶段
当前视频停留在结束界面
 */
- (BOOL)p_canShowNewPrompt {
    if (!self.enableAdjustFromSide) return NO;
    if (!self.playerViewController.isFullScreen) return NO;
    if (self.anotherPromptView.isAdjustPromptAnimating) return NO;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return NO;
    if (self.anotherPromptView.isScrollPromptAnimating) return NO;
    if (self.collectionView.tt_isPromptAnimating) return NO;
    if ([self.promptView pop_animationForKey:@"alphaStep1Animation"]) return NO;
    if ([self.promptView pop_animationForKey:@"alphaStep2Animation"]) return NO;
    if (self.playerViewController.isLocked) return NO;
    if (self.playerViewController.danmakuAdapter.danmakuIsFirstResponder) return NO;
    if (self.playerViewController.resolutionPanelShowing) return NO;
    if (self.playerViewController.playbackSpeedPanelShowing) return NO;
    if (self.playerMorePanelShowing) return NO;
    if (self.playerPseriesFloatViewShowing) return NO;
    if ([TTVPlayerFullScreenManager sharedInstance].fullscreenCommentView.isPresented) return NO;
    if (self.needWaitADToFinish) return NO;
    if (self.inCountDownTimes) return NO;
    if (self.playerViewController.viewModel.isPlaybackEnded) return NO;
    return YES;
}

#pragma mark - public
- (void)showAdjustPromptIfNeed {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:TTImmersePlayerViewControllerNewStylePromptKey]) {
        return;
    }
    if (![self p_canShowNewPrompt]) {
        return;
    }

    if (self.volumeChanged) {
        [self.playerViewController sendGestureGuideShowWithType:@"adjust_volume"];
        self.volumeChanged = NO;
    }
    if (self.brightnessChanged) {
        [self.playerViewController sendGestureGuideShowWithType:@"adjust_brightness"];
        self.brightnessChanged = NO;
    }
    
    [self.playerViewController hidePlayerControlsIfNeeded];
    [self.anotherPromptView removeFromSuperview];
    [self.collectionView addSubview:self.anotherPromptView];
    [self.collectionView bringSubviewToFront:self.anotherPromptView];
    self.anotherPromptView.frame = self.collectionView.bounds;
    [self.anotherPromptView startAdjustPromptAnimation];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TTImmersePlayerViewControllerNewStylePromptKey];
    self.volumeChangedWhenNotActive = NO;
    self.brightnessChangedWhenNotActive = NO;
    self.volumeBrightnessChangedInMorePanel = NO;
}

- (void)showScrollPromptIfNeed {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:TTImmersePlayerViewControllerNewStylePromptKey]) {
            return;
        }
    if (![self p_canShowNewPrompt]) {
        return;
    }
    
    [self.playerViewController hidePlayerControlsIfNeeded];
    [self.anotherPromptView removeFromSuperview];
    
    [self.playerViewController sendGestureGuideShowWithType:@"slide_guide"];
    
    self.anotherPromptView.alpha = 0.0f;
    [self.collectionView addSubview:self.anotherPromptView];
    [self.collectionView bringSubviewToFront:self.anotherPromptView];
    self.anotherPromptView.frame = self.collectionView.bounds;
    [self.anotherPromptView startScrollPromptAnimation];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:TTImmersePlayerViewControllerNewStylePromptKey];
}

- (void)attachPlayerFromFullScreenReturned{
    [self p_attachPlayerFromFullscreenInteractive];
}

- (void)adjustCollectionViewOffset:(CGPoint)offset{
    self.needAdjustContentOffset = YES;
    self.offsetToAdjust = offset;
    [self _realAdjustCollectionViewOffset];
}

- (void)_realAdjustCollectionViewOffset{
    if (!self.needAdjustContentOffset) {
        return;
    }
    self.collectionView.contentOffset = self.offsetToAdjust;
    // 奇怪的bug , 全屏互动回来左边会偏移
    [self.collectionView.visibleCells enumerateObjectsUsingBlock:^(__kindof UICollectionViewCell * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.frame.origin.x != 0) {
            obj.left = 0;
        }
    }];
    
    self.needAdjustContentOffset = NO;
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)recordImmerseLinkWithAllStayTime:(NSNumber *)allStayTime currentPlayerModel:(TTImmersePlayerModel *)playerModel {
    if (![playerModel isKindOfClass:TTImmersePlayerModel.class]) {
        playerModel = nil;
    }
    if (playerModel) {
        TTVFeedImmerseTrackStayImmersionLinkListModel *linkListModel = [[TTVFeedImmerseTrackStayImmersionLinkListModel alloc] init];
        linkListModel.ttv_group_id = [playerModel groupId];
        if ([playerModel.orginalModel respondsToSelector:@selector(tt_itemId)]) {
            linkListModel.ttv_item_id = [playerModel.orginalModel tt_itemId];
        }
        if ([playerModel.orginalModel respondsToSelector:@selector(tt_categoryName)]) {
            linkListModel.ttv_category_name = [playerModel.orginalModel tt_categoryName];
        }
        linkListModel.ttv_enter_from = @"click_category";
        linkListModel.ttv_stay_time = @(MIN([self.playerViewController currentWatchDuration], [allStayTime doubleValue]));
        if ([playerModel.orginalModel respondsToSelector:@selector(tt_pigeonNum)]) {
            linkListModel.ttv_pigeon_num = [playerModel.orginalModel tt_pigeonNum];
        }
        if ([playerModel.orginalModel respondsToSelector:@selector(tt_logPb)]) {
            linkListModel.ttv_log_pb = [playerModel.orginalModel tt_logPb];
        }
        [self.context ttv_recordStayImmersionLinkListModel:linkListModel];
    }
}

- (BOOL)setStartImmersePlay:(BOOL)startImmersePlay withCompleteBlock:(void (^)(void))block {
    if (startImmersePlay == self.startImmersePlay) {
        if (block) {
            block();
        }
        return NO;
    }
    
    // 进入或退出横屏沉浸式时，清空数据
    [[TTVADStreamRecordManager shared] reset];
    
    if (startImmersePlay) {
        self.finishCountTapGest.enabled = YES;
        self.finishCountPanGest.enabled = YES;
        if ([self p_usedPlayer].canFillScreenPlay) {
            [self p_usedPlayer].showFillScreenPlay = YES;
        } else {
            [self p_usedPlayer].showFillScreenPlay = NO;
        }
        self.ttv_playFullscreenTime += 1;
    } else {
        self.finishCountTapGest.enabled = NO;
        self.finishCountPanGest.enabled = NO;
        [self p_usedPlayer].zoomIn = NO;
    }
    NSNumber *stayTimeAll = @(floor(([[NSDate date] timeIntervalSince1970] - self.context.ttv_beginTime - self.context.ttv_pauseTime) * 1000));
    TTImmersePlayerModel *playerModel = (id)self.context.currentPlayerModel;
    if (![playerModel isKindOfClass:TTImmersePlayerModel.class]) {
        playerModel = nil;
    }
    self.context.ttv_beginTime = 0;
    self.context.ttv_pauseTime = 0;
    self.privateStartImmersePlay = startImmersePlay;
    self.context.startImmersePlay = startImmersePlay;
    self.viewModel = nil;
    self.context.currentPlayerModel = nil;
    self.context.currentSectionController = nil;
    self.context.willDisplaySectionController = nil;
    self.context.firstPlayerModel = nil;
    TTImmersePlayerRequest *request = nil;
    if (!startImmersePlay) {
        TTImmersePlayerCloseRequest *closeRequest = [[TTImmersePlayerCloseRequest alloc] init];
        closeRequest.willClose = YES;
        request = closeRequest;
        [self.playerViewController.viewModel removeExtraParam:@"drag_direction" forEvent:@"video_play_auto"];
        [self.playerViewController.viewModel removeExtraParam:@"drag_direction" forEvent:@"video_over_auto"];
        [self.playerViewController.viewModel removeExtraParam:@"drag_direction" forEvent:@"video_over_auto_segment"];
    } else {
        TTImmersePlayerBeginRequest *beginRequest = [[TTImmersePlayerBeginRequest alloc] init];
        beginRequest.willBegin = YES;
        request = beginRequest;
    }
    if ([self.interactor respondsToSelector:@selector(doWithRequest:)]) {
        [self.interactor doWithRequest:request];
    }
    if (startImmersePlay) {
        self.context.ttv_beginTime = [[NSDate date] timeIntervalSince1970];
        self.context.ttv_pauseTime = 0;
    }
    if (!startImmersePlay) {
        self.firstObj = nil;
        [self recordImmerseLinkWithAllStayTime:stayTimeAll currentPlayerModel:playerModel];
        self.context.ttv_stayImmersionModel.ttv_stay_time_all = stayTimeAll;
        [self.context ttv_sendStayImmersionTrack];
        [self ttv_exitView];
        [self p_removePromptAnimationIfNeed];
        [self.countdownTip dismissWithAnimate];
        if ([self.interactor respondsToSelector:@selector(resetStatus)]) {
            [self.interactor resetStatus];
        }
    }
    @weakify(self);
    [self.listAdapter performUpdatesAnimated:NO completion:^(BOOL finished) {
        @strongify(self);
        self.startImmersePlay = startImmersePlay;
        if (block) {
            block();
        }
        TTImmersePlayerRequest *request = nil;
        if (!startImmersePlay) {
            TTImmersePlayerCloseRequest *closeRequest = [[TTImmersePlayerCloseRequest alloc] init];
            closeRequest.willClose = NO;
            request = closeRequest;
        } else {
            [self ttv_enterView];
            TTImmersePlayerBeginRequest *beginRequest = [[TTImmersePlayerBeginRequest alloc] init];
            beginRequest.willBegin = NO;
            request = beginRequest;
        }
        if ([self.interactor respondsToSelector:@selector(doWithRequest:)]) {
            [self.interactor doWithRequest:request];
        }
    }];
    
    [self trackImmerseSectionLinkData:startImmersePlay];
    BOOL isAd = NO;
    if ([self.context.currentPlayerModel isKindOfClass:TTImmersePlayerModel.class]) {
        TTImmersePlayerModel *playerModel = (TTImmersePlayerModel *)self.context.currentPlayerModel;
        isAd = (playerModel.orginalModel.tt_adId.longLongValue > 0);
    }
    [self p_usedPlayer].enableSeekPreview = !isAd;
    return YES;
}

- (void)p_handleFrontPasterADViewModel:(TTImmersePlayerFrontPasterADViewModel *)viewModel {
    if ([viewModel.adPlayState unsignedIntegerValue] == TTVFrontPasterADPlayState_Started) {
        self.needWaitADToFinish = YES;
    } else if ([viewModel.adPlayState unsignedIntegerValue] == TTVFrontPasterADPlayState_Finished || [viewModel.adPlayState unsignedIntegerValue] == TTVFrontPasterADPlayState_Stopped) {
        self.needWaitADToFinish = NO;
    }
}

- (void)p_handleCountdownTipViewModel:(TTImmersePlayerCountdownTipViewModel *)viewModel {
    BOOL isAd = NO;
    if ([self.context.currentPlayerModel isKindOfClass:TTImmersePlayerModel.class]) {
        TTImmersePlayerModel *playerModel = (TTImmersePlayerModel *)self.context.currentPlayerModel;
        isAd = (playerModel.orginalModel.tt_adId.longLongValue > 0);
    }
    #define countdownTipTag_DidShow 100
    if ([viewModel.showTip boolValue] && !isAd && ![self p_usedPlayer].looping) {
        if (self.countdownTip.tag != countdownTipTag_DidShow) {
            self.countdownTip.tag = countdownTipTag_DidShow;
            [self.countdownTip showInPlayerVC:[self p_usedPlayer]];
        }
        self.inCountDownTimes = YES;
        [self.countdownTip updateTimeTo:[viewModel.count unsignedIntegerValue]];
    } else {
        self.inCountDownTimes = NO;
        [self.countdownTip dismissWithAnimate];
        self.countdownTip.tag = 0;
    }
}

- (void)p_handleVolumeChangedViewModel:(TTImmersePlayerVolumeChangedViewModel *)viewModel {
    self.volumeChanged = YES;
    if (self.playerMorePanelShowing) {
        self.volumeBrightnessChangedInMorePanel = YES;
    }
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        self.volumeChangedWhenNotActive = YES;
    }
    if (!self.volumeBrightnessChangedInMorePanel && [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showAdjustPromptIfNeed];
        });
    }
}

- (void)p_handleBrightnessChangedViewModel:(TTImmersePlayerBrightnessChangedViewModel *)viewModel {
    self.brightnessChanged = YES;
    if (self.playerMorePanelShowing) {
        self.volumeBrightnessChangedInMorePanel = YES;
    }
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        self.brightnessChangedWhenNotActive = YES;
    }
    
    if (!self.volumeBrightnessChangedInMorePanel && [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showAdjustPromptIfNeed];
        });
    }
}

- (void)p_handleMorePanelShowingViewModel:(TTImmersePlayerMorePanelShowingViewModel *)viewModel {
    self.playerMorePanelShowing = viewModel.morePanelShowing;
    if (!self.playerMorePanelShowing && self.volumeBrightnessChangedInMorePanel) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self showAdjustPromptIfNeed];
        });
    }
}

- (void)p_handlePSeriesFloatViewShowingViewModel:(TTImmersePlayerPSeriesFloatViewShowingViewModel *)viewModel {
    self.playerPseriesFloatViewShowing = viewModel.floatViewShowing;
}

- (NSArray *)p_filtedModels {
    NSArray *array = self.viewModel.models;
    //过滤不能处理的Model
    NSMutableArray *fliterArray = [NSMutableArray arrayWithCapacity:array.count];
    NSMutableSet *set = [NSMutableSet set];
    [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<IGListDiffable> diff = obj;
        id diffId = nil;
        if ([(id)diff respondsToSelector:@selector(diffIdentifier)]) {
            diffId = [diff diffIdentifier];
        }
        if (diffId && ![set containsObject:diffId] && [self p_canConfigModel:obj filterPortait:!self.context.noFilterPortrait]) {
            [fliterArray addObject:obj];
        }
        if (diffId) {
            [set addObject:diffId];
        }
    }];
    return fliterArray;
}

- (void)p_sendPlayerModelStatus {
    NSArray *models = [self p_filtedModels];
    TTImmersePlayerModelStatusRequest *request = [[TTImmersePlayerModelStatusRequest alloc] init];
    request.indexOfCurrentPlayerModel = NSNotFound;
    if (!self.context.currentPlayerModel) {
        request.indexOfCurrentPlayerModel = 0;
    } else {
        [models enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            TTImmerseModel *playerModel = obj;
            if ([playerModel isKindOfClass:[TTImmerseModel class]]) {
                if ([self.context.currentPlayerModel.groupId isEqualToString:playerModel.groupId]) {
                    request.indexOfCurrentPlayerModel = idx;
                    *stop = YES;
                }
            }
        }];
    }
    if (request.indexOfCurrentPlayerModel == NSNotFound) {
        NSAssert(NO, @"不应该找不到对应的PlayerModel");
    }
    request.allFilterPlayerModels = models;
    if ([self.interactor respondsToSelector:@selector(doWithRequest:)]) {
        [self.interactor doWithRequest:request];
    }
}

- (IGListSectionController *)p_showingSectionController {
    if (self.prevIndexPathAtCenter) {
        return [self.listAdapter sectionControllerForSection:self.prevIndexPathAtCenter.section];
    }
    NSArray<IGListSectionController *> *visableSection = [self.listAdapter visibleSectionControllers];
    CGPoint collectionViewCenter = (CGPoint) {
        .x = CGRectGetMidX(self.collectionView.bounds),
        .y = CGRectGetMidY(self.collectionView.bounds),
    };
    for (IGListSectionController *section in [visableSection copy]) {
        UICollectionViewCell *cell = [section.collectionContext cellForItemAtIndex:0 sectionController:section];
        if (CGSizeEqualToSize(cell.size, CGSizeZero)) {
            continue;
        }
        if (CGRectContainsPoint(cell.frame, collectionViewCenter)) {
            return section;
        }
    }
    return nil;
}

- (void)p_updateCurrentSectionController {
    if ([[TTVPlayerFullScreenManager sharedInstance] fullscreenInteractActive]) {
        return;
    }
    IGListSectionController *currentSectionController = [self p_showingSectionController];
    if (self.context.currentSectionController == currentSectionController || !currentSectionController) {
        return;
    }
    if ([self.context.currentSectionController respondsToSelector:@selector(didEndDisplayingSectionController)]) {
        [(id)self.context.currentSectionController didEndDisplayingSectionController];
    }
    
    if ([currentSectionController respondsToSelector:@selector(didDisplaySectionController)]) {
        [self startRecordImmersionLoadQuality];
        
        [(id)currentSectionController didDisplaySectionController];
    }
    self.context.currentSectionController = currentSectionController;
    
    [self.immerseSectionTracker startTrackWithModel:[self.listAdapter objectForSectionController:currentSectionController]];
}

- (void)startRecordImmersionLoadQuality {
    /// willDisplayObject和didEndDisplayingObject代理方法有个问题，在退出全屏时，会调用多次。做个容错判断处理
    if (self.playerViewController.isFullScreen) {
        [[TTQualityStat shareStat] onSceneStart:@"ShortVideo.HorizontalImmersionLoading"];
    }
}

- (void)p_attachPlayerFromFullscreenInteractive{
    IGListSectionController *currentSectionController = [self p_showingSectionController];
    if ([currentSectionController respondsToSelector:@selector(attachPlayer)]) {
        [(id)currentSectionController attachPlayer];
    }
    self.context.currentSectionController = currentSectionController;
}

#pragma mark - PromptPanGestureRecognizer Related Methods
- (void)p_showTouchableArea:(BOOL)touchRight {
    if (self.tt_viewIfLoaded && self.enableAdjustFromSide) {
        UIView *alphaView = [self.view viewWithTag:kAlphaViewTag];
        if (alphaView) {
            return;
        }
        
        CGFloat sideViewWidth = [self.anotherPromptView sideViewWidth];
        
        CGRect frame = CGRectZero;
        frame.size.width = sideViewWidth;
        frame.size.height = self.view.bounds.size.height;
        frame.origin.x = touchRight?(self.view.bounds.size.width-sideViewWidth):0;
        frame.origin.y = 0;
        
        alphaView = [[UIView alloc] initWithFrame:frame];
        alphaView.tag = kAlphaViewTag;
        
        CAGradientLayer *gradientLayer = [[CAGradientLayer alloc] init];
        gradientLayer.frame = (CGRect) {
            .origin.x = 0,
            .origin.y = 0,
            .size = frame.size,
        };
        gradientLayer.colors = @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:0.3].CGColor,
                                 (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor];
        gradientLayer.startPoint = (CGPoint){0, 0.5};
        gradientLayer.endPoint = (CGPoint){1,0.5};
        if (touchRight) {
            gradientLayer.locations = @[@0,@1];
        } else {
            gradientLayer.locations = @[@1, @0];
        }
        
        [alphaView.layer addSublayer:gradientLayer];
        [self.view addSubview:alphaView];
    }
}

- (void)p_removeTouchableArea {
    if (self.tt_viewIfLoaded && self.enableAdjustFromSide) {
        UIView *alphaView = [self.view viewWithTag:kAlphaViewTag];
        if (alphaView) {
            [alphaView removeFromSuperview];
        }
    }
}

- (void)p_handlePromptPanGesture:(UIPanGestureRecognizer *)gestureRecongnizer {
    if (!self.enableAdjustFromSide) {
        return;
    }
   
    BOOL firstTimePan = NO;

    if ([TTMacroManager isInHouse]) {
        if ([SSCommonLogic alwaysShowPrompt] || ![[NSUserDefaults standardUserDefaults] boolForKey: TTImmersePlayerViewControllerNewStylePromptKey]) {
            firstTimePan = YES;
        }
    } else {
        if (![[NSUserDefaults standardUserDefaults] boolForKey: TTImmersePlayerViewControllerNewStylePromptKey]) {
            firstTimePan = YES;
        }
    }
    
    if (!firstTimePan) {
        [self.anotherPromptView dismissAnimated:YES];
    }
    
    UIGestureRecognizerState state = gestureRecongnizer.state;
    CGPoint translation = [gestureRecongnizer translationInView:gestureRecongnizer.view];
    static BOOL touchRight = YES; // pan手势是否在屏幕右半边
    static BOOL swipeGestureChecking = NO; // swipe手势是否正在检测
    CGPoint touchPoint = [gestureRecongnizer locationInView:gestureRecongnizer.view];
    
    switch (state) {
        case UIGestureRecognizerStateBegan:
        {
            if (!firstTimePan) {
                swipeGestureChecking = YES;
                self.panStateChanged = NO;
                touchRight = touchPoint.x > gestureRecongnizer.view.width / 2.0f;
                WeakSelf;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    StrongSelf;
                    swipeGestureChecking = NO;
                    [self ttv_updateStartVolume:self.playerViewController.currentVolume];
                    [self ttv_updateStartBrightness:[TTVBrightnessManager shared].currentBrightness];
                });
            }
        }
            break;
        case UIGestureRecognizerStateChanged:
        {
            if (!firstTimePan && !swipeGestureChecking) {
                [self p_showTouchableArea:touchRight];
                if (touchRight) {
                    [self ttv_changeVolume:translation panStateChanged:self.panStateChanged];
                } else {
                    [self ttv_changeBrightness:translation panStateChanged:self.panStateChanged];
                }
                self.panStateChanged = YES;
            }
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
            if (firstTimePan) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self showScrollPromptIfNeed];
                });
            } else {
                [self p_removeTouchableArea];
                swipeGestureChecking = NO;
            }
        default:
            break;
    }
}

- (void)p_setupGestureIfNeed {
    [self.tt_viewIfLoaded addGestureRecognizer:self.finishCountTapGest];
    [self.tt_viewIfLoaded addGestureRecognizer:self.finishCountPanGest];
    if (self.enableAdjustFromSide) {
        self.promptPanGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
        [self.promptPanGestureRecognizer addTarget:self action:@selector(p_handlePromptPanGesture:)];
        self.promptPanGestureRecognizer.delegate = self;
        [self.tt_viewIfLoaded addGestureRecognizer:self.promptPanGestureRecognizer];
        [self.anotherPromptView addGestureRecognizer:self.promptViewTapGest];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.finishCountTapGest || gestureRecognizer == self.finishCountPanGest || otherGestureRecognizer == self.finishCountTapGest || otherGestureRecognizer == self.finishCountPanGest || gestureRecognizer == self.promptViewTapGest || otherGestureRecognizer == self.promptViewTapGest) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([self p_usedPlayer].isLocked) {
        return NO;
    }
    if (self.promptPanGestureRecognizer == gestureRecognizer) {
        if (!self.privateStartImmersePlay) {
            // 当不处于沉浸式播放状态下(例如竖屏时)不允许调整音量亮度
            return NO;
        }
        if ([self p_usedPlayer].viewModel.isPlaybackEnded) {
            // 当播放完成停留在分享页面上时不允许调整音量亮度
            return NO;
        }
        if ([self p_usedPlayer].resolutionPanelShowing ||
            [self p_usedPlayer].playbackSpeedPanelShowing ||
            self.playerMorePanelShowing ||
            [self p_usedPlayer].danmakuAdapter.danmakuIsFirstResponder ||
            self.playerPseriesFloatViewShowing) {
            return NO;
        }
        if ([TTVPlayerFullScreenManager sharedInstance].fullscreenCommentView.isPresented) {
            // 当正在展示全屏互动时不允许调节音量亮度
            return NO;
        }
        if (gestureRecognizer == self.promptPanGestureRecognizer) {
            CGFloat sideViewWidth = [self.anotherPromptView sideViewWidth];
            CGPoint touchPoint = [self.promptPanGestureRecognizer locationInView:self.promptPanGestureRecognizer.view];
            
            if (touchPoint.y < 30) {
                return NO;
            }
            CGFloat screenWidth = MAX(CGRectGetWidth(self.promptPanGestureRecognizer.view.bounds), CGRectGetHeight(self.promptPanGestureRecognizer.view.bounds));
            if (touchPoint.x > sideViewWidth && touchPoint.x < screenWidth - sideViewWidth) {
                return NO;
            }
            
            CGPoint velocity = [self.promptPanGestureRecognizer velocityInView:self.promptPanGestureRecognizer.view];
            
            BOOL vertical = (fabs(velocity.x) < fabs(velocity.y));
            
            return vertical;
        }
        return NO;
    } else if (self.finishCountPanGest == gestureRecognizer || self.finishCountTapGest == gestureRecognizer) {
        return YES;
    } else if (self.promptViewTapGest == gestureRecognizer) {
        return YES;
    }
    return NO;
}

#pragma mark - TTImmersePlayerDisplayLogic

- (void)displayWithViewModel:(TTImmersePlayerViewModel *)viewModel {
    if (viewModel.models.count > 0) self.viewModel.models = viewModel.models;
    self.context.displayModels = self.viewModel.models;
    if (viewModel.hasMore) self.viewModel.hasMore = viewModel.hasMore;

    if (!self.context.currentPlayerModel && viewModel.models.count > 0) {
        [self.context updateCurrentPlayerModel:viewModel.models.firstObject];
    }

    if (viewModel.models.count > 0 && !self.context.enterSource) {
        self.context.enterSource = @(viewModel.models.firstObject.enterSource);
    }

    if ([viewModel isKindOfClass:[TTImmersePlayerFrontPasterADViewModel class]]) {
        [self p_handleFrontPasterADViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerCountdownTipViewModel class]]) {
        [self p_handleCountdownTipViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerVolumeChangedViewModel class]]) {
        [self p_handleVolumeChangedViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerBrightnessChangedViewModel class]]) {
        [self p_handleBrightnessChangedViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerMorePanelShowingViewModel class]]) {
        [self p_handleMorePanelShowingViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerPSeriesFloatViewShowingViewModel class]]) {
        [self p_handlePSeriesFloatViewShowingViewModel:(id)viewModel];
    }
    
    if ([viewModel isKindOfClass:[TTImmersePlayerReplaceViewModel class]]) {
        NSNumber *stayTimeAll = @(floor(([[NSDate date] timeIntervalSince1970] - self.context.ttv_beginTime - self.context.ttv_pauseTime) * 1000));
        [self recordImmerseLinkWithAllStayTime:stayTimeAll currentPlayerModel:(id)self.context.currentPlayerModel];
    }
    if ([viewModel isKindOfClass:TTImmersePlayerPlaybackViewModel.class]) {
        if ([self.context.currentSectionController conformsToProtocol:@protocol(TTImmersePlayerPlaySectionControllerProtocol)]) {
            TTImmersePlayerPlaybackViewModel *playbackViewModel = (TTImmersePlayerPlaybackViewModel *)viewModel;
            [(IGListSectionController<TTImmersePlayerPlaySectionControllerProtocol> *)self.context.currentSectionController updateTime:playbackViewModel.time duration:playbackViewModel.duration];
        }
    }
    
    //没有传models说明models没有变化，则不更新列表
    if (!viewModel.models) {
        [self.tt_viewIfLoaded setNeedsLayout];
        return;
    }
    
    @weakify(self);
    self.performBatchUpdatesCompleteBlock = ^{
        @strongify(self);
        if ([viewModel isKindOfClass:[TTImmersePlayerReplaceViewModel class]]) {
            [self p_updateCurrentSectionController];
        }
        [self p_handleLoadPrevWithViewModel:viewModel];
    };
    
    [self.listAdapter performUpdatesAnimated:NO completion:^(BOOL finished) {
        @strongify(self);
        //传递能处理的playerModels和目前正在播放的PlayerModel的序号
        [self p_sendPlayerModelStatus];
        if (finished && self.privateStartImmersePlay) {
            if (self.context.firstPlayerModel == nil) {
                self.context.firstPlayerModel = self.viewModel.models.firstObject;
                self.context.ttv_stayImmersionModel.ttv_group_id_first = [self.viewModel.models.firstObject groupId];
                self.context.ttv_stayImmersionModel.ttv_cell_type_first = @"fullscreen";
                self.context.ttv_stayImmersionModel.ttv_category_name_first = [self.viewModel.models.firstObject categoryId];
            }
            TTImmersePlayerPlayNextViewModel *playNextViewModel = (id)viewModel;
            if ([playNextViewModel isKindOfClass:[TTImmersePlayerPlayNextViewModel class]]) {
                
                NSUInteger index = NSNotFound;
                TTImmerseModel *currentModel = self.context.currentPlayerModel;
                NSArray *models = [self.listAdapter.objects copy];
                if (currentModel != nil) {
                    for (NSUInteger i = 0; i < models.count; i ++) {
                        TTImmerseModel *model = models[i];
                        if (![model isKindOfClass:TTImmerseModel.class]) {
                            continue;
                        }
                        if ([model.groupId isEqualToString:currentModel.groupId]) {
                            index = i;
                            break;
                        }
                    }
                }
                
                if (index + 1 >= models.count || index == NSNotFound) {
                    return;
                }

                NSUInteger realNextModelIndex = index + 1;
                
                if (realNextModelIndex >= models.count) {
                    return;
                }

                //兜底：如果两刷没有能播放的视频则设置hasMore=NO
                if (realNextModelIndex < models.count) {
                    self.playNextNeedLoadMore = NO;
                    TTImmerseModel *nextPlayerModel = models[realNextModelIndex];
                    UICollectionViewScrollPosition scrollPositon = UICollectionViewScrollPositionCenteredVertically;
                    //移动到下一个视频之前移除Prompt
                    [self p_removePromptAnimationIfNeed];
                    //设置context的userAction,之后发埋点会用到
                    self.context.userAction = TTImmerseUserActionAutoPlay;
                    self.context.dragDirection = TTImmerseDragDirectionUp;
                    //设置禁止滑动后再允许滑动，解决需要滑到下一个视频时，手正好在滑动collectionView
                    self.collectionView.panGestureRecognizer.enabled = NO;
                    self.collectionView.panGestureRecognizer.enabled = YES;
                    
                    WeakSelf;
                    dispatch_block_t scrollToNextBlock = ^{
                        StrongSelf;
                        [self.listAdapter scrollToObject:nextPlayerModel
                                      supplementaryKinds:nil
                                         scrollDirection:UICollectionViewScrollDirectionVertical
                                          scrollPosition:scrollPositon
                                                animated:YES];
                    };
                    
                    // App在后台时不自动滚动到下个视频，否则在从横屏广告跳出App后自动滚动播放导致异常
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
                        self.pendingScrollToNextBlock = scrollToNextBlock;
                    } else {
                        scrollToNextBlock();
                    }
                } else if (!self.playNextNeedLoadMore) {
                    self.playNextNeedLoadMore = YES;
                    TTImmersePlayerLoadMoreRequest *request = [[TTImmersePlayerLoadMoreRequest alloc] init];
                    request.needPlayNext = YES;
                    if ([self.interactor respondsToSelector:@selector(doWithRequest:)]) {
                        [self.interactor doWithRequest:request];
                    }
                } else {
                    self.viewModel.hasMore = @(NO);
                }
            }
        }
    }];
    
    [self.tt_viewIfLoaded setNeedsLayout];
}

#pragma mark - IGListAdapterDataSource

- (NSArray<id<IGListDiffable>> *)objectsForListAdapter:(IGListAdapter *)listAdapter {
    if (!self.privateStartImmersePlay) {
        return @[];
    }
    return [self p_filtedModels];
}

- (IGListSectionController *)listAdapter:(IGListAdapter *)listAdapter sectionControllerForObject:(id)object {
    __block Class<TTImmersePlayerSectionControllerProtocol> retCls = nil;
    [[[self class] p_buildSectionControllers] enumerateObjectsUsingBlock:^(Class<TTImmersePlayerSectionControllerProtocol>  _Nonnull cls, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([cls respondsToSelector:@selector(canConfigModel:filterPortait:)] && [cls canConfigModel:object filterPortait:!self.context.noFilterPortrait]) {
            retCls = cls;
            *stop = YES;
        }
    }];
    IGListSectionController *ret = [[[retCls class] alloc] init];
    
    if (![ret isKindOfClass:[IGListSectionController class]] ||
        ![ret conformsToProtocol:@protocol(TTImmersePlayerSectionControllerProtocol)]) {
        ret = nil;
    }
    NSAssert(ret != nil, @"过滤数据没过滤干净, 或者没能生成SectionController");
    
    IGListSectionController<TTImmersePlayerSectionControllerProtocol> *immersePlayerSectionController = (id)ret;
    
    if ([immersePlayerSectionController respondsToSelector:@selector(configContext:)]) {
        [immersePlayerSectionController configContext:self.context];
    }
    
    if ([ret conformsToProtocol:@protocol(TTImmersePlayerPlaySectionControllerProtocol)]) {
        id<TTImmersePlayerPlaySectionControllerProtocol> playSectionController = (id)immersePlayerSectionController;
        
        //在传给Section使用之前先监听一些属性
        TTVPlayerAdapterViewController *usedPlayer = [self p_usedPlayer];
        [self p_observePlayerIfNeed:usedPlayer];
        
        if ([playSectionController respondsToSelector:@selector(configPlayer:)]) {
            [playSectionController configPlayer:usedPlayer];
        }
    }
    
    //fallback:理论上不应该发生数据没过滤干净的情况，如果有修改代码出bug真的发生这种问题，这里使用一个空SectionController
    if (!ret) {
        ret = [[TTImmersePlayerEmptySectionController alloc] init];
    }
    return ret;
}

- (UIView *)emptyViewForListAdapter:(IGListAdapter *)listAdapter {
    return nil;
}

#pragma mark - IGListAdapterDelegate

- (void)listAdapter:(IGListAdapter *)listAdapter willDisplayObject:(id)object atIndex:(NSInteger)index {
    if ([self shouldRecordItemImpression:object]) {
        [self ttv_recordObject:object isShowing:YES];
    }
    [self calcScrollDirectionWithIndex:index];
}

- (void)listAdapter:(IGListAdapter *)listAdapter didEndDisplayingObject:(id)object atIndex:(NSInteger)index {
    if ([self shouldRecordItemImpression:object]) {
        [self ttv_recordObject:object isShowing:NO];
    }
}

- (void)calcScrollDirectionWithIndex:(NSInteger)index {
    NSUInteger currentIndex = 0;
    if (self.context.currentSectionController) {
        currentIndex = [self.listAdapter sectionForSectionController:self.context.currentSectionController];
    }
    if (index < currentIndex) {
        self.context.dragDirection = TTImmerseDragDirectionDown;
    } else {
        self.context.dragDirection = TTImmerseDragDirectionUp;
    }
}

/// willDisplayObject和didEndDisplayingObject代理方法有个问题，在退出全屏时，会调用多次，
/// 并且回调过来的object从未在屏幕展现过，导致item_impression埋点多报误报。
/// 所以在这里做个容错判断，过滤掉isFullScreen==NO的异常回调数据。
- (BOOL)shouldRecordItemImpression:(id)object {
    return [object conformsToProtocol:@protocol(IGListDiffable)] &&
           [self.playerViewController isFullScreen];
}

#pragma mark - TTImmersePlayerContextListener

- (void)context:(TTImmerseContext *)context oldValue:(id)oldValue newValue:(id)newValue key:(NSString *)key {
    if ([key isEqualToString:@keypath(self.context, currentPlayerModel)]) {
        if (oldValue != newValue) {
            BOOL needUpdateCollection = NO;
            if ([self.interactor respondsToSelector:@selector(doWithRequest:)] &&
                ([newValue isKindOfClass:[TTImmerseModel class]] || !newValue) &&
                ([oldValue isKindOfClass:[TTImmerseModel class]] || !oldValue)) {

                TTImmersePlayerUpdateModelRequest *request = [[TTImmersePlayerUpdateModelRequest alloc] init];
                request.theOldModel = oldValue;
                request.theNewModel = newValue;
                request.theNewModelIndex = NSNotFound;
                [[self p_filtedModels] enumerateObjectsUsingBlock:^(TTImmerseModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj respondsToSelector:@selector(isEqualToDiffableObject:)]) {
                        if ([[obj groupId] isEqualToString:[(TTImmerseModel *)newValue groupId]]) {
                            request.theNewModelIndex = idx;
                            *stop = YES;
                        }
                    }
                }];
                request.allPlayerModels = [self p_filtedModels];
                [self.interactor doWithRequest:request];
                if (self.listAdapter.objects.count != [self objectsForListAdapter:self.listAdapter].count) {
                    needUpdateCollection = YES;
                }
            }
            if (needUpdateCollection) {
                @weakify(self);
                [self.listAdapter performUpdatesAnimated:NO completion:^(BOOL finished) {
                    @strongify(self);
                    [self p_sendPlayerModelStatus];
                }];
                [self.collectionView layoutIfNeeded];
            } else {
                [self p_sendPlayerModelStatus];
            }
        }
    } else if ([key isEqualToString:@keypath(self.context, enableScroll)]) {
        self.collectionView.scrollEnabled = self.context.enableScroll;
    }
}

#pragma mark - UICollectionViewDelegate
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    self.willDisplayIndexPath = indexPath;
    self.needShowPromptAnimation = NO;
    [self p_showPromptAnimationIfNeedIsFirstTime:YES];
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    
    //去掉回弹的情况
    if ([indexPath compare:self.willDisplayIndexPath] == NSOrderedSame) {
        return;
    }
    [self.countdownTip dismissWithAnimate];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.collectionView.tracking) {
        [self p_removePromptAnimationIfNeed];
    }
    [[self p_usedPlayer] dismissControlsFloatingView];
    if ([self.interactor respondsToSelector:@selector(doWithRequest:)]) {
        TTImmersePlayerDidScrollRequest *request = [[TTImmersePlayerDidScrollRequest alloc] init];
        [self.interactor doWithRequest:request];
    }
    if (self.context.startImmersePlay && self.collectionView.panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        [self ttv_swiped];
        [self ttv_resetCount];
    }
    
//    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(p_updateCurrentSectionController) object:nil];
//    [self performSelector:@selector(p_updateCurrentSectionController) withObject:nil afterDelay:0];
    
    if ([SSCommonLogic isFPSMonitorEnabled]) {
        [self.fpsMonitor monitoredScrollViewDidScroll:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if ([SSCommonLogic preloadVideoEnabled]) {
        [self startPreload];
    }
    [self p_updateCurrentSectionController];
}

- (void)startPreload {
    [TTVPlayerPreloadManager cancelAllPreloadTask];
    NSInteger preloadCount = [TTKitchen getInt:kVideoSettingsVideoImmersePreloadCount];
    NSInteger currentDisplayIndex = self.willDisplayIndexPath.section + 1;
    NSInteger maxIndex = currentDisplayIndex + preloadCount;
    if (maxIndex >= self.listAdapter.objects.count) {
        maxIndex = self.listAdapter.objects.count - 1;
    }
    for (NSInteger i = currentDisplayIndex; i < maxIndex; i++) {
        TTImmersePlayerModel *playerModel = [self.listAdapter.objects btd_objectAtIndex:i class:[TTImmersePlayerModel class]];
        Article *article = playerModel.orginalModel.tt_article;
        if ([article isKindOfClass:[Article class]]) {
            TTVideoEngineModel *videoEngineModel = [TTVideoEngineModel videoModelWithDict:article.videoPlayInfo];
            TTVPlayerPreloadModel *preloadModel = [TTVPlayerPreloadModel new];
            preloadModel.videoEngineModel = videoEngineModel;
            [TTVPlayerPreloadManager addPreloadModel:preloadModel];
        }
    }
    BOOL isLowState = [TTCatowerAdviserManger sharedManager].videoAdviser.videoPreloadStrategy.isLowDevice || ![TTCatowerAdviserManger sharedManager].videoAdviser.videoPreloadStrategy.isGoodNetWork;
    if (![TTKitchen getBOOL:kVideoSettingsVideoPreloadApmOptEnable]) {
        // 开关关闭时，直接启动预加载
        [TTVPlayerPreloadManager startPreload];
    } else{
        // 开关开启，非弱网或低端机选状态
        if (!isLowState) {
            [TTVPlayerPreloadManager startPreload];
        }
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    self.context.userAction = TTImmerseUserActionDrag;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (![self.viewModel.hasMore boolValue]){
        if (CGRectGetMaxY(self.collectionView.bounds) >= self.collectionView.contentSize.height &&
            !self.toastShowing) {
            self.toastShowing = YES;
            [TTIndicatorView showWithIndicatorStyle:TTIndicatorViewStyleImage indicatorText:@"暂无更多视频" indicatorImage:nil autoDismiss:YES dismissHandler:^(BOOL isUserDismiss) {
                self.toastShowing = NO;
            }];
        }
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self p_updateCurrentSectionController];
}

#pragma mark - Section Tracker
- (TTVFeedImmerseSectionTracker *)immerseSectionTracker {
    if (!_immerseSectionTracker) {
        _immerseSectionTracker = [TTVFeedImmerseSectionTracker new];
    }
    return _immerseSectionTracker;
}

- (void)trackImmerseSectionLinkData:(BOOL)startImmersePlay {
    if (startImmersePlay) {
        [self trackImmerseSectionLinkEnter];
    } else {
        [self trackImmerseSectionLinkLeave];
    }
}

- (void)trackImmerseSectionLinkLeave {
    [self.immerseSectionTracker invalid];
    self.immerseSectionTracker = nil;
}

- (void)trackImmerseSectionLinkEnter {
    if (![self.viewModel.models count]) {
        return;
    }
    TTImmersePlayerModel *model = (id)self.viewModel.models.firstObject;
    if (![model isKindOfClass:[TTImmersePlayerModel class]]) {
        return;
    }
    self.immerseSectionTracker.firstCellType = @"fullscreen";
    self.immerseSectionTracker.firstGroupId = model.orginalModel.tt_groupId;
    self.immerseSectionTracker.firstEnterFrom = [XIGTrackerUtil enterFromWithCategoryID:model.orginalModel.tt_categoryName];
    self.immerseSectionTracker.firstCategoryName = model.orginalModel.tt_categoryName;
    [self.immerseSectionTracker startTrackWithModel:model];
}

#pragma mark - TTPlayerGestureControllerPanGestStatusDelegate
- (BOOL)ttv_panGesture:(UIPanGestureRecognizer *)panGesture shouldBeginForDirection:(TTPlayerGestureDirection)direction {
    return TTPlayerGestureDirectionHorizontal&direction;
}

- (TTVideoFPSMonitor *)fpsMonitor {
    if (!_fpsMonitor) {
        _fpsMonitor = [[TTVideoFPSMonitor alloc] init];
        _fpsMonitor.monitorLabel = @"fullscreen_immersion";
    }
    return _fpsMonitor;
}

@end
