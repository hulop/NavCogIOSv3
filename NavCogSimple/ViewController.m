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
#import "SettingViewController.h"
#import "NavDeviceTTS.h"

@interface ViewController () {
    NavWebviewHelper *helper;
    UISwipeGestureRecognizer *recognizer;
    NSDictionary *uiState;
}

@end

@implementation ViewController {
    BOOL first;
    ViewState state;
    UIColor *defaultColor;
}

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    recognizer = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    first = YES;
    
    defaultColor = self.navigationController.navigationBar.barTintColor;
    
    state = ViewStateLoading;
    
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView server:server];
    helper.delegate = self;
    
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(openMenu:)];
    recognizer.delegate = self;
    [self.webView addGestureRecognizer:recognizer];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartNavigation:) name:REQUEST_START_NAVIGATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uiStateChanged:) name:WCUI_STATE_CHANGED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openURL:) name: REQUEST_OPEN_URL object:nil];
    
    [self updateView];
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkState:) userInfo:nil repeats:YES];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    if (first) {
        first = NO;
        // TODO: load configure
        [[NSUserDefaults standardUserDefaults] setObject:@"hulop-mapservice.au-syd.mybluemix.net" forKey:@"selected_hokoukukan_server"];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:@"hokoukukan_server_context"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"https_connection"];
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
        NSDictionary *json = [helper getState];
        [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:json];
    });
}

- (void) openURL:(NSNotification*)note
{
    [NavUtil openURL:[note userInfo][@"url"] onViewController:self];
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
    [helper triggerWebviewControl:WebviewControlRouteSearchButton];
}

- (IBAction)stopNavigation:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [helper triggerWebviewControl:WebviewControlNone];
}

- (IBAction)doCancel:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [helper triggerWebviewControl:WebviewControlNone];
}

- (IBAction)doDone:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [helper triggerWebviewControl:WebviewControlDoneButton];
}

- (IBAction)doBack:(id)sender {
    if (state == ViewStateSearchDetail) {
        //state = ViewStateTransition;
        //[self updateView];
        [helper triggerWebviewControl:WebviewControlBackToControl];
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

#pragma mark - NavWebviewHelperDelegate

- (void) startLoading {
    [_indicator startAnimating];
}

- (void) loaded {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
}

- (void)checkConnection
{
    _errorMessage.hidden = NO;
    _retryButton.hidden = NO;
}

- (void) speak:(NSString*)text withOptions:(NSDictionary*)options {
    [[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:nil];
}

- (BOOL) isSpeaking {
    return [[NavDeviceTTS sharedTTS] isSpeaking];
}

- (void) vibrateOnAudioServices {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void) manualLocationChangedWithOptions:(NSDictionary*)options {
    [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION_CHANGED_NOTIFICATION object:self userInfo:options];
}

- (void) buildingChangedWithOptions:(NSDictionary*)options {
    [[NSNotificationCenter defaultCenter] postNotificationName:BUILDING_CHANGED_NOTIFICATION object:self userInfo:options];
}

- (void) wcuiStateChangedWithOptions:(NSDictionary*)options {
    [[NSNotificationCenter defaultCenter] postNotificationName:WCUI_STATE_CHANGED_NOTIFICATION object:self userInfo:options];
}

- (void) requestRatingWithOptions:(NSDictionary*)options {
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_RATING object:self userInfo:options];
}

- (void) requestOpenURL:(NSURL*)url {
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
    [helper setBrowserHash: hash];
}

- (void)startNavigationWithOptions:(NSDictionary *)options
{
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&elv=%d&stairs=%d", options[@"node_id"], [options[@"no_elevator"] boolValue]?1:9, [options[@"no_stairs"] boolValue]?1:9];
    
    [helper setBrowserHash: hash];
}

- (NSString *)getCurrentFloor
{
    return [helper evalScript:@"(function() {return $hulop.indoor.getCurrentFloor();})()"];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"user_settings"] && (state == ViewStateMap || state == ViewStateLoading)) {
        return YES;
    }
    if ([identifier isEqualToString:@"user_settings"] && state == ViewStateSearch) {
        state = ViewStateTransition;
        [self updateView];
        [helper triggerWebviewControl:WebviewControlRouteSearchOptionButton];
    }
    
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    segue.destinationViewController.restorationIdentifier = segue.identifier;
    
    if ([segue.identifier isEqualToString:@"user_settings"]) {
        SettingViewController *sv = (SettingViewController*)segue.destinationViewController;
        sv.webViewHelper = helper;
    }
}

- (IBAction)retry:(id)sender {
    [helper retry];
    _errorMessage.hidden = YES;
    _retryButton.hidden = YES;
}

- (void)locationStatusChanged:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavLocationStatus status = [[note userInfo][@"status"] unsignedIntegerValue];
        
        switch(status) {
            case NavLocationStatusLocating:
                [NavUtil showWaitingForView:self.view withMessage:NSLocalizedStringFromTable(@"Locating...", @"BlindView", @"")];
                break;
            default:
                [NavUtil hideWaitingForView:self.view];
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"developer_mode"]) {
        helper.developerMode = @(YES);
    }
}

@end
