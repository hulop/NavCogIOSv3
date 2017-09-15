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


@interface BlindViewController () {
    FPMode fpMode;
    
    int x, y;
    double fx, fy;
}

@end

@implementation BlindViewController {
    FingerprintManager *fpm;
    BeaconAddTableViewController *batvc;
    POIAddTableViewController *poivc;
    NSArray<NSObject*>* showingFeatures;
    NSDictionary*(^showingStyle)(NSObject* obj);
    NSObject* selectedFeature;
    POIManager *poim;
    HLPLocation *center;
    BOOL loaded;
    HLPRefpoint* currentRp;
    UITabBar *tabbar;
    UITabBarItem *item1, *item2, *item3;
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
    
    tabbar = [[UITabBar alloc] init];
    [self.view addSubview:tabbar];
    
    item1 = [[UITabBarItem alloc]initWithTitle:@"FingerPrint" image:[UIImage imageNamed:@"fingerprint"] tag:0];
    item2 = [[UITabBarItem alloc]initWithTitle:@"Beacon" image:[UIImage imageNamed:@"beacon"] tag:1];
    item3 = [[UITabBarItem alloc]initWithTitle:@"POI" image:[UIImage imageNamed:@"poi"] tag:2];
    item1.enabled = item2.enabled = item3.enabled = NO;
    
    tabbar.items = @[item1, item2, item3];
    tabbar.selectedItem = item1;
    tabbar.delegate = self;
    
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
    
    NSLayoutConstraint *layoutHeight =
    [NSLayoutConstraint constraintWithItem:tabbar
                                 attribute:NSLayoutAttributeHeight
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeHeight
                                multiplier:1.0
                                  constant:49];
    
    NSLayoutConstraint *layoutBottom2 =
    [NSLayoutConstraint constraintWithItem:self.view
                                 attribute:NSLayoutAttributeBottom
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:self.webView
                                 attribute:NSLayoutAttributeBottom
                                multiplier:1.0
                                  constant:49];

    [self.view addConstraints:@[layoutLeft, layoutRight, layoutBottom, layoutHeight, layoutBottom2]];
    [self.view layoutIfNeeded];

    [self.devUp setTitle:@"Up" forState:UIControlStateNormal];
    [self.devDown setTitle:@"Down" forState:UIControlStateNormal];
    [self.devLeft setTitle:@"Left" forState:UIControlStateNormal];
    [self.devRight setTitle:@"Right" forState:UIControlStateNormal];
    
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
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"developer_mode" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    FPMode modes[3] = {FPModeFingerprint, FPModeBeacon, FPModePOI};
    fpMode = modes[item.tag];
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
        NSString *result = [_webView stringByEvaluatingJavaScriptFromString:@"(function(){return $hulop.indoor.getCurrentFloor()})()"];
        NSLog(@"touched %@", result);
        double height = [result doubleValue];
        height = height<1?height:height-1;
        HLPLocation* temp = [[HLPLocation alloc] init];
        [temp update:center];
        [temp updateFloor:height];
        [self locationChange:temp];
        x = fx;
        y = fy;
    });
}

#pragma mark - FingerprintManagerDelegate

- (void)manager:(FingerprintManager *)manager didRefpointSelected:(HLPRefpoint *)refpoint
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showRefpoint:manager.selectedRefpoint];
        if (fpMode == FPModeBeacon) {
            [self showBeacons:manager.selectedFloorplan.beacons withRefpoint:manager.selectedRefpoint];
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
        if (fpMode == FPModeBeacon) {
            [self showBeacons:manager.selectedFloorplan.beacons withRefpoint:manager.selectedRefpoint];
        }
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
    [self updateView];
    long count = [[NSUserDefaults standardUserDefaults] integerForKey:@"finger_printing_duration"];
    if (sampleCount >= count) {
        [fpm sendData];
        return NO;
    }
    return YES;
}

- (void)manager:(FingerprintManager *)manager didSamplingsLoaded:(NSArray *)samplings
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideModalWaiting];
        if (fpMode == FPModeFingerprint) {
            [self showFingerprints:samplings];
        }
        [self updateView];
    });
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
    NSObject *poi = [self findFeatureAt:center];
    selectedFeature = poi;
    [self updateView];
}

- (void) startSampling
{
    fpm.delegate = self;
    [NavUtil showWaitingForView:self.view withMessage:@"Sampling..."];
    [fpm startSamplingAtLat:center.lat Lng:center.lng];
}
- (void) cancelSampling
{
    [NavUtil hideWaitingForView:self.view];
    [fpm cancel];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateView];
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
        BOOL isSampling = fpm.isSampling;
        
        BOOL showButtons = existRefpoint && (fpMode == FPModeFingerprint);
        
        self.devUp.hidden = !showButtons;
        self.devDown.hidden = !showButtons;
        self.devLeft.hidden = !showButtons;
        self.devRight.hidden = !showButtons;
        
        if (fpMode == FPModeFingerprint) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = fpm.isReady;
            
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
        } else if (fpMode == FPModeBeacon) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = fpm.isReady;
            
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

        } else if (fpMode == FPModePOI) {
            self.searchButton.enabled = nds.isManualLocation;
            self.settingButton.enabled =  YES;
            
            [NavUtil hideMessageView:self.view];
            if (selectedFeature) {
                self.searchButton.title = NSLocalizedStringFromTable(@"Delete", @"Fingerprint", @"");
                UIMessageView *view = [NavUtil showMessageView:self.view];
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
        if (fpMode != FPModePOI) {
            [_webView stringByEvaluatingJavaScriptFromString:@"$('div.floorToggle').hide();$('#rotate-up-button').hide();"];
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

- (void)bridgeInserted
{
    item1.enabled = item2.enabled = YES;
    item3.enabled = [[ServerConfig sharedConfig] isMapEditorKeyAvailable];

    [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self reload];
    }];
}

- (void) insertScript
{
    NSString *jspath = [[NSBundle mainBundle] pathForResource:@"fingerprint" ofType:@"js"];
    NSString *js = [[NSString alloc] initWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
    [_webView stringByEvaluatingJavaScriptFromString:js];
}

- (void) reload
{
    BOOL showRoute = [[NSUserDefaults standardUserDefaults] boolForKey:@"finger_printing_show_route"];
    
    [NavUtil showWaitingForView:self.view withMessage:@"Loading..."];
    if (fpMode == FPModePOI || showRoute) {
        [poim initCenter:center];
    }
    if (fpMode == FPModeFingerprint || fpMode == FPModeBeacon) {
        [fpm load];
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
                     @"count": @([p.beacons count])
                     };
        }
        return (NSDictionary*)nil;
    }];
}

- (void) showBeacons:(HLPGeoJSON*) beacons withRefpoint:(HLPRefpoint*)rp
{
    [self showFeatures:beacons.features withStyle:^(NSObject *obj) {
        if ([obj isKindOfClass:HLPGeoJSONFeature.class]) {
            HLPGeoJSONFeature* f = (HLPGeoJSONFeature*)obj;
            if ([f.properties[@"type"] isEqualToString:@"beacon"]) {
                MKMapPoint local = MKMapPointMake([f.geometry.coordinates[0] doubleValue], [f.geometry.coordinates[1] doubleValue]);
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
        [_webView stringByEvaluatingJavaScriptFromString:@"$hulop.map.clearRoute()"];
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
    showingStyle = nil;
    selectedFeature = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView stringByEvaluatingJavaScriptFromString:@"$hulop.fp.showFingerprints([]);"];
    });
}

- (void) showFeatures:(NSArray<NSObject*>*)features withStyle:(NSDictionary*(^)(NSObject* obj))styleFunction
{
    showingFeatures = features;
    showingStyle = styleFunction;

    NSObject *poi = [self findFeatureAt:center];
    selectedFeature = poi;

    
    NSMutableArray *temp = [@[] mutableCopy];
    for(NSObject *f in features) {
        NSDictionary *dict = styleFunction(f);
        if (dict) {
            [temp addObject:dict];
        }
    }
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:temp options:0 error:nil];
    NSString* str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    NSString* script = [NSString stringWithFormat:@"$hulop.fp.showFingerprints(%@);", str];
    //NSLog(@"%@", script);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_webView stringByEvaluatingJavaScriptFromString:script];
    });
}

- (NSObject*) findFeatureAt:(HLPLocation*)location
{
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:0 Lng:0];
    double min = DBL_MAX;
    NSObject *mino = nil;
    for(NSObject *f in showingFeatures) {
        NSDictionary *dict = showingStyle(f);
        if (dict) {
            [loc updateLat:[dict[@"lat"] doubleValue] Lng:[dict[@"lng"] doubleValue]];
            double d = [loc distanceTo:location];
            if (d < min) {
                min = d;
                mino = f;
            }
        }
    }
    double zoom = [[_webView stringByEvaluatingJavaScriptFromString:@"(function(){return $hulop.map.getMap().getView().getZoom();})()"] doubleValue];
    
    if (min < pow(2, 20-zoom)) {
        return mino;
    }
    return nil;
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
        } else if (fpMode == FPModeBeacon) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                [self checkDeletion:^{
                    [NavUtil showModalWaitingWithMessage:@"Deleting..."];
                    [fpm removeBeacon:(HLPGeoJSONFeature*)selectedFeature];
                } withType:@"Beacon"];
            } else {
                batvc = [[UIStoryboard storyboardWithName:@"FingerPrint" bundle:nil] instantiateViewControllerWithIdentifier:@"beaconadd"];
                [self.navigationController pushViewController:batvc animated:YES];
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


@end
