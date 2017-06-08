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
#import "BeaconAddTableViewController.h"
#import "POIAddTableViewController.h"


@interface BlindViewController () {
    NavWebviewHelper *helper;
    
    ViewState state;
}

@end

@implementation BlindViewController {
    FingerprintManager *fpm;
    BeaconAddTableViewController *batvc;
    POIAddTableViewController *poivc;
    NSString *fp_mode;
    NSArray<NSObject*>* showingFeatures;
    NSDictionary*(^showingStyle)(NSObject* obj);
    NSObject* selectedFeature;
    POIManager *poim;
    HLPLocation *center;
    BOOL loaded;
}

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    _settingButton = nil;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    state = ViewStateLoading;
    fp_mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"fp_mode"];

    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    UITapGestureRecognizer *webViewTapped = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapAction:)];
    webViewTapped.numberOfTapsRequired = 1;
    webViewTapped.delegate = self;
    [self.webView addGestureRecognizer:webViewTapped];
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:MANUAL_LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backToModeSelect:) name:@"BACK_TO_MODE_SELECTION" object:nil];
    
    
    fpm = [FingerprintManager sharedManager];
    fpm.delegate = self;
    
    poim = [POIManager sharedManager];
    poim.delegate = self;
}

- (void)backToModeSelect:(NSNotification*)note
{
    fpm.delegate = nil;
    poim.delegate = nil;

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tapAction:(UITapGestureRecognizer *)sender
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *result = [helper evalScript:@"(function(){return $hulop.indoor.getCurrentFloor()})()"];
        NSLog(@"touched %@", result);
        double height = [result doubleValue];
        height = height<1?height:height-1;
        HLPLocation* temp = [[HLPLocation alloc] init];
        [temp update:center];
        [temp updateFloor:height];
        [self locationChange:temp];
    });
}

#pragma mark - FingerprintManagerDelegate

- (void)manager:(FingerprintManager *)manager didRefpointSelected:(HLPRefpoint *)refpoint
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showRefpoint:manager.selectedRefpoint];
        if ([fp_mode isEqualToString:@"beacon"]) {
            [self showBeacons:manager.selectedFloorplan.beacons withRefpoint:manager.selectedRefpoint];
        }
        
        [self updateView];
    });
}

-(void) showRefpoint:(HLPRefpoint*)rp
{
    if (!rp) return;
    NSDictionary *param = @{
                            @"sync": @(false),
                            @"location": [[HLPLocation alloc] initWithLat:rp.anchor_lat Lng:rp.anchor_lng Floor:rp.floor_num]
                            };
    [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION object:self userInfo:param];
}

- (void)manager:(FingerprintManager *)manager didStatusChanged:(BOOL)isReady
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showRefpoint:manager.selectedRefpoint];
        [self updateView];
    });
}

- (void)manager:(FingerprintManager *)manager didSendData:(NSString *)idString withError:(NSError *)error
{
    NSLog(@"sample id %@", idString);
    [self vibrate];
    [self updateView];
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
        if ([fp_mode isEqualToString:@"fingerprint"]) {
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
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([fp_mode isEqualToString:@"poi"]) {
            [self showPOIs:pois];
            NSObject *poi = [self findFeatureAt:center];
            selectedFeature = poi;
        }
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
        BOOL isSampling = fpm.isSampling;
        
        if ([fp_mode isEqualToString:@"fingerprint"]) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = fpm.isReady;
            
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
        } else if ([fp_mode isEqualToString:@"beacon"]) {
            self.searchButton.enabled = existRefpoint && nds.isManualLocation && existUUID;
            self.settingButton.enabled = fpm.isReady;
            
            if (selectedFeature) {
                self.searchButton.title = NSLocalizedStringFromTable(@"Delete", @"Fingerprint", @"");
            } else {
                self.searchButton.title = NSLocalizedStringFromTable(@"Add", @"Fingerprint", @"");
            }
            self.devFingerprint.hidden = NO;
            
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
                    self.navigationItem.title = [NSString stringWithFormat:@"%@ Beacon [%ld]",
                                                 fpm.selectedRefpoint.floor,
                                                 [fpm beaconsCount]];
                }
                
            } else {
                self.navigationItem.title = @"Beacon";
            }

        } else if ([fp_mode isEqualToString:@"poi"]) {
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
            self.devFingerprint.hidden = NO;
            
            self.navigationItem.rightBarButtonItem = _searchButton;
            self.navigationItem.leftBarButtonItem = _settingButton;
            
            self.navigationItem.title = @"POI";
        }
        if (![fp_mode isEqualToString:@"poi"]) {
            [helper evalScript:@"$('div.floorToggle').hide();$('#rotate-up-button').hide();"];
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
    [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
        [fpm load];
    }];
}

- (void) insertScript
{
    NSString *jspath = [[NSBundle mainBundle] pathForResource:@"fingerprint" ofType:@"js"];
    NSString *js = [[NSString alloc] initWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
    [helper evalScript:js];
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
    [self showFeatures:pois withStyle:^NSDictionary *(NSObject *obj) {
        if ([obj isKindOfClass:HLPPOI.class]) {
            HLPPOI* p = (HLPPOI*)obj;
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
        else if ([obj isKindOfClass:HLPFacility.class]) {
            HLPFacility* p = (HLPFacility*)obj;
            NSString *name = @"F";
            
            return @{
                     @"lat": p.geometry.coordinates[1],
                     @"lng": p.geometry.coordinates[0],
                     @"count": name
                     };
        }
        return (NSDictionary*)nil;
    }];
}

- (void) showFeatures:(NSArray<NSObject*>*)features withStyle:(NSDictionary*(^)(NSObject* obj))styleFunction
{
    showingFeatures = features;
    showingStyle = styleFunction;
    selectedFeature = nil;
    
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
        [helper evalScript:script];
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
    if (min < 1) {
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
        if ([fp_mode isEqualToString:@"fingerprint"]) {
            if (fpm.isSampling) {
                [self cancelSampling];
            } else {
                [self startSampling];
            }
        } else if ([fp_mode isEqualToString:@"beacon"]) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                [fpm removeBeacon:(HLPGeoJSONFeature*)selectedFeature];
            } else {
                batvc = [[UIStoryboard storyboardWithName:@"FingerPrint" bundle:nil] instantiateViewControllerWithIdentifier:@"beaconadd"];
                [self.navigationController pushViewController:batvc animated:YES];
            }
        } else if ([fp_mode isEqualToString:@"poi"]) {
            if (selectedFeature && [selectedFeature isKindOfClass:HLPGeoJSONFeature.class]) {
                [poim removePOI:(HLPGeoJSONFeature*)selectedFeature];
            } else {
                poivc = [[UIStoryboard storyboardWithName:@"FingerPrint" bundle:nil] instantiateViewControllerWithIdentifier:@"poiadd"];
                [self.navigationController pushViewController:poivc animated:YES];
            }
        }
        return NO;
    }
    
    return YES;
}

- (IBAction)returnActionForSegue:(UIStoryboardSegue *)segue
{
    fpm.delegate = self;
    if (batvc && batvc.selectedBeacon) {
        [fpm addBeacon:batvc.selectedBeacon atLat:center.lat Lng:center.lng];
        batvc.selectedBeacon = nil;
    }
    if (poivc && poivc.selectedPOI) {
        [poim addPOI:poivc.selectedPOI at:center withOptions:@{}];
        poivc.selectedPOI = nil;
    }
    
}


@end
