//
//  XGVideoDetailPlayer.m
//  Article
//
//  Created by Chen Hong on 2019/5/17.
//

#import "XGVideoDetailPlayer.h"
#import "TTSpecialSellViewController.h"
#import "TTSettingsManager+ImmersePlay.h"
#import "ExploreOrderedData+Biz.h"
#import "TTVADModel.h"
#import "TTVideoAlbumView.h"
#import "TTVPlayerNormalVideoMediator.h"
#import "ExploreDetailManager.h"
#import "TTVideoAutoPlayNextUtil.h"
#import "TTVideoAutoPlayNextManager.h"
#import "TTVideoPlayNextService.h"
#import "TTVWatchedListService.h"
#import "TTVTabbarItemsManager.h"
#import "TTVLPlayerDiversionManager.h"
#import "TTVLPlayerSearchManager.h"
#import "TTVLPlayerSearchModel.h"
#import "XGVideoDetailAction.h"
#import "TTVDanmakuViewModel.h"
#import "TTVAppStoreManager.h"
#import <KVOController/KVOController.h>
#import <ReactiveObjC/ReactiveObjC.h>
#import "XGVideoDetailLog.h"
#import "SSWebViewController.h"
#import "TTMonitor.h"
#import "TTVideoSingletonService.h"
#import "TTVCommonActivityView.h"
#import "TTActionSheetController.h"
#import "TTVADConvertManager.h"
#import "TTVADHalfViewManger.h"
#import "TTVPlayerADExenstionService.h"
#import "TTVPlayerFunctionCardService.h"

// onVideo相关
#import "TTVOnVideoViewModel.h"
#import "TTVOnVideoADViewController.h"

#import <XIGADBusiness/TTURLTracker.h>
#import "SSADEventTracker.h"

#import "TTVideoDetailADPlayerLogHelper.h"
#import "TTImmersePlayerADVideoSectionCollectionViewCell.h"
#import "TTVideoTabViewController.h"
#import "TTNavigationController.h"
#import <TTVideoService/VideoApi.pbobjc.h>
#import "TTVXGPlayBubbleManager.h"
#import "TTVPlayerFullScreenManager.h"
#import "TTVFeedImmerseContextFinishCount.h"
#import "TTDetailResponderProtocol.h"
#import "UIFont+TTFont.h"
#import "TTDetailSeriseImmerseStream.h"
#import "TTVImmerseStoreMiddleware.h"
#import "TTImmerseStreamToOrderedDataMiddleware.h"
#import "TTDetailSeriesImmerseFilterMiddleware.h"
#import "TTVImmerseStreamPSeriesDataSortMiddleware.h"

#import "TTVPSeriesHelper.h"
#import "TTVSettingsConfiguration.h"
#import "NewsDetailConstant.h"
#import "TTVSeriesPlayerWrapper.h"
#import "XGVideoDetailPlayerInterface.h"
#import "TTVQualityManager.h"
#import "TTVPasterFlowServiceTrack.h"
#import "TTVDanmakuMediator.h"
#import "TTVVideoCacheMediator.h"
#import "TTVSeriesViewModel+Tracker.h"
#import <ByteDanceKit/NSDictionary+BTDAdditions.h>
#import <ByteDanceKit/NSURL+BTDAdditions.h>
#import <TTQualityStat/TTQualityStat.h>
#import <XIGBizPlayer/XIGBizPlayerConst.h>

#import "TTVLoopingPlayManager.h"

#define kAdDetailButtonGap 6

extern CGFloat kMinHeightForMovieContainerView;
extern NSNotificationName const kShowPreviewImageViewController;
extern NSNotificationName const kDismissPreviewImageViewController;

static void *kEnableFullScreenSave;

@interface XGVideoDetailPlayer () <
// 特卖
TTSpecialSellViewControllerDelegate,
// 后贴
TTVPasterADDelegate,
// OnVideo广告
 TTVOnVideoADViewControllerDelegate,
// 前贴广告
TTVFrontPasterADViewControllerDelegate,
// 沉浸式播放
TTImmersePlayerInteracterDelegate,
// 全屏互动
TTPlayerFullScreenMoreMenuViewDelegate,
// 全屏互动
TTPlayerFullScreenMoreMenuViewDataSource,
// 播放
TTVPlayerAdapterDelegate,
// 多重手势代理
TTPlayerGestureControllerPanGestStatusDelegate
>
// 特卖商品
@property (nonatomic, strong) TTSpecialSellViewController *specialSellVC;

@property (nonatomic, strong) TTVFeedImmerseContextFinishCount *immerseFinishCount;

@property (nonatomic, weak) TTVLPlayerDiversionManager *diversionManager;

@property (nonatomic, strong) UILabel *pasterADGuideLabel;

@property (nonatomic, strong) TTAlphaThemedButton *adButton;

@property (nonatomic, copy) NSString *landingURL;

@property (nonatomic, strong) TTVOnVideoADViewController *onVideoADVC;

@property (nonatomic, assign) BOOL moviePausedByOpenAppStore;

// 全屏互动需求
@property (nonatomic, assign) BOOL fullScreenIfNeed;

@property (nonatomic, weak) TTVXGPlayBubbleManager *xgPlayBubbleManager;

//全屏选集浮窗
@property (nonatomic, strong) UIButton *playerSeriesFloatMaskView;

@property (nonatomic, strong) TTDetailSeriseImmerseStream *immerseStream;
@property (nonatomic, strong) TTVImmerseStoreMiddleware *storeMiddleware;
@property (nonatomic, strong) TTImmerseStreamToOrderedDataMiddleware *toOrderedDataMiddleware;
@property (nonatomic, strong) TTDetailSeriesImmerseFilterMiddleware *filterMiddleware;
@property (nonatomic, strong) TTVImmerseStreamPSeriesDataSortMiddleware *sortMiddleware;

@property (nonatomic, weak) XGVideoDetailPlayerInterface *seriesPlayerInterface;

@property (nonatomic, assign) BOOL playModelChangeByTapSeries;

@property (nonatomic, assign) BOOL playModelChangeByImmerse;

@property (nonatomic, strong) RACDisposable *readyToDisplayDisposable;

@end

@implementation XGVideoDetailPlayer

- (void)dealloc {
    [self.playerViewController removeGestureDelegate:self];
}

- (instancetype)initWithDetailStore:(TTVReduxStore *)detailStore playerViewController:(TTVPlayerAdapterViewController *)playerVC {
    self = [super initWithDetailStore:detailStore];
    if (self) {
        _immerseFinishCount = [[TTVFeedImmerseContextFinishCount alloc] init];
        if (!playerVC) {
            [self createPlayerVC];
        } else {
            self.playerViewController = playerVC;
        }
        [self.playerViewController addGestureDelegate:self];
        [self _initNotification];
    }
    return self;
}

- (void)_initNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showPreviewImageView:) name:kShowPreviewImageViewController object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissPreviewImageView:) name:kDismissPreviewImageViewController object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skStoreViewDidAppear:) name:SKStoreProductViewDidAppearKey object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skStoreViewDidDisappear:) name:SKStoreProductViewDidDisappearKey object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerViewControllerPlaybackStateDidChanged:) name:kTTPlayerViewControllerPlaybackStateDidChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(panelDidShow:) name:kTTVCellBehaviorDidShowPanelNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(panelWillDismiss:) name:kTTVCellBehaviorWillDismissPanelNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(panelDidShow:) name:kTTActionSheetDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(panelWillDismiss:) name:kTTActionSheetWillDismissNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivePlayerLeaveNotification:) name:kVideoPlayerLeaveNotification object:nil];
}

- (void)setPlayerConfig:(TTVPlayerAdapterViewController *)player{
    BOOL enableFullScreenAB = self.orderedData.adID.longLongValue == 0 && !player.supportsPortaitFullScreen;
    [player enableFullScreenAB:enableFullScreenAB];
    player.showControlsTitle = NO;
    player.showsTitleShadow = YES;
    [player enableNetworkMonitor];
    [player ss_beginSpecialSellMonitorWithArticle:self.orderedData.article specialTrackParameters:[self specialTrackParameters]];
    @weakify(self);
    [player ss_setSpecialSellEntranceViewClick:^{
        @strongify(self);
        [self displayAllSpecialSellItems];
    }];
}

- (void)createPlayerVC {
    ExploreOrderedData *orderedData = self.state.detailModel.orderedData;
    [[TTSettingsManager sharedManager] tt_rereadImmerseSettings];
    BOOL enableImmerse = [TTSettingsManager sharedManager].tt_enableImmerse;
    if ([orderedData.adID unsignedLongLongValue] > 0) {
        enableImmerse = NO;
    }
    
    @weakify(self);
    self.playerViewController = [TTVPlayerAdapter createPlayerWithArticle:orderedData.article immerseEnable:enableImmerse isReadyToUse:^(TTVPlayerAdapterViewController *player, TTVPlayerWhenIsReadyToUse when) {
        @strongify(self);
        switch (when) {
            case TTVPlayerWhenIsReadyToUse_ViewDidLoad:
            {
                [self setPlayerConfig:player];
            }
                break;
                
            default:
                break;
        }
    }];
    BOOL isAD = self.detailModel.adID.longLongValue != 0;
    self.playerViewController.enableSeekPreview = !isAD;
    self.playerViewController.delegate = self;
    [self.playerViewController addPlayerAdapterDelegate:self];
    self.playerViewController.videoInfo = [TTVideoEngineModel videoModelWithDict:orderedData.article.videoPlayInfo].videoInfo;
    [self.playerViewController enableTracker:YES];
    [[TTVPlayerADExenstionService sharedInstance] addADExtensionForPlayer:self.playerViewController article:orderedData.article];
    [[TTVPlayerFunctionCardService sharedInstance] addFunctionCardForPlayer:self.playerViewController article:orderedData.article];
}

- (void)rebuildPlayerVC {
    [self createPlayerVC];
}

- (void)addDanmaku {
    [self.playerViewController addDanmakuWithDanmakuInfo:[TTVDanmakuMediator danmakuInfoWithArticle:self.orderedData.article] position:TTVDanmakuViewPositionDetail];
    if (!self.playerViewController.isFullScreen) {
        if (self.viewController.explore) {
            return;
        }
        [self.playerViewController.danmakuAdapter removeDanmakuButtons];
    }
}

- (void)updateDanmaku {
    [self.playerViewController.danmakuAdapter updateWithDanmakuInfo:[TTVDanmakuMediator danmakuInfoWithArticle:self.orderedData.article]];
}

- (void)displayAllSpecialSellItems
{
    if (self.specialSellVC && self.specialSellVC.view.superview) {
        return;
    }
    TTSpecialSellViewController *vc = [[TTSpecialSellViewController alloc] init];
    vc.specialTrackParameters = [self specialTrackParameters];
    vc.playerViewController = self.playerViewController;
    vc.article = self.orderedData.article;
    vc.delegate = self;
    vc.source = TTPlayerViewModelSourceDetail;
    vc.contentSize = self.movieShotViewSize;
    
    [self.playerViewController.rotateViewController addChildViewController:vc];
    [self.playerViewController.rotateViewController.view addSubview:vc.view];
    self.specialSellVC = vc;
    
    [vc.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(vc.view.superview);
    }];
    
    vc.view.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{
        vc.view.alpha = 1.0;
    }];
}

- (void)setViewController:(UIViewController<XGVideoDetailVCProtocol> *)viewController{
    _viewController = viewController;
}

- (NSString *)adIdString{
    NSNumber *ad_id = self.state.detailModel.article.relatedVideoExtraInfo[kArticleInfoRelatedVideoAdIDKey];
    NSString *aID = [ad_id longLongValue] > 0 ? [NSString stringWithFormat:@"%@", ad_id] : [self.detailModel.adID stringValue];
    return aID;
}

- (void)updatePlayerEngine
{
    Article *article = self.state.detailModel.article;
    ExploreOrderedData *orderedData = [[self.state.detailModel sharedDetailManager] currentOrderedData];
    TTPlayerViewModel *playerModel = self.playerViewController.viewModel;
    [self.playerViewController.viewModel addExtra:self.detailModel.extraTrackerLogParamas ?: @{} forEvents:@[@"video_play", @"video_over", @"video_play_auto", @"video_over_auto", @"video_over_segment", @"video_over_auto_segment"]];
    playerModel.source = TTPlayerViewModelSourceDetail;
    playerModel.direction = TTPlayerGestureDirectionHorizontal;
    playerModel.gModel = article.groupModel;
    playerModel.logExtra = orderedData.logExtra;
    playerModel.gdLabel = self.state.detailModel.gdLabel;
    if (isEmptyString(playerModel.gdLabel) && self.state.isAutoPlaying) {
        playerModel.gdLabel = @"click_related";
    }
    if ([TTVideoAlbumHolder holder].albumView) {
        playerModel.gdLabel = @"click_subv_hashtag";
    }

    NSString *aID = [self adIdString];
    NSArray *playUrls = nil;
    NSArray *playOverUrls = nil;
    NSArray *effectivePlayUrls = nil;
    if (!isEmptyString(aID)) {
        playUrls = self.orderedData.adModel.playTrackUrlList;
        playOverUrls = self.orderedData.adModel.playoverTrackUrlList;
        effectivePlayUrls = self.orderedData.adModel.effectivePlayTrackUrlList;
        self.playerViewController.effectivePlayDuration = self.orderedData.adModel.effectivePlayTime > 0 ? self.orderedData.adModel.effectivePlayTime : 10;
    }
    if (self.detailModel.article.isHotPush) {
        aID = [self.detailModel.article.hotPushModel.hotPushID stringValue];
        playerModel.logExtra = self.detailModel.article.hotPushModel.logExtra;
        playUrls = self.detailModel.article.hotPushModel.playTrackUrlList;
        playOverUrls = self.detailModel.article.hotPushModel.playoverTrackUrlList;
        effectivePlayUrls = self.detailModel.article.hotPushModel.effectivePlayTrackUrlList;
        self.playerViewController.effectivePlayDuration = self.detailModel.article.hotPushModel.effectivePlayTime>0?self.detailModel.article.hotPushModel.effectivePlayTime:10;
    }
    
    playerModel.aID = aID;
    playerModel.cID = [[self.state.detailModel sharedDetailManager] currentCategoryId];
    playerModel.playTrackUrlList = playUrls;
    playerModel.playoverTrackUrlList = playOverUrls;
    playerModel.effectivePlayTrackUrlList = effectivePlayUrls;
    playerModel.seriesDetailModel.isPlayingPSeriesGroup = self.state.detailModel.seriesDetailModel.isPlayingPSeriesGroup;
    playerModel.seriesDetailModel.parentAlbumId = self.state.detailModel.seriesDetailModel.parentAlbumId;
    playerModel.seriesDetailModel.enterFromPSeriesGroup = self.state.detailModel.seriesDetailModel.enterFromPSeriesGroup;
    if (self.state.detailModel.seriesDetailModel.enterFromPSeriesGroup) {
        playerModel.seriesDetailModel.parentGroupId = self.state.detailModel.seriesDetailModel.parentAlbumId;
    }
    
    if (!playerModel.logExtra) {
        playerModel.logExtra = [self.state.detailModel.article relatedLogExtra];
    }
    [self.playerViewController setAuthToken:self.orderedData.article.playAuthToken businessToken:self.orderedData.article.playBizToken];
    TTVideoEngineModel *videoEngineModel = [TTVideoEngineModel videoModelWithDict:article.videoPlayInfo];
    if (self.orderedData.adModel.isExternalVideo && !isEmptyString(self.orderedData.adModel.externalVideoUrl)) {
        [self.playerViewController setDirectPlayURL:self.orderedData.adModel.externalVideoUrl];
    } else if (videoEngineModel) {
        if (![self.playerViewController.videoEngineModel.videoInfo.videoID isEqualToString:videoEngineModel.videoInfo.videoID ?: @""]) {
            self.playerViewController.videoEngineModel = videoEngineModel;
        }
    } else {
        if (![self.playerViewController.videoID isEqualToString:article.videoID ?: @""]) {
            self.playerViewController.videoID = article.videoID;
        }
    }
    
    self.playerViewController.viewModel.isAutoPlaying = self.state.isAutoPlaying;
    self.playerViewController.viewModel.isFrom3DTouch = self.state.isFrom3DTouch;
    self.playerViewController.viewModel.touchSourceType = self.state.touchSourceType;
    self.playerViewController.viewModel.enterFromLabel = self.state.detailModel.enterFrom;
    self.playerViewController.viewModel.categoryID = self.state.detailModel.categoryID;
    [self updateSceneSourceType];
    if (self.state.detailModel.logpbDic) {
        self.playerViewController.viewModel.logPassbackDict = self.state.detailModel.logpbDic;
    }
    self.playerViewController.viewModel.authorID = [self.state.detailModel.article.userInfo btd_stringValueForKey:@"user_id"];
    self.playerViewController.viewModel.followingAuthor = [self.orderedData.article.userInfo btd_boolValueForKey:@"follow"];
    self.playerViewController.waterMarkInfo = article.videoLogoInfo;
    [self.playerViewController configureEmotionalProgressWithArticle:article];
    {
        // tracker
        NSMutableDictionary *tracker = [NSMutableDictionary dictionary];
        tracker[@"group_id"] = @(article.uniqueID);
        tracker[@"category_name"] = self.orderedData.categoryID;
        tracker[@"enter_from"] = self.detailModel.enterFrom;
        tracker[@"log_pb"] = self.detailModel.logpbDic;
        [self.playerViewController setTrackInfo:tracker];
        [[TTVPlayerFullScreenManager sharedInstance] setTrackerInfo:tracker];
    }
}

- (void)updateWithParentVC:(UIViewController *)parentVC
{
    //1.下拉返回时playerViewController为nil，
    if (self.playerViewController == nil) {
        return;
    }
    Article *article = self.state.detailModel.article;
    NSString *aID = [self adIdString];
    [self.playerViewController shareButtonEnable:isEmptyString(aID)];
    [self.playerViewController moreButtonHidden:![self showPlayerMoreBtn]];
    
    BOOL filterPortait = [self immersePlayerFilterPortait:self.playerViewController.immersePlayerInteracter];
    BOOL supportPortaitFullScreen = [self.orderedData.article supportPortaitFullscreen] && self.orderedData.article.videoProportion <= 1;
    if (supportPortaitFullScreen && filterPortait) {
        self.playerViewController.immerseEnable = NO;
    }
    
    
    if (parentVC && self.playerViewController.parentViewController != parentVC && !self.playerViewController.isFullScreen) {
        [self.playerViewController willMoveToParentViewController:parentVC];
        [parentVC addChildViewController:self.playerViewController];
        [self.playerViewController didMoveToParentViewController:parentVC];
    }
    
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        self.playerViewController.supportsPortaitFullScreen = NO;
    } else {
        BOOL supportPortaitFullScreen = [self.orderedData.article supportPortaitFullscreen] && self.orderedData.article.videoProportion <= 1;
        self.playerViewController.supportsPortaitFullScreen = supportPortaitFullScreen;
    }

    if ([self.orderedData.article.articleExtra valueForKey:@"hash_tag"]) {
        NSDictionary *hashTag = [self.orderedData.article.articleExtra valueForKey:@"hash_tag"];
        NSString *name = [hashTag valueForKey:@"name"];
        if (!isEmptyString(name)) {
            [self.playerViewController addExtraValue:name forKey:@"hashtag"];
        }
        
        NSNumber *tagType = [hashTag valueForKey:@"tag_type"];
        NSString *hashTagString = nil;
        switch (tagType.integerValue) {
            case HashTagTypeHashtag:
                hashTagString = @"hashtag";
                break;
            case HashTagTypeAlbum:
                hashTagString = @"album";
                break;
            case HashTagTypeSubject:
                hashTagString = @"subject";
                break;
            default:
                break;
        }
        
        if (!isEmptyString(hashTagString)) {
            [self.playerViewController addExtraValue:hashTagString forKey:@"hashtag_type"];
        }
    }
    if (!isEmptyString(article.title)) {
        if ([TTVPSeriesHelper shouldShowPSeriesStyleWithArticle:article]) {
            [self.playerViewController setPlayerAttributedTitle:[TTVPSeriesTagVideoTitleProducer getPSeriesTagVideoTitleWithOriginalTitle:article.title]];
        } else {
            [self.playerViewController setPlayerTitle:article.title];
        }
    }
    
    if (self.orderedData.adID.longLongValue){
        [self.playerViewController setAuthorInfo:[self p_adAvatarInfo]];
        WeakSelf;
        [self.playerViewController setDidClickAdAvatarButton:^{
            StrongSelf;
            [self p_clickedAdAvatarAction];
        }];
    } else {
        NSMutableDictionary *userExtraInfo = [NSMutableDictionary dictionaryWithDictionary:article.userInfo];
        
        userExtraInfo[@"mediaID"] = [article.mediaInfo btd_stringValueForKey:@"media_id"];
        userExtraInfo[@"itemID"] = article.itemID;
        [self.playerViewController setAuthorInfo:userExtraInfo];
    }
    [self.playerViewController addBottomInteractiveLikeView:[[TTVPlayerFullScreenManager sharedInstance] generateBottomLikeBtn:article] commentView:[[TTVPlayerFullScreenManager sharedInstance] generateBottomCommentBtn:article playerViewController:self.playerViewController]];
    {
        // tracker
        NSMutableDictionary *tracker = [NSMutableDictionary dictionary];
        tracker[@"group_id"] = @(article.uniqueID);
        tracker[@"category_name"] = self.orderedData.categoryID;
        tracker[@"enter_from"] = self.detailModel.enterFrom;
        tracker[@"log_pb"] = self.detailModel.logpbDic;
        [self.playerViewController setTrackInfo:tracker];
        [[TTVPlayerFullScreenManager sharedInstance] setTrackerInfo:tracker];
    }

    TTVideoEngineModel *videoEngineModel = [TTVideoEngineModel videoModelWithDict:article.videoPlayInfo];
    if (videoEngineModel) {
        if (![self.playerViewController.videoEngineModel.videoInfo.videoID isEqualToString:videoEngineModel.videoInfo.videoID ?: @""]) {
            self.playerViewController.videoEngineModel = videoEngineModel;
        }
    } else {
        if (![self.playerViewController.videoID isEqualToString:article.videoID ?: @""]) {
            self.playerViewController.videoID = article.videoID;
        }
    }
    
    self.playerViewController.viewModel.isAutoPlaying = self.state.isAutoPlaying;
    self.playerViewController.viewModel.isFrom3DTouch = self.state.isFrom3DTouch;
    self.playerViewController.viewModel.touchSourceType = self.state.touchSourceType;
    self.playerViewController.viewModel.enterFromLabel = self.state.detailModel.enterFrom;
    self.playerViewController.viewModel.categoryID = self.state.detailModel.categoryID;
    [self updateSceneSourceType];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *listName = [self.detailModel.extraTrackerLogParamas btd_stringValueForKey:@"list_name"];
    params[@"list_name"] = listName;
    [self.playerViewController.viewModel addExtra:params forEvent:@"video_over"];
    [self.playerViewController.viewModel addExtra:params forEvent:@"video_play"];
    
    NSMutableDictionary *commonExtra = [NSMutableDictionary dictionaryWithDictionary:self.playerViewController.viewModel.commonExtraTrackers ?: @{}];
    [commonExtra addEntriesFromDictionary:self.state.detailModel.extraTrackerLogParamas];
    self.playerViewController.viewModel.commonExtraTrackers = commonExtra;
    
    if (self.state.detailModel.logpbDic) {
        self.playerViewController.viewModel.logPassbackDict = self.state.detailModel.logpbDic;
    }
    self.playerViewController.viewModel.authorID = [self.state.detailModel.article.userInfo btd_stringValueForKey:@"user_id"];
    self.playerViewController.viewModel.followingAuthor = [self.orderedData.article.userInfo btd_boolValueForKey:@"follow"];
    
    if (!self.state.isAutoPlaying) {
        [[TTVideoAutoPlayNextManager sharedManager] resetAutoPlayCount];
    }

    [self.playerViewController ss_beginSpecialSellMonitorWithArticle:self.state.detailModel.orderedData.article specialTrackParameters:[self specialTrackParameters]];
    WeakSelf;
    [self.playerViewController ss_setSpecialSellEntranceViewClick:^{
        StrongSelf;
        [self.detailStore dispatch:[XGVideoDetailAction displaySpecialSellItemsAction:YES]];
    }];
    ExploreOrderedData *orderedData = [[self.state.detailModel sharedDetailManager] currentOrderedData];
    [[TTVPlayerADExenstionService sharedInstance] addADExtensionForPlayer:self.playerViewController article:orderedData.article];
    [[TTVPlayerFunctionCardService sharedInstance] addFunctionCardForPlayer:self.playerViewController article:orderedData.article];
    
    [self.playerViewController.danmakuAdapter updateWithDanmakuInfo:[TTVDanmakuMediator danmakuInfoWithArticle:self.orderedData.article]];
    
    // 将视频加入观看历史列表
    [TTVWatchedListService addToWatchHistoryListWithGroupID:[@(self.article.uniqueID) stringValue] ?: self.article.groupModel.groupID itemID:self.article.itemID seriesID:nil contentType:1 duration:[self.orderedData.article.historyDuration doubleValue] / 1000.0 authorID:[self.article.userInfo btd_stringValueForKey:@"user_id"] completion:nil];
    BOOL hasSeries = [self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries];
    if (hasSeries) {
        //合集再发一次
        [TTVWatchedListService addToWatchHistoryListWithGroupID:[@(self.article.uniqueID) stringValue] ?: self.article.groupModel.groupID itemID:self.article.itemID seriesID:self.seriesViewModel.pseriesId contentType:8 duration:[self.orderedData.article.historyDuration doubleValue] / 1000.0 authorID:[self.article.userInfo btd_stringValueForKey:@"user_id"] completion:nil];
    }
    
    ///*begin - 播放器长视频导流
    if ([TTVTabbarItemsManager hasTabBarWith:TTVTabbarItems_LongVideo] &&
        article.commoditys.count == 0 &&
        !isEmptyString(self.orderedData.article.relatedLongVideoData.openUrl) &&
        [self.orderedData.article.relatedLongVideoData isShowWithSectionControl:TTVLSectionControlBubble]) {
        self.diversionManager = [TTVLPlayerDiversionManager startWithPlayerController:self.playerViewController relatedLongVideoData:self.orderedData.article.relatedLongVideoData];
        self.diversionManager.inDetail = YES;
    } else {
        [TTVLPlayerDiversionManager endWithPlayerController:self.playerViewController];
    } ///*end - 播放器长视频导流
    if (article.commoditys.count == 0 && isEmptyString([self.orderedData.article.relatedLongVideoInfo btd_stringValueForKey:@"action_url"]) && !isEmptyString([self.orderedData.article.relatedSearchInfo btd_stringValueForKey:@"open_url"])) {
        TTVLPlayerSearchModel *model = [[TTVLPlayerSearchModel alloc]init];
        model.searchText = self.orderedData.article.relatedSearchInfo[@"content"];
        model.searchURL = self.orderedData.article.relatedSearchInfo[@"open_url"];
        model.searchQuery = self.orderedData.article.relatedSearchInfo[@"query"];
        [TTVLPlayerSearchManager startWithPlayerController:self.playerViewController playerSearchModel:model];
    } else {
        [TTVLPlayerSearchManager endWithPlayerController:self.playerViewController];
    }
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        [self wrapSeries];
    } else {
        [self unwrapSeries];
    }
}

- (void)attachPlayer:(UIView *)containerView parentVC:(UIViewController *)parentVC
{
    if (!self.playerViewController) return;
    {
        [self.playerViewController willMoveToParentViewController:parentVC];
        [parentVC addChildViewController:self.playerViewController];
        [containerView addSubview:self.playerViewController.view];
        [self.playerViewController didMoveToParentViewController:parentVC];
    }
    if (!self.playerViewController.isFullScreen) {
        self.playerViewController.view.frame = containerView.bounds;
        [containerView addSubview:self.playerViewController.view];
    } else {
        [self.playerViewController updatePlayerSuperView:containerView originalPlayerFrame:containerView.bounds inViewController:containerView.viewController];
    }
    WeakSelf;
    [self.playerViewController ss_setSpecialSellEntranceViewClick:^{
        StrongSelf;
        [self.detailStore dispatch:[XGVideoDetailAction displaySpecialSellItemsAction:YES]];
    }];
    self.playerViewController.muted = NO;

    //设置弹幕vc的位置到detail
    self.playerViewController.danmakuAdapter.danmakuViewPosition = TTVDanmakuViewPositionDetail;

    UIViewController *pasterAD = self.playerViewController.pasterADViewController;
    if (pasterAD) {
        self.pasterADViewController = (TTVPasterADViewController *)pasterAD;
        self.pasterADViewController.delegate = self;
        self.pasterADViewController.isInDetail = YES;
        self.pasterADViewController.pasterAdRequestInfo.adFrom = @"textlink";
        self.pasterADViewController.pasterAdRequestInfo.groupID = self.state.detailModel.article.groupModel.groupID;
        self.pasterADViewController.pasterAdRequestInfo.itemID = self.state.detailModel.article.groupModel.itemID;
        self.pasterADViewController.pasterAdRequestInfo.category = self.state.detailModel.categoryID;
        self.pasterADViewController.pasterAdRequestInfo.adExp = self.state.detailModel.article.adExp;
    }

    // 更新前贴
    if (self.playerViewController.frontPaster) {
        self.frontPasterADVC = self.playerViewController.frontPaster;
        
        // 如果前贴获取数据失败，则移除前贴
        if (self.frontPasterADVC.failToFetchADModel) {
            [self removeFrontPasterAD];
            if ([self.delegate respondsToSelector:@selector(xgvd_resumePlayAfterFrontPasterPlayOver)]) {
                [self.delegate xgvd_resumePlayAfterFrontPasterPlayOver];
            }
        } else {
            self.frontPasterADVC.delegate = self;
            self.frontPasterADVC.isInDetail = YES;
            [self.frontPasterADVC setMute:NO];
            [self.frontPasterADVC resume];
            
            WeakSelf;
            [RACObserve(self.playerViewController.fullScreenObserverState, fullScreenObserver) subscribeNext:^(NSNumber *fullScreen) {
                StrongSelf;
                [self.frontPasterADVC setFullScreen:[fullScreen boolValue] animated:YES];
            }];
            
        }
    }
    [self.readyToDisplayDisposable dispose];
    self.readyToDisplayDisposable = [RACObserve(self.playerViewController, readyForDisplay) subscribeNext:^(NSNumber *readyForDisplay) {
        StrongSelf;
        if ([readyForDisplay boolValue]) {
            [self.playerViewController disablePlayerControls:NO];
        }
        if ([readyForDisplay boolValue] && self.frontPasterADVC && !self.frontPasterADVC.failToFetchADModel) {
            [self.playerViewController pause];
        }
    }];

    if (self.adButton) {
        [self.playerViewController.rotateViewController.view addSubview:self.adButton];
    }
    // 如果从feed中进入，manager为空时尝试初始化一个manager
    if (!self.diversionManager) {
        if ([TTVTabbarItemsManager hasTabBarWith:TTVTabbarItems_LongVideo] &&
            self.orderedData.article.commoditys.count == 0 &&
            !isEmptyString(self.orderedData.article.relatedLongVideoData.openUrl) &&
            [self.orderedData.article.relatedLongVideoData isShowWithSectionControl:TTVLSectionControlBubble]) {
            self.diversionManager = [TTVLPlayerDiversionManager startWithPlayerController:self.playerViewController relatedLongVideoData:self.orderedData.article.relatedLongVideoData];
            self.diversionManager.inDetail = YES;
        } else {
            [TTVLPlayerDiversionManager endWithPlayerController:self.playerViewController];
        }
    }
}

- (void)detachPlayer
{
    if (!self.playerViewController) return;
    [self.playerViewController willMoveToParentViewController:nil];
    [self.playerViewController.view removeFromSuperview];
    [self.playerViewController removeFromParentViewController];

    if (self.adButton) {
        [self.adButton removeFromSuperview];
    }
    [self unwrapSeries];
}

- (BOOL)showShortToLongPlayerEnd:(TTVLRelatedArticleData *)longData
{
    BOOL isShow = [longData isShowWithSectionControl:TTVLSectionControlPlayFinish];
    BOOL shouldShowLongVideoDiversion = isShow && ([[SSAppPageManager sharedManager] canOpenURL:[NSURL btd_URLWithString:longData.openUrl]] || !isEmptyString(longData.webUrl));
    return shouldShowLongVideoDiversion;
}

#pragma mark - TTPlayerViewController delegate
- (void)playerEngineReadyToPlay:(TTVPlayerAdapterViewController *)player {
    NSMutableDictionary *extraDic = [NSMutableDictionary dictionary];
    extraDic[@"category_id"] = self.categoryName;
    extraDic[@"group_id"] = self.detailModel.article.groupModel.groupID;
//    [TTVQualityManager finishLoadWithScene:TTVShortVideoDetailVideoLoad error:nil description:extraDic];
    [[TTQualityStat shareStat] onSceneFinish:TTVShortVideoDetailVideoLoad description:[[TTQualityDescription alloc] initWithExtra:extraDic]];
}

- (BOOL)playerViewControllerShouldPlay {
    if (self.state.willShowing) {
        return YES;
    }
    //self.movieAutoPaused = YES;
    [self.detailStore dispatch:[TTVReduxAction actionWithType:XGVideoDetailActionType_MovieAutoPaused info:@{XGVideoDetailActionInfo:@(YES)}]];
    return NO;
}

- (void)playerViewController:(TTVPlayerAdapterViewController *)playerViewController didFinishPlayingWithError:(NSError *)error
{
    [self.seriesPlayerInterface dismissFloatViewIfNeed];
    
    if (self.diversionManager) {
        [self.diversionManager dismiss];
    }
    
    if ([self showShortToLongPlayerEnd:self.orderedData.article.relatedLongVideoData]) {
        [self.orderedData.article.relatedLongVideoData getAlbum];
        [self.orderedData.article.relatedLongVideoData resetRequestNumber];
    }
    
    if (playerViewController.frontPaster) {
        [self removeFrontPasterADVC:playerViewController.frontPaster];
        playerViewController.frontPaster = nil;
    }
    
    if (error) {
        [TTVideoSingletonService stopAllPlayers];
        [[TTMonitor shareManager] trackService:@"xigua_video_play_error" status:error.code extra:error.userInfo];
        NSMutableDictionary *extraDic = [NSMutableDictionary dictionary];
        extraDic[@"category_id"] = self.categoryName;
        extraDic[@"group_id"] = self.detailModel.article.groupModel.groupID;
        TTQualityDescription *desc = [[TTQualityDescription alloc] initWithExtra:extraDic];
        desc.desc = error.description;
        desc.descriptionCode = error.code;
        [[TTQualityStat shareStat] onSceneFinish:TTVShortVideoDetailVideoLoad description:desc];
//        [TTVQualityManager finishLoadWithScene:TTVShortVideoDetailVideoLoad error:error description:extraDic];
        
    }
    else if (playerViewController.viewModel.isPlaybackEnded) {
        
        if (playerViewController.looping == TTVLoopingTypeSingle) {
            [self.playerViewController removeProgressCacheIfNeeded];
            [self.pasterADGuideLabel removeFromSuperview];
            return;
        }
        
        if (self.orderedData.adModel.feedADType == TTVFeedADTypeFullframeVideo) {
            // 重播前，重计用户已观看时长duration，ugly
            [playerViewController.accessLog clearEvent];
            
            if (self.playerViewController.isFullScreen) {
                [self.playerViewController setFullScreen:NO animated:YES];
            }
            
            // 手动重播前将tracker开关关闭，防止重播重新发送play相关埋点
            [self.playerViewController enableTracker:NO];
            [self.playerViewController play];
            [self.playerViewController enableTracker:YES];
            [[SSADEventTracker sharedManager] trackEventWithOrderedData:self.orderedData label:@"auto_replay" eventName:@"embeded_ad"];
            TTURLTrackerModel *model = [[TTURLTrackerModel alloc] initWithAdId:self.orderedData.adID.stringValue logExtra:self.orderedData.logExtra trackURLType:TrackURLType_play];
            [[TTURLTracker shareURLTracker] trackURLs:self.orderedData.adModel.playTrackUrlList model:model];

            return;
        }
        //如果没有开启沉浸式播放，则处理各种后贴,自动播放
        if ((!playerViewController.immerseEnable ||
            !playerViewController.isFullScreen ||
            ![playerViewController.immersePlayerInteracter canAutoPlayNext])) {
            if (playerViewController.immerseEnable &&//沉浸式末尾视频
                playerViewController.isFullScreen) {
                [self _buildFinishControlViewForPlayerViewController:playerViewController];
                return;
            }
            // 播放后贴广告
            if (self.orderedData.adID.longLongValue == 0 && self.pasterADViewController && !playerViewController.isScreenCasting && ![playerViewController isInAudioMode]) {
                [self.pasterADViewController startPlay];
            }
            
            BOOL shouldSeriesAutoPlay = [TTVLoopingPlayManager.shared loopingTypeForGid:self.article.videoID] == TTVLoopingTypeMulti;
            if (self.orderedData.adID.longLongValue > 0) {
                if (self.playerViewController.isFullScreen) {
                    // 视频广告结束页面展现前，播放器重置为竖屏状态
                    @weakify(self);
                    [self.playerViewController setFullScreen:NO animated:YES completion:^(BOOL finished) {
                        @strongify(self);
                        [self _buildAdFinishViewForPlayerViewController:playerViewController];
                    }];
                }else{
                    [self _buildAdFinishViewForPlayerViewController:playerViewController];
                }
            } else {//非广告
                if (!shouldSeriesAutoPlay && [self showShortToLongPlayerEnd:self.orderedData.article.relatedLongVideoData] && self.orderedData.article.relatedLongVideoData.album) {//短到长
                    if (self.playerViewController.isFullScreen) {
                        @weakify(self);
                        [self.playerViewController setFullScreen:NO animated:YES completion:^(BOOL finished) {
                            @strongify(self);
                            [self _buildLongVideoFinishViewForPlayerViewController:playerViewController];
                        }];
                    }else{
                        [self _buildLongVideoFinishViewForPlayerViewController:playerViewController];
                    }

                } else {
                    [self _buildFinishControlViewForPlayerViewController:playerViewController];
                }
            }
            
            
            BOOL settingEnableAutoPlay = [TTVideoAutoPlayNextUtil autoPlayNextEnabled] && [TTVideoAutoPlayNextUtil detailViewAutoPlayNextEnabled];
            
            if (!shouldSeriesAutoPlay && !settingEnableAutoPlay) {
                playerViewController.enableFullScreen = NO;
            }
            if(!shouldSeriesAutoPlay){
                [playerViewController.rotateViewController.view bringSubviewToFront:self.pasterADViewController.view];
            }
            
            BOOL autoPlayNext = NO;
            if ([self.delegate respondsToSelector:@selector(xgvd_shouldAutoPlayNext)]) {
                autoPlayNext = [self.delegate xgvd_shouldAutoPlayNext];
            }
            
            if (!autoPlayNext) {
                playerViewController.enableFullScreen = NO;
            }
            
            //播放结束显示保存到相册
            NSDictionary *shareposterConfig = [[TTSettingsManager sharedManager] settingForKey:@"ug_share_config" defaultValue:@{} freeze:NO];
            BOOL isShowFinishDownload = [shareposterConfig btd_intValueForKey:@"share_panel_video_download_switch_position" default:0];
            
            //短带长后贴出现时禁止旋转
            if (self.longFinishView && !self.longFinishView.hidden) {
                playerViewController.enableFullScreen = NO;
            }
            
            if (!autoPlayNext && self.finishControlView) {
                if (self.orderedData.article.praiseInfo.praiseEnable) {
                    //可以赞赏
                    [self.finishControlView.finishView showWithStyle:TTPlayerCustomFinishViewStyle_shareWithPraise];
                } else if(!self.videoDisableDownload && isShowFinishDownload){
                    //可以保存到相册
                    [self.finishControlView.finishView showWithStyle:TTPlayerCustomFinishViewStyle_shareWithDownload];
                }
            }
        } else if ((playerViewController.immerseEnable
                    || [playerViewController.immersePlayerInteracter canAutoPlayNext])
                   && self.orderedData.adID.longLongValue > 0
                   && playerViewController.isFullScreen) {
            ///< 沉浸式广告
            [self _buildAdFinishViewForPlayerViewController:playerViewController];
        }
        
        if (playerViewController.immerseEnable && playerViewController.isFullScreen) {
            if (playerViewController.viewModel.autoType != TTPlayerViewModelAutoFinishType) {
                self.immerseFinishCount.finishCount = 0;
            }
        }
        
        [self logVideoOver];
    }
    
    //同步article的播放进度
    if ([self.article.videoID isEqualToString:playerViewController.videoID]) {
        self.article.historyDuration = @(playerViewController.currentPlaybackTime * 1000);
        [self.article save];
    }
    
    [self.playerViewController removeProgressCacheIfNeeded];
    [self.pasterADGuideLabel removeFromSuperview];
}

- (void)playerViewController:(TTVPlayerAdapterViewController *)playerViewController didShowDanmaku:(BOOL)show
{
}

- (void)playerViewControllerPrepared:(TTVPlayerAdapterViewController *)playerViewController {
    if (self.frontPasterADVC || playerViewController.frontPaster) {
        [playerViewController pause];
    }
}

- (void)moreActionWithPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[XGVideoDetailActionInfo_PlayerVC] = playerViewController;
    [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_MoreActionInPlayerVC info:info]];
}

- (void)shareActionWithPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[XGVideoDetailActionInfo_PlayerVC] = playerViewController;
    [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_ShareActionInPlayerVC info:info]];
}


- (TTImageInfosModel *)audioCoverModel {
    TTImageInfosModel *model = [[TTImageInfosModel alloc] initWithDictionary:self.orderedData.article.middleImageDict];
    return model;
}


- (BOOL)remoteControlEnablePre {
    return [[TTVideoAutoPlayNextManager sharedManager] audioModePlayPreEnableWithCurrentCellView:nil isListView:NO];
}

- (BOOL)remoteControlEnableNext {
    return [[TTVideoAutoPlayNextManager sharedManager] audioModePlayNextEnableWithCurrentCellView:nil isListView:NO];
}

- (void)remoteControlClickPre {
    [[TTVideoAutoPlayNextManager sharedManager] audioModePlayPreWithCurrentCellView:nil isListView:NO];
}

- (void)remoteControlClickNext {
    [[TTVideoAutoPlayNextManager sharedManager] audioModePlayNextWithCurrentCellView:nil isListView:NO];
}


#pragma mark - private
- (NSDictionary *)p_updatedConditionForArticle:(Article *)article {
    NSMutableDictionary *condition = [NSMutableDictionary dictionary];
    condition[@"log_pb"] = [article ttv_risky_logPassBackDict];
    NSMutableDictionary *extLogPb = [NSMutableDictionary dictionary];
    extLogPb[@"parent_group_id"] = self.detailModel.seriesDetailModel.parentGroupId;
    extLogPb[@"parent_impr_id"] = self.detailModel.seriesDetailModel.parentImprId;
    extLogPb[@"parent_impr_type"] = self.detailModel.seriesDetailModel.parentImprType;
    extLogPb[@"parent_group_source"] = self.detailModel.seriesDetailModel.parentGroupSource;
    extLogPb[@"parent_category_name"] = self.detailModel.seriesDetailModel.parentCategoryName;
    extLogPb[@"group_source"] = @(2);
    condition[@"ext_log_pb"] = extLogPb;
    condition[@"isAutoPlaying"] = @(NO);
    condition[@"category_name"] = kExploreVideoDetailRelatedListIDKey;
    NSMutableDictionary *extLogParams = [NSMutableDictionary dictionary];
    extLogParams[@"selection_entrance"] = @"Pseries_fullscreen_vert";
    extLogParams[@"fullscreen"] = self.playerViewController.isFullScreen ? @"fullscreen" : @"nofullscreen";
    extLogParams[@"album_type"] = @(18);
    extLogParams[@"enter_from"] = @"click_related";
    extLogParams[@"selection_range"] = [self.seriesViewModel rangeStringWithRank:[article.pSeriesRank unsignedIntegerValue]];
    extLogParams[@"is_updated_pseries"] = @(NO);
    
    condition[kNewsDetailViewExtraTrackerLogPramasKey] = extLogParams;
    return [condition copy];
}

- (void)wrapSeries {
    XGVideoDetailPlayerInterface *interface = [[XGVideoDetailPlayerInterface alloc] init];
    self.seriesPlayerInterface = interface;
    @weakify(self);
    @weakify(interface);
    interface.didUpdateArticle = ^(Article * _Nonnull article) {
        @strongify(self);
        @strongify(interface);
        if ([article.groupModel.groupID isEqualToString:self.orderedData.article.groupModel.groupID ?: @""]) {
            return;
        }
        UIResponder<TTDetailResponderProtocol> *res = TTDetailNearestResponder(self.viewController);
        NSDictionary *condition = [self p_updatedConditionForArticle:article];
        [res updateWithModel:article condition:condition];
        if ([self.viewController respondsToSelector:@selector(dismissFloatView)]) {
            [self.viewController dismissFloatView];
        }
        [interface dismissFloatViewIfNeed];
        if ([self.viewController respondsToSelector:@selector(tapSeries:)]) {
            [self.viewController tapSeries:article];
        }
    };
    interface.didTapEpisodeButtonBlock = ^{
        @strongify(self);
        NSMutableDictionary *extParams = [NSMutableDictionary dictionary];
        [extParams setValue:@"detail" forKey:@"position"];
        [self.seriesViewModel blockMoreWithCategoryName:self.categoryName fullScreen:self.playerViewController.isFullScreen extParams:[extParams copy]];
    };
    interface.categoryNameBlock = ^NSString * _Nonnull{
        @strongify(self);
        return self.categoryName;
    };
    interface.positionBlock = ^NSString * _Nonnull{
        return @"detail";
    };
    self.playerViewController = [TTVSeriesPlayerWrapper playerWithPlayer:self.playerViewController article:self.article fromCategory:self.categoryName interface:interface];
}

- (void)unwrapSeries {
    [self unwrapSeries:self.playerViewController];
}

- (void)unwrapSeries:(TTVPlayerAdapterViewController *)playerVC {
    [TTVSeriesPlayerWrapper unwrapPlayer:playerVC article:self.article];
}

- (void)_buildAdFinishViewForPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController
{
    TTPlayerAdFinishView *adFinishView = [[TTPlayerAdFinishView alloc] initWithFrame:playerViewController.rotateViewController.view.bounds exploreOrderedData:self.orderedData forPlayer:playerViewController];
    adFinishView.delegate = self;
    WeakSelf;
    adFinishView.didClickBackButtonBlock = ^(UIButton *button) {
        StrongSelf;
        if (self.playerViewController.isFullScreen) {
            [self.playerViewController setFullScreen:NO animated:YES];
        }
    };
    adFinishView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    BOOL canStartCountdownTip = YES;
    if([[TTVADHalfViewManger sharedManager].halfWebView isDescendantOfView:playerViewController.containerView]) {
        [playerViewController.containerView insertSubview:adFinishView belowSubview:[TTVADHalfViewManger sharedManager].halfWebView];
        canStartCountdownTip = NO;
    } else {
        [playerViewController.containerView addSubview:adFinishView];
    }
    if ((playerViewController.immerseEnable
         || [playerViewController.immersePlayerInteracter canAutoPlayNext])
        && self.orderedData.adID.longLongValue > 0
        && playerViewController.isFullScreen) {
        NSTimeInterval showTime = 3000;
        if ([[self.orderedData.article.rawAdData btd_dictionaryValueForKey:@"mask_info"] objectForKey:@"show_duration"]) {
            showTime = [[self.orderedData.article.rawAdData btd_dictionaryValueForKey:@"mask_info"] btd_unsignedIntegerValueForKey:@"show_duration"];
        }
        
        if (canStartCountdownTip) {
            [adFinishView startCountdownTipCountDownTime:showTime / 1000];
        } else {
            [adFinishView setupCountdownTipCountDownTime:showTime / 1000];
        }
        
        [[SSADEventTracker sharedManager] willRecord:kImmersePlayerAdFinishedView_showOver_background_recording];
        NSMutableDictionary *adExtra = [NSMutableDictionary dictionaryWithCapacity:1];
        adExtra[@"refer"] = @"background";
        [[SSADEventTracker sharedManager] trackEventWithOrderedData:self.orderedData label:@"othershow" eventName:@"draw_ad" extraDict:adExtra];
    }
}

- (void)_buildFinishControlViewForPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController
{
    //looping标记
    TTPlayerFinishControlView *finishControlView = [[TTPlayerFinishControlView alloc] initWithFrame:playerViewController.rotateViewController.view.bounds withAuthorInfo:self.state.detailModel.article.userInfo forPlayer:playerViewController];
    self.finishControlView = finishControlView;
    finishControlView.backgroundColor = [UIColor tt_black4Color];
    [playerViewController.rotateViewController.view addSubview:finishControlView];
    [playerViewController didAddFinishView:finishControlView];
    if (finishControlView.superview) {
        [finishControlView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(finishControlView.superview);
        }];
    }
    [playerViewController.rotateViewController.view bringSubviewToFront:self.pasterADViewController.view];
    
    if ([self.delegate respondsToSelector:@selector(xgvd_setupFinishControlView:)]) {
        [self.delegate xgvd_setupFinishControlView:finishControlView];
    }
}

- (void)_buildLongVideoFinishViewForPlayerViewController:(TTVPlayerAdapterViewController *)playerViewController
{
    TTVLPlayerFinishView *finishControlView = [[TTVLPlayerFinishView alloc] initWithFrame:playerViewController.rotateViewController.view.bounds];
    self.longFinishView = finishControlView;
    self.longFinishView.backgroundColor = [UIColor tt_black4Color];
    [playerViewController.rotateViewController.view addSubview:self.longFinishView];
    [self.longFinishView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(playerViewController.rotateViewController.view);
    }];
    [self.longFinishView updateWithData:self.orderedData.article.relatedLongVideoData];
    
    UIViewController<XGVideoDetailVCProtocol> *detailVC = self.viewController;
    BOOL hasSeries = [detailVC respondsToSelector:@selector(hasSeries)] && [detailVC hasSeries];
    BOOL settingEnableAutoPlay = [TTVideoAutoPlayNextUtil autoPlayNextEnabled] && [TTVideoAutoPlayNextUtil detailViewAutoPlayNextEnabled];
    BOOL shouldAutoPlay = hasSeries || settingEnableAutoPlay;
    
    if ([TTVideoAutoPlayNextUtil listViewAutoPlayNextStyle] == ListViewAutoPlayNextStyleScrolling && shouldAutoPlay) {
        self.longFinishView.hidden = YES;
    }

    if ([self.delegate respondsToSelector:@selector(xgvd_updateLongVideoFinishViewAction:)]) {
        [self.delegate xgvd_updateLongVideoFinishViewAction:self.longFinishView];
    }
    
    if (![TTVideoAutoPlayNextUtil detailViewAutoPlayNextEnabled] || ![TTVideoAutoPlayNextUtil autoPlayNextEnabled]) {
        [[TTVideoAutoPlayNextManager sharedManager] endCountDownTimer];
    }
}

- (NSDictionary *)p_adAvatarInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:3];
    ExploreOrderedData *data = self.orderedData;
    info[@"ad_id"] = data.adID;
    info[@"avatar_url"] = data.adModel.avatarUrl;
    info[@"name"] = data.adModel.source;
    return [info copy];
}

- (void)p_clickedAdAvatarAction {
    NSMutableDictionary *trackerParams = [NSMutableDictionary dictionary];
    BOOL immerseEnable = NO;
    if (self.playerViewController.immerseEnable
        && self.playerViewController.isFullScreen) {
        trackerParams[@"refer"] = @"photo";
        immerseEnable = YES;
    }
    [TTVideoDetailADPlayerLogHelper sendPlayerAdClickedActionWithOrderedData:self.orderedData immerseEnable:immerseEnable playerViewController:self.playerViewController extraDic:trackerParams];
    [TTVideoDetailADPlayerLogHelper executeAdClickedActionWithWithOrderedData:self.orderedData playerViewController:self.playerViewController immerseEnable:immerseEnable deeplinkEnable:YES];
}


#pragma mark - 移除广告播放结束view
- (void)removeADFinishView {
    UIView *adFinishView = nil;
    for (UIView *view in self.playerViewController.containerView.subviews) {
        if ([view isKindOfClass:TTPlayerAdFinishView.class]) {
            adFinishView = view;
            break;
        }
    }
    [adFinishView removeFromSuperview];
}

#pragma mark - TTSpecialSellViewControllerDelegate

- (void)specialSellViewControllerWillClose:(TTSpecialSellViewController *)vc {
    [self.detailStore dispatch:[XGVideoDetailAction displaySpecialSellItemsAction:NO]];
}

#pragma mark - TTVReduxStateObserver

- (void)stateDidChangedToNew:(XGVideoDetailState *)newState lastState:(XGVideoDetailState *)lastState store:(NSObject<TTVReduxStoreProtocol> *)store {
    // info
    if (!lastState.fetchInfoFinished && newState.fetchInfoFinished) {
        [self handleFetchInfoFinished:newState];
    }
    
    // action
    if (![newState hasEqualEvent:lastState]) {
        // 重播
        if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_ReplayActionInPlayerVC]) {
            TTVPlayerAdapterViewController *playerVC = newState.reduxActionInfo[XGVideoDetailActionInfo_PlayerVC];
            playerVC.enableFullScreen = YES;
            [playerVC play];
            [[TTVideoAutoPlayNextManager sharedManager] pauseCountDownTimer];
            [[TTVideoAutoPlayNextManager sharedManager] resetAutoPlayCount];
            [self.playerViewController.danmakuAdapter clear];
        }
        // PlayerFullScreenChanged
        else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_PlayerFullScreenChanged]) {
            BOOL isFullscreen = [newState.reduxActionInfo[XGVideoDetailActionInfo] boolValue];
            [self handleFullscreenChanged:isFullscreen];
        }
        // ChangePlayer
        else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_ChangePlayer]) {
            [self handleChangePlayer];
            UIViewController<XGVideoDetailVCProtocol> *detail = self.viewController;
            BOOL hasSeries = [detail respondsToSelector:@selector(hasSeries)] && [detail hasSeries];
            
            if (hasSeries) {
                [self wrapSeries];
            } else {
                [self unwrapSeries];
            }
        }
        // SelectedEpisode
        else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_CustomSelectedNewEpisode]) {
            TTVPlayerAdapterViewController *playerVC = newState.reduxActionInfo[XGVideoDetailActionInfo_PlayerVC];
            playerVC.enableFullScreen = YES;
            XGVideoDetailUpdateAction updateAction = XGVideoDetailUpdateActionUnknown;
            BOOL updateByImmerse = self.playModelChangeByImmerse;
            BOOL updateByTapSeries = self.playModelChangeByTapSeries;
            NSAssert(!(updateByTapSeries && updateByImmerse), @"");
            if (updateByImmerse) {
                updateAction = XGVideoDetailUpdateByImmerse;
            } else if (updateByTapSeries) {
                updateAction = XGVideoDetailUpdateByTapSeries;
            } else {
                updateAction = XGVideoDetailUpdateActionUnknown;
            }
            if ([self.viewController respondsToSelector:@selector(playWithCachedProgress:partUpdate:updateAction:)]) {
                [self.viewController playWithCachedProgress:YES partUpdate:YES updateAction:updateAction];
            } else {
                NSAssert(NO, @"");
                NSTimeInterval historyDuration = [self.article.historyDuration doubleValue] / 1000.0;
                [self.playerViewController restoreHistoryDuration:historyDuration ofVideoDuration:[self.article.videoDuration doubleValue]];
                [playerVC play];
            }
            [[TTVideoAutoPlayNextManager sharedManager] pauseCountDownTimer];
            [[TTVideoAutoPlayNextManager sharedManager] resetAutoPlayCount];
            [self.longFinishView removeFromSuperview];
            self.longFinishView = nil;
            
            if (self.playModelChangeByImmerse) {
                self.playModelChangeByImmerse = NO;
            }
            
            if (self.playModelChangeByTapSeries) {
                self.playModelChangeByTapSeries = NO;
                if (self.playerViewController.isFullScreen) {
                    [self immersePlayerWillBeginWithInteracter:self.playerViewController.immersePlayerInteracter];
                    [self.playerViewController.immersePlayerInteracter enableScroll];
                    [self.playerViewController.immersePlayerInteracter resetAll];
                }
            }
            
            NSMutableDictionary *info = (newState.reduxActionInfo ?: @{}).mutableCopy;
            static uint64_t episodeFixTime = 1;
            info[@"fullscreen"] = @(self.playerViewController.isFullScreen);
            info[@"episodeFixTime"] = @(episodeFixTime ++);
            XGVideoDetailAction *action = [[XGVideoDetailAction alloc] initWithType:XGVideoDetailActionType_CustomSelectedNewEpisodeFix info:info];
            [self.detailStore dispatch:action];
        } else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_DismissFloatView]) {
            [self.seriesPlayerInterface dismissFloatViewIfNeed];
        } else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_ChangePlayModelByTapSeries]) {
            [self.playerViewController cacheProgress];
            [self.playerViewController stop];
            [self.playerViewController.immersePlayerInteracter disableScroll];
            self.playModelChangeByTapSeries = YES;
            self.playModelChangeByImmerse = NO;
        } else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_ChangePlayModelByFullscreenImmerse]) {
            self.playModelChangeByImmerse = YES;
            self.playModelChangeByTapSeries = NO;
        } else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_FetchInfoFinished]) {
            if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries] && self.playerViewController.supportsPortaitFullScreen == YES) {
                //这里为了解决从列表上带进一个竖屏视频的时候，在有选集的情况下不展示竖直状态播放器
                if (self.playerViewController.isFullScreen) {
                    @weakify(self);
                    [self.playerViewController setFullScreen:NO animated:YES completion:^(BOOL finish) {
                        @strongify(self);
                        self.playerViewController.supportsPortaitFullScreen = NO;
                    }];
                } else {
                    self.playerViewController.supportsPortaitFullScreen = NO;
                }
            }
        } else if ([newState.reduxActionType isEqualToString:XGVideoDetailActionType_DidSetPlayer]) {
            NSDictionary *info = newState.reduxActionInfo;
            TTVPlayerAdapterViewController *newPlayer = info[XGVideoDetailActionInfo_PlayerVC];
            TTVPlayerAdapterViewController *oldPlayer = info[XGVideoDetailActionInfo_OldPlayerVC];
            if (newPlayer == nil && oldPlayer) {
                [self unwrapSeries:oldPlayer];
            } else {
                if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
                    [self wrapSeries];
                } else {
                    [self unwrapSeries];
                }
            }
        }
    }
    
    // 展示特卖
    if (!lastState.showSpecialSell && newState.showSpecialSell) {
        [self displayAllSpecialSellItems];
    }
    else if (lastState.showSpecialSell && !newState.showSpecialSell) {
        self.specialSellVC = nil;
    }
    
    // viewWillAppear
    if (!lastState.willShowing && newState.willShowing) {
        [self handleViewWillAppear];
    }
    else if (!lastState.isShowing && newState.isShowing) {
        [self handleViewDidAppear];
    }
    else if (!lastState.willDisappear && newState.willDisappear) {
        [self handleViewWillDisappear];
    }
    else if (lastState.isShowing && !newState.isShowing) {
        [self handleViewDidDisappear];
    }
}

#pragma mark -

- (void)handleFetchInfoFinished:(XGVideoDetailState *)newState
{
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        [self wrapSeries];
    } else {
        [self unwrapSeries];
    }

    [self.playerViewController ss_beginSpecialSellMonitorWithArticle:self.state.detailModel.orderedData.article specialTrackParameters:[self specialTrackParameters]];
    
    WeakSelf;
    [self.playerViewController ss_setSpecialSellEntranceViewClick:^{
        StrongSelf;
        [self.detailStore dispatch:[XGVideoDetailAction displaySpecialSellItemsAction:YES]];
    }];
    
    [[TTVPlayerADExenstionService sharedInstance] addADExtensionForPlayer:self.playerViewController article:self.state.detailModel.orderedData.article];
    [[TTVPlayerFunctionCardService sharedInstance] addFunctionCardForPlayer:self.playerViewController article:self.state.detailModel.orderedData.article];

    
    if (!isEmptyString(newState.videoAdUrl) && [self.state.detailModel.orderedData.adID integerValue] > 0) {
        self.landingURL = newState.videoAdUrl;
        self.adButton = [self getAdButton];
        [self.playerViewController.rotateViewController.view addSubview:self.adButton];
    } else {
        if (self.adButton) {
            [self.adButton removeFromSuperview];
            self.adButton = nil;
        }
    }
}

- (void)handleViewWillAppear
{
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        [self wrapSeries];
    } else {
        [self unwrapSeries];
    }
    
    BOOL isApplicationActive = [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    
    if (self.longFinishView.superview && !self.longFinishView.hidden) {
        [self.longFinishView updateWithData:self.orderedData.article.relatedLongVideoData];
    }
    
    if (self.pasterADViewController.isPaused && isApplicationActive) {
        [self.pasterADViewController resumeCurrentAD];
    }
    
    if (self.frontPasterADVC.isPaused && isApplicationActive) {
        [self.frontPasterADVC resume];
    }

    if ([self.orderedData.article.articleExtra valueForKey:@"hash_tag"]) {
        NSDictionary *hashTag = [self.orderedData.article.articleExtra valueForKey:@"hash_tag"];
        if ([hashTag valueForKey:@"name"]) {
            NSString *name = [hashTag valueForKey:@"name"];
            NSString *label = [self.state.detailModel.clickLabel stringByReplacingOccurrencesOfString:@"click" withString:@"show"];
            NSNumber *tagType = [hashTag valueForKey:@"tag_type"];
            NSString *tagID = [hashTag valueForKey:@"id"];
            NSString *hashTagString = nil;
            switch (tagType.integerValue) {
                case HashTagTypeHashtag:
                    hashTagString = @"hashtag";
                    break;
                case HashTagTypeAlbum:
                    hashTagString = @"album";
                    break;
                case HashTagTypeSubject:
                    hashTagString = @"subject";
                    break;
                default:
                    break;
            }
            if (!isEmptyString(hashTagString)) {
                [TTTrackerWrapper event:@"hashtag" label:label value:self.orderedData.article.groupModel.groupID extValue:tagID extValue2:nil dict:@{@"position":@"detail",@"hashtag":name,@"hashtag_type":hashTagString}];
            }
        }
    }
    
    if (!self.playerViewController.viewModel.isPlaybackEnded && !self.playerViewController.isScreenCasting) {
        self.playerViewController.enableFullScreen = YES;
    }
}

- (void)handleViewDidAppear {
    self.pasterADViewController.isAppeared = YES;
    
    if (self.frontPasterADVC) {
        [self.frontPasterADVC pasterDidAppera];
    }
    
    if (self.fullScreenIfNeed) {
        [self.playerViewController play];
        BOOL needShowCommentView = [[TTVPlayerFullScreenManager sharedInstance] needStashCommentView];
        self.playerViewController.blockMonitoring = NO;
        WeakSelf;
        [self.playerViewController setFullScreen:YES animated:YES completion:^(BOOL finish) {
            dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showSafeLoginWindow" object:nil userInfo:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showOneKeyWindow" object:nil userInfo:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"showAwemeWindow" object:nil userInfo:nil];
            });
            StrongSelf;
            if (needShowCommentView) {
                [[TTVPlayerFullScreenManager sharedInstance] showCommentViewIn:self.playerViewController article:self.state.detailModel.article trackerParams:nil animated:NO];
            }
            [[TTVPlayerFullScreenManager sharedInstance] resetInteractiveStatus];
        }];

        self.fullScreenIfNeed = NO;
    }
}

- (void)handleViewWillDisappear {
    if (self.playerViewController) {
        [self.pasterADViewController pauseCurrentAD];
        [self.frontPasterADVC pause];
    } else {
        // 因播放器下拉返回时，移除后贴
        [self removePasterADView];
    }
}

- (void)handleViewDidDisappear {
    [self unwrapSeries];
    self.pasterADViewController.isAppeared = NO;
    
    if (self.frontPasterADVC) {
        [self.frontPasterADVC pasterDidDisappear];
    }
}

- (void)handleFullscreenChanged:(BOOL)isFullscreen {
    self.longFinishView.isFullScreen = isFullscreen;
    
    [self.playerViewController moreButtonHidden:![self showPlayerMoreBtn]];
    [self.playerViewController shareButtonEnable:[self.orderedData.adID integerValue] == 0];
    
    if (isFullscreen) {
        [self.playerViewController.danmakuAdapter restoreDanmakuButtons];
    } else {
        if (self.viewController.explore) {
            return;
        }
        [self.playerViewController.danmakuAdapter removeDanmakuButtons];
    }

    Article *article = self.orderedData.article;
    if (article && !isEmptyString(article.title)) {
        if (isFullscreen) {
            if ([TTVPSeriesHelper shouldShowPSeriesStyleWithArticle:article]) {
                [self.playerViewController setPlayerAttributedTitle:[TTVPSeriesTagVideoTitleProducer getPSeriesTagVideoTitleWithOriginalTitle:article.title]];
            } else {
                [self.playerViewController setPlayerTitle:article.title];
            }
        } else {
            [self.playerViewController setPlayerTitle:article.title];
        }
    }
    if (self.playerViewController.immerseEnable && self.playerViewController.isFullScreen &&
        ![self.pasterADViewController isPlayingMovie] &&
        ![self.pasterADViewController isPlayingImage]) {
        self.pasterADViewController.shouldHidePasterAD = YES;
    } else {
        self.pasterADViewController.shouldHidePasterAD = NO;
    }
    [self.seriesPlayerInterface dismissFloatViewIfNeed];
}

- (void)handleChangePlayer {
    if (!self.playerViewController) {
        [self.KVOController unobserveAll];
        return;
    }
    
    BOOL filterPortait = [self immersePlayerFilterPortait:self.playerViewController.immersePlayerInteracter];
    BOOL supportPortaitFullScreen = [self.orderedData.article supportPortaitFullscreen] && self.orderedData.article.videoProportion <= 1;
    if (supportPortaitFullScreen && filterPortait) {
        self.playerViewController.immerseEnable = NO;
    }
    if ([self.orderedData.adID unsignedLongLongValue] > 0 && !self.playerViewController.isFullScreen && !self.playerViewController.immerseEnable) {
        self.playerViewController.immerseEnable = NO;
    }
    if (self.playerViewController.immerseEnable) {
        self.playerViewController.immersePlayerInteracter.delegate = self;
        if (self.playerViewController.immersePlayerInteracter.context.finishCount) {
            self.immerseFinishCount = self.playerViewController.immersePlayerInteracter.context.finishCount;
        }
    } else {
        self.playerViewController.immersePlayerInteracter.delegate = nil;
    }
    
    //self.passPlayerFromPreviousPage = NO;
    
    if (self.playerViewController && self.proportionTransition.panGestureInMovie) {
        [self.playerViewController.view addGestureRecognizer:self.proportionTransition.panGestureInMovie];
    }
    
    self.playerViewController.viewModel.source = TTPlayerViewModelSourceDetail;
    self.playerViewController.viewModel.direction = TTPlayerGestureDirectionHorizontal;
    
    NSMutableDictionary *mutablePlayerViewModel = [NSMutableDictionary dictionaryWithDictionary:self.playerViewController.viewModel.commonExtraTrackers];
    [mutablePlayerViewModel addEntriesFromDictionary:self.detailModel.extraTrackerLogParamas];
    self.playerViewController.viewModel.commonExtraTrackers = [mutablePlayerViewModel copy];
    
    self.playerViewController.showControlsTitle = NO;
    self.playerViewController.showsTitleShadow = self.playerViewController.isFullScreen;
    self.playerViewController.delegate = self;
    [self.playerViewController addPlayerAdapterDelegate:self];
    
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        self.playerViewController.supportsPortaitFullScreen = NO;
    } else {
        self.playerViewController.supportsPortaitFullScreen = supportPortaitFullScreen;
    }

    [self.playerViewController moreButtonHidden:![self showPlayerMoreBtn]];
    [self.playerViewController shareButtonEnable:[self.orderedData.adID integerValue] == 0];
    BOOL disableScreenCast = (self.orderedData.adID.longLongValue != 0) || (self.orderedData.article.isHotPush) || self.viewController.explore;
    [self.playerViewController setScreenCastDisable:disableScreenCast];
    
    @weakify(self);
    [self.KVOController observe:self.playerViewController.fullScreenObserverState keyPath:@keypath(self.playerViewController.fullScreenObserverState, fullScreenObserver) options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        @strongify(self);
        BOOL wasFullScreen = [[change valueForKey:NSKeyValueChangeOldKey] boolValue];
        BOOL isFullScreen = [[change valueForKey:NSKeyValueChangeNewKey] boolValue];
        
        if (self.playerViewController.immerseEnable &&
            self.playerViewController.isFullScreen &&
            ![self.pasterADViewController isPlayingMovie] &&
            ![self.pasterADViewController isPlayingImage]) {
            self.pasterADViewController.shouldHidePasterAD = YES;
        } else {
            self.pasterADViewController.shouldHidePasterAD = NO;
        }
        
        if (wasFullScreen != isFullScreen) {
            [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_PlayerFullScreenChanged info:@{XGVideoDetailActionInfo:@(isFullScreen)}]];
        }
    }];
    
    BOOL enableFullScreenAB = self.orderedData.adID.longLongValue == 0 && !self.playerViewController.supportsPortaitFullScreen;
    NSDictionary *settingDict = [[TTSettingsManager sharedManager] settingForKey:@"xg_ui_ab_config" defaultValue:@{} freeze:NO];
    BOOL interactiveFullscreen = [settingDict btd_boolValueForKey:@"interactive_fullscreen"];
    [self.playerViewController enableFullScreenAB:enableFullScreenAB && interactiveFullscreen];
    self.playerViewController.menuDelegate = self;
    self.playerViewController.menuDataSource = self;
}

- (NSMutableDictionary *)specialTrackParameters
{
    Article *article = self.orderedData.article;
    NSMutableDictionary *trackerParam = [NSMutableDictionary dictionary];
    trackerParam[@"group_id"] = article.groupModel.groupID;
    trackerParam[@"enter_group_id"] = article.groupModel.groupID;
    trackerParam[@"enter_type"] = @"goods_card";
    trackerParam[@"g_composition"] = article.composition;
    trackerParam[@"position"] =  @"detail";
    trackerParam[@"enter_group_id"] = article.groupModel.groupID;
    trackerParam[@"author_uid"] = article.userInfo[@"user_id"];
    trackerParam[@"g_source"] = @(self.orderedData.groupSource);
    trackerParam[@"category_name"] = self.orderedData.categoryID;
    trackerParam[@"enter_from"] = self.state.detailModel.enterFrom;
    trackerParam[@"impr_id"] = self.state.detailModel.logpbDic[@"impr_id"];
    return trackerParam;
}

#pragma mark - 后贴广告

- (void)addPasterADView
{
    self.pasterADViewController = [[TTVPasterADViewController alloc] initWithPlayerViewController:self.playerViewController];
    self.pasterADViewController.delegate = self;
    self.pasterADViewController.isInDetail = YES;
    TTVPasterADURLRequestInfo *pasterRequest = [[TTVPasterADURLRequestInfo alloc] init];
    pasterRequest.groupID = self.orderedData.article.groupModel.groupID;
    pasterRequest.itemID = self.orderedData.article.itemID;
    pasterRequest.category = self.orderedData.categoryID;
    pasterRequest.adFrom = @"textlink";
    pasterRequest.adExp = self.orderedData.article.adExp;
    self.pasterADViewController.pasterAdRequestInfo = pasterRequest;
    [self.playerViewController.rotateViewController addChildViewController:self.pasterADViewController];
    [self.playerViewController.rotateViewController.view addSubview:self.pasterADViewController.view];
    [self.pasterADViewController didMoveToParentViewController:self.playerViewController.rotateViewController];
    [self.pasterADViewController.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.pasterADViewController.view.superview);
    }];
}

- (void)removePasterADView
{
    if (self.pasterADViewController) {
        [self.pasterADViewController stopCurrentADVideo];
        [self.pasterADViewController willMoveToParentViewController:nil];
        [self.pasterADViewController.view removeFromSuperview];
        [self.pasterADViewController removeFromParentViewController];
        self.pasterADViewController = nil;
    }
}

#pragma mark - 后贴广告 TTVPasterADDelegate

- (void)videoPasterADViewControllerToggledToFullScreen:(BOOL)fullScreen animationed:(BOOL)animationed completionBlock:(void(^)(BOOL finished))completionBlock
{
    [self.playerViewController setFullScreen:fullScreen animated:animationed completion:completionBlock];
}

- (void)videoPasterADViewControllerShouldShowGuideViewWithText:(NSString *)guideText
{
    [self createPasterADGuideLabel];
    [self.pasterADGuideLabel setText:guideText];
    [self.playerViewController.rotateViewController.view addSubview:self.pasterADGuideLabel];
    [UIView performWithoutAnimation:^{
        [self.pasterADGuideLabel sizeToFit];
        self.pasterADGuideLabel.left = [TTBusinessManager tt_padding:13];
        self.pasterADGuideLabel.height = 28;
        self.pasterADGuideLabel.width += 2 * [TTBusinessManager tt_padding:16];
        self.pasterADGuideLabel.bottom = self.playerViewController.rotateViewController.view.height - [TTBusinessManager tt_padding:8];
        self.pasterADGuideLabel.layer.cornerRadius = 14;
    }];
    
    [self.pasterADGuideLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.mas_equalTo(self.playerViewController.rotateViewController.view).offset(- [TTBusinessManager tt_padding:8]);
    }];
    
    WeakSelf;
    [[RACSignal combineLatest:@[RACObserve(self.playerViewController.controlsObserverState, controlsShowingObserver),
                                RACObserve(self.playerViewController.controlsObserverState, showingResolutionTipObserver)]
                       reduce:^ {
                           StrongSelf;
                           return @(self.playerViewController.controlsShowing
                           || self.playerViewController.resolutionTipShowing);
                       }] subscribeNext:^(NSNumber *showing) {
                           StrongSelf;
                           [UIView animateWithDuration:0.25 animations:^{
                               self.pasterADGuideLabel.bottom = self.playerViewController.rotateViewController.view.height - [TTBusinessManager tt_padding:8];
                           }];
                       }];
}

- (BOOL)isMovieFullScreen {
    return self.playerViewController.isFullScreen;
}

#pragma mark -

- (UILabel *)createPasterADGuideLabel
{
    if (!_pasterADGuideLabel) {
        _pasterADGuideLabel = [[UILabel alloc] init];
        _pasterADGuideLabel.backgroundColor = [UIColor tt_black5Color];
        _pasterADGuideLabel.layer.masksToBounds = YES;
        _pasterADGuideLabel.textAlignment = NSTextAlignmentCenter;
        _pasterADGuideLabel.font = [UIFont systemFontOfSize:[TTBusinessManager tt_fontSize:13]];
        _pasterADGuideLabel.textColor = [UIColor whiteColor];
    }
    return _pasterADGuideLabel;
}

- (TTAlphaThemedButton *)getAdButton
{
    TTAlphaThemedButton *button = [[TTAlphaThemedButton alloc] init];
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleTopMargin;
    [button setTitleColorThemeKey:kColorText8];
    [button.titleLabel setFont:[UIFont systemFontOfSize:[TTBusinessManager tt_fontSize:10]]];
    button.backgroundColorThemeKey = kColorBackground13;
    [button setTitle:NSLocalizedString(@"查看详情", nil) forState:UIControlStateNormal];
    [button.titleLabel sizeToFit];
    button.width = [TTBusinessManager tt_padding:60];
    button.height = [TTBusinessManager tt_padding:20];
    button.right = self.playerViewController.rotateViewController.view.width - kAdDetailButtonGap;
    button.bottom = self.playerViewController.rotateViewController.view.height - 40 - kAdDetailButtonGap;
    button.layer.cornerRadius = 10;
    button.layer.masksToBounds = YES;
    [button addTarget:self action:@selector(showDetailButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    button.hidden = YES;
    
    WeakSelf;
    [[RACObserve(self.playerViewController.fullScreenObserverState, fullScreenObserver) map:^(NSNumber *fullScreen) {
        StrongSelf;
        return @(![fullScreen boolValue] && [self shouldShowDetailButton]);
    }] subscribeNext:^(NSNumber *show) {
        button.hidden = ![show boolValue];
    }];
    return button;
}

- (BOOL)shouldShowDetailButton
{
    if (!isEmptyString(self.landingURL)) {
        return YES;
    }
    return NO;
}

- (void)showDetailButtonClicked
{
    if (!isEmptyString(self.landingURL) && ([self.orderedData.adID longLongValue] > 0)) {
        UINavigationController *vc = [TTUIResponderHelper topNavigationControllerFor:self.viewController];
        ssOpenWebView([NSURL btd_URLWithString:self.landingURL], nil, vc, NO, nil);
        [XGVideoDetailLog sendADEvent:@"embeded_ad" label:@"ad_click" value:[self.orderedData.adID stringValue] extra:nil logExtra:self.orderedData.logExtra];
    }
}

#pragma mark - OnVideo

- (void)addOnVideoADViewController
{
    NSString *pbStr = self.state.detailModel.article.onVideoInfoPBString;
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:pbStr options:0];
    NSError *error = nil;
    TTVOnvideoInfo *info = [TTVOnvideoInfo parseFromData:decodedData error:&error];
    NSArray *materialList = [NSArray arrayWithArray:info.materialListArray];
    
    if (materialList.count > 0) {
        TTVOnVideoViewModel *onVideoViewModel = [[TTVOnVideoViewModel alloc] initWithMaterialArray:materialList];
        TTVOnVideoADViewController *onVideoADVC = [[TTVOnVideoADViewController alloc] initWithPlayerViewController:self.playerViewController viewModel:onVideoViewModel];
        [self.playerViewController addOnVideoViewController:onVideoADVC];
        [onVideoADVC.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.mas_equalTo(self.playerViewController.controlView);
        }];
        onVideoADVC.delegate = self;
        self.onVideoADVC = onVideoADVC;
    }
}

- (void)removeOnVideoADViewController
{
    if (self.onVideoADVC) {
        [self.onVideoADVC willMoveToParentViewController:nil];
        [self.onVideoADVC.view removeFromSuperview];
        [self.onVideoADVC removeFromParentViewController];
        self.onVideoADVC = nil;
    }
    
    // 防止PlayerViewController复用，导致无法移除彻底
    for (TTVOnVideoADViewController *vc in self.playerViewController.controlsChildViewControllers) {
        if ([vc isKindOfClass:[TTVOnVideoADViewController class]]) {
            [vc willMoveToParentViewController:nil];
            [vc.view removeFromSuperview];
            [vc removeFromParentViewController];
            // Fix 解决横屏点击下一个视频时，上一个视频详情页持有的onVideoVC因其播放器被下一个视频详情页复用，导致继续发生回调bug。该解决方法比较ugly，但由于其他解法回归成本高，而需求因头号任务比较紧急，因此采用此解法
            vc.delegate = nil;
        }
    }
}

#pragma mark - TTVOnVideoADViewControllerDelegate

- (void)ttvOnVideoADViewControllerComponentDidShowWithModle:(TTVOnVideoModel *)model
{
    NSMutableDictionary * v3Dict = [[self onVideoTrackCommonParams] mutableCopy];
    v3Dict[@"comp_id"] = @(model.materialComponent.materialId);
    v3Dict[@"comp_type"] = [model getComponentTypeName];
    [TTTrackerWrapper eventV3:@"onvideo_comp_show" params:v3Dict];
}

- (void)ttvOnVideoADViewControllerComponentDidClickWithModle:(TTVOnVideoModel *)model
{
    // webUrl和openUrl同时为空时，不发送点击埋点
    BOOL shouldTrack = !(isEmptyString(model.materialComponent.openURL) && isEmptyString(model.materialComponent.webURL));
    if (!shouldTrack && model.materialCard) {
        shouldTrack = YES;
    }
    if (shouldTrack) {
        NSMutableDictionary * v3Dict = [[self onVideoTrackCommonParams] mutableCopy];
        v3Dict[@"comp_id"] = @(model.materialComponent.materialId);
        v3Dict[@"comp_type"] = [model getComponentTypeName];
        v3Dict[@"video_pct"] = @(ceilf(self.playerViewController.currentPlaybackTime / self.playerViewController.duration * 1000) / 10.0);
        [TTTrackerWrapper eventV3:@"onvideo_comp_click" params:v3Dict];
    }
}

- (void)ttvOnVideoADViewControllerCardViewDidShowWithModle:(TTVOnVideoModel *)model
{
    NSMutableDictionary * v3Dict = [[self onVideoTrackCommonParams] mutableCopy];
    v3Dict[@"card_id"] = @(model.materialCard.materialId);
    [TTTrackerWrapper eventV3:@"onvideo_card_show" params:v3Dict];
}

- (void)ttvOnVideoADViewControllerCardViewDidDismissWithModle:(TTVOnVideoModel *)model
{
    NSMutableDictionary * v3Dict = [[self onVideoTrackCommonParams] mutableCopy];
    v3Dict[@"card_id"] = @(model.materialCard.materialId);
    v3Dict[@"video_pct"] = @(ceilf(self.playerViewController.currentPlaybackTime / self.playerViewController.duration * 1000) / 10.0);
    [TTTrackerWrapper eventV3:@"onvideo_card_cancel" params:v3Dict];
}

- (void)ttvOnVideoADViewControllerCardViewDidClickWithModle:(TTVOnVideoModel *)model
{
    // webUrl和openUrl同时为空时，不发送点击埋点
    BOOL shouldTrack = !(isEmptyString(model.materialCard.openURL) && isEmptyString(model.materialCard.webURL));
    if (shouldTrack) {
        NSMutableDictionary * v3Dict = [[self onVideoTrackCommonParams] mutableCopy];
        v3Dict[@"card_id"] = @(model.materialCard.materialId);
        v3Dict[@"video_pct"] = @(ceilf(self.playerViewController.currentPlaybackTime / self.playerViewController.duration * 1000) / 10.0);
        [TTTrackerWrapper eventV3:@"onvideo_card_click" params:v3Dict];
    }
}

- (NSDictionary *)onVideoTrackCommonParams
{
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
    params[@"category_name"] = self.orderedData.categoryID;
    params[@"log_pb"] = self.state.detailModel.logpbDic;
    params[@"group_id"] = @(self.orderedData.article.uniqueID);
    params[@"section"] = self.playerViewController.isFullScreen ? @"fullplayer" : @"player";
    params[@"position"] = @"detail";
    return [params copy];
}

#pragma mark - 前贴广告

- (void)addFrontPasterAD {
    if (self.frontPasterADVC) {
        [self removeFrontPasterAD];
    }
    
    if(![TTVFrontPasterADManager shouldShowFrontPasterWithData:self.orderedData]) {
        return;
    }
    
    TTVFrontPasterADURLRequestInfo *requestInfo = [[TTVFrontPasterADURLRequestInfo alloc] init];
    requestInfo.groupID = self.orderedData.article.groupModel.groupID;
    requestInfo.itemID = self.orderedData.article.itemID;
    requestInfo.preadParamsStr = self.orderedData.article.preadParamsStr;
    requestInfo.category = self.orderedData.categoryID;
    requestInfo.adFrom = @"textlink";
    requestInfo.isFeedNearbyAD = NO;
    
    self.frontPasterADVC = [[TTVFrontPasterADViewController alloc] initWithRequestInfo:requestInfo];
    self.frontPasterADVC.delegate = self;
    self.frontPasterADVC.pasterFlowService.videoSize = [[self.playerViewController.videoInfo videoInfoForType:self.playerViewController.currentResolution] getValueNumber:VALUE_SIZE].floatValue;
    self.frontPasterADVC.pasterFlowService.flowTracker = [[TTVPasterFlowServiceTrack alloc] initWithViewModel:self.playerViewController.viewModel];
    self.playerViewController.flowTipEnable = NO;
    self.playerViewController.gestureEnable = NO;
    self.frontPasterADVC.isInDetail = YES;
    [self.playerViewController.rotateViewController addChildViewController:self.frontPasterADVC];
    [self.playerViewController.rotateViewController.view addSubview:self.frontPasterADVC.view];
    [self.frontPasterADVC didMoveToParentViewController:self.playerViewController.rotateViewController];
    [self.frontPasterADVC.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self.frontPasterADVC.view.superview);
    }];
    [self.frontPasterADVC pasterDidAppera];
    self.playerViewController.frontPaster = self.frontPasterADVC;
    
    WeakSelf;
    [RACObserve(self.playerViewController.fullScreenObserverState, fullScreenObserver) subscribeNext:^(NSNumber *fullScreen) {
        StrongSelf;
        [self.frontPasterADVC setFullScreen:[fullScreen boolValue] animated:YES];
    }];
}

- (void)removeFrontPasterAD {
    self.playerViewController.flowTipEnable = !self.frontPasterADVC.pasterFlowService.didMakeFlowDecision;
    self.playerViewController.gestureEnable = YES;
    [self removeFrontPasterADVC:self.frontPasterADVC];
    self.playerViewController.frontPaster = nil;
    self.frontPasterADVC = nil;
}

- (void)removeFrontPasterADVC:(TTVFrontPasterADViewController *)frontVC {
    [frontVC stop];
    frontVC.delegate = nil;
    [frontVC willMoveToParentViewController:nil];
    [frontVC.view removeFromSuperview];
    [frontVC removeFromParentViewController];
    [frontVC pasterDidDisappear];
}

#pragma mark - 前贴广告 TTVFrontPasterADViewControllerDelegate

- (void)frontPasterADReadToPlay:(TTVFrontPasterADViewController *)pasterAD
{
    if ([self.delegate respondsToSelector:@selector(xgvd_frontPasterIsReadyToPlay)]) {
        [self.delegate xgvd_frontPasterIsReadyToPlay];
    }
}

- (void)frontPasterADDidFetchADModel:(TTVFrontPasterModel *)pasterModel error:(NSError *)error {
    if (!error && pasterModel) {
        
    } else {
        [self removeFrontPasterAD];
        if ([self.delegate respondsToSelector:@selector(xgvd_resumePlayAfterFrontPasterPlayOver)]) {
            [self.delegate xgvd_resumePlayAfterFrontPasterPlayOver];
        }
    }
}

- (void)frontPasterADDidSkip:(TTVFrontPasterADViewController *)pasterAD
{
    [self removeFrontPasterAD];
    if ([self.delegate respondsToSelector:@selector(xgvd_resumePlayAfterFrontPasterPlayOver)]) {
        [self.delegate xgvd_resumePlayAfterFrontPasterPlayOver];
    }

}

- (void)frontPasterADDidFinish:(TTVFrontPasterADViewController *)pasterAD error:(NSError *)error
{
    [self removeFrontPasterAD];
    if ([self.delegate respondsToSelector:@selector(xgvd_resumePlayAfterFrontPasterPlayOver)]) {
        [self.delegate xgvd_resumePlayAfterFrontPasterPlayOver];
    }
}

- (void)frontPasterADDidToggleFullScreen:(BOOL)isToggleFullScreen animated:(BOOL)animated completion:(void (^)(BOOL))completion {
    if (self.playerViewController) {
        [self.playerViewController setFullScreen:isToggleFullScreen animated:animated completion:completion];
    }
}

- (void)frontPasterADDidToggleFullScreen:(BOOL)isToggleFullScreen animated:(BOOL)animated{
    [self frontPasterADDidToggleFullScreen:isToggleFullScreen animated:animated completion:^(BOOL finished) {
        
    }];
}

#pragma mark - TTPlayerAdFinishViewDelegate
- (void)ttPlayerAdFinishViewDidClikedADActionButton:(TTPlayerAdFinishView *)finishView {
    NSMutableDictionary *trackerParams = [NSMutableDictionary dictionary];
    BOOL immerseEnable = NO;
    if (self.playerViewController.immerseEnable
        && self.playerViewController.isFullScreen) {
        trackerParams[@"refer"] = @"bg_button";
        immerseEnable = YES;
    }
    [TTVideoDetailADPlayerLogHelper sendPlayerAdButtonClickedActionEventWithOrderedData:self.orderedData immerseEnable:immerseEnable playerViewController:self.playerViewController extraDic:trackerParams];
    [TTVideoDetailADPlayerLogHelper executeAdButtonClickedActionWithOrderedData:self.orderedData playerViewController:self.playerViewController immerseEnable:immerseEnable];
}

- (void)ttPlayerAdFinishViewDidClikedADTitle:(TTPlayerAdFinishView *)finishView {
    NSMutableDictionary *trackerParams = [NSMutableDictionary dictionary];
    BOOL immerseEnable = NO;
    if (self.playerViewController.immerseEnable
        && self.playerViewController.isFullScreen) {
        trackerParams[@"refer"] = @"bg_source";
        immerseEnable = YES;
    }
    [TTVideoDetailADPlayerLogHelper sendPlayerAdClickedActionWithOrderedData:self.orderedData immerseEnable:immerseEnable playerViewController:self.playerViewController extraDic:trackerParams];
    [TTVideoDetailADPlayerLogHelper executeAdClickedActionWithWithOrderedData:self.orderedData playerViewController:self.playerViewController immerseEnable:immerseEnable deeplinkEnable:NO];
}

- (void)ttPlayerAdFinishViewDidClikedADIcon:(TTPlayerAdFinishView *)finishView {
    NSMutableDictionary *trackerParams = [NSMutableDictionary dictionary];
    BOOL immerseEnable = NO;
    if (self.playerViewController.immerseEnable
        && self.playerViewController.isFullScreen) {
        trackerParams[@"refer"] = @"bg_photo";
        immerseEnable = YES;
    }
    [TTVideoDetailADPlayerLogHelper sendPlayerAdClickedActionWithOrderedData:self.orderedData immerseEnable:immerseEnable playerViewController:self.playerViewController extraDic:trackerParams];
    [TTVideoDetailADPlayerLogHelper executeAdClickedActionWithWithOrderedData:self.orderedData playerViewController:self.playerViewController immerseEnable:immerseEnable deeplinkEnable:NO];
}

- (void)ttPlayerAdFinishViewDidEndCountDownTimer:(TTPlayerAdFinishView *)finishView {
    [finishView endCountdownTip];
    if ((self.playerViewController.immerseEnable
         || [self.playerViewController.immersePlayerInteracter canAutoPlayNext])
        && self.orderedData.adID.longLongValue > 0
        && self.playerViewController.isFullScreen) {
        [self.playerViewController.immersePlayerInteracter playNextImmediately];
    }
}

#pragma mark - TTImmersePlayerInteracterDelegate

- (BOOL)immersePlayerInvokePlayOutSide:(TTImmersePlayerInteracter *)interactor {
    return YES;
}

- (BOOL)immersePlayerDisableScreenCastOutSide:(TTImmersePlayerInteracter *)interactor{
    // 激进详情页先屏蔽投屏
    return self.viewController.explore;
}

- (void)immersePlayerWillCloseWithInteracter:(TTImmersePlayerInteracter *)interactor {
    self.immerseFinishCount.finishCount = 0;
    if (self.playerViewController.viewModel.autoType == TTPlayerViewModelAutoFinishType) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"finish_count"] = @(0);
        [self.playerViewController.viewModel addExtra:params forEvents:@[@"video_over_auto", @"video_over_auto_segment"]];
    } else {
        [self.playerViewController.viewModel removeExtraParam:@"finish_count" forEvents:@[@"video_over_auto", @"video_over_auto_segment"]];
    }
    self.storeMiddleware = nil;
    self.immerseStream = nil;
    self.filterMiddleware = nil;
    self.toOrderedDataMiddleware = nil;
    self.sortMiddleware = nil;
}

- (void)immersePlayerDidTriggleFinishCount:(TTImmersePlayerInteracter *)interactor {
    self.immerseFinishCount.finishCount = 0;
    if (self.playerViewController.viewModel.autoType == TTPlayerViewModelAutoFinishType) {
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        params[@"finish_count"] = @(0);
        [self.playerViewController.viewModel addExtra:params forEvents:@[@"video_over_auto", @"video_over_auto_segment"]];
    } else {
        [self.playerViewController.viewModel removeExtraParam:@"finish_count" forEvents:@[@"video_over_auto", @"video_over_auto_segment"]];
    }
}

- (TTVFeedImmerseContextFinishCount *)immersePlayerFinishCountPointWithInteractor:(TTImmersePlayerInteracter *)interactor {
    if (interactor.context.finishCount) {
        return interactor.context.finishCount;
    }
    return self.immerseFinishCount;
}

- (BOOL)immersePlayerFilterPortait:(TTImmersePlayerInteracter *)interactor {
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)immersePlayerRequestOutSideStreamWithInteracter:(TTImmersePlayerInteracter *)interactor {
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        NSMutableDictionary *ret = @{}.mutableCopy;
        ret[kTTImmersePlayerInteracterOutsideStreamKey] = self.immerseStream;
        ret[kTTImmersePlayerInteracterOutsideStreamStoreKey] = self.storeMiddleware;
        ret[kTTImmersePlayerInteracterOutsideStreamToOrderedDataKey] = self.toOrderedDataMiddleware;
        ret[kTTImmersePlayerInteracterOutsideStreamFilterKey] = self.filterMiddleware;
        ret[kTTImmersePlayerInteracterOutsideStreamSortKey] = self.sortMiddleware;
        return ret;
    }
    return @{};
}

- (void)immersePlayerInteracter:(TTImmersePlayerInteracter *)interactor didUpdatePlayerModel:(TTImmerseModel *)playerModel {
    if (self.viewController.explore) {
        [self p_handleRadicalDetailImmersePlayerInteracter:interactor didUpdatePlayerModel:playerModel];
    } else {
        [self p_handleNormalDetailImmersePlayerInteracter:interactor didUpdatePlayerModel:playerModel];
    }
}

- (NSArray<TTImmerseModel *> *)immersePlayerGetBringPlayerModelsInteracter:(TTImmersePlayerInteracter *)interactor {
    TTImmerseModel *playerModel = [TTImmerseModelFactory modelWithOriginalData:self.orderedData enterSource:TTImmersePlayerEnterSource_VideoDetail index:0];
    NSMutableArray<TTImmerseModel *> *ret = [NSMutableArray arrayWithCapacity:1];
    if (playerModel) {
        if ([playerModel isKindOfClass:[TTImmersePlayerModel class]]) {
            TTImmersePlayerModel *inPlayerModel = (id)playerModel;
            inPlayerModel.isBringToImmerseList = YES;
        }
        [ret addObject:playerModel];
    }
    return ret;
}

- (BOOL)immersePlayerNeedPlayNextAutoWithInteractor:(TTImmersePlayerInteracter *)interactor {
    NSNumber *disableAutoPlaySettings = [[TTSettingsManager sharedManager] settingForKey:@"video_immersive" defaultValue:@{} freeze:NO][@"disable_auto_play"];
    if (![disableAutoPlaySettings isKindOfClass:[NSNumber class]]) {
        disableAutoPlaySettings = nil;
    }
    BOOL canAutoPlay = !disableAutoPlaySettings || ![disableAutoPlaySettings boolValue];
    return canAutoPlay || [self.orderedData.adID longLongValue] > 0;
}

- (NSString *)immersePlayerCategoryNameWithInteracter:(TTImmersePlayerInteracter *)interactor {
    BOOL hasSeries = [self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries];
    //分p使用自己的category
    if (hasSeries) {
        return self.categoryName;
    }
    __block BOOL isHorImmersiveCategory = NO;
    TTVideoTabViewController *tabViewController = nil;
    TTNavigationController *nav = (TTNavigationController *)[TTVTabbarItemsManager tabbarItemModelWithItemType:TTVTabbarItems_NormalVideo].viewController;
    if (![nav isKindOfClass:TTNavigationController.class]) {
        return nil;
    }
    tabViewController = nav.viewControllers.firstObject;
    if (![tabViewController isKindOfClass:[TTVideoTabViewController class]]) {
        return nil;
    }
    NSArray<TTSegmentedCategoryItem *> *segItems = tabViewController.categoryItems;
    if (!isEmptyString(self.orderedData.categoryID)) {
        [segItems enumerateObjectsUsingBlock:^(TTSegmentedCategoryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[TTSegmentedCategoryItem class]]) {
                if ([obj.channel.horImmersiveCategory isEqualToString:self.orderedData.categoryID ?: @""]) {
                    isHorImmersiveCategory = YES;
                }
            }
        }];
    }
    if (isHorImmersiveCategory) {
        return self.orderedData.categoryID;
    } else {
        __block NSString *category = @"";
        [segItems enumerateObjectsUsingBlock:^(TTSegmentedCategoryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[TTSegmentedCategoryItem class]]) {
                if ([obj.channel.category isEqualToString:self.orderedData.categoryID ?: @""]) {
                    category = obj.channel.horImmersiveCategory;
                    *stop = YES;
                }
            }
        }];
        return category;
    }
}


- (TTImmersePlayerEnterSource)immersePlayerEnterSourceWithInteracter:(TTImmersePlayerInteracter *)interactor {
    return TTImmersePlayerEnterSource_VideoDetail;
}

- (void)immersePlayerWillBeginWithInteracter:(TTImmersePlayerInteracter *)interactor {
    self.immerseFinishCount.finishCount = 0;
    if ([self.viewController respondsToSelector:@selector(hasSeries)] && [self.viewController hasSeries]) {
        NSMutableArray *data = @[].mutableCopy;
        for (Article *article in [self.seriesViewModel nextModels]) {
            NSMutableDictionary *dict = ([article zzz_originalDict] ?: @{}).mutableCopy;
            [dict addEntriesFromDictionary:article.toDictionary ?: @{}];
            NSMutableDictionary *d = @{}.mutableCopy;
            d[@"content"] = dict;
            d[@"code"] = @"";
            TTVFeedImmerseStreamPageStreamDataJSONModel *model = [[TTVFeedImmerseStreamPageStreamDataJSONModel alloc] initWithDictionary:d error:nil];
            if (model) {
                [data addObject:model];
            }
        }
        TTVFeedImmerseStreamPageStreamJSONModel *model = [[TTVFeedImmerseStreamPageStreamJSONModel alloc] init];
        model.ttv_data = (id)data;
        model.ttv_total_number = data.count;
        model.ttv_has_more = [self.seriesViewModel hasMoreNext];
        
        self.storeMiddleware = [[TTVImmerseStoreMiddleware alloc] initWithAllData:model];
        self.immerseStream = [[TTDetailSeriseImmerseStream alloc] initWithSeriseViewModel:self.seriesViewModel];
        self.filterMiddleware = [[TTDetailSeriesImmerseFilterMiddleware alloc] init];
        self.sortMiddleware = [[TTVImmerseStreamPSeriesDataSortMiddleware alloc] init];
        self.toOrderedDataMiddleware = [[TTImmerseStreamToOrderedDataMiddleware alloc] init];
        self.toOrderedDataMiddleware.category = self.categoryName;
        self.toOrderedDataMiddleware.parentImprId = self.detailModel.seriesDetailModel.parentImprId;
        self.toOrderedDataMiddleware.parentImprType = self.detailModel.seriesDetailModel.parentImprType;
        self.toOrderedDataMiddleware.parentGroupId = self.detailModel.seriesDetailModel.parentGroupId;
        self.toOrderedDataMiddleware.parentGroupSource = self.detailModel.seriesDetailModel.parentGroupSource;
        self.toOrderedDataMiddleware.parentCategoryName = self.detailModel.seriesDetailModel.parentCategoryName;
    }
}

- (BOOL)immersePlayerWillRequestInSegmentWithInteractor:(TTImmersePlayerInteracter *)interactor {
    return self.seriesViewModel.shouldShowSegments;
}

- (void)p_handleRadicalDetailImmersePlayerInteracter:(TTImmersePlayerInteracter *)interactor didUpdatePlayerModel:(TTImmerseModel *)playerModel{
    // 激进详情页替换当前页面
    TTImmersePlayerModel *inPlayerModel = (id)playerModel;
    if (![inPlayerModel isKindOfClass:[TTImmersePlayerModel class]]) {
        if (inPlayerModel) {
            NSAssert(NO, @"数据类型不对");
        }
        return;
    }
    if ([inPlayerModel.orginalModel isKindOfClass:[ExploreOrderedData class]]) {
        ExploreOrderedData *orderedData = (id)inPlayerModel.orginalModel;
        
        //广告视频要push详情页，不能分块刷新
        if ([orderedData.adID longLongValue] > 0) {
            // 广告先不管
        }
        //其它视频分块刷新
        else {
            XGVideoDetailAction *action = [[XGVideoDetailAction alloc] initWithType:XGVideoDetailActionType_ChangePlayModelByFullscreenImmerse];
            [self.detailStore dispatch:action];
            if (![self.detailModel.categoryID isEqualToString:orderedData.categoryID]) {
                //全屏沉浸式切换categoryID会变，需要更新
                self.detailModel.categoryID = orderedData.categoryID;
            }
        }
        
        [self.detailStore dispatch:[XGVideoDetailAction immersePlayNextWithOrderedData:orderedData]];
    }
}

- (void)p_handleNormalDetailImmersePlayerInteracter:(TTImmersePlayerInteracter *)interactor didUpdatePlayerModel:(TTImmerseModel *)playerModel{
    TTImmersePlayerModel *inPlayerModel = (id)playerModel;
    if (![inPlayerModel isKindOfClass:[TTImmersePlayerModel class]]) {
        
    }
    NSAssert(self.viewController.navigationController.topViewController == self.viewController ||
             self.viewController.navigationController.topViewController == self.viewController.parentViewController, @"保证执行此操作时此vc在导航控制器最上面，发生assert不匹配时应该在此vc被覆盖后将delegate移除");
    if (self.viewController.navigationController.topViewController != self.viewController &&
        self.viewController.navigationController.topViewController != self.viewController.parentViewController) {
        if(interactor.delegate == self) {
            interactor.delegate = nil;
        }
        return;
    }
    if ([inPlayerModel.orginalModel isKindOfClass:[ExploreOrderedData class]]) {
        ExploreOrderedData *orderedData = (id)inPlayerModel.orginalModel;
        
        //广告视频要push详情页，不能分块刷新
        if ([orderedData.adID longLongValue] > 0) {
            [TTVideoPlayNextService playNextWithCurrentDetailViewController:self.viewController nextOrderedData:orderedData];
        }
        //其它视频分块刷新
        else {
            XGVideoDetailAction *action = [[XGVideoDetailAction alloc] initWithType:XGVideoDetailActionType_ChangePlayModelByFullscreenImmerse];
            [self.detailStore dispatch:action];
            if (![self.detailModel.categoryID isEqualToString:orderedData.categoryID]) {
                //全屏沉浸式切换categoryID会变，需要更新
                self.detailModel.categoryID = orderedData.categoryID;
            }
            [TTVideoPlayNextService playNextWithCurrentDetailViewController:self.viewController nextArticle:orderedData.article partUpdate:YES byTapSeries:NO autoPlay:NO];
        }
        
        [self.detailStore dispatch:[XGVideoDetailAction immersePlayNextWithOrderedData:orderedData]];
    }
}

#pragma mark - showPreviewImageView NSNotification

- (void)showPreviewImageView:(NSNotification *)noti {
    objc_setAssociatedObject(self, kEnableFullScreenSave, @(self.playerViewController.enableFullScreen ?: NO), OBJC_ASSOCIATION_COPY_NONATOMIC);
    self.playerViewController.enableFullScreen = NO;
}

- (void)dismissPreviewImageView:(NSNotification *)noti {
    NSNumber *enable = objc_getAssociatedObject(self, kEnableFullScreenSave);
    if ([enable isKindOfClass:[NSNumber class]]) {
        self.playerViewController.enableFullScreen = [enable boolValue];
    }
    objc_setAssociatedObject(self, kEnableFullScreenSave, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - skStoreView NSNotification

- (void)skStoreViewDidAppear:(NSNotification *)notification
{
    if (self.playerViewController.playbackState == TTVideoEnginePlaybackStatePlaying) {
        [self.playerViewController pause];
        self.moviePausedByOpenAppStore = YES;
    }
    
    self.pasterADViewController.isAppeared = NO;
    if (self.pasterADViewController.isPlayingImage || self.pasterADViewController.isPlayingMovie) {
        [self.pasterADViewController pauseCurrentAD];
    }
}

- (void)skStoreViewDidDisappear:(NSNotification *)notification
{
    BOOL hasFinishView = NO;
    TTPlayerAdFinishView *adFinishView = [TTPlayerAdFinishView findNearestAdFinishViewInPlayer:self.playerViewController];
    hasFinishView = adFinishView != nil;
    //    if (self.finishControlView) {
    //        hasFinishView = YES;
    //    }
    if (!hasFinishView && self.moviePausedByOpenAppStore && [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [self.playerViewController play];
    }
    self.moviePausedByOpenAppStore = NO;
    
    self.pasterADViewController.isAppeared = YES;
    if (self.pasterADViewController.isPaused) {
        [self.pasterADViewController resumeCurrentAD];
    }
}

#pragma mark - menu delegate & TTPlayerFullScreenMoreMenuViewDataSource

- (BOOL)videoDidCollected
{
    return [self.orderedData.article.userRepined boolValue];
}

- (BOOL)videoDisableDownload
{
    return [self.orderedData.article.banDownload boolValue];
}

- (void)downloadVideoAction:(UIView<TTPlayerFullScreenMoreMenuViewProtocol> *)menu
{
    [TTVVideoCacheMediator cacheWithExploreOrderedData:self.orderedData playerViewController:self.playerViewController trackPostion:@"detail"];
}

- (void)videoDownloadAction:(UIView<TTPlayerFullScreenMoreMenuViewProtocol> *)menu {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:4];
    params[@"group_id"] = @(self.orderedData.article.uniqueID);
    params[@"author_id"] = [self.article.userInfo btd_stringValueForKey:@"user_id"];
    params[@"enter_from"] = self.detailModel.enterFrom;
    params[@"position"] = @"full_screen";
    params[@"is_author_action"] = @(0);
    params[@"video_type"] = @"short_video";
    [TTTrackerWrapper eventV3:@"rt_download_to_local_ck" params:[params copy]];
    [TTVVideoCacheMediator downloadWithArticle:self.orderedData.article categoryID:self.orderedData.categoryID logPassBackDict:self.orderedData.logPassBackDict playerViewController:self.playerViewController trackDict:params];
}

- (void)shareVideoAction:(UIView<TTPlayerFullScreenMoreMenuViewProtocol> *)menu
{
    [self shareActionWithPlayerViewController:self.playerViewController];
}

- (void)dislikeVideoAction:(UIView<TTPlayerFullScreenMoreMenuViewProtocol> *)menu
{
    self.playerViewController.blockMonitoring = NO;
    WeakSelf;
    [self.playerViewController setFullScreen:NO animated:YES completion:^(BOOL finish) {
        StrongSelf;
        // 兼容xcode 10, iOS 13转屏
        [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_ShowDislike info:nil]];
    }];
    
    if (TTVideoEnginePlaybackStatePlaying == self.playerViewController.playbackState) {
        [self.playerViewController pause];
    }
    
}

- (void)collectedVideoAction:(UIView<TTPlayerFullScreenMoreMenuViewProtocol> *)menu collected:(BOOL)collected
{
    [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_ToggleCollect info:nil]];
}

- (void)reportVideoAction:(TTPlayerFullScreenMoreMenuView *)menu
{
    WeakSelf;
    [self.playerViewController setFullScreen:NO animated:YES completion:^(BOOL finish) {
        StrongSelf;
        [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_ShowReport info:nil]];
    }];
    
    if (TTVideoEnginePlaybackStatePlaying == self.playerViewController.playbackState) {
        [self.playerViewController pause];
    }
}

- (void)rotateToSmallScreen
{
    if (self.playerViewController.isFullScreen) {
        [self.playerViewController setFullScreen:NO animated:NO];
    }
    if (TTVideoEnginePlaybackStatePlaying == self.playerViewController.playbackState) {
        [self.playerViewController pause];
    }
}

#pragma mark - playbackStateDidChanged NSNotification

- (void)playerViewControllerPlaybackStateDidChanged:(NSNotification *)notification
{
    TTVPlayerAdapterViewController *playerViewController = notification.object;
    if (![playerViewController isKindOfClass:[TTVPlayerAdapterViewController class]]) {
        return;
    }
    
    if (playerViewController != self.playerViewController) {
        return;
    }
    
    [self.detailStore dispatch:[XGVideoDetailAction actionWithType:XGVideoDetailActionType_PlaybackStateChanged info:@{XGVideoDetailActionInfo_PlayerVC:playerViewController}]];
}

#pragma mark - pannel NSNotification

- (void)panelDidShow:(NSNotification *)notification
{
    self.playerViewController.enableFullScreen = NO;
}

- (void)panelWillDismiss:(NSNotification *)notification
{
    self.playerViewController.enableFullScreen = YES;
}

#pragma mark - 全屏互动

- (void)receivePlayerLeaveNotification:(NSNotification *)notification
{
    self.fullScreenIfNeed = self.playerViewController.isFullScreen;
    self.playerViewController.blockMonitoring = YES;
}

#pragma mark - TTPlayerGestureControllerPanGestStatusDelegate
- (BOOL)ttv_panGesture:(UIPanGestureRecognizer *)panGesture shouldBeginForDirection:(TTPlayerGestureDirection)direction{
    if (!self.viewController.explore) {
        return YES;
    }
    if (self.playerViewController.isFullScreen) {
        return YES;
    }
    if (self.playerViewController.controlsShowing) {
        return YES;
    }
    return NO;
}

#pragma mark - Log

//详情页视频播放展示重播、分享
- (void)logVideoOver
{
    NSMutableDictionary * eventContext = [[NSMutableDictionary alloc] init];
    [eventContext setValue:@"detail" forKey:@"position"];
    NSString * label = [self.playerViewController dataTrackLabel];
    label = [label stringByReplacingOccurrencesOfString:@"click" withString:@"show"];
    [TTTrackerWrapper event:@"replay" label:label value:[self articleGroupID] extValue:nil extValue2:nil dict:eventContext];
    [TTTrackerWrapper event:@"share" label:label value:[self articleGroupID] extValue:nil extValue2:nil dict:eventContext];
}

- (NSString *)articleGroupID
{
    return [@(self.state.detailModel.article.uniqueID) stringValue] ?: self.state.detailModel.article.groupModel.groupID;
}

- (void)updateSceneSourceType{
    NSString *enterFrom = self.state.detailModel.enterFrom;
    TTPlayerSceneSourceType sceneSourceType = TTPlayerSceneSourceType_Detail;
    if (self.playerViewController.isFullScreen) {
        sceneSourceType = TTPlayerSceneSourceType_Immerse;
    }else if([enterFrom containsString:@"search"]){
        sceneSourceType = TTPlayerSceneSourceType_Search;
    }else if ([enterFrom containsString:@"pgc"]){
        sceneSourceType = TTPlayerSceneSourceType_Pgc;
        NSString *tabName = [self.state.detailModel.extraTrackerLogParamas btd_stringValueForKey:@"tab_name" default:nil];
        self.playerViewController.viewModel.sceneSubSource = tabName;
    }else if ([enterFrom containsString:@"category"]){
        sceneSourceType = TTPlayerSceneSourceType_Feed;
    }else if ([enterFrom containsString:@"related"]){
        sceneSourceType = TTPlayerSceneSourceType_DetailRelated;
    }else if ([enterFrom containsString:@"history"]){
        sceneSourceType = TTPlayerSceneSourceType_History;
    }else if ([enterFrom containsString:@"favorite"]){
        sceneSourceType = TTPlayerSceneSourceType_Like;
    }
    self.playerViewController.viewModel.sceneSourceType = sceneSourceType;
    NSString *scene = [NSString stringWithFormat:@"%zd_%zd",sceneSourceType,self.playerViewController.viewModel.source];
    [self.playerViewController setOptionForKey:VEKKeyLogCustomStr_NSString value:scene];
}
#pragma mark - Setter & Getter Method

- (BOOL)showPlayerMoreBtn
{
    if (NewsGoDetailFromSourceRelateReading == self.state.detailModel.fromSource 
        && self.state.detailModel.adID.longLongValue > 0
        && !self.playerViewController.immerseEnable) {
        return NO;
    }
    return YES;
}

@end
