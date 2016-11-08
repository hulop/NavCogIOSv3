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
#import "NavCommander.h"

#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavUtil.h"
@import CoreMotion;

@interface BlindViewController () {
    NavWebviewHelper *helper;
    NavNavigator *navigator;
    NavCommander *commander;
    
    NSTimer *autoTimer;
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    double yaws[10];
    int yawsIndex;
    double accs[10];
    int accsIndex;
    
    BOOL autoProceed;
        
    NSTimer *timerForSimulator;
}

@end

@implementation BlindViewController

- (void)dealloc
{
    [helper prepareForDealloc];
    helper.delegate = nil;
    helper = nil;
    
    [navigator stop];
    navigator.delegate = nil;
    navigator = nil;
    
    [autoTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    helper = [[NavWebviewHelper alloc] initWithWebview:self.webView];
    helper.delegate = self;
    
    navigator = [[NavNavigator alloc] init];
    
    commander = [[NavCommander alloc] init];
    navigator.delegate = self;
    
    self.searchButton.enabled = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logReplay:) name:REQUEST_LOG_REPLAY object:nil];
    
    [self locationChanged:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self updateView];
}

- (void) updateView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.searchButton.title = NSLocalizedStringFromTable([navigator isActive]?@"Stop":@"Search", @"BlindView", @"");
        [self.searchButton setAccessibilityLabel:NSLocalizedStringFromTable([navigator isActive]?@"Stop Navigation":@"Search Route", @"BlindView", @"")];
        
        BOOL devMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"developer_mode"];
        BOOL previewMode = [NavDataStore sharedDataStore].previewMode;
        BOOL isActive = [navigator isActive];

        self.devGo.hidden = !devMode || previewMode;
        self.devLeft.hidden = !devMode || previewMode;
        self.devRight.hidden = !devMode || previewMode;
        self.devAuto.hidden = !devMode || previewMode || !isActive;
        self.devReset.hidden = !devMode || previewMode;
        self.devMarker.hidden = !devMode || previewMode;
        
        self.devUp.hidden = !devMode || previewMode;
        self.devDown.hidden = !devMode || previewMode;
        self.devNote.hidden = !devMode || previewMode;
        
        self.devAuto.selected = autoProceed;
        self.cover.hidden = devMode || !isActive;
        
        self.navigationItem.title = NSLocalizedStringFromTable(previewMode?@"Preview":@"NavCog", @"BlindView", @"");
    });

}

- (void)locationChanged:(NSNotification*)notification
{
    if (!self.searchButton.enabled) {
        if ([[NavDataStore sharedDataStore] currentLocation]) {
            self.searchButton.enabled = YES;
        }
    }
}

- (void) logReplay:(NSNotification*)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIMessageView *mv = [NavUtil showMessageView:self.view];
        
        id observer = [[NSNotificationCenter defaultCenter] addObserverForName:LOG_REPLAY_PROGRESS object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
            long progress = [[note object][@"progress"] longValue];
            long total = [[note object][@"total"] longValue];
            NSDictionary *marker = [note object][@"marker"];
            double floor = [[note object][@"floor"] doubleValue];
            double difft = [[note object][@"difft"] doubleValue]/1000;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (marker) {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%%:%03.1fs (%d:%.2f)",
                                       (progress /(double)total)*100, difft, [marker[@"floor"] intValue], floor];
                } else {
                    mv.message.text = [NSString stringWithFormat:@"Log %03.0f%%", (progress /(double)total)*100];
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

- (void) actionPerformed
{
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOG_REPLAY_STOP object:nil];
}


- (void) startLoading {
    [_indicator startAnimating];
    _indicator.hidden = NO;
}

- (void) loaded {
    [_indicator stopAnimating];
    _indicator.hidden = YES;
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

#pragma mark - IBActions

- (IBAction)turnLeftBit:(id)sender
{
    [self manualTurn:-10];
}

- (IBAction)turnRightBit:(id)sender {
    [self manualTurn:10];
}

- (IBAction)goForwardBit:(id)sender {
    [self manualGoForward:0.5];
}

- (IBAction)floorUp:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    
    [self manualGoFloor:floor+1];
}

- (IBAction)floorDown:(id)sender {
    double floor = [[[NavDataStore sharedDataStore] currentLocation] floor];
    [self manualGoFloor:floor-1];
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
                                                  NSLog(@"Note,%@",[[alert.textFields objectAtIndex:0]text]);
                                              }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)resetLocation:(id)sender {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:
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

- (IBAction)retry:(id)sender {
    [helper retry];
    _retryButton.hidden = YES;
    _errorMessage.hidden = YES;
}


#pragma mark - manual movement functions

- (void) manualTurn:(double)angle
{
    [[NavDataStore sharedDataStore] manualTurn:angle];
}

- (void)manualGoForward:(double)distance {
    HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
    HLPLocation *newLoc = [loc offsetLocationByDistance:distance Bearing:loc.orientation];
    
    [self manualLocation:newLoc];
}

- (void)manualLocation:(HLPLocation*)loc {
    if ([NavDataStore sharedDataStore].previewMode) {
        [[NavDataStore sharedDataStore] manualLocation:loc];
    } else {
        NSMutableString* script = [[NSMutableString alloc] init];
        [script appendFormat:@"$hulop.map.setSync(false);"];
        [script appendFormat:@"var map = $hulop.map.getMap();"];
        [script appendFormat:@"var c = new google.maps.LatLng(%f, %f);", loc.lat, loc.lng];
        [script appendFormat:@"map.setCenter(c);"];
        dispatch_async(dispatch_get_main_queue(), ^{
            [helper evalScript:script];
        });
    }
}

- (void)manualGoFloor:(double)floor {
    //NSLog(@"go floor %f", floor);
    
    if ([NavDataStore sharedDataStore].previewMode) {
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        [loc updateLat:loc.lat Lng:loc.lng Accuracy:loc.accuracy Floor:floor];
        [[NavDataStore sharedDataStore] manualLocation:loc];
    } else {

        int ifloor = round(floor<0?floor:floor+1);
        [helper evalScript:[NSString stringWithFormat:@"$hulop.indoor.showFloor(%d);", ifloor]];
        [self manualGoForward:0];
    }
}

- (IBAction)autoProceed:(id)sender {
    [self setAutoProceed:!autoProceed];
    [self updateView];
}

- (void) setAutoProceed:(BOOL) flag
{
    autoProceed = flag;
    if (autoProceed) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        BOOL needAction = [ud boolForKey:@"preview_with_action"];
        BOOL __block forwardAction = NO;
        double __block turnAction = 0;
        if (!motionManager && needAction) {
            motionManager = [[CMMotionManager alloc] init];
            motionManager.deviceMotionUpdateInterval = 0.1;
            motionQueue = [[NSOperationQueue alloc] init];
            motionQueue.maxConcurrentOperationCount = 1;
            motionQueue.qualityOfService = NSQualityOfServiceBackground;
        }
        if (needAction) {
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
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL pm = [NavDataStore sharedDataStore].previewMode;
            double ps = 1.0 / [ud doubleForKey:@"preview_speed"];
            
            autoTimer = [NSTimer scheduledTimerWithTimeInterval:pm?ps:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                //NSLog(@"angle=%f, dist=%f, floor=%f, f=%d, t=%f", commander.targetAngle, commander.targetDistance, commander.targetFloor, forwardAction, turnAction);
                if (needAction) {
                    if (fabs(commander.targetAngle) > 5 && turnAction != 0) {
                        if (commander.targetAngle < 0 && turnAction < 0) {
                            [[NavDataStore sharedDataStore] manualTurn:commander.targetAngle];
                            commander.targetAngle = 0;
                        } else if (commander.targetAngle > 0 && turnAction > 0) {
                            [[NavDataStore sharedDataStore] manualTurn:commander.targetAngle];
                            commander.targetAngle = 0;
                        }
                    }
                    
                    if (!isnan(commander.targetDistance) && commander.targetDistance > 0 && forwardAction) {
                        [self manualGoForward:0.2];
                        commander.targetDistance -= 0.2;
                        return;
                    }
                    
                    if (!isnan(commander.targetFloor) && turnAction) {
                        [self manualGoFloor:commander.targetFloor];
                        commander.targetFloor = NAN;
                        return;
                    }
                } else {
                    if (fabs(commander.targetAngle) > 5) {
                        if (isnan(commander.targetDistance) || commander.targetDistance < 0) {
                            if (fabs(commander.targetAngle) > 1) {
                                const double PREVIEW_TURN_RATE = 0.75;
                                [[NavDataStore sharedDataStore] manualTurn:commander.targetAngle*PREVIEW_TURN_RATE];
                                commander.targetAngle *= (1.0-PREVIEW_TURN_RATE);
                                return;
                            }
                        } else {
                            [[NavDataStore sharedDataStore] manualTurn:commander.targetAngle<0?-5:5];
                            commander.targetAngle -= commander.targetAngle<0?-5:5;
                        }
                    }
                    
                    if (!isnan(commander.targetDistance) && commander.targetDistance > 0) {
                        [self manualGoForward:0.2];
                        commander.targetDistance -= 0.2;
                        return;
                    }
                    
                    if (!isnan(commander.targetFloor)) {
                        [self manualGoFloor:commander.targetFloor];
                        commander.targetFloor = NAN;
                        return;
                    }
                }
                [[NavDataStore sharedDataStore] manualLocation:nil];

            }];
        });
    } else {
        [autoTimer invalidate];
        [motionManager stopDeviceMotionUpdates];
    }
}


#pragma mark - DialogViewControllerDelegate

- (void)startNavigationWithOptions:(NSDictionary *)options
{
    NSString *hash = [NSString stringWithFormat:@"navigate=%@&elv=%d&stairs=%d", options[@"node_id"], [options[@"no_elevator"] boolValue]?1:9, [options[@"no_stairs"] boolValue]?1:9];
    
    [helper setBrowserHash: hash];
}

- (NSString *)getCurrentFloor
{
    return [helper evalScript:@"(function() {return $hulop.indoor.getCurrentFloor();})()"];
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
    if ([properties[@"isActive"] boolValue]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [helper evalScript:@"$hulop.map.setSync(true);"];
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_as_start_point"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:properties];
                
                // if there is no location manager response
                timerForSimulator = [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer * _Nonnull timer) {
                    [self manualGoFloor: [properties[@"location"] floor]];
                    [self manualGoForward:0];
                }];
            }
            
            [NavUtil showWaitingForView:self.view];
            
            if ([NavDataStore sharedDataStore].previewMode) {
                [[NavDataStore sharedDataStore] manualLocationReset:properties];
                
                double delayInSeconds = 2.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self setAutoProceed:YES];
                });
            }
        });
    } else {
        [self setAutoProceed:NO];
    }
    [self updateView];
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
    [commander couldNotStartNavigation:properties];
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    if (timerForSimulator) {
        [timerForSimulator invalidate];
        timerForSimulator = nil;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [helper evalScript:[NSString stringWithFormat:@"$hulop.map.getMap().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]]];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        NSArray *temp = [[NavDataStore sharedDataStore] route];
        //temp = [temp arrayByAddingObjectsFromArray:properties[@"oneHopLinks"]];
        [helper showRoute:temp];
    });
    
    [commander didNavigationStarted:properties];
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    [commander didNavigationFinished:properties];
    
    [self setAutoProceed:NO];
    
    [NavDataStore sharedDataStore].previewMode = NO;
}

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    [commander userNeedsToChangeHeading:properties];
}
- (void)userAdjustedHeading:(NSDictionary*)properties
{
    [commander userAdjustedHeading:properties];
}
- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    [commander remainingDistanceToTarget:properties];
}
- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    [commander userIsApproachingToTarget:properties];
}
- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    [commander userNeedsToTakeAction:properties];
}
- (void)userNeedsToWalk:(NSDictionary*)properties
{
    [commander userNeedsToWalk:properties];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties
{
    [commander userMaybeGoingBackward:properties];
}
- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    [commander userMaybeOffRoute:properties];
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    [commander userMayGetBackOnRoute:properties];
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    [commander userShouldAdjustBearing:properties];
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    [commander userIsApproachingToPOI:properties];
}
- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    [commander userIsLeavingFromPOI:properties];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    [segue destinationViewController].restorationIdentifier = segue.identifier;
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"show_search"] && [navigator isActive]) {
        [[NavDataStore sharedDataStore] clearRoute];
        [NavDataStore sharedDataStore].previewMode = NO;
        [self setAutoProceed:NO];
        dispatch_async(dispatch_get_main_queue(), ^{
            [NavUtil hideWaitingForView:self.view];
        });

        return NO;
    }
    
    return YES;
}


@end
