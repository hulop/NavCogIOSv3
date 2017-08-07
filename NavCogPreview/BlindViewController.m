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
#import "NavDeviceTTS.h"
#import "LocationEvent.h"
#import "NavUtil.h"
#import "NavDataStore.h"
#import "SettingViewController.h"
#import "NavBlindWebviewHelper.h"
#import "POIViewController.h"
#import "ServerConfig+Preview.h"
#import "ExpConfig.h"
#import "Logging.h"


#import <CoreMotion/CoreMotion.h>


@interface BlindViewController () {
}

@end


@implementation BlindViewController {
    NavBlindWebviewHelper *helper;
    HLPPreviewer *previewer;
    HLPPreviewCommander *commander;
    NSTimer *locationTimer;

    NSArray<NSObject*>* showingFeatures;
    NSDictionary*(^showingStyle)(NSObject* obj);
    NSObject* selectedFeature;
    HLPLocation *center;
    BOOL loaded;
    
    HLPPreviewEvent *current;
    HLPLocation *userLocation;
    HLPLocation *animLocation;
    
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    
    double baseYaw;
#define YAWS_MAX 100
    double yaws[YAWS_MAX];
    long yawsMax;
    int yawsIndex;
    NSTimeInterval lastGyroCommand;
    double prevDiff;
    
    double startAt;
    NSString *logFile;
    NSTimer *timeout;
}

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    _settingButton = nil;
    
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"developer_mode"];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.devUp setTitle:@"Up" forState:UIControlStateNormal];
    [self.devDown setTitle:@"Down" forState:UIControlStateNormal];
    [self.devLeft setTitle:@"Left" forState:UIControlStateNormal];
    [self.devRight setTitle:@"Right" forState:UIControlStateNormal];
    
    NSString *server = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_hokoukukan_server"];
    helper = [[NavBlindWebviewHelper alloc] initWithWebview:self.webView server:server];
    helper.userMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"user_mode"];
    helper.delegate = self;
    
    _indicator.accessibilityLabel = NSLocalizedString(@"Loading, please wait", @"");
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _indicator);
    
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(checkMapCenter:) userInfo:nil repeats:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(routeChanged:) name:ROUTE_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voiceOverStatusChanged:) name:UIAccessibilityVoiceOverStatusChanged object:nil];
    
    
    motionManager = [[CMMotionManager alloc] init];
    motionManager.deviceMotionUpdateInterval = 0.1;
    motionQueue = [[NSOperationQueue alloc] init];
    
    previewer = [[HLPPreviewer alloc] init];
    previewer.delegate = self;
    
    commander = [[HLPPreviewCommander alloc] init];
    commander.delegate = self;

    _cover.delegate = self;
}

- (void) voiceOverStatusChanged:(NSNotification*)note
{
    [self updateView];
}

- (void) resetMotionAverage
{
    [motionQueue addOperationWithBlock:^{
        yawsIndex = 0;
        lastGyroCommand = 0;
    }];
}

double average(double array[], long count) {
    double x = 0;
    double y = 0;
    for(int i = 0; i < count; i++) {
        x += cos(array[i]);
        y += sin(array[i]);
    }
    return atan2(y, x);
}

double stdev(double array[], long count) {
    double ave = average(array, count);
    double dev = 0;
    for(int i = 0; i < count; i++) {
        dev += (array[i] - ave) * (array[i] - ave);
    }
    return sqrt(dev);
}

- (void) routeChanged:(NSNotification*)note
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NavDataStore *nds = [NavDataStore sharedDataStore];
    [previewer startAt:nds.from.location];
    
    yawsMax = 20;
    [self resetMotionAverage];
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical toQueue:motionQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (previewer == nil || previewer.isActive == NO) {
            return;
        }
        
        yaws[yawsIndex] = motion.attitude.yaw;
        yawsIndex = (yawsIndex+1)%yawsMax;
        
        if (stdev(yaws, yawsMax) < M_PI * 2.5 / 180.0) {
            baseYaw = average(yaws, yawsMax);
        }
        
        double diff = [HLPLocation normalizeDegree:(baseYaw - motion.attitude.yaw)/M_PI*180];
        HLPPreviewEvent *right = current.right;
        HLPPreviewEvent *left = current.left;
        if (fabs(diff) > 20 &&  lastGyroCommand + 3 < NSDate.date.timeIntervalSince1970) {
            if (right && diff > right.turnedAngle - 20) {
                if (isnan(prevDiff) || prevDiff < 0) {
                    NSLog(@"gyro,right,%f,%f,%f",right.turnedAngle,diff,NSDate.date.timeIntervalSince1970);
                    [self faceRight];
                    prevDiff = diff;
                    yawsIndex = 0;
                    lastGyroCommand = NSDate.date.timeIntervalSince1970;
                }
            }
            else if (left && diff < left.turnedAngle + 20) {
                if (isnan(prevDiff) || prevDiff > 0) {
                    NSLog(@"gyro,left,%f,%f,%f",left.turnedAngle,diff,NSDate.date.timeIntervalSince1970);
                    [self faceLeft];
                    prevDiff = diff;
                    yawsIndex = 0;
                    lastGyroCommand = NSDate.date.timeIntervalSince1970;
                }
            }
        }
        else {
            prevDiff = NAN;
        }
        
        /*
        if (fabs(diff) > [[NSUserDefaults standardUserDefaults] integerForKey:@"gyro_motion_threshold"]) {
            if (isnan(prevDiff)) {
                if (diff > 0) { // right
                    NSLog(@"gyro,right,%f",NSDate.date.timeIntervalSince1970);
                    [self faceRight];
                } else { // left
                    NSLog(@"gyro,left,%f",NSDate.date.timeIntervalSince1970);
                    [self faceLeft];
                }
                prevDiff = diff;
            }
        } else {
            prevDiff = NAN;
        }
         */
    }];
    
    [self updateView];
}

- (void) _showRoute
{
    NavDataStore *nds = [NavDataStore sharedDataStore];

    NSArray *route = nds.route;
    
    if (!route) {// show all if no route
        route = [[NavDataStore sharedDataStore].features filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            if ([evaluatedObject isKindOfClass:HLPLink.class]) {
                HLPLink *link = (HLPLink*)evaluatedObject;
                return (link.sourceHeight == current.location.floor || link.targetHeight == current.location.floor);
            }
            return NO;
        }]];
    }
    [helper showRoute:route];
}

- (void) checkMapCenter:(NSTimer*)timer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HLPLocation *loc = [helper getCenter];
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

- (void)viewWillAppear:(BOOL)animated
{
}

- (void)viewWillDisappear:(BOOL)animated
{
}

- (void)viewDidAppear:(BOOL)animated
{
    [self updateView];
}

- (void)viewDidDisappear:(BOOL)animated
{
}

#pragma mark - HLPPreivewCommanderDelegate

- (void) playStep
{
    [[NavSound sharedInstance] playStep:nil];
}

- (void) playNoStep
{
    [[NavSound sharedInstance] playNoStep];
}

- (void)playSuccess
{
    [[NavSound sharedInstance] vibrate:nil];
    //[[NavSound sharedInstance] playSuccess];
    [[NavSound sharedInstance] playAnnounceNotification];
}

- (void)playFail
{
    [[NavSound sharedInstance] playFail];
}

- (void) vibrate
{
    [[NavSound sharedInstance] vibrate:nil];
}

- (void)speak:(NSString *)text withOptions:(NSDictionary *)options completionHandler:(void (^)())handler
{
    [[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:handler];
}

- (BOOL)isAutoProceed
{
    return previewer.isAutoProceed;
}

#pragma mark - HLPPreviewerDelegate

-(void)previewStarted:(HLPPreviewEvent*)event
{
    logFile = [Logging startLog];
    startAt = [[NSDate date] timeIntervalSince1970];
    
    if ([[ServerConfig sharedConfig] isExpMode]) {
        NSDictionary *info = [[ExpConfig sharedConfig] expUserCurrentRouteInfo];
        NSDictionary *route = [[ExpConfig sharedConfig] currentRoute];
        if (route) {
            double limit = [route[@"limit"] doubleValue];
            double elapsed_time = 0;
            if (info && info[@"elapsed_time"]) {
                elapsed_time = [info[@"elapsed_time"] doubleValue];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                timeout = [NSTimer scheduledTimerWithTimeInterval:(limit - elapsed_time) repeats:NO block:^(NSTimer * _Nonnull timer) {
                    [previewer stop];
                    [self speak:@"Time is up." withOptions:@{@"force":@(NO)} completionHandler:nil];
                }];
            });
        }
    }
    
    [commander previewStarted:event];
    current = event;
    [self _showRoute];
}

-(void)previewUpdated:(HLPPreviewEvent*)event
{
    [commander previewUpdated:event];
    current = event;
}

-(void)previewStopped:(HLPPreviewEvent*)event
{
    if (timeout) {
        [timeout invalidate];
        timeout = nil;
    }
    
    [motionManager stopDeviceMotionUpdates];
    
    [commander previewStopped:event];
    [helper clearRoute];
    current = nil;
    userLocation = nil;
    animLocation = nil;
    [locationTimer invalidate];
    locationTimer = nil;
    [self updateView];

    dispatch_async(dispatch_get_main_queue(), ^{
        [Logging stopLog];
        if ([[ServerConfig sharedConfig] isExpMode]) {
            [NavUtil showModalWaitingWithMessage:@"Saving log..."];
            [[ExpConfig sharedConfig] endExpStartAt:startAt withLogFile:logFile withComplete:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [NavUtil hideModalWaiting];
                });
            }];
        }
    });
}

- (void)userMoved:(double)distance
{
    [commander userMoved:distance];
}

- (void)userLocation:(HLPLocation*)location
{
    if (!userLocation) {
        userLocation = [[HLPLocation alloc] init];
        [userLocation update:location];
        [userLocation updateOrientation:location.orientation withAccuracy:0];
        animLocation = [[HLPLocation alloc] init];
        [animLocation update:location];
    } else {
        if (!animLocation) {
            animLocation = [[HLPLocation alloc] init];
        }
        [animLocation update:location];
        [animLocation updateOrientation:location.orientation withAccuracy:0];
    }
    [self startLocationAnimation];
}

- (void)remainingDistance:(double)distance
{
    [commander remainingDistance:distance];
}

- (void)startLocationAnimation
{
    if (!locationTimer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            locationTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer * _Nonnull timer) {
                double r = 0.5;
                [userLocation updateFloor:animLocation.floor];
                [userLocation updateLat:userLocation.lat*r + animLocation.lat*(1-r)
                                    Lng:userLocation.lng*r + animLocation.lng*(1-r)];
                
                double diff = [HLPLocation normalizeDegree:animLocation.orientation - userLocation.orientation];
                double ori = userLocation.orientation + diff * (1-r);

                [userLocation updateOrientation:ori withAccuracy:0];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showLocation];
                });
            }];
        });
    }
}

- (void) showLocation
{
    double orientation = -userLocation.orientation / 180 * M_PI;
    
    [helper sendData:@[@{
                           @"type":@"ORIENTATION",
                           @"z":@(orientation)
                           }]
            withName:@"Sensor"];
    
    [helper sendData:@{
                       @"lat":@(userLocation.lat),
                       @"lng":@(userLocation.lng),
                       @"floor":@(userLocation.floor),
                       @"accuracy":@(1),
                       @"rotate":@(0), // dummy
                       @"orientation":@(999), //dummy
                       @"debug_info":[NSNull null],
                       @"debug_latlng":[NSNull null]
                       }
            withName:@"XYZ"];
}

#pragma mark - PreviewCommandDelegate

- (void)speakAtPoint:(CGPoint)point
{
    // not implemented
    [self stopSpeaking];
}

- (void)stopSpeaking
{
    [previewer autoStepForwardStop];
    [[NavDeviceTTS sharedTTS] stop:NO];
}

- (void)speakCurrentPOI
{
    [previewer autoStepForwardStop];
    [commander previewCurrentFull];
}

- (void)selectCurrentPOI
{
    [previewer autoStepForwardStop];
    if (current && current.targetPOIs) {
        POIViewController *vc = [[UIStoryboard storyboardWithName:@"Preview" bundle:nil] instantiateViewControllerWithIdentifier:@"poi_view"];
        vc.pois = current.targetPOIs;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)quit
{
    NSString *title = @"Quit Preview";
    NSString *message = @"Are you sure to quit preview?";
    NSString *quit = @"Quit";
    NSString *cancel = @"Cancel";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:quit
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                  [previewer stop];
                                              }]];
    [alert addAction:[UIAlertAction actionWithTitle:cancel
                                              style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                              }]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentViewController:alert animated:YES completion:nil];
    });
}

#pragma mark - PreviewTraverseDelegate

- (void)gotoBegin
{
    [self resetMotionAverage];
    [previewer gotoBegin];
}

- (void)gotoEnd
{
    [self resetMotionAverage];
    [previewer gotoEnd];
}

- (void)stepForward
{
    [self resetMotionAverage];
    [previewer stepForward];
}

- (void)stepBackward
{
    [self resetMotionAverage];
    [previewer stepBackward];
}

- (void)jumpForward
{
    [self resetMotionAverage];
    [previewer jumpForward];
}

- (void)jumpBackward
{
    [self resetMotionAverage];
    [previewer jumpBackward];
}

- (void)faceRight
{
    [previewer faceRight];
}

- (void)faceLeft
{
    [previewer faceLeft];
}

- (void)autoStepForwardUp
{
    [self resetMotionAverage];
    [[NavSound sharedInstance] playStep:nil];
    [previewer autoStepForwardUp];
}

- (void)autoStepForwardDown
{
    [[NavSound sharedInstance] playStep:nil];
    [previewer autoStepForwardDown];
}

#pragma mark - private

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NavDataStore *nds = [NavDataStore sharedDataStore];
        
        BOOL hasCenter = [nds mapCenter] != nil;
        
        self.searchButton.enabled = hasCenter;
        if (previewer.isActive) {
            self.cover.hidden = NO;
            [self.cover becomeFirstResponder];
            self.searchButton.title = @"Quit";
            self.searchButton.accessibilityLabel = @"Quit preview";
        } else {
            self.cover.hidden = YES;
            if ([[ServerConfig sharedConfig] isExpMode]) {
                self.searchButton.title = @"Select";
                self.searchButton.accessibilityLabel = @"Select a route";
            } else {
                self.searchButton.title = @"Search";
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

- (void)bridgeInserted
{
}

- (void) insertScript
{
    NSString *jspath = [[NSBundle mainBundle] pathForResource:@"fingerprint" ofType:@"js"];
    NSString *js = [[NSString alloc] initWithContentsOfFile:jspath encoding:NSUTF8StringEncoding error:nil];
    [helper evalScript:js];
}

- (void) showPOIs:(NSArray<HLPObject*>*)pois
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [helper evalScript:@"$hulop.map.clearRoute()"];
        NSArray *route = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            if ([evaluatedObject isKindOfClass:HLPLink.class]) {
                HLPLink *link = (HLPLink*)evaluatedObject;
                return (link.sourceHeight == center.floor || link.targetHeight == center.floor);
            }
            return NO;
        }]];
        
        [helper showRoute:route];
    });
    
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
            /*
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
             */
        }
        return (NSDictionary*)nil;
    }];
}

- (void) clearFeatures
{
    showingFeatures = @[];
    showingStyle = nil;
    selectedFeature = nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [helper evalScript:@"$hulop.fp.showFingerprints([]);"];
    });
}

- (void) showFeatures:(NSArray<NSObject*>*)features withStyle:(NSDictionary*(^)(NSObject* obj))styleFunction
{
    showingFeatures = features;
    showingStyle = styleFunction;

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


#pragma mark - NavWebviewHelperDelegate

- (void) speak:(NSString*)text withOptions:(NSDictionary*)options {
    //[[NavDeviceTTS sharedTTS] speak:text withOptions:options completionHandler:nil];
}

- (BOOL) isSpeaking {
    //return [[NavDeviceTTS sharedTTS] isSpeaking];
    return NO;
}

- (void) vibrateOnAudioServices {
    //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
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

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [segue destinationViewController].restorationIdentifier = segue.identifier;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
    });
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"]) {
        if (previewer.isActive) {
            [previewer stop];
            return NO;
        }
        
        UIViewController *vc = nil;
        if ([[ServerConfig sharedConfig] isExpMode]) {
            vc = [[UIStoryboard storyboardWithName:@"Preview" bundle:nil] instantiateViewControllerWithIdentifier:@"setting_view"];
            vc.restorationIdentifier = @"exp_settings";
        } else {
            vc = [[UIStoryboard storyboardWithName:@"Preview" bundle:nil] instantiateViewControllerWithIdentifier:@"search_view"];
        }
        [self.navigationController pushViewController:vc animated:YES];
        
        return NO;
    }
    return YES;
}

@end
