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
#import "ServerConfig+FingerPrint.h"
#import "NavDataStore.h"
#import "BeaconAddTableViewController.h"
#import "POIAddTableViewController.h"
#import "SettingViewController.h"
#import "NavDeviceTTS.h"
#import "NavBlindWebView.h"
#import <CoreMotion/CoreMotion.h>

#define IS_IOS11orHIGHER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0)

@interface TargetLayer: CALayer {
}

@property CGSize size;
@property CGPoint center;
@property BOOL isCentered;
@property CGRect target;
@property CGRect border;
@property BOOL inBorder;
@end


@implementation TargetLayer

- (void)drawInContext:(CGContextRef)ctx
{
    if (_size.width == 0) {
        return;
    }
    
    double scale = MAX(self.frame.size.height / _size.width, self.frame.size.width / _size.height);

    CGContextTranslateCTM(ctx, 0, - (_size.width*scale - self.frame.size.height)/2);
    CGContextRotateCTM(ctx, -M_PI_2);
    CGContextScaleCTM(ctx, -scale, scale);
    //CGContextTranslateCTM(ctx, self.frame.size.width, - (_size.width*scale - self.frame.size.height)/2);
    //CGContextRotateCTM(ctx, M_PI_2);
    //CGContextScaleCTM(ctx, scale, scale);

    CGFloat lineWidth = 5/scale;

    CGColorRef outColor = [UIColor colorWithRed:1 green:0 blue:0 alpha:1].CGColor;
    CGColorRef inColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:1].CGColor;
    CGColorRef targetColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1].CGColor;
    
    CGContextSetStrokeColorWithColor(ctx, targetColor);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextStrokeRect(ctx, _target);
    
    CGContextSetStrokeColorWithColor(ctx, _inBorder ? inColor : outColor);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextStrokeRect(ctx, _border);
    
    CGContextMoveToPoint(ctx, (self.size.width-100)/2, (self.size.height)/2);
    CGContextAddLineToPoint(ctx, (self.size.width+100)/2, (self.size.height)/2);
    CGContextMoveToPoint(ctx, (self.size.width)/2, (self.size.height-100)/2);
    CGContextAddLineToPoint(ctx, (self.size.width)/2, (self.size.height+100)/2);
    CGContextSetStrokeColorWithColor(ctx, targetColor);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextStrokePath(ctx);
    
    CGContextMoveToPoint(ctx, (self.size.width-100)/2+_center.x, (self.size.height)/2+_center.y);
    CGContextAddLineToPoint(ctx, (self.size.width+100)/2+_center.x, (self.size.height)/2+_center.y);
    CGContextMoveToPoint(ctx, (self.size.width)/2+_center.x, (self.size.height-100)/2+_center.y);
    CGContextAddLineToPoint(ctx, (self.size.width)/2+_center.x, (self.size.height+100)/2+_center.y);
    CGContextSetStrokeColorWithColor(ctx, _isCentered ? inColor : outColor);
    CGContextSetLineWidth(ctx, lineWidth);
    CGContextStrokePath(ctx);
}

@end

@implementation BlindViewController {
    FPMode fpMode;
    
    int x, y;
    double fx, fy;
    
    UIView *arView;
    HLPLocation *qrLocation;
    HLPLocation *lastQrLocation;

    NSTimer *qrCodeTimer;
    NSTimeInterval lastQRCodeTime;
    NSTimeInterval lastQRLocationTime;
    CIQRCodeFeature* qrCode;
    CMMotionManager *motionManager;
    NSLayoutConstraint *arViewLayoutWidth;
    NSLayoutConstraint *arViewLayoutHeight;
    TargetLayer *arTargetLayer;
    
    FingerprintManager *fpm;
    BeaconAddTableViewController *batvc;
    POIAddTableViewController *poivc;
    NSArray<NSObject*>* showingFeatures;
    NSMutableDictionary* styleMap;
    NSObject* selectedFeature;
    POIManager *poim;
    HLPLocation *center;
    BOOL loaded;
    HLPRefpoint* currentRp;
    UITabBar *tabbar;
    UITabBarItem *item1, *item2, *item3, *item4, *item5;
    
}

- (void)reset {
    qrLocation = nil;
    lastQrLocation = Nil;
    lastQRLocationTime = 0;
    qrCode = nil;
    [fpm reset];
    [qrCodeTimer invalidate];
}

- (void)dealloc
{
    _webView.delegate = nil;
    
    _settingButton = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    //[_webView setFullScreenForView:self.view];
    
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 11.0, *)) {
        //[self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view.safeAreaLayoutGuide attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    } else {
        //[self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
        [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
    }
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    [self.view addConstraint:[NSLayoutConstraint constraintWithItem:_webView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeRight multiplier:1.0 constant:0]];

    
    UITapGestureRecognizer *webViewTapped = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    webViewTapped.numberOfTapsRequired = 1;
    webViewTapped.delegate = self;
    [self.webView addGestureRecognizer:webViewTapped];
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:MANUAL_LOCATION_CHANGED_NOTIFICATION object:self];
    
    poim = [[POIManager alloc] init];
    fpm = [FingerprintManager sharedManager];
    fpm.delegate = self;
    poim.delegate = self;
    
    
    tabbar = [[UITabBar alloc] init];
    [self.view addSubview:tabbar];
    
    item1 = [[UITabBarItem alloc]initWithTitle:@"FingerPrint" image:[UIImage imageNamed:@"fingerprint"] tag:0];
    item5 = [[UITabBarItem alloc]initWithTitle:@"ARFingerPrint" image:[UIImage imageNamed:@"fingerprint"] tag:1];
    item2 = [[UITabBarItem alloc]initWithTitle:@"Beacon" image:[UIImage imageNamed:@"beacon"] tag:2];
    item3 = [[UITabBarItem alloc]initWithTitle:@"ID" image:[UIImage imageNamed:@"id"] tag:3];
    item4 = [[UITabBarItem alloc]initWithTitle:@"POI" image:[UIImage imageNamed:@"poi"] tag:4];
    item1.enabled = item5.enabled = item2.enabled = item3.enabled = item4.enabled = NO;
    
    tabbar.items = @[item1, item5, item2, item3, item4];
    tabbar.selectedItem = item1;
    tabbar.delegate = self;
    
    
    [self.devUp setTitle:@"Up" forState:UIControlStateNormal];
    [self.devDown setTitle:@"Down" forState:UIControlStateNormal];
    [self.devLeft setTitle:@"Left" forState:UIControlStateNormal];
    [self.devRight setTitle:@"Right" forState:UIControlStateNormal];
    [self.devNote setTitle:@"Accept" forState:UIControlStateNormal];
    
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    
    [tabbar setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSLayoutConstraint *layoutLeft =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeLeading
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.view
                                 attribute:NSLayoutAttributeLeading
                                multiplier:1.0
                                  constant:0.0];
    
    NSLayoutConstraint *layoutRight =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeTrailing
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.view
                                 attribute:NSLayoutAttributeTrailing
                                multiplier:1.0
                                  constant:0.0];
    
    NSLayoutConstraint *layoutBottom =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeBottom
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.view
                                 attribute:NSLayoutAttributeBottom
                                multiplier:1.0
                                  constant:0.0];
    
    int height = 49;
    if (IS_IOS11orHIGHER) { height += self.view.safeAreaInsets.bottom; }
    
    NSLayoutConstraint *layoutHeight =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1.0
                                  constant:height ];
    
    NSLayoutConstraint *layoutBottom2 =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeTop
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.webView
                                 attribute:NSLayoutAttributeBottom
                                multiplier:1.0
                                  constant:0];
    
    [self.view addConstraints:@[layoutLeft, layoutRight, layoutBottom, layoutHeight, layoutBottom2]];
    [self.view layoutIfNeeded];
    
    [self updateView];
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    FPMode modes[5] = {FPModeFingerprint, FPModeARFingerprint, FPModeBeacon, FPModeID, FPModePOI};
    fpMode = modes[item.tag];
    
    if (fpMode == FPModeID) {
        if (!fpm.isSampling) {
            [fpm startSampling];
        }
    } else {
        if (fpm.isSampling) {
            [NavUtil hideMessageView:self.view];
            [fpm cancel];
        }
        [self reset];
    }
    
    [self clearFeatures];
    [self updateView];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated
{
    [poim initCenter:center];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if(fpm.isSampling) {
        [self cancelSampling];
    }
}

- (void)tapAction:(UITapGestureRecognizer *)sender
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [_webView evaluateJavaScript:@"(function(){return $hulop.indoor.getCurrentFloor()})()" completionHandler:^(id _Nullable result, NSError * _Nullable error) {
            NSLog(@"touched %@", result);
            double height = [result doubleValue];
            height = height<1?height:height-1;
            HLPLocation* temp = [[HLPLocation alloc] init];
            [temp update:center];
            [temp updateFloor:height];
            [self locationChange:temp];
            x = fx;
            y = fy;
        }];
    });
}

#pragma mark - FingerprintManagerDelegate

- (void)manager:(FingerprintManager *)manager didRefpointSelected:(HLPRefpoint *)refpoint
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showRefpoint:manager.selectedRefpoint];
        if (fpMode == FPModeBeacon) {
            [self showBeaconsOnFloorplan:manager.selectedFloorplan withRefpoint:manager.selectedRefpoint];
        }
        
        [self updateView];
    });
}

-(void) showRefpoint:(HLPRefpoint*)rp
{
    if (!rp) return;
    if (currentRp == rp) return;
    
    HLPLocation* loc = [[HLPLocation alloc] initWithLat:rp.anchor_lat Lng:rp.anchor_lng Floor:rp.floor_num];
    [_webView manualLocation:loc withSync:NO];
    currentRp = rp;
}

- (void)manager:(FingerprintManager *)manager didStatusChanged:(BOOL)isReady
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        [NavUtil hideModalWaiting];
        
        [self showRefpoint:manager.selectedRefpoint];
        //if (fpMode == FPModeBeacon) {
        //[self showBeaconsOnFloorplan:manager.selectedFloorplan withRefpoint:manager.selectedRefpoint];
        //}
        [self updateView];
    });
}

- (void)manager:(FingerprintManager *)manager didSendData:(NSString *)idString withError:(NSError *)error
{
    NSLog(@"sample id %@", idString);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        [self vibrate];
        [self updateView];
    });
}

- (BOOL)manager:(FingerprintManager *)manager didObservedBeacons:(int)beaconCount atSample:(int)sampleCount
{
    if (fpMode == FPModeID) {
        CLBeacon *b = [fpm strongestBeacon];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (b) {
                UIMessageView *mv = [NavUtil showMessageView:self.view];

                mv.action.hidden = YES;
                mv.message.font = [UIFont fontWithName:@"Courier" size:32];
                mv.message.numberOfLines = 2;
                mv.message.preferredMaxLayoutWidth = mv.bounds.size.width;
                mv.message.text = [NSString stringWithFormat:@"Major:%5d Minor:%5d\nRSSI=%4ld",[b.major intValue],[b.minor intValue],b.rssi];
                mv.message.adjustsFontSizeToFitWidth = YES;
                
            }
        });
            
        [fpm reset];
        return YES;
    } else {
        [self updateView];
        if (fpMode == FPModeFingerprint) {
            long count = [[NSUserDefaults standardUserDefaults] integerForKey:@"finger_printing_duration"];
            if (sampleCount >= count) {
                [fpm sendData];
                return NO;
            }
        }
        if (fpMode == FPModeARFingerprint) {
            [self redrawFingerprint];
        }
        return YES;
    }
}

- (void)manager:(FingerprintManager *)manager didSamplingsLoaded:(NSArray *)samplings
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideModalWaiting];
        [self redrawFingerprint];
        [self updateView];
    });
}

- (void)manager:(FingerprintManager *)manager didQRCodeDetect:(CIQRCodeFeature *)feature
{
    if (!fpm.locationAdjustable) {
        return;
    }
    NSString *message = feature.messageString;
    NSArray<NSString*>* items = [message componentsSeparatedByString:@":"];
    
    if (![@"latlng" isEqualToString:items[0]]) {
        return;
    }
    
    double lat = items[1].doubleValue;
    double lng = items[2].doubleValue;
    double floor = items[3].doubleValue;
    if (floor > 0) {
        floor = floor - 1;
    }
    
    qrCode = feature;
    lastQRCodeTime = [[NSDate date] timeIntervalSince1970];
    if (!qrCodeTimer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            qrCodeTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
                
                if ((now - lastQRCodeTime) > fpm.sampler.qrCodeInterval*2) {
                    qrCode = nil;
                }
            }];
        });
    }
    HLPLocation *location = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:floor];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView evaluateJavaScript:@"$hulop.map.getMap().getView().setZoom(21);" completionHandler:nil];
        
        double eps = 10e-7;
        if (fabs(lastQrLocation.lat - location.lat) < eps &&
            fabs(lastQrLocation.lng - location.lng) < eps &&
            fabs(lastQrLocation.floor - location.floor) < 0.1) {
            return;
        }
        
        qrLocation = location;
        [self.webView manualLocation:location withSync:NO];
        
        for(HLPRefpoint *rp in fpm.refpoints) {
            if (fabs(rp.floor_num - location.floor) < 0.1) {
                [fpm select:rp];
                [self updateView];
                break;
            }
        }
        
        lastQrLocation = qrLocation;
    });
}

- (void)manager:(FingerprintManager *)manager didARLocationChange:(HLPLocation *)location
{
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (!qrLocation && now - lastQRLocationTime > 0.1) {
        [location updateFloor:NAN];
        [self.webView manualLocation:location withSync:NO];
        lastQRLocationTime = now;
    }
}

#pragma mark - POIManagerDelegate

- (void)didStartLoading
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil showWaitingForView:self.view withMessage:@"Loading..."];
    });
}

- (void)manager:(POIManager *)manager didPOIsLoaded:(NSArray<HLPObject *> *)pois
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        [NavUtil hideModalWaiting];

        [self showPOIs:pois];
        [self updateView];
    });
}

- (void)manager:(POIManager *)manager requestInfo:(NSString *)type forPOI:(NSDictionary*)poi at:(HLPLocation*)loc withOptions:(NSDictionary*)options
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@", type]
                                                                   message:@"Input text"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
    }];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  NSMutableDictionary *temp = [@{} mutableCopy];
                                                  temp[type] = alert.textFields[0].text;
                                                  
                                                  [manager addPOI:poi at:loc withOptions:[temp mtl_dictionaryByAddingEntriesFromDictionary:options]];
                                              }]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - private

- (void)locationChanged:(NSNotification*)note
{
    NavDataStore *nds = [NavDataStore sharedDataStore];
    if (nds.isManualLocation) {
        if (fpm.selectedRefpoint) {
            MKMapPoint local = [FingerprintManager convertFromGlobal: CLLocationCoordinate2DMake([nds currentLocation].lat, [nds currentLocation].lng) ToLocalWithRefpoint:fpm.selectedRefpoint];
            fx = local.x;
            fy = local.y;
        }
        
        [self updateView];
    }
    
    NSDictionary *obj = [note userInfo];
    double floor = [obj[@"floor"] doubleValue];
    if (floor == 0) {
        floor = NAN;
    } else if (floor >= 1) {
        floor -= 1;
    }
    
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:[obj[@"lat"] doubleValue]
                                                       Lng:[obj[@"lng"] doubleValue]
                                                  Accuracy:1
                                                     Floor:floor
                                                     Speed:1.0
                                               Orientation:0
                                       OrientationAccuracy:999];
    [self locationChange:loc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"developer_mode"]) {
        _webView.isDeveloperMode = @([[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"]);
    }
}

- (void)locationChange:(HLPLocation*)loc
{
    center = loc;
    [poim initCenter:center];
    [self findFeatureAt:center completionHandler:^(NSObject *poi) {
        selectedFeature = poi;
        [self updateView];
    }];
}

- (void) startSampling
{
    if (fpMode != FPModeARFingerprint) {
        [NavUtil showWaitingForView:self.view withMessage:@"Sampling..."];
    }
    [fpm startSamplingAtLat:center.lat Lng:center.lng];
}

- (void) cancelSampling
{
    [NavUtil hideWaitingForView:self.view];
    [fpm cancel];
    [self redrawFingerprint];
}

- (void) completeSampling
{
    [NavUtil hideWaitingForView:self.view];
    [fpm sendData];
    [fpm stopSampling];
}

- (void) viewDidDisappear:(BOOL)animated
{
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavDataStore *nds = [NavDataStore sharedDataStore];
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        BOOL existRefpoint = fpm.selectedRefpoint != nil;
        BOOL existUUID = ([ud stringForKey:@"selected_finger_printing_beacon_uuid"] != nil);
        BOOL isSampling = fpm.isSampling;
        BOOL showButtons = existRefpoint && (fpMode == FPModeFingerprint);
        BOOL showAccept = existRefpoint && (fpMode == FPModeARFingerprint) && qrLocation;
        
        self.devUp.hidden = !showButtons;
        self.devDown.hidden = !showButtons;
        self.devLeft.hidden = !showButtons;
        self.devRight.hidden = !showButtons;
        
        self.devNote.hidden = !showAccept;
        
        UIView *temp = [fpm enableARKit:(fpMode == FPModeARFingerprint)];
        if (!arView && temp) {
            [self.view addSubview:temp];
            
            [temp setTranslatesAutoresizingMaskIntoConstraints:NO];
            //temp.layer.opacity = 0.5;
            
            NSLayoutConstraint *layoutLeft =
            [NSLayoutConstraint constraintWithItem:temp
                                         attribute:NSLayoutAttributeLeading
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:self.webView
                                         attribute:NSLayoutAttributeLeading
                                        multiplier:1.0
                                          constant:0.0];
            
            int top = 0;
            //if (IS_IOS11orHIGHER) { top += self.view.safeAreaInsets.top; }
            
            NSLayoutConstraint *layoutTop =
            [NSLayoutConstraint constraintWithItem:temp
                                         attribute:NSLayoutAttributeTop
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:self.webView
                                         attribute:NSLayoutAttributeTop
                                        multiplier:1.0
                                          constant:top];
            
            arViewLayoutWidth =
            [NSLayoutConstraint constraintWithItem:temp
                                         attribute:NSLayoutAttributeWidth
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:nil
                                         attribute:NSLayoutAttributeWidth
                                        multiplier:1.0
                                          constant:120];
            
            arViewLayoutHeight =
            [NSLayoutConstraint constraintWithItem:temp
                                         attribute:NSLayoutAttributeHeight
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:nil
                                         attribute:NSLayoutAttributeHeight
                                        multiplier:1.0
                                          constant:160];
            
            [self.view addConstraints:@[layoutLeft, layoutTop, arViewLayoutWidth, arViewLayoutHeight]];
            [self.view layoutIfNeeded];
            
            motionManager = [[CMMotionManager alloc] init];
            [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                               toQueue:[[NSOperationQueue alloc] init]
                                                           withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
                                                               
                                                               if (!arView || !qrLocation || !qrCode) {
                                                                   if (arTargetLayer.size.width != 0) {
                                                                       arTargetLayer.size = CGSizeMake(0,0);
                                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                                           [arTargetLayer setNeedsDisplay];
                                                                       });
                                                                   }
                                                                   return;
                                                               }
                                                               
                                                               CGSize size = ((ARSCNView*)arView).session.currentFrame.camera.imageResolution;
                                                               CGRect border = qrCode.bounds;
                                                               border.size.width += 100;
                                                               border.size.height += 100;
                                                               border.origin.x = (size.width - border.size.width) / 2;
                                                               border.origin.y = (size.height - border.size.height) / 2;
                                                               CGPoint center = CGPointMake(motion.attitude.pitch*200, motion.attitude.roll*200);
                                                               arTargetLayer.size = size;
                                                               arTargetLayer.target = qrCode.bounds;
                                                               arTargetLayer.border = border;
                                                               arTargetLayer.center = center;
                                                               
                                                               arTargetLayer.inBorder = YES;
                                                               arTargetLayer.inBorder =
                                                                (fabs((qrCode.bottomLeft.x + qrCode.topRight.x) - size.width) <= 50) &&
                                                                (fabs((qrCode.bottomLeft.y + qrCode.topRight.y) - size.height) <= 50);
                                                               
                                                               arTargetLayer.isCentered =
                                                                (fabs(motion.attitude.roll) <= 0.1) &&
                                                                (fabs(motion.attitude.pitch) <= 0.1);
                                                               
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   [arTargetLayer setNeedsDisplay];
                                                               });
                                                               
                                                               if (!arTargetLayer.inBorder || !arTargetLayer.isCentered) {
                                                                   return;
                                                               }
                                                               
                                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                                   [self acceptQRLocation];
                                                               });
                                                           }];
            arTargetLayer = [[TargetLayer alloc] init];
            [temp.layer addSublayer:arTargetLayer];
            arTargetLayer.frame = temp.bounds;
        }
        if (qrLocation && arView && arViewLayoutWidth.constant == 120) {
            arViewLayoutWidth.constant = 240;
            arViewLayoutHeight.constant = 320;
            arTargetLayer.frame = CGRectMake(0, 0, 240, 320);
            fpm.sampler.qrCodeInterval = 0.1;
            [self.view layoutIfNeeded];
        }
        if (!qrLocation && arView && arViewLayoutWidth.constant == 240) {
            arViewLayoutWidth.constant = 120;
            arViewLayoutHeight.constant = 160;
            arTargetLayer.frame = CGRectMake(0, 0, 120, 150);
            fpm.sampler.qrCodeInterval = 0.5;
            [self.view layoutIfNeeded];
        }
        
        if (!temp && arView) {
            [arView removeFromSuperview];
        }
        arView = temp;
        
        if (fpMode == FPModeFingerprint) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = true;//fpm.isReady || !_retryButton.hidden;
            
            if (selectedFeature) {
                self.searchButton.title = NSLocalizedStringFromTable(@"Delete", @"Fingerprint", @"");
            } else {
                self.searchButton.title = NSLocalizedStringFromTable(isSampling?@"Cancel":@"Start", @"Fingerprint", @"");
            }
            
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
                        self.navigationItem.title = [NSString stringWithFormat:@"%@ [%ld] (%.1f, %.1f)",
                                                     fpm.selectedRefpoint.floor,
                                                     [fpm.samplings count], fx, fy];
                    } else {
                        self.navigationItem.title = fpm.selectedRefpoint.floor;
                    }
                } else {
                    self.navigationItem.title = @"No Reference Point";
                }
            }
        } else if (fpMode == FPModeARFingerprint) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID && fpm.arkitSamplingReady;
            self.settingButton.enabled = true;//fpm.isReady || !_retryButton.hidden;
            
            self.searchButton.title = NSLocalizedStringFromTable(isSampling?@"End":@"Start", @"FingerPrint", @"");
            self.settingButton.title = isSampling?NSLocalizedStringFromTable(@"Cancel", @"FingerPrint", @""):NSLocalizedStringFromTable(@"2FQ-fL-pff.headerTitle", @"Main", @"");
            
            self.navigationItem.rightBarButtonItem = _searchButton;
            self.navigationItem.leftBarButtonItem = _settingButton;
            
            if (isSampling) {
                self.navigationItem.title = [NSString stringWithFormat:@"%@ - %ld (%ld)",
                                             fpm.selectedRefpoint.floor,
                                             fpm.beaconsSampleCount, fpm.visibleBeaconCount];
            } else {
                if (existRefpoint) {
                    if (fpm.samplings) {
                        self.navigationItem.title = [NSString stringWithFormat:@"%@ [%ld] (%.1f, %.1f)",
                                                     fpm.selectedRefpoint.floor,
                                                     [fpm.samplings count], fx, fy];
                    } else {
                        self.navigationItem.title = fpm.selectedRefpoint.floor;
                    }
                } else {
                    self.navigationItem.title = @"No Reference Point";
                }
            }
        }
        else if (fpMode == FPModeBeacon) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = fpm.isReady || !_retryButton.hidden;
            
            if (selectedFeature) {
                self.searchButton.title = NSLocalizedStringFromTable(@"Delete", @"Fingerprint", @"");
            } else {
                self.searchButton.title = NSLocalizedStringFromTable(@"Add", @"Fingerprint", @"");
            }
            
            self.navigationItem.rightBarButtonItem = _searchButton;
            self.navigationItem.leftBarButtonItem = _settingButton;
            
            if (existRefpoint) {
                if (selectedFeature &&
                    [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                    HLPGeoJSONFeature* f = (HLPGeoJSONFeature*)selectedFeature;
                    NSString *maj = f.properties[@"major"];
                    NSString *min = f.properties[@"minor"];
                    self.navigationItem.title = [NSString stringWithFormat:@"%@-%@", maj, min];
                } else {
                    self.navigationItem.title = [NSString stringWithFormat:@"%@ [%ld]",
                                                 fpm.selectedRefpoint.floor,
                                                 [fpm beaconsCount]];
                }
                
            } else {
                self.navigationItem.title = @"No Reference Point";
            }

        } else if (fpMode == FPModeID) {
            self.settingButton.enabled =  YES;
            [NavUtil hideMessageView:self.view];
            
            self.navigationItem.rightBarButtonItem = nil;
            self.navigationItem.leftBarButtonItem = _settingButton;
            
            self.navigationItem.title = @"ID";
        } else if (fpMode == FPModePOI) {
            self.searchButton.enabled = nds.isManualLocation;
            self.settingButton.enabled =  YES;
            
            [NavUtil hideMessageView:self.view];
            if (selectedFeature) {
                self.searchButton.title = NSLocalizedStringFromTable(@"Delete", @"Fingerprint", @"");
                UIMessageView *view = [NavUtil showMessageView:self.view];
                view.action.hidden = YES;
                view.message.preferredMaxLayoutWidth = view.bounds.size.width;
                NSString *name = @"";
                NSString *category = @"";
                if ([selectedFeature isKindOfClass:HLPFacility.class]) {
                    HLPFacility *l = (HLPFacility*)selectedFeature;
                    name = l.name;
                    if (l.addr) {
                        name = [NSString stringWithFormat:@"%@ (%@)", l.name, l.addr];
                    }
                    category = l.category==HLP_OBJECT_CATEGORY_TOILET?@"Toilet":@"Facility";
                }
                if ([selectedFeature isKindOfClass:HLPPOI.class]) {
                    HLPPOI *p = (HLPPOI*)selectedFeature;
                    name = [p name];
                    category = p.poiCategoryString;
                    if (p.minorCategory) {
                        category = [NSString stringWithFormat:@"%@ (%@)", category, p.minorCategory];
                    }
                }
                view.message.text = [NSString stringWithFormat:@"    Name: %@\nCategory: %@", name, category];
            } else {
                self.searchButton.title = NSLocalizedStringFromTable(@"Add", @"Fingerprint", @"");
            }
            
            self.navigationItem.rightBarButtonItem = _searchButton;
            self.navigationItem.leftBarButtonItem = _settingButton;
            
            self.navigationItem.title = @"POI";
        }
        if (fpMode != FPModePOI && fpMode != FPModeARFingerprint) {
            [_webView evaluateJavaScript:@"$('div.floorToggle').hide();$('#rotate-up-button').hide();" completionHandler:nil];
        }
    });
}


- (void)webViewDidInsertBridge:(WKWebView *)webView
{
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self reload];
        item1.enabled = item5.enabled = item2.enabled = item3.enabled = YES;
        item4.enabled = [[ServerConfig sharedConfig] isMapEditorKeyAvailable];
    }];
}

- (void) insertScript
{
    NSString *jspath = [[NSBundle mainBundle] pathForResource:@"fingerprint" ofType:@"js"];
    NSString *js = [[NSString alloc] initWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
    [_webView evaluateJavaScript:js completionHandler:nil];
}

- (void) reload
{
    fpm.delegate = self;
    BOOL showRoute = [[NSUserDefaults standardUserDefaults] boolForKey:@"finger_printing_show_route"];
    
    if (fpMode == FPModePOI || showRoute) {
        [poim initCenter:center];
    }
    if (fpMode == FPModeFingerprint || fpMode == FPModeARFingerprint ||fpMode == FPModeBeacon) {
        [NavUtil showWaitingForView:self.view withMessage:@"Loading..."];
        [fpm load];
    }
}

- (void) redrawFingerprint
{
    [self clearFeatures];
    if (fpMode == FPModeFingerprint || fpMode == FPModeARFingerprint) {
        [self showFingerprints:fpm.samplings];
    }
    if (fpMode == FPModeARFingerprint) {
        [self showARFingerprints:fpm.sampler.samples.samples];
    }
}

- (void) showFingerprints:(NSArray*) points
{
    [self showFeatures:points withStyle:^NSDictionary *(NSObject *obj) {
        if([obj isKindOfClass:HLPSampling.class]) {
            HLPSampling *p = (HLPSampling*)obj;
            return @{
                     @"lat": @(p.lat),
                     @"lng": @(p.lng),
                     @"count": ([p.beacons count] ? @([p.beacons count]) : @"")
                     };
        }
        return (NSDictionary*)nil;
    }];
}

- (void) showARFingerprints:(NSArray*) samples
{
    [self showFeatures:samples withStyle:^NSDictionary *(NSObject *obj) {
        if([obj isKindOfClass:HLPBeaconSample.class]) {
            HLPBeaconSample *s = (HLPBeaconSample*)obj;
            MKMapPoint l = MKMapPointMake(s.point.x, s.point.y);
            CLLocationCoordinate2D g = [FingerprintManager convertFromLocal:l ToGlobalWithRefpoint:fpm.selectedRefpoint];
            
            return @{
                     @"lat": @(g.latitude),
                     @"lng": @(g.longitude),
                     @"count": @"*"
                     };
        }
        return (NSDictionary*)nil;
    }];
}

- (void) showBeaconsOnFloorplan:(HLPFloorplan*) floorplan withRefpoint:(HLPRefpoint*)rp
{
    NSLog(@"showBeacons");
    [self showFeatures:floorplan.beacons.features withStyle:^(NSObject *obj) {
        if ([obj isKindOfClass:HLPGeoJSONFeature.class]) {
            HLPGeoJSONFeature* f = (HLPGeoJSONFeature*)obj;
            if ([f.properties[@"type"] isEqualToString:@"beacon"]) {
                MKMapPoint local = MKMapPointMake([f.geometry.coordinates[0] doubleValue], [f.geometry.coordinates[1] doubleValue]);
                if ([floorplan.beacons.crs isEqualToString:@"epsg:3857"]) { // updated feature
                    local = MKMapPointMake((local.x - floorplan.origin_x) / floorplan.ppm_x , (local.y - floorplan.origin_y) / floorplan.ppm_y);
                }
                CLLocationCoordinate2D global = [FingerprintManager convertFromLocal:local ToGlobalWithRefpoint:rp];
                
                return @{
                   @"lat": @(global.latitude),
                   @"lng": @(global.longitude),
                   @"count": @"B"
                   };
            }
        }
        return (NSDictionary*)nil;
    }];
}

- (void) showPOIs:(NSArray<HLPObject*>*)pois
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView evaluateJavaScript:@"$hulop.map.clearRoute()" completionHandler:nil];
        BOOL showRoute = [[NSUserDefaults standardUserDefaults] boolForKey:@"finger_printing_show_route"];
        if (showRoute) {
            NSArray *route = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
                if ([evaluatedObject isKindOfClass:HLPLink.class]) {
                    HLPLink *link = (HLPLink*)evaluatedObject;
                    return (link.sourceHeight == center.floor || link.targetHeight == center.floor);
                }
                return NO;
            }]];
            
            [_webView showRoute:route];
        }
    });
    if (fpMode == FPModePOI) {
        [self showFeatures:pois withStyle:^NSDictionary *(NSObject *obj) {
            if ([obj isKindOfClass:HLPPOI.class]) {
                HLPPOI* p = (HLPPOI*)obj;
                if (isnan(center.floor) || isnan(p.height) || center.floor == p.height){
                    NSString *name = @"P";
                    if (p.poiCategoryString) {
                        name = [name stringByAppendingString:[p.poiCategoryString substringToIndex:1]];
                    }
                    
                    return @{
                             @"lat": p.geometry.coordinates[1],
                             @"lng": p.geometry.coordinates[0],
                             @"count": name
                             };
                }
            }
            else if ([obj isKindOfClass:HLPFacility.class]) {
                HLPFacility* f = (HLPFacility*)obj;
                HLPNode *n = [poim nodeForFaciligy:f];
                if (isnan(center.floor) ||
                    (n && n.height == center.floor) ||
                    (!n && !isnan(f.height) && f.height == center.floor)) {
                    
                    return @{
                             @"lat": f.geometry.coordinates[1],
                             @"lng": f.geometry.coordinates[0],
                             @"count": @"F"
                             };
                }
            }
            return (NSDictionary*)nil;
        }];
    }
}

- (void) clearFeatures
{
    showingFeatures = @[];
    styleMap = [@{} mutableCopy];
    selectedFeature = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView evaluateJavaScript:@"$hulop.fp.showFingerprints([]);" completionHandler:nil];
    });
}

- (void) showFeatures:(NSArray<NSObject*>*)features withStyle:(NSDictionary*(^)(NSObject* obj))styleFunction
{
    if (!features) {
        return;
    }
    
    showingFeatures = [showingFeatures arrayByAddingObjectsFromArray:features];
    for(NSObject<NSCopying> *f in features) {
        [styleMap setObject:styleFunction forKey:f.description];
    }

    [self findFeatureAt:center completionHandler:^(NSObject *poi) {
        selectedFeature = poi;
        
        NSMutableArray *temp = [@[] mutableCopy];
        for(NSObject *f in showingFeatures) {
            NSDictionary*(^styleFunction)(NSObject* obj) = [styleMap objectForKey:f.description];
            if (!styleFunction) {
                NSLog(@"no style function for %@", f);
                continue;
            }
            NSDictionary *dict = styleFunction(f);
            if (dict) {
                [temp addObject:dict];
            }
        }
        
        NSData *data = [NSJSONSerialization dataWithJSONObject:temp options:0 error:nil];
        NSString* str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSString* script = [NSString stringWithFormat:@"$hulop.fp.showFingerprints(%@);", str];
        //NSLog(@"%@", script);
        NSLog(@"showFeatures");
        dispatch_async(dispatch_get_main_queue(), ^{
            [_webView evaluateJavaScript:script completionHandler:nil];
        });
    }];
    
}

- (void) findFeatureAt:(HLPLocation*)location completionHandler:(void (^)(NSObject *obj))completionHandler;{
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:0 Lng:0];
    double min = DBL_MAX;
    NSObject *mino = nil;
    for(NSObject<NSCopying> *f in showingFeatures) {
        NSDictionary*(^styleFunction)(NSObject* obj) = [styleMap objectForKey:f.description];
        if (!styleFunction) {
            NSLog(@"no style function for %@", f);
            continue;
        }
        NSDictionary *dict = styleFunction(f);
        if (dict) {
            [loc updateLat:[dict[@"lat"] doubleValue] Lng:[dict[@"lng"] doubleValue]];
            double d = [loc distanceTo:location];
            if (d < min) {
                min = d;
                mino = f;
            }
        }
    }
    [_webView evaluateJavaScript:@"(function(){return $hulop.map.getMap().getView().getZoom();})()" completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        double zoom = [value doubleValue];
        if (min < pow(2, 20-zoom)) {
            completionHandler(mino);
        } else {
            completionHandler(nil);
        }
    }];
}


- (void)checkConnection {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
    _retryButton.hidden = NO;
    _errorMessage.hidden = NO;
    [self updateView];
}

- (IBAction)retry:(id)sender {
    [_webView reload];
    _retryButton.hidden = YES;
    _errorMessage.hidden = YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)vibrate
{
    [[NavSound sharedInstance] vibrate:nil];
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
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self insertScript];
    });
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

#pragma mark - HLPWebviewHelperDelegate

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

- (void)webView:(HLPWebView *)webView openURL:(NSURL *)url
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_OPEN_URL object:self userInfo:@{@"url": url}];
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
        segue.destinationViewController.hidesBottomBarWhenPushed = YES;
        if ([segue.destinationViewController isKindOfClass:SettingViewController.class]) {
            ((SettingViewController*)segue.destinationViewController).fp_mode = fpMode;
        }
    }
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"]) {
        if (fpMode == FPModeFingerprint) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPSampling.class]) {
                [self checkDeletion:^{
                    [NavUtil showModalWaitingWithMessage:@"Deleting..."];
                    [fpm deleteFingerprint:((HLPSampling*)selectedFeature)._id[@"$oid"]];
                } withType:@"Fingerprint"];
            } else {
                if (fpm.isSampling) {
                    [self cancelSampling];
                } else {
                    [self startSampling];
                }
            }
        } else if (fpMode == FPModeARFingerprint) {
            if (fpm.isSampling) {
                [self completeSampling];
            } else {
                [self startSampling];
            }
        } else if (fpMode == FPModeBeacon) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                [self checkDeletion:^{
                    [NavUtil showModalWaitingWithMessage:@"Deleting..."];
                    [fpm removeBeacon:(HLPGeoJSONFeature*)selectedFeature];
                } withType:@"Beacon"];
            } else {
                batvc = [[UIStoryboard storyboardWithName:@"FingerPrint" bundle:nil] instantiateViewControllerWithIdentifier:@"beaconadd"];
                [self.navigationController showDetailViewController:batvc sender:self];
                //[self.navigationController pushViewController:batvc animated:YES];
            }
        } else if (fpMode == FPModePOI) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                [self checkDeletion:^{
                    [NavUtil showModalWaitingWithMessage:@"Deleting..."];
                    [poim removePOI:(HLPGeoJSONFeature*)selectedFeature];
                } withType:@"POI"];
            } else {
                poivc = [[UIStoryboard storyboardWithName:@"FingerPrint" bundle:nil] instantiateViewControllerWithIdentifier:@"poiadd"];
                [self.navigationController pushViewController:poivc animated:YES];
            }
        }
        return NO;
    }
    if ([identifier isEqualToString:@"blind_settings"]) {
        if (fpMode == FPModeARFingerprint) {
            if (fpm.isSampling) {
                [self cancelSampling];
                return NO;
            }
        }
    }
    
    return YES;
}

-(void) checkDeletion:(void(^)(void))deletion withType:(NSString*)type
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Delete %@", type]
                                                                   message:@"Are you sure to delete?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"Cancel", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"BlindView", @"")
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  deletion();
                                              }]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });

}


- (IBAction)returnActionForSegue:(UIStoryboardSegue *)segue
{
    fpm.delegate = self;
    if (batvc && batvc.selectedBeacon) {
        [NavUtil showModalWaitingWithMessage:@"Adding..."];
        [fpm addBeacon:batvc.selectedBeacon atLat:center.lat Lng:center.lng];
        batvc.selectedBeacon = nil;
    }
    if (poivc && poivc.selectedPOI) {
        [NavUtil showModalWaitingWithMessage:@"Adding..."];
        [poim addPOI:poivc.selectedPOI at:center withOptions:@{}];
        poivc.selectedPOI = nil;
    }
    [self reload];
}

# pragma mark action

- (void)updateMapCenter
{
    HLPRefpoint *rp = fpm.selectedRefpoint;
    if (!rp) {
        return;
    }
    CLLocationCoordinate2D global = [FingerprintManager convertFromLocal:MKMapPointMake(x, y) ToGlobalWithRefpoint:rp];
    fx = x;
    fy = y;
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:global.latitude Lng:global.longitude Floor:rp.floor_num];
    
    [_webView manualLocation:loc withSync:NO];
}

- (IBAction)turnLeftBit:(id)sender
{
    x -= 1;
    [self updateMapCenter];
    [self updateView];
}

- (IBAction)turnRightBit:(id)sender
{
    x += 1;
    [self updateMapCenter];
    [self updateView];
}

- (IBAction)floorDown:(id)sender
{
    y -= 1;
    [self updateMapCenter];
    [self updateView];
}

- (IBAction)floorUp:(id)sender
{
    y += 1;
    [self updateMapCenter];
    [self updateView];
}

- (IBAction)addNote:(id)sender
{
    [self acceptQRLocation];
}

- (void) acceptQRLocation
{
    if (fpMode == FPModeARFingerprint) {
        [fpm adjustLocation:qrLocation];
        lastQrLocation = qrLocation;
        qrLocation = nil;
        [self redrawFingerprint];
        [self updateView];
    }
}

@end
