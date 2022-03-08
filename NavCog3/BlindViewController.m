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

#import "BlindViewController.h"

#import "NavDeviceTTS.h"
#import "NavSound.h"

#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavUtil.h"

#import "NavDebugHelper.h"

#import "RatingViewController.h"

#import "SettingViewController.h"

#import "ServerConfig.h"

#import <HLPLocationManager/HLPLocationManager+Player.h>
#import "DefaultTTS.h"
#import <CoreMotion/CoreMotion.h>

@import JavaScriptCore;
@import CoreMotion;


@interface BlindViewController () {
    NavNavigator *navigator;
    NavCommander *commander;
    NavPreviewer *previewer;
    
    NSTimer *timerForSimulator;
    
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
    
    UIColor *defaultColor;
    
    DialogViewHelper *dialogHelper;
    
    NSTimeInterval lastShake;
    
    NSTimeInterval lastLocationSent;
    NSTimeInterval lastOrientationSent;
    
    BOOL initialViewDidAppear;
    BOOL needVOFocus;
    WebViewController *showingPage;
}

@end

@implementation BlindViewController

- (void)dealloc
{
    NSLog(@"dealloc BlindViewController");
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
    
    dialogHelper.delegate = nil;
    dialogHelper = nil;
    
    _settingButton = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_STOP object:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    initialViewDidAppear = YES;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    _webView = [[NavBlindWebView alloc] initWithFrame:CGRectMake(0,0,0,0) configuration:[[WKWebViewConfiguration alloc] init]];
    _webView.isDeveloperMode = [ud boolForKey:@"developer_mode"];
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
    
    navigator = [[NavNavigator alloc] init];
    commander = [[NavCommander alloc] init];
    previewer = [[NavPreviewer alloc] init];
    navigator.delegate = self;
    commander.delegate = self;
    previewer.delegate = self;
    _cover.fsSource = navigator;
    
    defaultColor = self.navigationController.navigationBar.barTintColor;
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
    self.searchButton.enabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logReplay:) name:REQUEST_LOG_REPLAY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(debugPeerStateChanged:) name:DEBUG_PEER_STATE_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestDialogStart:) name:REQUEST_DIALOG_START object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogStateChanged:) name:DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLocaionUnknown:) name:REQUEST_HANDLE_LOCATION_UNKNOWN object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name: REQUEST_OPEN_URL object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestRating:) name:REQUEST_RATING object:nil];


    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkMapCenter:) userInfo:nil repeats:YES];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(destinationChanged:) name:DESTINATIONS_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeCleared:) name:ROUTE_CLEARED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manualLocation:) name:MANUAL_LOCATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestShowRoute:) name:REQUEST_PROCESS_SHOW_ROUTE object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareForDealloc) name:REQUEST_UNLOAD_VIEW object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
    
    [self updateView];
    
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"first_launch"]) {
        NSURL *url = [WebViewController hulopHelpPageURLwithType:@"instructions" languageDetection:YES];
        __weak typeof(self) weakself = self;
        [WebViewController checkHttpStatusWithURL:url completionHandler:^(NSURL * _Nonnull url, NSInteger statusCode) {
            __weak NSURL *weakurl = url;
            dispatch_async(dispatch_get_main_queue(), ^{
                WebViewController *vc = [WebViewController getInstance];
                if (statusCode == 200) {
                    vc.url = weakurl;
                } else {
                    vc.url = [WebViewController hulopHelpPageURLwithType:@"instructions" languageDetection:NO];
                }
                vc.title = NSLocalizedString(@"Instructions", @"");
                [weakself.navigationController showViewController:vc sender:weakself];
            });
        }];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"first_launch"];
    }

    BOOL checked = [ud boolForKey:@"checked_altimeter"];
    if (!checked && ![CMAltimeter isRelativeAltitudeAvailable]) {
        NSString *title = NSLocalizedString(@"NoAltimeterAlertTitle", @"");
        NSString *message = NSLocalizedString(@"NoAltimeterAlertMessage", @"");
        NSString *ok = NSLocalizedString(@"I_Understand", @"");
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:ok
                                                  style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  }]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self topMostController] presentViewController:alert animated:YES completion:nil];
        });
        [ud setBool:YES forKey:@"checked_altimeter"];
    }
}

- (void)elementDidBecomeFocused:(NSNotification*)note
{
    NSLog(@"elementDidBecomeFocused");
    if (needVOFocus) {
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _cover.center);
        needVOFocus = NO;
    }
}

- (UIViewController*) topMostController
{
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    return topController;
}

- (void) checkMapCenter:(NSTimer*)timer
{
    [_webView getCenterWithCompletion:^(HLPLocation *loc) {
        if (loc != nil) {
            [NavDataStore sharedDataStore].mapCenter = loc;
            HLPLocation *cloc = [NavDataStore sharedDataStore].currentLocation;
            if (isnan(cloc.lat) || isnan(cloc.lng)) {
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


- (void) openURL:(NSNotification*)note
{
    [NavUtil openURL:[note userInfo][@"url"] onViewController:self];
}

- (void) requestRating:(NSNotification*)note
{
    if ([NavDataStore sharedDataStore].previewMode == NO &&
        [[ServerConfig sharedConfig] shouldAskRating]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self performSegueWithIdentifier:@"show_rating" sender:self];
        });
    }
}

- (void)dialogViewTapped
{
    [dialogHelper inactive];
    dialogHelper.helperView.disabled = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_DIALOG_START object:self];
}

- (void)dialogStateChanged:(NSNotification*)note
{
    [self updateView];
}

// show p2p debug
- (void)handleSettingLongPressGesture:(UILongPressGestureRecognizer*)sender
{
    if (sender.state == UIGestureRecognizerStateBegan && sender.numberOfTouches == 1) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NavDebugHelper *dhelper = [NavDebugHelper sharedHelper];
            [dhelper start];
            
            MCBrowserViewController *viewController = [[MCBrowserViewController alloc] initWithServiceType:NAVCOG3_DEBUG_SERVICE_TYPE
                                                                                                   session:dhelper.session];
            viewController.delegate = self;
            
            [self presentViewController:viewController animated:YES completion:nil];
        });
    }
}

- (BOOL)browserViewController:(MCBrowserViewController *)browserViewController
      shouldPresentNearbyPeer:(MCPeerID *)peerID
            withDiscoveryInfo:(NSDictionary *)info
{
    return YES;
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController
{
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}


- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (UILabel*)findLabel:(NSArray*)views
{
    for(UIView* view in views) {
        if ([view isKindOfClass:UILabel.class]) {
            return (UILabel*)view;
        }
        if (view.subviews) {
            UILabel* result = [self findLabel:view.subviews];
            if (result) {
                return result;
            }
        }
    }
    return (UILabel*)nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(elementDidBecomeFocused:) name:AccessibilityElementDidBecomeFocused object:nil];
    
    if (!initialViewDidAppear) {
        needVOFocus = YES;
    }
    initialViewDidAppear = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_ACCELEARATION object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_STABILIZE_LOCALIZE object:self];
    [self becomeFirstResponder];
    
    if (!dialogHelper) {
        dialogHelper = [[DialogViewHelper alloc] init];
        double scale = 0.75;
        double size = (113*scale)/2;
        double x = size+8;
        double y = self.view.bounds.size.height + self.view.bounds.origin.y - (size+8);
        if (@available(iOS 11.0, *)) {
            y -= self.view.safeAreaInsets.bottom;
        }
        dialogHelper.scale = scale;
        [dialogHelper inactive];
        [dialogHelper setup:self.view position:CGPointMake(x, y)];
        dialogHelper.delegate = self;
        dialogHelper.helperView.hidden = YES;
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

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

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_ACCELEARATION object:self];
    [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_STABILIZE_LOCALIZE object:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AccessibilityElementDidBecomeFocused object:nil];
}

- (void)debugPeerStateChanged:(NSNotification*)note
{
    [self updateView];
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchButton.title = NSLocalizedStringFromTable([self->navigator isActive]?@"Stop":@"Search", @"BlindView", @"");
        [self.searchButton setAccessibilityLabel:NSLocalizedStringFromTable([self->navigator isActive]?@"Stop Navigation":@"Search Route", @"BlindView", @"")];
        
        BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
        BOOL debugFollower = [[NSUserDefaults standardUserDefaults] boolForKey:@"p2p_debug_follower"];
        BOOL hasCenter = [[NavDataStore sharedDataStore] mapCenter] != nil;
        BOOL previewMode = [NavDataStore sharedDataStore].previewMode;
        BOOL exerciseMode = [NavDataStore sharedDataStore].exerciseMode;
        BOOL isActive = [self->navigator isActive];
        BOOL peerExists = [[[NavDebugHelper sharedHelper] peers] count] > 0;

        self.devGo.hidden = !devMode || previewMode;
        self.devLeft.hidden = !devMode || previewMode;
        self.devRight.hidden = !devMode || previewMode;
        self.devAuto.hidden = !devMode || previewMode || !isActive;
        self.devReset.hidden = !devMode || previewMode;
        self.devMarker.hidden = !devMode || previewMode;
        
        self.devUp.hidden = !devMode || previewMode;
        self.devDown.hidden = !devMode || previewMode;
        self.devNote.hidden = !devMode || previewMode;
        self.devRestart.hidden = !devMode || previewMode;
        
        self.devAuto.selected = self->previewer.autoProceed;
        //self.cover.hidden = devMode || !isActive;
        self.cover.hidden = devMode;
        
        self.searchButton.enabled = hasCenter;
        
        self.navigationItem.leftBarButtonItem = nil;
        if ((isActive && !devMode) || previewMode || self->initFlag) {
        } else {
            self.navigationItem.leftBarButtonItem = self->_settingButton;
            UILongPressGestureRecognizer* longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSettingLongPressGesture:)];
            longPressGesture.minimumPressDuration = 1.0;
            longPressGesture.numberOfTouchesRequired = 1;
            [[self->_settingButton valueForKey:@"view"] addGestureRecognizer:longPressGesture];
        }
        
        UILabel *titleView = [[UILabel alloc] init];
        titleView.text = NSLocalizedStringFromTable(exerciseMode?@"Exercise":(previewMode?@"Preview":@"NavCog"), @"BlindView", @"");
        if (debugFollower) {
            titleView.text = NSLocalizedStringFromTable(@"Follow", @"BlindView", @"");
        }
        titleView.accessibilityLabel = @"( )";
        titleView.accessibilityTraits = UIAccessibilityTraitStaticText;
        self.navigationItem.titleView = titleView;
        
        if (debugFollower || self->initFlag) {
            self.navigationItem.rightBarButtonItem = nil;
        } else {
            self.navigationItem.rightBarButtonItem = self->_searchButton;
        }
        
        if (peerExists) {
            self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.9 alpha:1.0];
        } else {
            //self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.9 alpha:1.0];
            self.navigationController.navigationBar.barTintColor = self->defaultColor;
        }
        
        [self dialogHelperUpdate];
        
        NSString *cn = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"lastcommit" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
        [self.commitLabel setText:cn];
        
        NSMutableArray *elements = [@[self.navigationItem] mutableCopy];
        if (self->dialogHelper && self->dialogHelper.helperView && !self->dialogHelper.helperView.hidden) {
            [elements addObject:self->dialogHelper.helperView];
        }
        [elements addObject:self->_cover];
        self.view.accessibilityElements = elements;
    });
}

- (void) dialogHelperUpdate
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLocation *loc = [nds currentLocation];
    BOOL validLocation = loc && !isnan(loc.lat) && !isnan(loc.lng) && !isnan(loc.floor);
    BOOL isPreviewDisabled = [[ServerConfig sharedConfig] isPreviewDisabled];
    BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
    BOOL hasCenter = [[NavDataStore sharedDataStore] mapCenter] != nil;
    BOOL isActive = [navigator isActive];

    if ([[DialogManager sharedManager] isAvailable] && !isActive) {
        if (dialogHelper.helperView.hidden) {
            dialogHelper.helperView.hidden = NO;
            [dialogHelper recognize];
        }
        dialogHelper.helperView.disabled = !(hasCenter && (!isPreviewDisabled || devMode || validLocation));
    } else {
        dialogHelper.helperView.hidden = YES;
    }
}


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
                NSLog(@"%@", mv.message.text);
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

- (void)locationStatusChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HLPLocationStatus status = [[note userInfo][@"status"] unsignedIntegerValue];
        
        switch(status) {
            case HLPLocationStatusLocating:
                [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Locating...", @"BlindView", @"")];
                break;
            default:
                [NavUtil hideWaitingForView:self.view];
        }        
    });
}

- (void) actionPerformed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY_STOP object:self];
}

#pragma mark - MKWebViewDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
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

- (void)webView:(HLPWebView *)webView openURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL object:self userInfo:@{@"url": url}];
}

- (void)speak:(NSString *)text force:(BOOL)isForce completionHandler:(void (^)(void))handler
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force": @(isForce)} completionHandler:handler];
}

- (BOOL)isSpeaking
{
    return [[NavDeviceTTS sharedTTS] isSpeaking];
}

/*
- (void)vibrate
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}
 */

- (void)webView:(HLPWebView *)webView didChangeLatitude:(double)lat longitude:(double)lng floor:(double)floor synchronized:(BOOL)sync
{
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
    NSDictionary *navigationInfo =
    @{
      @"start": @(start),
      @"end": @(end),
      @"from": from,
      @"to": to,
      };
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RATING object:self userInfo:navigationInfo];
}



#pragma mark - notification handlers

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
        if (!location || [location isEqual:[NSNull null]]) {
            return;
        }
        
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        
        double orientation = -location.orientation / 180 * M_PI;
        
        if (self->lastOrientationSent + 0.2 < now) {
            [self->_webView sendData:@[@{
                                   @"type":@"ORIENTATION",
                                   @"z":@(orientation)
                                   }]
                    withName:@"Sensor"];
            self->lastOrientationSent = now;
        }
        
        
        location = locations[@"actual"];
        if (!location || [location isEqual:[NSNull null]]) {
            return;
        }
        
        /*
         if (isnan(location.lat) || isnan(location.lng)) {
         return;
         }
         */
        
        if (now < self->lastLocationSent + [[NSUserDefaults standardUserDefaults] doubleForKey:@"webview_update_min_interval"]) {
            if (!location.params) {
                return;
            }
            //return; // prevent too much send location info
        }
        
        double floor = location.floor;
        
        [self->_webView sendData:@{
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
        
        self->lastLocationSent = now;
        [self dialogHelperUpdate];
    });
}

- (void) destinationChanged: (NSNotification*) note
{
    [_webView initTarget:[note userInfo][@"destinations"]];
}

- (void) routeCleared: (NSNotification*) note
{
    [_webView clearRoute];
}

- (void)requestShowRoute:(NSNotification*)note
{
    NSArray *route = [note userInfo][@"route"];
    [_webView showRoute:route];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"developer_mode"]) {
        _webView.isDeveloperMode = @([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]);
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBActions

- (IBAction)turnLeftBit:(id)sender
{
    [previewer manualTurn:-10];
}

- (IBAction)turnRightBit:(id)sender {
    [previewer manualTurn:10];
}

- (IBAction)goForwardBit:(id)sender {
    [previewer manualGoForward:0.5];
}

- (IBAction)floorUp:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    
    [previewer manualGoFloor:floor+1];
}

- (IBAction)floorDown:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    [previewer manualGoFloor:floor-1];
}

- (IBAction)addNote:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add Note"
                                                                   message:@"Input note for log"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
    }];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  NSLog(@"Note,%@,%ld",[[alert.textFields objectAtIndex:0]text],(long)([[NSDate date] timeIntervalSince1970]*1000));
                                              }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)resetLocation:(id)sender {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_HEADING_RESET object:self userInfo:
     @{
       @"location":loc,
       @"heading":@(loc.orientation)
       }];
}

- (IBAction)makeMarker:(id)sender {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    long timestamp = (long)([[NSDate date] timeIntervalSince1970]*1000);
    NSLog(@"Marker,%f,%f,%f,%ld",loc.lat,loc.lng,loc.floor,timestamp);
}

- (IBAction)restartLocalization:(id)sender {
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESTART object:self];
}

- (IBAction)retry:(id)sender {
    [_webView reload];
    _retryButton.hidden = YES;
    _errorMessage.hidden = YES;
}


- (IBAction)autoProceed:(id)sender {
    [previewer setAutoProceed:!previewer.autoProceed];
    [self updateView];
}

- (double)turnAction
{
    return turnAction;
}

- (BOOL)forwardAction
{
    return forwardAction;
}

- (void)stopAction
{
    [motionManager stopDeviceMotionUpdates];    
}

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
            self->yaws[self->yawsIndex] = motion.attitude.yaw;
            self->yawsIndex = (self->yawsIndex+1)%10;
            double ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += self->yaws[i]*0.1;
            }
            //NSLog(@"angle=, %f, %f, %f", ave, motion.attitude.yaw, fabs(ave - motion.attitude.yaw));
            if (fabs(ave - motion.attitude.yaw) > M_PI*10/180) {
                self->turnAction = ave - motion.attitude.yaw;
            } else {
                self->turnAction = 0;
            }
            
            CMAcceleration acc =  motion.userAcceleration;
            double d = sqrt(pow(acc.x, 2)+pow(acc.y, 2)+pow(acc.z, 2));
            self->accs[self->accsIndex] = d;
            self->accsIndex = (self->accsIndex+1)%10;
            ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += self->accs[i]*0.1;
            }
            //NSLog(@"angle=, %f", ave);
            self->forwardAction = ave > 0.3;
            
        }];
    }
    if (exerciseMode) {
        [motionManager startDeviceMotionUpdatesToQueue:motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            if (self->yawsIndex > 0) {
                self->turnAction = [HLPLocation normalizeDegree:-(motion.attitude.yaw - self->yaws[0])/M_PI*180];
            } else {
                self->turnAction = 0;
            }
            self->yaws[0] = motion.attitude.yaw;
            self->yawsIndex = 1;
            
            CMAcceleration acc =  motion.userAcceleration;
            double d = sqrt(pow(acc.x, 2)+pow(acc.y, 2)+pow(acc.z, 2));
            self->accs[self->accsIndex] = d;
            self->accsIndex = (self->accsIndex+1)%10;
            double ave = 0;
            for(int i = 0; i < 10; i++) {
                ave += self->accs[i]*0.1;
            }
            self->forwardAction = ave > 0.05;
        }];
        
    }
}

#pragma mark - NavNavigator actions

- (IBAction)repeatLastSpokenAction:(id)sender
{
    
}

// tricky information in NavCog
// If there is any accessibility information the user is notified
// The user can access the information by executing this command
- (IBAction)speakAccessibilityInfo:(id)sender
{
    
}

// speak surroungind information
//  - link info for source node
//  - transit info
- (IBAction)speakSurroundingPOI:(id)sender
{
    
}

- (IBAction)stopNavigation:(id)sender
{
    
}

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
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]) {
                [self->_webView evaluateJavaScript:@"$hulop.map.setSync(true);" completionHandler:nil];
            }
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
                [self->previewer setAutoProceed:YES];
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
    if (timerForSimulator) {
        [timerForSimulator invalidate];
        timerForSimulator = nil;
    }
    [NavDataStore sharedDataStore].start = [[NSDate date] timeIntervalSince1970];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_webView evaluateJavaScript:[NSString stringWithFormat:@"$hulop.map.getMap().getView().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]] completionHandler:nil];

        //_cover.preventCurrentStatus = YES;
        [NavUtil hideModalWaiting];
    });
    
    
    //double delayInSeconds = 1.0;
    //dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    //dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        //_cover.preventCurrentStatus = NO;
        [commander didNavigationStarted:properties];
        [previewer didNavigationStarted:properties];

        NSArray *temp = [[NavDataStore sharedDataStore] route];
        //temp = [temp arrayByAddingObjectsFromArray:properties[@"oneHopLinks"]];
        if (temp) {
            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_SHOW_ROUTE object:self userInfo:@{@"route":temp}];
        }
        //[helper showRoute:temp];
    //});
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"stabilize_localize_on_elevator"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:DISABLE_STABILIZE_LOCALIZE object:self];
    }
    
    [_webView logToServer:@{@"event": @"navigation", @"status": @"finished"}];

    [commander didNavigationFinished:properties];
    [previewer didNavigationFinished:properties];
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
    [nds requestRerouteFrom:[NavDataStore destinationForCurrentLocation]._id To:nds.to._id withPreferences:prefs complete:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideModalWaiting];
        });
    }];
}

#pragma mark - NavCommanderDelegate

- (void)speak:(NSString*)text withOptions:(NSDictionary*)options completionHandler:(void (^)(void))handler
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:handler];
}

- (void)playSuccess
{
    BOOL result = [[NavSound sharedInstance] vibrate:nil];
    result = [[NavSound sharedInstance] playAnnounceNotification] || result;
    if (result) {
        [[NavDeviceTTS sharedTTS] pause:NAV_SOUND_DELAY];
    }
}

- (void)vibrate
{
    BOOL result = [[NavSound sharedInstance] vibrate:nil];
    result = [[NavSound sharedInstance] playAnnounceNotification] || result;
    if (result) {
        [[NavDeviceTTS sharedTTS] pause:NAV_SOUND_DELAY];
    }
}

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
            if (self->showingPage) {
                [self->showingPage.navigationController popViewControllerAnimated:YES];
            }
            return;
        }
        if (self->showingPage) {
            return;
        }
        
        self->showingPage = [WebViewController getInstance];
        self->showingPage.delegate = self;
        
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
        
        self->showingPage.title = name;
        self->showingPage.url = url;
        [self.navigationController showViewController:self->showingPage sender:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_PAUSE object:nil];
    });
}

- (void)webViewControllerClosed:(WebViewController *)controller
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_NAVIGATION_RESUME object:nil];
    showingPage = nil;
}

- (void)requestDialogStart:(NSNotification *)note
{
    if ([navigator isActive] ||
        self.navigationController.topViewController != self ||
        !self.searchButton.enabled) {
        
        [[NavSound sharedInstance] playFail];
        return;
    }
    [[NavSound sharedInstance] playVoiceRecoEnd];
    [self performSegueWithIdentifier:@"show_search" sender:@[@"toDestinations", @"show_dialog"]];
}

- (void)handleLocaionUnknown:(NSNotification*)note
{
    if (self.navigationController.topViewController == self) {
        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_UNKNOWN object:self];
    }
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [segue destinationViewController].restorationIdentifier = segue.identifier;
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
    
    if ([segue.identifier isEqualToString:@"blind_settings"]) {
        SettingViewController *sv = (SettingViewController*)segue.destinationViewController;
        sv.webView = _webView;
    }
    if ([segue.identifier isEqualToString:@"show_rating"]) {
        RatingViewController *rv = (RatingViewController*)segue.destinationViewController;
        NavDataStore *nds = [NavDataStore sharedDataStore];
        rv.start = nds.start;
        rv.end = [[NSDate date] timeIntervalSince1970];
        rv.from = nds.from._id;
        rv.to = nds.to._id;
        rv.device_id = [nds userID];
    }
    if ([segue.identifier isEqualToString:@"show_search"]) {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]) {
            [_webView evaluateJavaScript:@"$hulop.map.setSync(true);" completionHandler:nil];
        }
    }
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"] && [navigator isActive]) {
        [[NavDataStore sharedDataStore] clearRoute];
        
        [_webView logToServer:@{@"event": @"navigation", @"status": @"canceled"}];
        [NavDataStore sharedDataStore].previewMode = NO;
        [NavDataStore sharedDataStore].exerciseMode = NO;
        [previewer setAutoProceed:NO];

        return NO;
    }
    
    return YES;
}


@end
