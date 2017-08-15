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
//#import "SettingViewController.h"

#import "ServerConfig.h"
#import "HLPLocationManager+Player.h"
#import "DefaultTTS.h"

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
}

@end

@implementation BlindViewController

- (void)dealloc
{
    /*
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
     */
    
    _webView.delegate = nil;
    
    [navigator stop];
    navigator.delegate = nil;
    navigator = nil;
    
    _settingButton = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    helper = [[NavBlindWebviewHelper alloc] initWithWebview:self.webView server:server];
    helper.developerMode = @([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]);
    helper.userMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"user_mode"];
    helper.delegate = self;
     */

    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    _webView.isDeveloperMode = [ud boolForKey:@"developer_mode"];
    _webView.userMode = [ud stringForKey:@"user_mode"];
    _webView.config = @{
                        @"serverHost":[ud stringForKey:@"selected_hokoukukan_server"],
                        @"serverContext":[ud stringForKey:@"hokoukukan_server_context"],
                        @"usesHttps":@([ud boolForKey:@"https_connection"])
                        };

    _webView.delegate = self;
    _webView.tts = self;
    
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
    
    dialogHelper = [[DialogViewHelper alloc] init];
    double scale = 0.75;
    double size = (113*scale)/2;
    double x = size+8;
    double y = self.view.bounds.size.height - (size+8) - 63;
    dialogHelper.transparentBack = YES;
    dialogHelper.layerScale = scale;
    [dialogHelper inactive];
    [dialogHelper setup:self.view position:CGPointMake(x, y)];
    dialogHelper.delegate = self;
    dialogHelper.helperView.hidden = YES;
    
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
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
    
    [self updateView];
}

- (void) checkMapCenter:(NSTimer*)timer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HLPLocation *loc = [_webView getCenter];
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
    });
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

- (void)tapped
{
    [dialogHelper inactive];
    dialogHelper.helperView.hidden = YES;
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
    [[NSNotificationCenter defaultCenter] postNotificationName:ENABLE_ACCELEARATION object:self];
    [self becomeFirstResponder];
    
    UIView* target = [self findLabel:self.navigationController.navigationBar.subviews];
    
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, target.superview);
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
}

- (void)debugPeerStateChanged:(NSNotification*)note
{
    [self updateView];
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchButton.title = NSLocalizedStringFromTable([navigator isActive]?@"Stop":@"Search", @"BlindView", @"");
        [self.searchButton setAccessibilityLabel:NSLocalizedStringFromTable([navigator isActive]?@"Stop Navigation":@"Search Route", @"BlindView", @"")];
        
        BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
        BOOL debugFollower = [[NSUserDefaults standardUserDefaults] boolForKey:@"p2p_debug_follower"];
        BOOL hasCenter = [[NavDataStore sharedDataStore] mapCenter] != nil;
        BOOL previewMode = [NavDataStore sharedDataStore].previewMode;
        BOOL exerciseMode = [NavDataStore sharedDataStore].exerciseMode;
        BOOL isActive = [navigator isActive];
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
        
        self.devAuto.selected = previewer.autoProceed;
        //self.cover.hidden = devMode || !isActive;
        self.cover.hidden = devMode;
        
        self.searchButton.enabled = hasCenter;
        
        self.navigationItem.leftBarButtonItem = nil;
        if ((isActive && !devMode) || previewMode || initFlag) {
        } else {
            self.navigationItem.leftBarButtonItem = _settingButton;
            UILongPressGestureRecognizer* longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSettingLongPressGesture:)];
            longPressGesture.minimumPressDuration = 1.0;
            longPressGesture.numberOfTouchesRequired = 1;
            [[_settingButton valueForKey:@"view"] addGestureRecognizer:longPressGesture];
        }
        
        self.navigationItem.title = NSLocalizedStringFromTable(exerciseMode?@"Exercise":(previewMode?@"Preview":@"NavCog"), @"BlindView", @"");
        
        if (debugFollower) {
            self.navigationItem.title = NSLocalizedStringFromTable(@"Follow", @"BlindView", @"");
        }
        
        if (debugFollower || initFlag) {    
            self.navigationItem.rightBarButtonItem = nil;
        } else {
            self.navigationItem.rightBarButtonItem = _searchButton;
        }
        
        if (peerExists) {
            self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.9 alpha:1.0];
        } else {
            //self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.9 alpha:1.0];
            self.navigationController.navigationBar.barTintColor = defaultColor;
        }
        
        if ([[DialogManager sharedManager] isDialogAvailable] && !isActive && hasCenter) {
            if (dialogHelper.helperView.hidden) {
                dialogHelper.helperView.hidden = NO;
                [dialogHelper recognize];
            }
        } else {
            dialogHelper.helperView.hidden = YES;
        }

    });
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

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

#pragma mark - HLPWebViewCoreDelegate

- (void)webView:(HLPWebView *)webView openURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL object:self userInfo:@{@"url": url}];
}


#pragma mark - HLPTTSProtocol

- (void)speak:(NSString *)text force:(BOOL)isForce
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force": @(isForce)} completionHandler:nil];
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

#pragma mark - HLPWebViewDelegate

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
    [[NSNotificationCenter defaultCenter] postNotificationName:BUILDING_CHANGED_NOTIFICATION object:self userInfo:@{@"building": building}];
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
    
    if (lastOrientationSent + 0.2 < now) {
        [_webView sendData:@[@{
                             @"type":@"ORIENTATION",
                             @"z":@(orientation)
                             }]
              withName:@"Sensor"];
        lastOrientationSent = now;
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

#pragma mark - DialogViewControllerDelegate

- (void)startNavigationWithOptions:(NSDictionary *)options
{
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&elv=%d&stairs=%d", options[@"node_id"], [options[@"no_elevator"] boolValue]?1:9, [options[@"no_stairs"] boolValue]?1:9];
    
    [_webView setBrowserHash: hash];
}

- (NSString *)getCurrentFloor
{
    return [_webView stringByEvaluatingJavaScriptFromString:@"(function() {return $hulop.indoor.getCurrentFloor();})()"];
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
                [_webView stringByEvaluatingJavaScriptFromString:@"$hulop.map.setSync(true);"];
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
        
        if ([NavDataStore sharedDataStore].previewMode) {
            [[NavDataStore sharedDataStore] manualLocationReset:properties];
            double delayInSeconds = 2.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [previewer setAutoProceed:YES];
            });
        }

    } else {
        [previewer setAutoProceed:NO];
    }
    [self updateView];
    rerouteFlag = NO;
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
        [_webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"$hulop.map.getMap().getView().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]]];

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

- (void)speak:(NSString*)text withOptions:(NSDictionary*)options completionHandler:(void (^)())handler
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:handler];
}

- (void)playSuccess
{
    BOOL result = [[NavSound sharedInstance] vibrate:nil];
    //result = [[NavSound sharedInstance] playSuccess] || result;
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
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"] && [navigator isActive]) {
        [[NavDataStore sharedDataStore] clearRoute];
        [NavDataStore sharedDataStore].previewMode = NO;
        [NavDataStore sharedDataStore].exerciseMode = NO;
        [previewer setAutoProceed:NO];

        return NO;
    }
    
    return YES;
}


@end
