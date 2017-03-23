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
#import "NavSound.h"
#import "LocationEvent.h"
#import "NavUtil.h"
#import "ServerConfig.h"
#import "NavDataStore.h"


@interface BlindViewController () {
    NavWebviewHelper *helper;
    
    ViewState state;
}

@end

@implementation BlindViewController {
    FingerprintManager *fpm;
}

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    _settingButton = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    state = ViewStateLoading;

    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    
    fpm = [FingerprintManager sharedManager];
    fpm.delegate = self;
    [fpm load];
}

- (void)manager:(FingerprintManager *)manager didStatusChanged:(BOOL)isReady
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HLPRefpoint *rp = manager.selectedRefpoint;
        NSDictionary *param = @{
                                @"sync": @(false),
                                @"location": [[HLPLocation alloc] initWithLat:rp.anchor_lat Lng:rp.anchor_lng Floor:rp.floor_num]
                                };
        [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION object:self userInfo:param];
        [self updateView];
    });
}

- (void)manager:(FingerprintManager *)manager didSendData:(NSString *)idString withError:(NSError *)error
{
    NSLog(@"sample id %@", idString);
    [self updateView];
}

- (BOOL)manager:(FingerprintManager *)manager didObservedBeacons:(int)beaconCount atSample:(int)sampleCount
{
    [self updateView];
    long count = [[NSUserDefaults standardUserDefaults] integerForKey:@"finger_printing_duration"];
    if (sampleCount >= count) {
        return NO;
    }
    return YES;
}

- (void)manager:(FingerprintManager *)manager didSamplingsLoaded:(NSArray *)samplings
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showFingerprints:samplings];
        [self updateView];
    });
}

- (void)locationChanged:(NSNotification*)note
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (nds.isManualLocation) {
        [self updateView];
    }
}

- (void) startSampling
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    HLPLocation *center = nds.mapCenter;
    [fpm startSamplingAtLat:center.lat Lng:center.lng];
}
- (void) cancelSampling
{
    [fpm cancel];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void)viewDidAppear:(BOOL)animated
{
}

- (void)viewDidDisappear:(BOOL)animated
{
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavDataStore *nds = [NavDataStore sharedDataStore];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        
        BOOL existRefpoint = fpm.selectedRefpoint != nil;
        BOOL existUUID = ([ud stringForKey:@"selected_finger_printing_beacon_uuid"] != nil);
        
        self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
        self.settingButton.enabled = fpm.isReady;
        
        BOOL isSampling = fpm.isSampling;
        self.searchButton.title = NSLocalizedStringFromTable(isSampling?@"Cancel":@"Start", @"Fingerprint", @"");
        self.devFingerprint.hidden = NO;

        self.navigationItem.rightBarButtonItem = _searchButton;
        self.navigationItem.leftBarButtonItem = _settingButton;
        
        if (isSampling) {
            long count = [ud integerForKey:@"finger_printing_duration"];
            self.navigationItem.title = [NSString stringWithFormat:@"%@ - %ld/%ld (%ld)",
                                         fpm.selectedRefpoint.floor,
                                         fpm.beaconsSampleCount, count, fpm.visibleBeaconCount];
        } else {
            if (existRefpoint) {
                if (fpm.samplings) {
                    self.navigationItem.title = [NSString stringWithFormat:@"%@ [%ld]",
                                                 fpm.selectedRefpoint.floor,
                                                 [fpm.samplings count]];
                } else {
                    self.navigationItem.title = fpm.selectedRefpoint.floor;
                }
            } else {
                self.navigationItem.title = @"Fingerprint";
            }
        }
    });
}

- (void) startLoading {
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void) loaded {
    [_indicator stopAnimating];
    _indicator.hidden = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self insertScript];
    });
}

- (void) insertScript
{
    NSString *jspath = [[NSBundle mainBundle] pathForResource:@"fingerprint" ofType:@"js"];
    NSString *js = [[NSString alloc] initWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
    [helper evalScript:js];
}

- (void) showFingerprints:(NSArray*) points
{
    NSMutableArray *temp = [@[] mutableCopy];
    for(HLPSampling *p in points) {
        [temp addObject:
         @{
           @"lat": @(p.lat),
           @"lng": @(p.lng),
           @"count": @([p.beacons count])
           }];
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:temp options:0 error:nil];
    NSString* str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSString* script = [NSString stringWithFormat:@"$hulop.fp.showFingerprints(%@);", str];
    NSLog(@"%@", script);
    [helper evalScript:script];
}

- (void)checkConnection {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)vibrate
{
    [[NavSound sharedInstance] vibrate:nil];
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
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"]) {
        if (fpm.isSampling) {
            [self cancelSampling];
        } else {
            [self startSampling];
        }
        return NO;
    }
    
    return YES;
}


@end
