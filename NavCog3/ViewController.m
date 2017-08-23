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

#import "ViewController.h"
#import "LocationEvent.h"
#import "NavDebugHelper.h"
#import "NavUtil.h"
#import "NavDataStore.h"
#import "RatingViewController.h"
// ???: HLPSetting.h:43:5: Expected identifier
//#import "SettingViewController.h"
#import "ServerConfig.h"
#import "NavDeviceTTS.h"
#import <HLPLocationManager/HLPLocationManager.h>
#import "DefaultTTS.h"

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

@interface ViewController () {
    UISwipeGestureRecognizer *recognizer;
    NSDictionary *uiState;
    DialogViewHelper *dialogHelper;
    NSDictionary *ratingInfo;
    
    NSTimeInterval lastLocationSent;
    NSTimeInterval lastOrientationSent;
}

@end

@implementation ViewController {
    ViewState state;
    UIColor *defaultColor;
}

- (void)dealloc
{
    //[_webView prepareForDealloc];
    _webView.delegate = nil;
    //_webView = nil;
    recognizer = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    defaultColor = self.navigationController.navigationBar.barTintColor;
    
    state = ViewStateLoading;
    
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
    
    /*
    NSString *server = ;
    helper = [[HLPWebviewHelper alloc] initWithWebview:self.webView server:server];
    helper.developerMode = @([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]);
    helper.userMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"user_mode"];
    helper.delegate = self;
     */
    
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(openMenu:)];
    recognizer.delegate = self;
    [self.webView addGestureRecognizer:recognizer];
    
    dialogHelper = [[DialogViewHelper alloc] init];
    double scale = 0.75;
    double size = (113*scale)/2;
    double x = size+8;
    double y = self.view.bounds.size.height - (size+8) - 63;
    dialogHelper.scale = scale;
    [dialogHelper inactive];
    [dialogHelper setup:self.view position:CGPointMake(x, y)];
    dialogHelper.delegate = self;
    dialogHelper.helperView.hidden = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartNavigation:) name:REQUEST_START_NAVIGATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uiStateChanged:) name:WCUI_STATE_CHANGED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogStateChanged:) name:DialogManager.DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name: REQUEST_OPEN_URL object:nil];
    
    [self updateView];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkState:) userInfo:nil repeats:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestRating:) name:REQUEST_RATING object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
}

- (void) requestRating:(NSNotification*)note
{
    if ([[ServerConfig sharedConfig] shouldAskRating]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            ratingInfo = [note userInfo];
            [self performSegueWithIdentifier:@"show_rating" sender:self];
        });
    }
}

- (void) checkState:(NSTimer*)timer
{
    if (state != ViewStateLoading) {
        [timer invalidate];
        return;
    }
    NSLog(@"checkState");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *json = [_webView getState];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:json];
    });
}

- (void) openURL:(NSNotification*)note
{
    [NavUtil openURL:[note userInfo][@"url"] onViewController:self];
}


- (void)dialogViewTapped
{
    [dialogHelper inactive];
    dialogHelper.helperView.hidden = YES;
    [self performSegueWithIdentifier:@"show_dialog_wc" sender:self];
    
}

- (void)dialogStateChanged:(NSNotification*)note
{
    [self updateView];
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

- (IBAction)doSearch:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [_webView triggerWebviewControl:HLPWebviewControlRouteSearchButton];
}

- (IBAction)stopNavigation:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [_webView triggerWebviewControl:HLPWebviewControlNone];
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
    if (state == ViewStateSearchDetail) {
        //state = ViewStateTransition;
        //[self updateView];
        [_webView triggerWebviewControl:HLPWebviewControlBackToControl];
    }
}


- (void)updateView
{
    BOOL debugFollower = [[NSUserDefaults standardUserDefaults] boolForKey:@"p2p_debug_follower"];
    BOOL peerExists = [[[NavDebugHelper sharedHelper] peers] count] > 0;

    switch(state) {
        case ViewStateMap:
            self.navigationItem.rightBarButtonItems = debugFollower ? @[] : @[self.searchButton];
            self.navigationItem.leftBarButtonItems = @[self.settingButton];
            break;
        case ViewStateSearch:
            self.navigationItem.rightBarButtonItems = @[self.settingButton];
            self.navigationItem.leftBarButtonItems = @[self.cancelButton];
            break;
        case ViewStateSearchDetail:
            self.navigationItem.rightBarButtonItems = @[self.backButton];
            self.navigationItem.leftBarButtonItems = @[self.cancelButton];
            break;
        case ViewStateSearchSetting:
            self.navigationItem.rightBarButtonItems = @[self.searchButton];
            self.navigationItem.leftBarButtonItems = @[];
            break;
        case ViewStateNavigation:
            self.navigationItem.rightBarButtonItems = @[];
            self.navigationItem.leftBarButtonItems = @[self.stopButton];
            break;
        case ViewStateRouteConfirm:
            self.navigationItem.rightBarButtonItems = @[self.cancelButton];
            self.navigationItem.leftBarButtonItems = @[];
            break;
        case ViewStateRouteCheck:
            self.navigationItem.rightBarButtonItems = @[self.doneButton];
            self.navigationItem.leftBarButtonItems = @[];
            break;
        case ViewStateTransition:
            self.navigationItem.rightBarButtonItems = @[];
            self.navigationItem.leftBarButtonItems = @[];
            break;
        case ViewStateLoading:
            self.navigationItem.rightBarButtonItems = @[];
            self.navigationItem.leftBarButtonItems = @[self.settingButton];
            break;
    }
    
    if (state == ViewStateMap) {
        if ([[DialogManager sharedManager] isAvailable]) {
            if (dialogHelper.helperView.hidden) {
                dialogHelper.helperView.hidden = NO;
                [dialogHelper recognize];
            }
        } else {
            dialogHelper.helperView.hidden = YES;
        }
    } else {
        dialogHelper.helperView.hidden = YES;
    }
    
    self.navigationItem.title = NSLocalizedStringFromTable(@"NavCog", @"BlindView", @"");
    
    if (debugFollower) {
        self.navigationItem.title = NSLocalizedStringFromTable(@"Follow", @"BlindView", @"");
    }
    
    if (peerExists) {
        self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.9 alpha:1.0];
    } else {
        self.navigationController.navigationBar.barTintColor = defaultColor;
    }
}

#pragma mark - HLPWebviewHelperDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [_indicator startAnimating];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    _errorMessage.hidden = NO;
    _retryButton.hidden = NO;
    
}

- (void)speak:(NSString *)text force:(BOOL)isForce
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:@{@"force": @(isForce)} completionHandler:nil];
}

- (BOOL)isSpeaking
{
    return [[NavDeviceTTS sharedTTS] isSpeaking];
}

- (void)vibrate
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

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
    NSDictionary *uiState_ =
    @{
      @"page": page,
      @"navigation": @(inNavigation),
      };
    [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:uiState_];
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

- (void)webView:(HLPWebView *)webView openURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL object:self userInfo:@{@"url": url}];
}

#pragma mark -

- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    NSLog(@"%@", touches);
    NSLog(@"%@", event);
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)openMenu:(UIGestureRecognizer*)sender
{
    NSLog(@"%@", sender);
    
    CGPoint p = [sender locationInView:self.webView];
    NSLog(@"%f %f", p.x, p.y);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)requestStartNavigation:(NSNotification*)note
{
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
    
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&dummy=%f%@%@%@", options[@"toID"],
                      [[NSDate date] timeIntervalSince1970], elv, stairs, esc];
    [_webView setLocationHash:hash];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"user_settings"] && (state == ViewStateMap || state == ViewStateLoading)) {
        return YES;
    }
    if ([identifier isEqualToString:@"user_settings"] && state == ViewStateSearch) {
        state = ViewStateTransition;
        [self updateView];
        [_webView triggerWebviewControl:HLPWebviewControlRouteSearchOptionButton];
    }
    
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    segue.destinationViewController.restorationIdentifier = segue.identifier;
    
    if ([segue.identifier isEqualToString:@"user_settings"]) {
        SettingViewController *sv = (SettingViewController*)segue.destinationViewController;
        sv.webView = _webView;
    }
    if ([segue.identifier isEqualToString:@"show_rating"] && ratingInfo) {
        RatingViewController *rv = (RatingViewController*)segue.destinationViewController;
        rv.start = [ratingInfo[@"start"] doubleValue]/1000.0;
        rv.end = [ratingInfo[@"end"] doubleValue]/1000.0;
        rv.from = ratingInfo[@"from"];
        rv.to = ratingInfo[@"to"];
        rv.device_id = [[NavDataStore sharedDataStore] userID];
        
        ratingInfo = nil;
    }
    if ([segue.identifier isEqualToString:@"show_dialog_wc"]){
        DialogViewController* dView = (DialogViewController*)segue.destinationViewController;
        dView.tts = [DefaultTTS new];
    }
}

- (IBAction)retry:(id)sender {
    [_webView reload];
    _errorMessage.hidden = YES;
    _retryButton.hidden = YES;
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"developer_mode"]) {
        _webView.isDeveloperMode = @([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]);
    }
}

@end
