/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

#import "MapViewController.h"
#import "NavDeviceTTS.h"
#import "DefaultTTS.h"
#import "NavSound.h"
#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavTalkButton.h"
#import "NavUtil.h"
#import "ServerConfig.h"
#import "SettingViewController.h"
#import "NavDebugHelper.h"
#import "SettingDataManager.h"  // new
#import <HLPLocationManager/HLPLocationManager.h>
#import <HLPLocationManager/HLPLocationManager+Player.h>
#import <CoreMotion/CoreMotion.h>

@import JavaScriptCore;
@import CoreMotion;

typedef NS_ENUM(NSInteger, ViewState) {
    ViewStateMap,
    ViewStateSearch,
    ViewStateSearchDetail,
    ViewStateSearchSetting,
    ViewStateRouteConfirm,
    ViewStateNavigation,
    ViewStateTransition,
    ViewStateRouteCheck,
    ViewStateLoading,
};

@interface MapViewController () {
    NavNavigator *navigator;
    NavCommander *commander;
    NavPreviewer *previewer;

    ViewState state;
    NSDictionary *uiState;
    
    NSTimeInterval lastShake;
    NSTimeInterval lastLocationSent;
    NSTimeInterval lastOrientationSent;
    
    // Blind
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    double yaws[10];
    int yawsIndex;
    double accs[10];
    int accsIndex;
    
    double turnAction;
    BOOL forwardAction;
    
    BOOL initFlag;
    BOOL rerouteFlag;
    
    BOOL initialViewDidAppear;
    BOOL needVOFocus;
    WebViewController *showingPage;
    
    BOOL isBlindMode;   // new
    NSString *destId;   // new
    BOOL isNaviStarted; // new
    
    NavTalkButton *talkButton;
}

@end

@implementation MapViewController

- (void)dealloc
{
    NSLog(@"%s: %d" , __func__, __LINE__);
}

- (void)prepareForDealloc
{
    _webView.delegate = nil;
    
    [navigator stop];
    navigator.delegate = nil;
    navigator = nil;
    
    commander.delegate = nil;
    commander = nil;
    
    previewer.delegate = nil;
    previewer = nil;

    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_STOP object:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    initialViewDidAppear = YES;
    
    [self updateTitle];

    state = ViewStateLoading;
    isNaviStarted = NO;     // new

    [[NavDataStore sharedDataStore] setUpHLPLocationManager];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    _webView = [[NavBlindWebView alloc] initWithFrame:CGRectMake(0,0,0,0) configuration:[[WKWebViewConfiguration alloc] init]];
    [self.view addSubview:_webView];
    for(UIView *v in self.view.subviews) {
        if (v != _webView) {
            [self.view bringSubviewToFront:v];
        }
    }
    _webView.userMode = [ud stringForKey:@"user_mode"];
    _webView.config = @{
                        @"serverHost":[ud stringForKey:@"selected_hokoukukan_server"],
                        @"serverContext":[ud stringForKey:@"hokoukukan_server_context"],
                        @"usesHttps":@([ud boolForKey:@"https_connection"])
                        };
    _webView.delegate = self;
    _webView.tts = self;
    [_webView setFullScreenForView:self.view];
    
    [self.stopButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Stop Navigation", @"BlindView", @"")];
    [self.searchButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Search Route", @"BlindView", @"")];
    [self.settingButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Settings", @"BlindView", @"")];
    [self.backButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Back", @"BlindView", @"")];
    [self.cancelButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")];
    [self.doneButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Done", @"BlindView", @"")];
    [self.retryButton setAccessibilityLabel:NSLocalizedStringFromTable(@"Retry", @"BlindView", @"")];

    navigator = [[NavNavigator alloc] init];
    commander = [[NavCommander alloc] init];
    previewer = [[NavPreviewer alloc] init];
    navigator.delegate = self;
    commander.delegate = self;
    previewer.delegate = self;

    NSString *userMode = [ud stringForKey:@"user_mode"];

    isBlindMode = [userMode isEqualToString:@"user_blind"];

    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    [self updateIndicatorStop];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logReplay:) name:REQUEST_LOG_REPLAY object:nil];                  // blind
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartNavigation:) name:REQUEST_START_NAVIGATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uiStateChanged:) name:WCUI_STATE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogStateChanged:) name:DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLocaionUnknown:) name:REQUEST_HANDLE_LOCATION_UNKNOWN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name: REQUEST_OPEN_URL object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeCleared:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocation:) name:MANUAL_LOCATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestShowRoute:) name:REQUEST_PROCESS_SHOW_ROUTE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareForDealloc) name:REQUEST_UNLOAD_VIEW object:nil];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkState:) userInfo:nil repeats:YES];

    [self updateView];

    BOOL checked = [ud boolForKey:@"checked_altimeter"];
    if (!checked && ![CMAltimeter isRelativeAltitudeAvailable]) {
        NSString *title = NSLocalizedString(@"NoAltimeterAlertTitle", @""); // 気圧計がありません。
        NSString *message = NSLocalizedString(@"NoAltimeterAlertMessage", @"");
        NSString *ok = NSLocalizedString(@"I_Understand", @"");
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:ok
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *action) {
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self topMostController] presentViewController:alert animated:YES completion:nil];
        });
        [ud setBool:YES forKey:@"checked_altimeter"];
    }

    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"user_mode"
                                               options:NSKeyValueObservingOptionNew context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    NSLog(@"%@, %@, %@", keyPath, object, change);
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:@"user_mode"] && change[@"new"]) {
            if (isNaviStarted) {
                [self stopNavigation:nil];
            }
            _webView.userMode = change[@"new"];
            isBlindMode = [change[@"new"] isEqualToString:@"user_blind"];
            [self updateTitle];
            [self updateView];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // blind
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(elementDidBecomeFocused:) name:AccessibilityElementDidBecomeFocused object:nil];
    if (!initialViewDidAppear) {
        needVOFocus = YES;
    }
    initialViewDidAppear = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_ACCELEARATION object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_STABILIZE_LOCALIZE object:self];
    [self becomeFirstResponder];
    // blind

    [self setTalkButton];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
//    [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_ACCELEARATION object:self];  // blind
//    [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_STABILIZE_LOCALIZE object:self];  // blind
//    [[NSNotificationCenter defaultCenter] removeObserver:self name:AccessibilityElementDidBecomeFocused object:nil];  // blind
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIViewController*) topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].windows.firstObject.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (void) checkState:(NSTimer*)timer
{
    if (state != ViewStateLoading) {
        [timer invalidate];
        return;
    }

    [_webView getStateWithCompletionHandler:^(NSDictionary * _Nonnull json) {
        [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:json];
    }];
    
    // blind
    [_webView getCenterWithCompletion:^(HLPLocation *loc) {
        if (loc != nil) {
            [NavDataStore sharedDataStore].mapCenter = loc;
            HLPLocation *center = [NavDataStore sharedDataStore].currentLocation;
            if (isnan(center.lat) || isnan(center.lng)) {
                NSDictionary *param =
                @{
                  @"floor": @(loc.floor),
                  @"lat": @(loc.lat),
                  @"lng": @(loc.lng),
                  @"sync": @(YES)
                  };
                [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION_CHANGED_NOTIFICATION object:self userInfo:param];

            }
            [self updateView];
            [timer invalidate];
        }
    }];
}

- (void)updateTitle {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    UILabel *titleView = [[UILabel alloc] init];
    UIFont *font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
    NSString* userMode = [ud stringForKey:@"user_mode"];
    NSString *title = NSLocalizedString(userMode, @"");
    if([title length] == 0) {
        title = NSLocalizedString(@"Miraikan", @"");
    }
    titleView.text = title;
    titleView.accessibilityLabel = @"( )";
    titleView.isAccessibilityElement = NO;
    titleView.font = font;
    self.navigationItem.titleView = titleView;
}

- (void)updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL hasCenter = [[NavDataStore sharedDataStore] mapCenter] != nil;
        BOOL isActive = [navigator isActive];
        
        if (isBlindMode) {
            self.searchButton.enabled = hasCenter;

            if (isActive) {
                self.navigationItem.rightBarButtonItems = @[self.stopButton];
                self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
            } else {
                self.navigationItem.rightBarButtonItems = @[self.searchButton, self.settingButton];
                self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
            }

        } else {
            switch(state) {
                case ViewStateMap:
                    self.navigationItem.rightBarButtonItems = @[self.searchButton, self.settingButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateSearch:
                    self.navigationItem.rightBarButtonItems = @[self.settingButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateSearchDetail:
                    self.navigationItem.rightBarButtonItems = @[];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];
                    break;
                case ViewStateSearchSetting:
                    self.navigationItem.rightBarButtonItems = @[self.searchButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateNavigation:
                    self.navigationItem.rightBarButtonItems = @[self.stopButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateRouteConfirm:
                    self.navigationItem.rightBarButtonItems = @[];
                    self.navigationItem.leftBarButtonItems = @[self.cancelButton];
                    break;
                case ViewStateRouteCheck:
                    self.navigationItem.rightBarButtonItems = @[self.doneButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateTransition:
                    self.navigationItem.rightBarButtonItems = @[];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
                case ViewStateLoading:
                    self.navigationItem.rightBarButtonItems = @[self.settingButton];
                    self.navigationItem.leftBarButtonItems = @[self.backButton];   // new
                    break;
            }
        }

        [self dialogHelperUpdate];
    });
}

- (void) dialogHelperUpdate
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLocation *loc = [nds currentLocation];
    BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
    BOOL isPreviewDisabled = [[ServerConfig sharedConfig] isPreviewDisabled];

    if (isBlindMode) {
        if ([[DialogManager sharedManager] isAvailable] && ![navigator isActive]) {
            [talkButton setHidden:false];
        } else {
            [talkButton setHidden:true];
        }

        NSMutableArray *elements = [@[self.navigationItem] mutableCopy];
        if (talkButton && !talkButton.hidden) {
            [elements addObject:talkButton];
        }
        self.view.accessibilityElements = elements;
    } else {
        if (state == ViewStateMap) {
            if ([[DialogManager sharedManager] isAvailable]  && (!isPreviewDisabled || validLocation)) {
                [talkButton setHidden:false];
            } else {
                [talkButton setHidden:true];
            }
        } else {
            [talkButton setHidden:true];
        }
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    [segue destinationViewController].restorationIdentifier = segue.identifier;
    
    if (isBlindMode) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideWaitingForView:self.view];
        });
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            if ([sender isKindOfClass:NSArray.class]) {
                NSArray *temp = [sender copy];
                if ([temp count] > 0) {
                    NSString *name = temp[0];
                    temp = [temp subarrayWithRange:NSMakeRange(1, [temp count]-1)];
                    [[segue destinationViewController] performSegueWithIdentifier:name sender:temp];
                }
            }
        });
    }
    
    if ([segue.identifier isEqualToString:@"user_settings"]) {
        SettingViewController *sv = (SettingViewController*)segue.destinationViewController;
        sv.webView = _webView;
    }
    if ([segue.identifier isEqualToString:@"show_dialog_wc"]){
        DialogViewController* dView = (DialogViewController*)segue.destinationViewController;
        dView.tts = [DefaultTTS new];
        dView.root = self;
        dView.title = NSLocalizedString(@"Ask AI", comment: "");
        dView.view.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - 50);
        [dView.dialogViewHelper removeFromSuperview];
        [dView.dialogViewHelper setup: dView.view
                             position: CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height - 50)];
    }
    if ([segue.identifier isEqualToString:@"show_search"]) {
        [self updateIndicatorStart];
        [_webView evaluateJavaScript:@"$hulop.map.setSync(true);"
                   completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            [self updateIndicatorStop];
        }];
    }
}

// blind
- (void) actionPerformed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY_STOP object:self];
}

// blind
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

// blind
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [_indicator startAnimating];
    _indicator.hidden = NO;
    _webView.alpha = 0;
    [self webFooterHidden];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;

    [self webFooterHidden];
    [UIView animateWithDuration:0.3 animations: ^{
        self.webView.alpha = 1;
    }];
    initFlag = true;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

#pragma mark - HLPWebView

- (void)webView:(HLPWebView *)webView didChangeLatitude:(double)lat longitude:(double)lng floor:(double)floor synchronized:(BOOL)sync
{
    if (floor == 0) {
        return;
    }
    NSDictionary *loc =
    @{
      @"lat": @(lat),
      @"lng": @(lng),
      @"floor": @(floor),
      @"sync": @(sync),
      };
    [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION_CHANGED_NOTIFICATION object:self userInfo:loc];
}

- (void)webView:(HLPWebView *)webView didChangeBuilding:(NSString *)building
{
    [[NSNotificationCenter defaultCenter] postNotificationName:BUILDING_CHANGED_NOTIFICATION object:self userInfo:(building != nil ? @{@"building": building} : @{})];
}

- (void)webView:(HLPWebView *)webView didChangeUIPage:(NSString *)page inNavigation:(BOOL)inNavigation
{
    NSDictionary *uiState =
    @{
      @"page": page,
      @"navigation": @(inNavigation),
      };
    [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:uiState];
}

- (void)webView:(HLPWebView *)webView didFinishNavigationStart:(NSTimeInterval)start end:(NSTimeInterval)end from:(NSString *)from to:(NSString *)to
{
    destId = nil;
    isNaviStarted = false;
}

- (void)webView:(HLPWebView *)webView openURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL object:self userInfo:@{@"url": url}];
}

#pragma mark - notification handlers
- (void)elementDidBecomeFocused:(NSNotification*)note
{
    // blind
    if (needVOFocus) {
        needVOFocus = NO;
    }
}

- (void) openURL:(NSNotification*)note
{
    [NavUtil openURL:[note userInfo][@"url"] onViewController:self];
}

- (void)talkTap:(id)sender
{
    [talkButton setHidden:true];
    if (isBlindMode) {
        if ([navigator isActive] ||
            self.navigationController.topViewController != self ||
            !self.searchButton.enabled) {
            
            [[NavSound sharedInstance] playFail];
            return;
        }
        [[NavSound sharedInstance] playVoiceRecoEnd];
        [self performSegueWithIdentifier:@"show_search" sender:@[@"toDestinations", @"show_dialog"]];
    } else {
        [self performSegueWithIdentifier:@"show_dialog_wc" sender:self];
    }
}

- (void)dialogStateChanged:(NSNotification*)note
{
    [self updateView];
}

// blind
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
    if(event.type == UIEventSubtypeMotionShake)
    {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - lastShake < 5) {
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_UNKNOWN object:self];
            [[NavSound sharedInstance] vibrate:@{@"repeat":@(2)}];
            lastShake = 0;
        } else {
            [[NavSound sharedInstance] vibrate:nil];
            lastShake = now;
        }
    }
}

// blind
- (void) logReplay:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIMessageView *mv = [NavUtil showMessageView:self.view];
        
        __block __weak id observer = [[NSNotificationCenter defaultCenter] addObserverForName:LOG_REPLAY_PROGRESS object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            long progress = [[note userInfo][@"progress"] longValue];
            long total = [[note userInfo][@"total"] longValue];
            NSDictionary *marker = [note userInfo][@"marker"];
            double floor = [[note userInfo][@"floor"] doubleValue];
            double difft = [[note userInfo][@"difft"] doubleValue]/1000;
            const char* msg = [[note userInfo][@"message"] UTF8String];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (marker) {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%%:%03.1fs (%d:%.2f) %s",
                                       (progress /(double)total)*100, difft, [marker[@"floor"] intValue], floor, msg];
                } else {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%% %s", (progress /(double)total)*100, msg];
                }
            });
            
            if (progress == total) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NavUtil hideMessageView:self.view];
                });
                [[NSNotificationCenter defaultCenter] removeObserver:observer];
            }
        }];
        
        [mv.action addTarget:self action:@selector(actionPerformed) forControlEvents:UIControlEventTouchDown];
    });
}

- (void)uiStateChanged:(NSNotification*)note
{
    uiState = [note userInfo];

    NSString *page = uiState[@"page"];
    BOOL inNavigation = [uiState[@"navigation"] boolValue];

    if (page) {
        if ([page isEqualToString:@"control"]) {
            state = ViewStateSearch;
        }
        else if ([page isEqualToString:@"settings"]) {
            state = ViewStateSearchSetting;
        }
        else if ([page isEqualToString:@"confirm"]) {
            state = ViewStateRouteConfirm;
        }
        else if ([page hasPrefix:@"map-page"]) {
            if (inNavigation) {
                state = ViewStateNavigation;
            } else {
                state = ViewStateMap;
            }
        }
        else if ([page hasPrefix:@"ui-id-"]) {
            state = ViewStateSearchDetail;
        }
        else if ([page isEqualToString:@"confirm_floor"]) {
            state = ViewStateRouteCheck;
        }
        else {
            NSLog(@"unmanaged state: %@", page);
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateView];
    });
}

// Voice dialogue information
- (void)requestStartNavigation:(NSNotification*)note
{
    if (isBlindMode) {
        return;
    }

    // new
    if (isNaviStarted) {
        return;
    }
    
    // general mode
    // Sentence information before the start of navigation
    NSDictionary *options = [note userInfo];
    if (options[@"toID"] == nil) {
        return;
    }
    NSString *elv = @"";
    if (options[@"use_elevator"]) {
        elv = [options[@"use_elevator"] boolValue]?@"&elv=9":@"&elv=1";
    }
    NSString *stairs = @"";
    if (options[@"use_stair"]) {
        stairs = [options[@"use_stair"] boolValue]?@"&stairs=9":@"&stairs=1";
    }
    NSString *esc = @"";
    if (options[@"use_escalator"]) {
        esc = [options[@"use_escalator"] boolValue]?@"&esc=9":@"&esc=1";
    }
    NSString *dist = [NSString stringWithFormat: @"&dist=%@", @(500)];
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&dummy=%f%@%@%@%@",
                      options[@"toID"], [[NSDate date] timeIntervalSince1970], elv, stairs, esc, dist];
    [talkButton setHidden:true];
    [_webView setLocationHash:hash];
    isNaviStarted = YES;      // new
}

#pragma mark - Navigation
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"user_settings"] && (state == ViewStateMap || state == ViewStateLoading)) {
        return YES;
    }
    if ([identifier isEqualToString:@"user_settings"] && state == ViewStateSearch) {
        state = ViewStateTransition;
        [self updateView];
        [_webView triggerWebviewControl:HLPWebviewControlRouteSearchOptionButton];
        return NO;
    }

    return YES;
}

- (void)locationStatusChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HLPLocationStatus status = [[note userInfo][@"status"] unsignedIntegerValue];
        switch(status) {
            case HLPLocationStatusLocating:
                [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Locating...", @"BlindView", @"")];
                break;
            case HLPLocationStatusUnknown:
                break;
            default:
                [NavUtil hideWaitingForView:self.view];
        }
    });
}

- (void) manualLocation: (NSNotification*) note
{
    HLPLocation* loc = [note userInfo][@"location"];
    BOOL sync = [[note userInfo][@"sync"] boolValue];
    [_webView manualLocation:loc withSync:sync];
}

- (void) locationChanged: (NSNotification*) note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
        if (appState == UIApplicationStateBackground || appState == UIApplicationStateInactive) {
            return;
        }
        
        NSDictionary *locations = [note userInfo];
        if (!locations) {
            return;
        }
        HLPLocation *location = locations[@"current"];
        if (!location || isnan(location.lat) || isnan(location.lng)) {
            return;
        }
        
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        
        double orientation = -location.orientation / 180 * M_PI;
        
        if (lastOrientationSent + 0.2 < now) {
            [_webView sendData:@[@{
                                     @"type":@"ORIENTATION",
                                     @"z":@(orientation)
                                     }]
                      withName:@"Sensor"];
            lastOrientationSent = now;
        }
        
        location = locations[@"actual"];
        if (!location || isnan(location.lat) || isnan(location.lng)) {
            return;
        }
        
        if (now < lastLocationSent + [[NSUserDefaults standardUserDefaults] doubleForKey:@"webview_update_min_interval"]) {
            if (!location.params) {
                return;
            }
            //return; // prevent too much send location info
        }

        double floor = location.floor;
        
        [_webView sendData:@{
                             @"lat":@(location.lat),
                             @"lng":@(location.lng),
                             @"floor":@(floor),
                             @"accuracy":@(location.accuracy),
                             @"rotate":@(0), // dummy
                             @"orientation":@(999), //dummy
                             @"debug_info":location.params?location.params[@"debug_info"]:[NSNull null],
                             @"debug_latlng":location.params?location.params[@"debug_latlng"]:[NSNull null]
                             }
                  withName:@"XYZ"];
        
        lastLocationSent = now;
        [self dialogHelperUpdate];  // blind

        if (!destId || isNaviStarted) {
            return;
        }
        [self startNavi];
    });
}

// blind
- (void) destinationChanged: (NSNotification*) note
{
    [_webView initTarget:[note userInfo][@"destinations"]];
}

// blind
- (void) routeCleared: (NSNotification*) note
{
    [_webView clearRoute];
}

// blind
- (void)requestShowRoute:(NSNotification*)note
{
    NSArray *route = [note userInfo][@"route"];
    [_webView showRoute:route];
}

#pragma mark - IBActions
// blind
- (IBAction)restartLocalization:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESTART object:self];
}

- (IBAction)doSetting:(id)sender {
    [self performSegueWithIdentifier:@"user_settings" sender:nil];
}

- (IBAction)doSearch:(id)sender {
    if (isBlindMode) {
        [self performSegueWithIdentifier:@"show_search" sender:nil];
    } else {
        state = ViewStateTransition;
        [self updateView];
        [_webView triggerWebviewControl:HLPWebviewControlRouteSearchButton];
    }
}

- (IBAction)stopNavigation:(id)sender {
    
    if (isBlindMode) {
        if ([navigator isActive]) {
            [[NavDataStore sharedDataStore] clearRoute];

            [_webView logToServer:@{@"event": @"navigation", @"status": @"canceled"}];
            [NavDataStore sharedDataStore].previewMode = NO;
            [NavDataStore sharedDataStore].exerciseMode = NO;
            [previewer setAutoProceed:NO];
        }
    } else {
        state = ViewStateTransition;
        [self updateView];
        [_webView triggerWebviewControl:HLPWebviewControlNone];
    }
}

- (IBAction)doCancel:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [_webView triggerWebviewControl:HLPWebviewControlNone];
}

- (IBAction)doDone:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [_webView triggerWebviewControl:HLPWebviewControlDoneButton];
}

- (IBAction)doBack:(id)sender {

    if (isBlindMode) {
        
#if NavCogMiraikan
        [self.navigationController popViewControllerAnimated:YES];
#else
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
#endif
        
    } else {
        switch(state) {
            case ViewStateSearch:
                state = ViewStateTransition;
                [self updateView];
                [_webView triggerWebviewControl:HLPWebviewControlNone];
                break;
            case ViewStateSearchDetail:
                [_webView triggerWebviewControl:HLPWebviewControlBackToControl];
                break;
            case ViewStateSearchSetting:
                [_webView triggerWebviewControl:HLPWebviewControlBackToControl];
                break;
            case ViewStateRouteConfirm:
                [_webView triggerWebviewControl:HLPWebviewControlBackToControl];
                break;
            case ViewStateRouteCheck:
                [_webView triggerWebviewControl:HLPWebviewControlBackToControl];
                break;
            default:
                
#if NavCogMiraikan
                [self.navigationController popViewControllerAnimated:YES];
#else
                [self.navigationController dismissViewControllerAnimated:YES completion:nil];
#endif
                break;
        }
    }
}

- (IBAction)retry:(id)sender {
    [_webView reload];
    _retryButton.hidden = YES;
    _errorMessage.hidden = YES;
}

// blind
- (double)turnAction
{
    return turnAction;
}

// blind
- (BOOL)forwardAction
{
    return forwardAction;
}

// blind
- (void)stopAction
{
    [motionManager stopDeviceMotionUpdates];
}

// blind
- (void)startAction
{
    BOOL exerciseMode = [NavDataStore sharedDataStore].exerciseMode;
    BOOL previewWithAction = [[NSUserDefaults standardUserDefaults] boolForKey:@"preview_with_action"] && !exerciseMode;
    if (!motionManager && (previewWithAction || exerciseMode)) {
        motionManager = [[CMMotionManager alloc] init];
        motionManager.deviceMotionUpdateInterval = 0.1;
        motionQueue = [[NSOperationQueue alloc] init];
        motionQueue.maxConcurrentOperationCount = 1;
        motionQueue.qualityOfService = NSQualityOfServiceBackground;
    }
    if (previewWithAction) {
        [motionManager startDeviceMotionUpdatesToQueue:motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            yaws[yawsIndex] = motion.attitude.yaw;
            yawsIndex = (yawsIndex+1)%10;
            double ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += yaws[i]*0.1;
            }
            //NSLog(@"angle=, %f, %f, %f", ave, motion.attitude.yaw, fabs(ave - motion.attitude.yaw));
            if (fabs(ave - motion.attitude.yaw) > M_PI*10/180) {
                turnAction = ave - motion.attitude.yaw;
            } else {
                turnAction = 0;
            }
            
            CMAcceleration acc =  motion.userAcceleration;
            double d = sqrt(pow(acc.x, 2)+pow(acc.y, 2)+pow(acc.z, 2));
            accs[accsIndex] = d;
            accsIndex = (accsIndex+1)%10;
            ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += accs[i]*0.1;
            }
            //NSLog(@"angle=, %f", ave);
            forwardAction = ave > 0.3;
            
        }];
    }
    if (exerciseMode) {
        [motionManager startDeviceMotionUpdatesToQueue:motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            if (yawsIndex > 0) {
                turnAction = [HLPLocation normalizeDegree:-(motion.attitude.yaw - yaws[0])/M_PI*180];
            } else {
                turnAction = 0;
            }
            yaws[0] = motion.attitude.yaw;
            yawsIndex = 1;
            
            CMAcceleration acc =  motion.userAcceleration;
            double d = sqrt(pow(acc.x, 2)+pow(acc.y, 2)+pow(acc.z, 2));
            accs[accsIndex] = d;
            accsIndex = (accsIndex+1)%10;
            double ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += accs[i]*0.1;
            }
            forwardAction = ave > 0.05;
        }];
        
    }
}

// blind
#pragma mark - NavNavigatorDelegate

- (void)didActiveStatusChanged:(NSDictionary *)properties
{
    [commander didActiveStatusChanged:properties];
    [previewer didActiveStatusChanged:properties];
    BOOL isActive = [properties[@"isActive"] boolValue];
    BOOL requestBackground = isActive && ![NavDataStore sharedDataStore].previewMode;
    if (!requestBackground) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_BACKGROUND_LOCATION object:self userInfo:@{@"value":@(requestBackground)}];
    if ([properties[@"isActive"] boolValue]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateIndicatorStart];
            [_webView evaluateJavaScript:@"$hulop.map.setSync(true);"
                       completionHandler:^(id _Nullable result, NSError * _Nullable error) {
                [self updateIndicatorStop];
            }];
        });
            
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_as_start_point"] && !rerouteFlag) {
            [[NavDataStore sharedDataStore] manualLocationReset:properties];
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_as_start_heading"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_HEADING_RESET object:self userInfo:properties];
            } else {
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:self userInfo:properties];
            }
        }
        
        if (!rerouteFlag) {
            [_webView logToServer:@{@"event": @"navigation", @"status": @"started"}];
        } else {
            [_webView logToServer:@{@"event": @"navigation", @"status": @"rerouted"}];
        }

        if ([NavDataStore sharedDataStore].previewMode) {
            [[NavDataStore sharedDataStore] manualLocationReset:properties];
            double delayInSeconds = 2.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [previewer setAutoProceed:YES];
            });
        }

        rerouteFlag = NO;
    } else {
        [previewer setAutoProceed:NO];
    }
    [self updateView];
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    [commander couldNotStartNavigation:properties];
    [previewer couldNotStartNavigation:properties];
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideModalWaiting];
    });
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    [NavDataStore sharedDataStore].start = [[NSDate date] timeIntervalSince1970];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateIndicatorStart];
        [_webView evaluateJavaScript:[NSString stringWithFormat:@"$hulop.map.getMap().getView().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]]
                   completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            [self updateIndicatorStop];
        }];

        [NavUtil hideModalWaiting];
    });
    
    
    [commander didNavigationStarted:properties];
    [previewer didNavigationStarted:properties];

    NSArray *temp = [[NavDataStore sharedDataStore] route];
    if (temp) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_SHOW_ROUTE object:self userInfo:@{@"route":temp}];
    }
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"stabilize_localize_on_elevator"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_STABILIZE_LOCALIZE object:self];
    }
    
    [_webView logToServer:@{@"event": @"navigation", @"status": @"finished"}];

    [commander didNavigationFinished:properties];
    [previewer didNavigationFinished:properties];
    
    [[NavDataStore sharedDataStore] clearRoute];  // new
}

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    [commander userNeedsToChangeHeading:properties];
    [previewer userNeedsToChangeHeading:properties];
}
- (void)userAdjustedHeading:(NSDictionary*)properties
{
    [commander userAdjustedHeading:properties];
    [previewer userAdjustedHeading:properties];
}
- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    [commander remainingDistanceToTarget:properties];
    [previewer remainingDistanceToTarget:properties];
}
- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    [commander userIsApproachingToTarget:properties];
    [previewer userIsApproachingToTarget:properties];
}
- (void)userIsHeadingToPOI:(NSDictionary*)properties
{
    [commander userIsHeadingToPOI:properties];
    [previewer userIsHeadingToPOI:properties];
}
- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    [commander userNeedsToTakeAction:properties];
    [previewer userNeedsToTakeAction:properties];
}
- (void)userNeedsToWalk:(NSDictionary*)properties
{
    [commander userNeedsToWalk:properties];
    [previewer userNeedsToWalk:properties];
}
- (void)userGetsOnElevator:(NSDictionary *)properties
{
    [commander userGetsOnElevator:properties];
    [previewer userGetsOnElevator:properties];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties
{
    [commander userMaybeGoingBackward:properties];
    [previewer userMaybeGoingBackward:properties];
}
- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    [commander userMaybeOffRoute:properties];
    [previewer userMaybeOffRoute:properties];
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    [commander userMayGetBackOnRoute:properties];
    [previewer userMayGetBackOnRoute:properties];
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    [commander userShouldAdjustBearing:properties];
    [previewer userShouldAdjustBearing:properties];
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    [commander userIsApproachingToPOI:properties];
    [previewer userIsApproachingToPOI:properties];
}
- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    [commander userIsLeavingFromPOI:properties];
    [previewer userIsLeavingFromPOI:properties];
}

// Summary
- (NSString*)summaryString:(NSDictionary *)properties
{
    return [commander summaryString:properties];
}

- (void)currentStatus:(NSDictionary *)properties
{
    [commander currentStatus:properties];
}

- (void)requiresHeadingCalibration:(NSDictionary *)properties
{
    [commander requiresHeadingCalibration:properties];
}

- (void)playHeadingAdjusted:(int)level
{
    [[NavSound sharedInstance] playHeadingAdjusted:level];
}
- (void)reroute:(NSDictionary *)properties
{
    [self updateIndicatorStart];
    rerouteFlag = YES;
    [commander reroute:properties];
    NavDataStore *nds = [NavDataStore sharedDataStore];
    [nds clearRoute];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *prefs = @{
                            @"dist":@"500",
                            @"preset":@"9",
                            @"min_width":@"8",
                            @"slope":@"9",
                            @"road_condition":@"9",
                            @"deff_LV":@"9",
                            @"stairs":[ud boolForKey:@"route_use_stairs"]?@"9":@"1",
                            @"esc":[ud boolForKey:@"route_use_escalator"]?@"9":@"1",
                            @"elv":[ud boolForKey:@"route_use_elevator"]?@"9":@"1",
                            @"mvw":[ud boolForKey:@"route_use_moving_walkway"]?@"9":@"1",
                            @"tactile_paving":[ud boolForKey:@"route_tactile_paving"]?@"1":@"",
                            };
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil showModalWaitingWithMessage:NSLocalizedString(@"Loading, please wait",@"")];
    });
    [nds requestRerouteFrom:[NavDataStore destinationForCurrentLocation]._id
                         To:nds.to._id
            withPreferences:prefs
                   complete:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideModalWaiting];
            [self updateIndicatorStop];
        });
    }];
}

#pragma mark - NavCommanderDelegate

- (void)speak:(NSString *)text force:(BOOL)isForce completionHandler:(void (^)(void))handler
{
    if (!isBlindMode &&
        (![[NSUserDefaults standardUserDefaults] boolForKey:@"isVoiceGuideOn"])) {
        handler();
        return;
    }

    [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force": @(isForce)} completionHandler:handler];
}

// blind
- (void)speak:(NSString*)text withOptions:(NSDictionary*)options completionHandler:(void (^)(void))handler
{
    if (!isBlindMode &&
        (![[NSUserDefaults standardUserDefaults] boolForKey:@"isVoiceGuideOn"])) {
        handler();
        return;
    }

    [[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:handler];
}

// blind
- (void)playSuccess
{
    BOOL result = [[NavSound sharedInstance] vibrate:nil];
    result = [[NavSound sharedInstance] playAnnounceNotification] || result;
    if (result) {
        [[NavDeviceTTS sharedTTS] pause:NAV_SOUND_DELAY];
    }
}

- (BOOL)isSpeaking
{
    return [[NavDeviceTTS sharedTTS] isSpeaking];
}

- (void)vibrate
{
    if (isBlindMode) {
        BOOL result = [[NavSound sharedInstance] vibrate:nil];
        result = [[NavSound sharedInstance] playAnnounceNotification] || result;
        if (result) {
            [[NavDeviceTTS sharedTTS] pause:NAV_SOUND_DELAY];
        }
    } else {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

// blind
- (void)executeCommand:(NSString *)command
{
    JSContext *ctx = [[JSContext alloc] init];
    ctx[@"speak"] = ^(NSString *message) {
        [self speak:message withOptions:@{} completionHandler:^{
        }];
    };
    ctx[@"speakInLang"] = ^(NSString *message, NSString *lang) {
        [self speak:message withOptions:@{@"lang":lang} completionHandler:^{
        }];
    };
    ctx[@"openURL"] = ^(NSString *url, NSString *title, NSString *message) {
        if (!title || !message || !url) {
            if (url) {
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]
                                                       options:@{}
                                             completionHandler:^(BOOL success) {
                    }];
                });
            }
            return;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  }]];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                      dispatch_async(dispatch_get_main_queue(), ^(void){
                                                          [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]
                                                                                             options:@{}
                                                                                   completionHandler:^(BOOL success) {}];
                                                      });
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alert animated:YES completion:nil];
        });
    };
    ctx.exceptionHandler = ^(JSContext *ctx, JSValue *e) {
        NSLog(@"%@", e);
        NSLog(@"%@", [e toDictionary]);
    };
    [ctx evaluateScript:command];
}

- (void)showPOI:(NSString *)contentURL withName:(NSString*)name
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (contentURL == nil && name == nil) {
            if (showingPage) {
                [showingPage.navigationController popViewControllerAnimated:YES];
            }
            return;
        }
        if (showingPage) {
            return;
        }
        
        showingPage = [WebViewController getInstance];
        showingPage.delegate = self;
        
        NSURL *url = nil;
        if ([contentURL hasPrefix:@"bundle://"]) {
            NSString *tempurl = [contentURL substringFromIndex:@"bundle://".length];
            NSString *file = [tempurl lastPathComponent];
            NSString *ext = [file pathExtension];
            NSString *name = [file stringByDeletingPathExtension];
            NSString *dir = [tempurl stringByDeletingLastPathComponent];
            url = [[NSBundle mainBundle] URLForResource:name withExtension:ext subdirectory:dir];
        } else {
            url = [NSURL URLWithString:contentURL];
        }
        
        showingPage.title = name;
        showingPage.url = url;
        [self.navigationController showViewController:showingPage sender:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_PAUSE object:nil];
    });
}

- (void)webViewControllerClosed:(WebViewController *)controller
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_RESUME object:nil];
    showingPage = nil;
}

// blind
- (void)handleLocaionUnknown:(NSNotification*)note
{
    if (self.navigationController.topViewController == self) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_UNKNOWN object:self];
    }
}

// 追加機能
- (void)webFooterHidden
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateIndicatorStart];
        [self.webView evaluateJavaScript: @"document.getElementById('map-footer').style.display ='none';"
                       completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            [self updateIndicatorStop];
        }];
    });
}

- (void)setDestinationId:(NSString*)destinationId {
    destId = destinationId;
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLocation *loc = [nds currentLocation];
    BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
    if (!validLocation) {
        [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Locating...", @"BlindView", @"")];
    }
}

- (void)startNavi {
    
    if (!isBlindMode) {
        if (destId != nil) {
            if (!isNaviStarted) {
                __block NSMutableDictionary *prefs = SettingDataManager.sharedManager.getPrefs;
                NSString *elv = [NSString stringWithFormat: @"&elv=%@", prefs[@"elv"]];
                NSString *stairs = [NSString stringWithFormat: @"&stairs=%@", prefs[@"stairs"]];
                NSString *esc = [NSString stringWithFormat: @"&esc=%@", prefs[@"esc"]];
                NSString *dist = [NSString stringWithFormat: @"&dist=%@", prefs[@"dist"]];
                NSString *hash = [NSString stringWithFormat: @"navigate=%@&dummy=%f%@%@%@%@",
                                  destId, [[NSDate date] timeIntervalSince1970], elv, stairs, esc, dist];
                state = ViewStateNavigation;
                [talkButton setHidden:true];
                [_webView setLocationHash:hash];
                isNaviStarted = YES;
                return;
            }
        }
    } else {
        [self setupNavigation];
    }
}

- (void)initMap {
    destId = nil;
    if (isNaviStarted) {
        [self stopNavigation:nil];
    }
    isNaviStarted = false;
//    state = ViewStateMap;
}


// blind
- (void)setupNavigation
{
    if (isNaviStarted) {
        return;
    }

    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (nds.directory == nil) {
        return;
    }

    NavDestination *from = [NavDataStore destinationForCurrentLocation];
    NavDestination *to = [nds destinationByID:destId];

    HLPLocation *location = nds.currentLocation;
    if (isnan(location.lat) || isnan(location.lng)) {
        location = from.location;
    }

    __block NSMutableDictionary *prefs = SettingDataManager.sharedManager.getPrefs;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionAllowBluetooth
                                           error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    [self updateIndicatorStart];
    dispatch_async(dispatch_get_main_queue(), ^{
        isNaviStarted = YES;
        [nds requestRouteFrom:from.singleId
                           To:to._id
              withPreferences:prefs
                     complete:^{
            if (self == nil) return;
            nds.previewMode = NO;
            nds.exerciseMode = NO;
            [self updateIndicatorStop];
        }];
    });
}

- (void)setTalkButton
{
    if (!talkButton) {
        double scale = 0.75;
        double size = (113*scale)/2;
        double x = size+8;
        double y = self.view.bounds.size.height + self.view.bounds.origin.y - (size+8);
        y -= self.view.safeAreaInsets.bottom;

        talkButton = [[NavTalkButton alloc] initWithFrame:CGRectMake(x - size, y - size, size * 2, size * 2)];
        [talkButton setHidden:true];
        [self.view addSubview: talkButton];
        [talkButton addTarget:self action:@selector(talkTap:) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)updateIndicatorStart
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_updateIndicator startAnimating];
        _updateIndicator.hidden = NO;
    });
}

- (void)updateIndicatorStop
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_updateIndicator stopAnimating];
        _updateIndicator.hidden = YES;
    });
}

@end
