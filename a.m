//
//  TTImmersePlayerPresenter.m
//  Article
//
//  Created by yangshaobo on 2019/4/17.
//

#import "TTImmersePlayerPresenter.h"
#import "ExploreOrderedData.h"
#import "ExploreOrderedData+TTImmersePlayerModel.h"

NSUInteger const TTImmersePlayerPresenterShowTipTime = 3;

@interface TTImmersePlayerPresenter ()

@property (nonatomic, copy, null_unspecified) NSArray<TTImmerseModel *> *bringPlayerModels;

@property (nonatomic, assign) BOOL showCountdownTip;

@property (nonatomic, assign) BOOL isLastPlayerModel;

@end

@implementation TTImmersePlayerPresenter

@synthesize context = _context;

- (instancetype)init {
    if (self = [super init]) {
        _isLastPlayerModel = YES;
    }
    return self;
}

#pragma mark - TTImmersePlayerPresentationLogic

- (void)presentWithResponse:(TTImmersePlayerResponse *)response {
    if ([response isKindOfClass:[TTImmersePlayerLoadMoreResponse class]]) {
        [self p_handleLoadMoreResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerLoadContentResponse class]]) {
        [self p_handleLoadContentResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerPlayNextResponse class]]) {
        [self p_handlePlayNextResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerPlaybackResponse class]]) {
        [self p_handlePlaybackResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerIsLastPlayerModelChangeResponse class]]) {
        [self p_handleIsLastPlayerModelChangeResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerFrontPasterADResponse class]]) {
        [self p_handleFrontPasterADResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerReplaceResponse class]]) {
        [self p_handleReplaceResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerLoadPrevResponse class]]) {
        [self p_handleLoadPrevResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerVolumeChangedResponse class]]) {
        [self p_handleVolumeChangedResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerBrightnessChangedResponse class]]) {
        [self p_handleBrightnessChangedResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerMorePanelShowingResponse class]]) {
        [self p_handleMorePanelShowingResponse:(id)response];
    } else if ([response isKindOfClass:[TTImmersePlayerPSeriesFloatViewShowingResponse class]]) {
        [self p_handlePSeriesFloatViewShowingResponse:(id)response];
    }
}

- (void)resetStatus {
    self.bringPlayerModels = nil;
    self.isLastPlayerModel = YES;
    self.showCountdownTip = NO;
}

#pragma mark - Util

- (void)p_handleIsLastPlayerModelChangeResponse:(TTImmersePlayerIsLastPlayerModelChangeResponse *)response {
    self.isLastPlayerModel = response.isLastPlayerModel;
}

- (void)p_handleReplaceResponse:(TTImmersePlayerReplaceResponse *)response {
    self.bringPlayerModels = response.bringPlayerModels;
    TTImmersePlayerViewModel *viewModel = [[TTImmersePlayerReplaceViewModel alloc] init];
    [self p_buildViewModelWithAllFetchPlayerModels:response.allFetchPlayerModels hasMore:nil needSetViewModel:viewModel categoryName:response.categoryName enterSource:response.enterSource checkAllFetchPlayerModels:YES requestInSegment:NO];
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleFrontPasterADResponse:(TTImmersePlayerFrontPasterADResponse *)response {
    TTImmersePlayerFrontPasterADViewModel *adViewModel = [[TTImmersePlayerFrontPasterADViewModel alloc] init];
    adViewModel.adPlayState = @(response.adPlayState);
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:adViewModel];
    }
}

- (void)p_handlePlaybackResponse:(TTImmersePlayerPlaybackResponse *)response {
    TTImmersePlayerPlaybackViewModel *playbackViewModel = [[TTImmersePlayerPlaybackViewModel alloc] init];
    playbackViewModel.time = response.time;
    playbackViewModel.duration = response.duration;
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:playbackViewModel];
    }
    
    NSTimeInterval playbackTimeInterval = response.duration - response.time;
    if (!self.isLastPlayerModel &&
        response.duration > 0 &&
        playbackTimeInterval > 0 && 
        playbackTimeInterval < TTImmersePlayerPresenterShowTipTime + 1) {
        TTImmersePlayerCountdownTipViewModel *viewModel = [[TTImmersePlayerCountdownTipViewModel alloc] init];
        viewModel.showTip = @(self.context.canAutoPlay);
        viewModel.count = @((NSUInteger)floor(response.duration - response.time));
        if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
            [self.displayer displayWithViewModel:viewModel];
        }
        self.showCountdownTip = YES;
    } else {
        if (!self.showCountdownTip) {
            return;
        }
        self.showCountdownTip = NO;
        TTImmersePlayerCountdownTipViewModel *viewModel = [[TTImmersePlayerCountdownTipViewModel alloc] init];
        viewModel.showTip = @(NO);
        if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
            [self.displayer displayWithViewModel:viewModel];
        }
    }
}

- (void)p_handlePlayNextResponse:(TTImmersePlayerPlayNextResponse *)response {
    TTImmersePlayerPlayNextViewModel *viewModel = [[TTImmersePlayerPlayNextViewModel alloc] init];
    if (response.nextIndex < response.allModels.count) {
        if (response.allModels[response.nextIndex] == response.nextModel) {
            viewModel.models = response.allModels;
            viewModel.nextModel = response.nextModel;
            if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
                [self.displayer displayWithViewModel:viewModel];
            }
        }
    }
}

- (void)p_handleLoadContentResponse:(TTImmersePlayerLoadContentResponse *)response {
    self.bringPlayerModels = response.bringPlayerModels;
    TTImmersePlayerViewModel *viewModel = [[TTImmersePlayerViewModel alloc] init];
    [self p_buildViewModelWithAllFetchPlayerModels:response.allFetchPlayerModels hasMore:@(response.hasMore) needSetViewModel:viewModel categoryName:response.categoryName enterSource:response.enterSource checkAllFetchPlayerModels:NO requestInSegment:NO];
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleLoadMoreResponse:(TTImmersePlayerLoadMoreResponse *)response {
    TTImmersePlayerViewModel *viewModel = [[TTImmersePlayerViewModel alloc] init];
    [self p_buildViewModelWithAllFetchPlayerModels:response.allFetchPlayerModels hasMore:@(response.hasMore) needSetViewModel:viewModel categoryName:response.categoryName enterSource:response.enterSource checkAllFetchPlayerModels:YES requestInSegment:response.requestInSegment];
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleLoadPrevResponse:(TTImmersePlayerLoadPrevResponse *)response {
    TTImmersePlayerLoadPrevViewModel *viewModel = [[TTImmersePlayerLoadPrevViewModel alloc] init];
    [self p_buildViewModelWithAllFetchPlayerModels:response.allFetchPlayerModels hasMore:nil needSetViewModel:viewModel categoryName:response.categoryName enterSource:response.enterSource checkAllFetchPlayerModels:YES requestInSegment:response.requestInSegment];
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleVolumeChangedResponse:(TTImmersePlayerVolumeChangedResponse *)response {
    TTImmersePlayerVolumeChangedViewModel *viewModel = [[TTImmersePlayerVolumeChangedViewModel alloc] init];
    viewModel.changedBySystemButton = response.changedBySystemButton;
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleBrightnessChangedResponse:(TTImmersePlayerBrightnessChangedResponse *)response {
    TTImmersePlayerBrightnessChangedViewModel *viewModel = [[TTImmersePlayerBrightnessChangedViewModel alloc] init];
    viewModel.changedBySystemButton = response.changedBySystemButton;
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handleMorePanelShowingResponse:(TTImmersePlayerMorePanelShowingResponse *)response {
    TTImmersePlayerMorePanelShowingViewModel *viewModel = [[TTImmersePlayerMorePanelShowingViewModel alloc] init];
    viewModel.morePanelShowing = response.morePanelShowing;
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_handlePSeriesFloatViewShowingResponse:(TTImmersePlayerPSeriesFloatViewShowingResponse *)response {
    TTImmersePlayerPSeriesFloatViewShowingViewModel *viewModel = [[TTImmersePlayerPSeriesFloatViewShowingViewModel alloc] init];
    viewModel.floatViewShowing = response.floatViewShowing;
    if ([self.displayer respondsToSelector:@selector(displayWithViewModel:)]) {
        [self.displayer displayWithViewModel:viewModel];
    }
}

- (void)p_buildViewModelWithAllFetchPlayerModels:(NSArray *)allFetchPlayerModels
                                         hasMore:(NSNumber *)hasMore
                                needSetViewModel:(TTImmersePlayerViewModel *)viewModel
                                    categoryName:(NSString *)categoryName
                                     enterSource:(TTImmersePlayerEnterSource)enterSource
                       checkAllFetchPlayerModels:(BOOL)checkAllFetchPlayerModels
                                requestInSegment:(BOOL)requestInSegment {
    NSMutableArray<TTImmerseModel *> *allPlayerModel = [NSMutableArray arrayWithCapacity:allFetchPlayerModels.count + self.bringPlayerModels.count];
    
    __block NSUInteger index = 0;
    
    if (requestInSegment) {
        [allFetchPlayerModels enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ExploreOrderedData *orderedData = (id)obj;
            if ([orderedData isKindOfClass:[ExploreOrderedData class]]) {
                if (orderedData.article) {
                    orderedData.categoryID = categoryName;
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:orderedData.article.zzz_originalDict ?: @{}];
                    if (!isEmptyString(categoryName)) {
                        dict[@"categoryID"] = categoryName;
                    }
                    orderedData.article.zzz_originalDict = dict;
                    TTImmerseModel *playerModel = [TTImmerseModelFactory modelWithOriginalData:orderedData enterSource:enterSource index:index];
                    if (playerModel) {
                        [allPlayerModel addObject:playerModel];
                    }
                }
                index += 1;
            }
        }];
    } else {
        [allFetchPlayerModels enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ExploreOrderedData *orderedData = (id)obj;
            if ([orderedData isKindOfClass:[ExploreOrderedData class]]) {
                if (!orderedData.ttv_isLoadPrev) {
                    return;
                }
                if (orderedData.article) {
                    orderedData.categoryID = categoryName;
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:orderedData.article.zzz_originalDict ?: @{}];
                    if (!isEmptyString(categoryName)) {
                        dict[@"categoryID"] = categoryName;
                    }
                    orderedData.article.zzz_originalDict = dict;
                    TTImmerseModel *playerModel = [TTImmerseModelFactory modelWithOriginalData:orderedData enterSource:enterSource index:index];
                    if (playerModel) {
                        [allPlayerModel addObject:playerModel];
                    }
                }
                index += 1;
            }
        }];
        
        [self.bringPlayerModels enumerateObjectsUsingBlock:^(TTImmerseModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[TTImmerseModel class]]) {
                obj.enterSource = enterSource;
                obj.index = index;
                [allPlayerModel addObject:obj];
                index += 1;
            }
        }];
        
        [allFetchPlayerModels enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            ExploreOrderedData *orderedData = (id)obj;
            if ([orderedData isKindOfClass:[ExploreOrderedData class]]) {
                if (orderedData.ttv_isLoadPrev) {
                    return;
                }
                if (orderedData.article) {
                    orderedData.categoryID = categoryName;
                    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:orderedData.article.zzz_originalDict ?: @{}];
                    if (!isEmptyString(categoryName)) {
                        dict[@"categoryID"] = categoryName;
                    }
                    orderedData.article.zzz_originalDict = dict;
                    TTImmerseModel *playerModel = [TTImmerseModelFactory modelWithOriginalData:orderedData enterSource:enterSource index:index];
                    if (playerModel) {
                        [allPlayerModel addObject:playerModel];
                    }
                }
                index += 1;
            }
        }];
    }
     
    if (allPlayerModel.count > 0) {
        viewModel.models = allPlayerModel;
    }
    
    if (checkAllFetchPlayerModels && allFetchPlayerModels.count == 0) {
        viewModel.models = nil;
    }
    
    viewModel.hasMore = hasMore;
    return;
}

@end
