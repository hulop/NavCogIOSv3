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

@interface ViewController () {
    NavWebviewHelper *helper;
    UISwipeGestureRecognizer *recognizer;
    NSDictionary *uiState;
    DialogViewHelper *dialogHelper;
}

@end

typedef NS_ENUM(NSInteger, ViewState) {
    ViewStateMap,
    ViewStateSearch,
    ViewStateSearchDetail,
    ViewStateSearchSetting,
    ViewStateRouteConfirm,
    ViewStateNavigation,
    ViewStateTransition,
    ViewStateRouteCheck,
    ViewStateLoading
};

@implementation ViewController {
    ViewState state;
    UIColor *defaultColor;
}

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    recognizer = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    defaultColor = self.navigationController.navigationBar.barTintColor;
    
    state = ViewStateLoading;
    
    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(openMenu:)];
    recognizer.delegate = self;
    [self.webView addGestureRecognizer:recognizer];
    
    dialogHelper = [[DialogViewHelper alloc] init];
    double x = 70;
    double y = self.view.bounds.size.height - 70;
    dialogHelper.transparentBack = YES;
    dialogHelper.layerScale = 0.75;
    [dialogHelper inactive];
    [dialogHelper setup:self.view position:CGPointMake(x, y)];
    dialogHelper.delegate = self;
    dialogHelper.helperView.hidden = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestStartNavigation:) name:REQUEST_START_NAVIGATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uiStateChanged:) name:WCUI_STATE_CHANGED_NOTIFICATION object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dialogStateChanged:) name:DIALOG_AVAILABILITY_CHANGED_NOTIFICATION object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationStatusChanged:) name:NAV_LOCATION_STATUS_CHANGE object:nil];
    
    [self updateView];
}


- (void)tapped
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
    [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:self userInfo:@{@"control":ROUTE_SEARCH_BUTTON}];
}

- (IBAction)stopNavigation:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:self userInfo:@{@"control":@""}];
}

- (IBAction)doCancel:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:self userInfo:@{@"control":@""}];
}

- (IBAction)doDone:(id)sender {
    state = ViewStateTransition;
    [self updateView];
    [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:self userInfo:@{@"control":DONE_BUTTON}];
}

- (IBAction)doBack:(id)sender {
    if (state == ViewStateSearchDetail) {
        //state = ViewStateTransition;
        //[self updateView];
        [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL object:self userInfo:@{@"control":BACK_TO_CONTROL}];
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
        if ([[DialogManager sharedManager] isDialogAvailable]) {
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
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&dummy=%f", options[@"toID"], [[NSDate date] timeIntervalSince1970]];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:TRIGGER_WEBVIEW_CONTROL
                                                            object:self userInfo:@{@"control":ROUTE_SEARCH_OPTION_BUTTON}];
    }
    
    return NO;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    segue.destinationViewController.restorationIdentifier = segue.identifier;
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

@end
