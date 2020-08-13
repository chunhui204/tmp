//
//  TTVPlayerAdapterViewController+VideoEngine.m
//  Article
//
//  Created by 戚宽 on 2019/8/12.
//

#import "TTVPlayerAdapterViewController+VideoEngine.h"
#import "TTVPlayerAdapterViewController+Internal.h"
#import "TTVPlayerAdapterViewController+Controls.h"
#import "TTVPlayerAdapterViewController+Tracker.h"
#import "TTVPlayerAdapterViewController+Danmaku.h"
#import "TTSettingsManager.h"
#import "TTVSettingsConfiguration.h"
#import <BDScreenCast/BDScreenCastAdapter.h>
#import "TTVPlayerAdapterViewController+ScreenCast.h"
#import "TTVPlayerQosTrackerPart.h"
#import "TTVPlayerAction+Extension.h"
#import <TTVPlayerPod/TTVPlayer+Engine.h>
#import <TTVPlayerPod/TTVPlayer+Part.h>
#import <TTVPlayerPod/TTVFreeZoomingPart.h>
#import "SSCommonLogic+VideoPlayer.h"
#import "TTVPlayerAdapterViewController+AudioModel.h"

@interface TTVPlayerAdapterViewController ()

@property (nonatomic, strong, readwrite) TTVPlayerEngineObserverState *engineObserverState;
@property (nonatomic, strong, readonly) NSHashTable<id<TTVPlayerEngineBehaviorProtocol>> *engineBehaviorObservers;

@end

@implementation TTVPlayerAdapterViewController (VideoEngine)

- (TTVideoEngine *)videoEngine{
    if ([self.playerVCtrl respondsToSelector:@selector(videoEngine)]) {
        return [self.playerVCtrl valueForKey:@"videoEngine"];
    }
    return nil;
}

#pragma mark - readonly property
- (NSTimeInterval)duration {
    return self.playerVCtrl.duration;
}

- (NSTimeInterval)currentPlaybackTime {
    return self.playerVCtrl.playbackTime.currentPlaybackTime;
}

- (NSTimeInterval)playableDuration {
    return self.playerVCtrl.playableDuration;
}

- (NSTimeInterval)durationWatched {
    return self.playerVCtrl.durationWatched;
}

- (UIView *)playerView {
    return self.playerVCtrl.playerView;
}

- (TTVideoEngineResolutionType)currentResolution {
    return (TTVideoEngineResolutionType)self.playerVCtrl.currentResolution;
}

- (TTVideoEngineResolutionType)currentShowingResolution {
    if (self.playerVCtrl.playerState.resolutionState.fakeAutoResolutionSelected) {
        return TTVideoEngineResolutionTypeAuto;
    }
    return [self currentResolution];
}

- (void)setCustomResolutionMap:(NSDictionary *)resolutionMap {
    self.playerVCtrl.resolutionMap = resolutionMap;
}

- (TTVideoEngineLoadState)loadState {
    return (TTVideoEngineLoadState)self.playerVCtrl.loadState;
}

- (TTVideoEnginePlaybackState)playbackState {
    return (TTVideoEnginePlaybackState)self.playerVCtrl.playbackState;
}

- (TTVideoEngineState)state {
    return (TTVideoEngineState)self.playerVCtrl.state;
}

- (BOOL)shouldPlay {
    return self.playerVCtrl.shouldPlay;
}

- (TTVideoEngineAVPlayerItemAccessLog *)accessLog {
    return [self videoEngine].accessLog;
}

- (TTVideoEngineScalingMode)scaleMode {
    TTVFreeZoomingPart *freeZooming = (id) [self.playerVCtrl partForKey:TTVPlayerPartKey_FreeZooming];
    if (freeZooming) {
        // Players with free zooming enabled is not using the engine's scale ability.
        return freeZooming.preferredAspectFill
            ? TTVideoEngineScalingModeAspectFill : TTVideoEngineScalingModeNone;
    }
    
    return [self videoEngine].scaleMode;
}

- (NSInteger)biterate{
    return self.playerVCtrl.biterate;
}
#pragma mark - readwrite property
- (void)setIsDashSource:(BOOL)isDashSource {
    objc_setAssociatedObject(self, @selector(isDashSource), @(isDashSource), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isDashSource {
    return [objc_getAssociatedObject(self,@selector(isDashSource)) boolValue];
}

- (void)setSettingsBlock:(TTVPlayerSettingsBlock)settingsBlock{
    objc_setAssociatedObject(self, @selector(settingsBlock), settingsBlock, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (TTVPlayerSettingsBlock)settingsBlock{
    return objc_getAssociatedObject(self, @selector(settingsBlock));
}

- (BOOL)h265Enabled {
    return self.playerVCtrl.h265Enabled;
}

- (BOOL)muted {
    return self.playerVCtrl.muted;
}

- (void)setMuted:(BOOL)muted {
    self.playerVCtrl.muted = muted;
}

- (CGFloat)playbackSpeed {
    return self.playerVCtrl.playbackSpeed;
}

- (void)setPlaybackSpeed:(CGFloat)playbackSpeed {
    [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction changeSpeedToAction:playbackSpeed shouldShowSpeedTip:NO]];
}

- (void)setPlaybackSpeed:(CGFloat)playbackSpeed section:(NSString *)section {
    self.playerVCtrl.playbackSpeed = playbackSpeed;
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:2];
    info[TTVPlayerActionInfo_BOOL] = @(NO);
    info[@"section"] = section;
    [self.playerVCtrl.playerStore dispatch:[[TTVReduxAction alloc] initWithType:TTVPlayerActionType_ChangeSpeed info:info]];
}

- (NSString *)encryptedDecryptionKey {
    return [self videoEngine].encryptedDecryptionKey;
}

- (void)setEncryptedDecryptionKey:(NSString *)encryptedDecryptionKey {
    [[self videoEngine] setEncryptedDecryptionKey:encryptedDecryptionKey];
}

- (id<TTVideoEngineDelegate>)engineDelegate {
    return [self videoEngine].delegate;
}

- (void)setEngineDelegate:(id<TTVideoEngineDelegate>)engineDelegate {
    [self videoEngine].delegate = engineDelegate;
}

- (void)setEngineObserverState:(TTVPlayerEngineObserverState *)engineObserverState {
    objc_setAssociatedObject(self, @selector(engineObserverState), engineObserverState, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (TTVPlayerEngineObserverState *)engineObserverState {
    return objc_getAssociatedObject(self, @selector(engineObserverState));
}

- (void)setEnableBackgroundPlay:(BOOL)enableBackgroundPlay {
    [self.playerVCtrl setSupportBackgroundPlayback:enableBackgroundPlay];
    [self.playerVCtrl.playerStore dispatch:[TTVPlayerAction actionWithType:TTVPlayerActionType_Background info:@{TTVPlayerActionInfo_BackgroudEnable:@(enableBackgroundPlay)}]];
}

- (BOOL)enableBackgroundPlay {
    return self.playerVCtrl.playerState.audioModeState.enableBackground;
}

- (void)setDisableHDR:(BOOL)disableHDR {
    self.playerVCtrl.disableHDR = disableHDR;
    objc_setAssociatedObject(self, @selector(disableHDR), @(disableHDR), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)disableHDR {
    return [objc_getAssociatedObject(self, @selector(disableHDR)) boolValue];
}

- (void)setHasCloseAsync:(BOOL)hasCloseAsync {
    objc_setAssociatedObject(self, @selector(hasCloseAsync), @(hasCloseAsync), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)hasCloseAsync {
    return [objc_getAssociatedObject(self, @selector(hasCloseAsync)) boolValue];
}

#pragma mark - public method
- (void)setupVideoEngine {
    [self resetVideoEngine];
}

- (void)resetVideoEngine {
    if (![self videoEngine] || self.hasCloseAsync) {
        self.hasCloseAsync = NO;
        [self.playerVCtrl resetVideoEngine];
    }
    self.engineObserverState = [TTVPlayerEngineObserverState observerStateForVideoEngine:[self videoEngine]];
    TTVideoEngine *videoEngine = [self videoEngine];
    videoEngine.hardwareDecode = [SSCommonLogic hardwareDecodeEnabled];
    [self setOptionForKey:VEKKeyPlayerH265Enabled_BOOL value:@([SSCommonLogic videoPlayerH265Enable] ?: NO)];
    [self setOptionForKey:VEKKeyPlayerKsyHevcDecode_BOOL value:@([SSCommonLogic videoPlayerH265Enable] ?: NO)];
    [self setOptionForKey:VEKKeyPlayerBoeEnabled_BOOL value:@(ttv_boeEnviEnable())];
    [self setOptionForKey:VEKKeyPlayerSeekEndEnabled_BOOL value:@(YES)];

    if (self.isLongVideo) {
        // 长视频的预加载预置settings
        NSDictionary *dic = [[TTSettingsManager sharedManager] settingForKey:@"video_lvideo_config" defaultValue:@{} freeze:NO];
        if ([[dic allKeys] containsObject:@"video_enable_preload"] && [[dic valueForKey:@"video_enable_preload"] boolValue]) {
            videoEngine.proxyServerEnable = YES;
            [self setOptionForKey:VEKKeyModelCacheVideoInfoEnable_BOOL value:@(YES)];
        } else {
            videoEngine.proxyServerEnable = NO;
            [self setOptionForKey:VEKKeyModelCacheVideoInfoEnable_BOOL value:@(NO)];
        }
    } else {
        // 短视频预加载实验settings
        videoEngine.proxyServerEnable = [SSCommonLogic preloadVideoEnabled];
        [self setOptionForKey:VEKKeyModelCacheVideoInfoEnable_BOOL value:@([SSCommonLogic preloadVideoEnabled])];
    }
//    if(self.openRadioMode) {
//        //videoEngine 开启音频模式
//        videoEngine.radioMode = YES;
//    }

    BOOL metalEnable = [[[TTSettingsManager sharedManager] settingForKey:@"video_player_flag" defaultValue:@{} freeze:NO] tt_boolValueForKey:@"metal_enable"];
    if (metalEnable && [TTVideoEngine isSupportMetal]) {
        [self setOptionForKey:VEKKeyViewRenderEngine_ENUM value:@(TTVideoEngineRenderEngineMetal)];
    }
    // 是否开启DNS缓存
    [self setOptionForKey:VEKKeyPlayerDnsCacheEnabled_BOOL value:@([[[TTSettingsManager sharedManager] settingForKey:@"video_player_flag" defaultValue:@{} freeze:NO] tt_boolValueForKey:@"dns_cache_enable"])];
    
    [self.playerVCtrl.playerStore dispatch:[self.playerVCtrl.playerAction resetEngineOnBusinessLevel]];
}

- (void)addEngineBehaviorObserver:(id<TTVPlayerEngineBehaviorProtocol>)observer {
    NSAssert(observer && [observer conformsToProtocol:@protocol(TTVPlayerEngineBehaviorProtocol)], @"observer不存在或有未实现的协议方法");
    [self.engineBehaviorObservers addObject:observer];
}

- (void)removeEngineBehaviorObserver:(id<TTVPlayerEngineBehaviorProtocol>)observer {
    NSAssert(observer && [observer conformsToProtocol:@protocol(TTVPlayerEngineBehaviorProtocol)], @"observer不存在或有未实现的协议方法");
    if ([self.engineBehaviorObservers containsObject:observer]) {
        [self.engineBehaviorObservers removeObject:observer];
    }
}

- (BOOL)hasVideoEngine {
    return YES;
}

- (void)play {
    if (![self canPlay]) {
        return;
    }
    [self sendPlayStartTrack];
    [self pauseTimingForKey:@"ClickToPlay"];
    if (![self hasTimingForKey:[NSString stringWithFormat:@"%p-FirstFrame", self.playerVCtrl]]) {
        [self playerStartTimingForKey:[NSString stringWithFormat:@"%p-FirstFrame", self.playerVCtrl]];
    }
    [self.playerVCtrl play];
}

- (void)prepareToPlay {
    [self.playerVCtrl prepareToPlay];
}

- (void)pause {
    [self.playerVCtrl pause];
}

- (void)pauseAsync:(BOOL)async {
    [self.playerVCtrl pauseAsync:async];
}

- (void)stop {
    [self.playerVCtrl stop];
}

- (void)closeAsync {
    if (self.hasCloseAsync) {
        return;
    }
    [self.playerVCtrl closeAysnc];
    self.hasCloseAsync = YES;
}

- (void)isOnlyPlayAudio {
    BOOL enableAudioPlay = ttvs_enableAudioPlayMode();
    if(!enableAudioPlay) return;
    if(![self.playerVCtrl partForKey:TTVPlayerPartKey_Audio]) {
        [self.playerVCtrl addPartFromConfigForKey:TTVPlayerPartKey_Audio];
    }
    //TODO:在这里设置就要求短视频入口一定要是这里，或许有更好的地方设置。短视频设置音频按钮隐藏
    if (!self.playerVCtrl.playerState.audioModeState.hiddenAudioButtonOnControl) {
        [self.playerVCtrl.playerStore dispatch:[TTVPlayerAction actionWithType:TTVPlayerActionType_AudioButtonHidden info:@{TTVPlayerActionInfo_AudioButtonHidden:@(YES)}]];
    }
    
    [self.playerVCtrl.playerStore dispatch:[TTVPlayerAction actionWithType:TTVPlayerActionType_AudioClick info:@{}]];
    //NOTE：开启连续视频播放且启用“定时关闭”功能时，由于详情页中不同视频使用的不是同一个播放器。需要记住上个视频播放完成后剩余的时间。下个视频开播前设置剩余时间。
    if(self.audioPlayCountdown > 0) {
        NSMutableDictionary *taskModelDic = [NSMutableDictionary dictionary];
        taskModelDic[@"turnOn"] = @(YES);
        taskModelDic[@"singleMode"] = @(NO);
        taskModelDic[@"duration"] = @(self.audioPlayCountdown);
        taskModelDic[@"isCustomSeleted"] = @(YES);
        [self.playerVCtrl.playerStore dispatch:[TTVPlayerAction actionWithType:TTVPlayerActionType_TimerTaskSelected info:@{@"taskModelDic":taskModelDic}]];
    }
}

- (CGFloat)currentPlayerProgress {
    return self.playerVCtrl.playerState.playbackTime.progress;
}

- (NSArray<NSNumber *> *)supportedResolutionTypes {
    NSMutableArray<NSNumber *> *supportedResolutionTypes = [[self.playerVCtrl supportedResolutionTypes] mutableCopy];
    //如果外部业务控制强制关闭HDR，那么需要关闭
    if (self.disableHDR) {
        for (NSInteger i=0; i<supportedResolutionTypes.count; i++) {
            if (supportedResolutionTypes[i].integerValue == TTVideoEngineResolutionTypeHDR) {
                [supportedResolutionTypes removeObjectAtIndex:i];
            }
        }
    }
    return supportedResolutionTypes;
}

- (void)removeTimeObserver {
    [[self videoEngine] removeTimeObserver];
}

- (id)getOptionBykey:(VEKKeyType)key {
    return [self.playerVCtrl getOptionBykey:key];
}

- (void)setOptionForKey:(NSInteger)key value:(id)value {
    [self.playerVCtrl setOptionForKey:key value:value];
}

- (void)setProxyServerEnable:(BOOL)proxyServerEnable {
    [[self videoEngine] setProxyServerEnable:proxyServerEnable];
}

- (NSInteger)getVideoWidth {
    return [self.playerVCtrl getVideoWidth];
}

- (NSInteger)getVideoHeight {
    return [self.playerVCtrl getVideoHeight];
}

- (void)configResolution:(TTVideoEngineResolutionType)resolution {
    [self.playerVCtrl configResolution:(TTVPlayerResolutionTypes)resolution completion:nil];
}

- (void)configResolution:(TTVideoEngineResolutionType)resolution completion:(void(^)(BOOL success, TTVideoEngineResolutionType completeResolution))completion {
    if (completion) {
        void (^didResolutionChanged)(TTVideoEngineResolutionType resolution);
        if (self.controlsResolutionDidChanged) {
            didResolutionChanged = [self.controlsResolutionDidChanged copy];
        }
        self.controlsResolutionDidChanged = ^(TTVideoEngineResolutionType resolution) {
            if (completion) {
                completion(YES, resolution);
            }
            if (didResolutionChanged) {
                didResolutionChanged(resolution);
            }
        };
    }
    [self switchResolution:resolution afterDegrade:NO];
}

/// Using media loader,the size of hit cache.
/// @param player player instance
/// @param key The task key of using media loader
/// @param cacheSize hit cache size.
- (void)player:(TTVPlayer *)player mdlKey:(NSString *)key hitCacheSze:(NSInteger)cacheSize {
    BOOL isHitCache = NO;
    NSInteger hitCacheSize = 0;
    TTVideoEngineURLInfo *info = [self.videoInfo videoInfoForType:(TTVideoEngineResolutionType)self.currentResolution];
    if(info != nil){
        NSString *temFilehash = [info getValueStr:VALUE_FILE_HASH];
        if ([temFilehash isEqualToString:key]) {
            isHitCache = YES;
            hitCacheSize = cacheSize;
        }
    }
    [self qosPlayerTracker].isHitCache = isHitCache;
    [self qosPlayerTracker].hitCacheSize = hitCacheSize;
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime complete:(void(^)(BOOL success))finised {
    [self.hookPlaybackBlockBefore enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        void (^block)(NSArray *) = obj;
        NSMutableArray *argumentsArr = [[NSMutableArray alloc] initWithCapacity:2];
        [argumentsArr addObject:@(currentPlaybackTime)];
        [argumentsArr btd_addObject:finised];
        if (block) {
            block([argumentsArr copy]);
        }
    }];
    @weakify(self);
    [self.playerVCtrl setCurrentPlaybackTime:currentPlaybackTime complete:^(BOOL success) {
        @strongify(self);
        if (success) {
            [self.danmakuAdapter playerSeeked];
        }
        if (finised) {
            finised(success);
        }
    }];
    [self.hookPlaybackBlockAfter enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        void (^block)(NSArray *) = obj;
        NSMutableArray *argumentsArr = [[NSMutableArray alloc] initWithCapacity:2];
        [argumentsArr addObject:@(currentPlaybackTime)];
        [argumentsArr btd_addObject:finised];
        if (block) {
            block([argumentsArr copy]);
        }
    }];
}

- (void)setLocalURL:(NSString *)localURL {
    [self.playerVCtrl setLocalURL:localURL];
}

- (NSString *)localURL{
    return [self.playerVCtrl localURL];
}

- (BOOL)looping {
    return self.playerVCtrl.looping;
}

- (void)setLooping:(BOOL)looping {
    self.playerVCtrl.looping = looping;
}

- (void)setDirectPlayURL:(NSString *)directPlayURL {
    [self.playerVCtrl setDirectPlayURL:directPlayURL];
}

- (NSString *)directPlayURL{
    return [self.playerVCtrl directPlayURL];
}

- (void)setDrmCreater:(DrmCreater)drmCreater {
    [self.playerVCtrl setDrmCreater:drmCreater];
}

- (void)setOpenTimeOut:(NSInteger)timerOut
{
    if (timerOut > 0) {
        [self.playerVCtrl setOptionForKey:VEKKeyPlayerOpenTimeOut_NSInteger value:@(timerOut)];
    }
}

#pragma mark - private method
- (BOOL)canPlay {
    //播放器回收复用，会延时使用closeAys节省播放器重置耗时，所以判断如果正在回收中，不能播放，重置完会重置该变量
    if (self.isPlayerRecycling) {
        return NO;
    }
    if (self.viewModel.aID.integerValue != 0) {
        return YES;
    }
    if (self.screenCastCloseButtonClicked) {
        self.screenCastCloseButtonClicked = NO;
        return YES;
    }
    if (self.shouldPlayByInnerScreenCast) {
        self.shouldPlayByInnerScreenCast = NO;
        [self pause];
        return NO;
    }
    if (self.isScreenCasting) {
        return NO;
    }
    if (self.screenCastViewIsShowing) {
        [self pause];
        return NO;
    }
    return YES;
}

- (NSHashTable *)engineBehaviorObservers {
    NSHashTable *hashTable = objc_getAssociatedObject(self, @selector(engineBehaviorObservers));
    if (!hashTable) {
        hashTable = [NSHashTable weakObjectsHashTable];
        objc_setAssociatedObject(self, @selector(engineBehaviorObservers), hashTable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return hashTable;
}

- (void)engineBehaviorCallbackForSelector:(SEL)selector withObjects:(id)object,... {
    for (id<TTVPlayerEngineBehaviorProtocol> observer in self.engineBehaviorObservers.allObjects) {
        if (observer && ![observer isKindOfClass:[NSNull class]]) {
            if ([observer respondsToSelector:selector]) {
                NSMethodSignature *signature = [[observer class] instanceMethodSignatureForSelector:selector];
                if (signature == nil) {
                    NSAssert(NO, @"找不到 %@ 方法", NSStringFromSelector(selector));
                }
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                invocation.target = observer;
                invocation.selector = selector;
                NSInteger paramsCount = signature.numberOfArguments - 2;
                // 设置参数
                va_list params;
                va_start(params, object);
                int i = 0;
                for (id tmpObject = object; i < paramsCount; i++) {
                    [invocation setArgument:&tmpObject atIndex:i + 2];
                    if (i < paramsCount - 1) {
                        tmpObject = va_arg(params, id);
                    }
                }
                va_end(params);
                [invocation retainArguments];
                // 调用方法
                [invocation invoke];
            }
        }
    }
}

#pragma mark - Debug Tool
- (BOOL)videoDebugViewIsShowing {
    return [self.playerVCtrl videoDebugViewIsShowing];
}

- (void)showDebugViewInView:(UIView *)hudView indexInhudView:(NSInteger)index {
    [self.playerVCtrl showDebugViewInView:hudView indexInhudView:index];
}

- (void)hideDebugView {
    [self.playerVCtrl hideDebugView];
}

- (void)removeDebugView {
    [self.playerVCtrl removeDebugView];
}

- (void)showDebugView {
    [self.playerVCtrl showDebugView];
}

- (void)setDebugViewIsFullScreen:(BOOL)isFullScreen {
    [self.playerVCtrl setDebugViewIsFullScreen:isFullScreen];
}


@end
