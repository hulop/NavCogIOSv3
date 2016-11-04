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
#import "LocationEvent.h"
#import "NavDataStore.h"
#import "NavSound.h"
#import "TTTOrdinalNumberFormatter.h"
#import "NavDeviceTTS.h"
#import "NavUtil.h"
@import JavaScriptCore;
@import CoreMotion;

@interface BlindViewController () {
    NavWebviewHelper *helper;
    NavNavigator *navigator;
    
    NSTimer *autoTimer;
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    double yaws[10];
    int yawsIndex;
    double accs[10];
    int accsIndex;
    
    BOOL autoProceed;
    double targetAngle;
    double targetDistance;
    double targetFloor;
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
    
    navigator = [NavNavigator sharedNavigator];
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
    NSLog(@"go floor %f", floor);
    
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
                //NSLog(@"angle=%f, dist=%f, floor=%f, f=%d, t=%f", targetAngle, targetDistance, targetFloor, forwardAction, turnAction);
                if (needAction) {
                    if (fabs(targetAngle) > 5 && turnAction != 0) {
                        if (targetAngle < 0 && turnAction < 0) {
                            [[NavDataStore sharedDataStore] manualTurn:targetAngle];
                            targetAngle = 0;
                        } else if (targetAngle > 0 && turnAction > 0) {
                            [[NavDataStore sharedDataStore] manualTurn:targetAngle];
                            targetAngle = 0;
                        }
                    }
                    
                    if (!isnan(targetDistance) && targetDistance > 0 && forwardAction) {
                        [self manualGoForward:0.2];
                        targetDistance -= 0.2;
                        return;
                    }
                    
                    if (!isnan(targetFloor) && turnAction) {
                        [self manualGoFloor:targetFloor];
                        targetFloor = NAN;
                        return;
                    }
                } else {
                    if (fabs(targetAngle) > 5) {
                        if (isnan(targetDistance) || targetDistance < 0) {
                            if (fabs(targetAngle) > 1) {
                                const double PREVIEW_TURN_RATE = 0.75;
                                [[NavDataStore sharedDataStore] manualTurn:targetAngle*PREVIEW_TURN_RATE];
                                targetAngle *= (1.0-PREVIEW_TURN_RATE);
                                return;
                            }
                        } else {
                            [[NavDataStore sharedDataStore] manualTurn:targetAngle<0?-5:5];
                            targetAngle -= targetAngle<0?-5:5;
                        }
                    }
                    
                    if (!isnan(targetDistance) && targetDistance > 0) {
                        [self manualGoForward:0.2];
                        targetDistance -= 0.2;
                        return;
                    }
                    
                    if (!isnan(targetFloor)) {
                        [self manualGoFloor:targetFloor];
                        targetFloor = NAN;
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

#pragma mark - string builder functions

- (NSString*) floorString:(double) floor
{
    NSString *type = NSLocalizedStringFromTable(@"FloorNumType", @"BlindView", @"floor num type");

    if ([type isEqualToString:@"ordinal"]) {
        TTTOrdinalNumberFormatter*ordinalNumberFormatter = [[TTTOrdinalNumberFormatter alloc] init];
        [ordinalNumberFormatter setLocale:[NSLocale currentLocale]];
        [ordinalNumberFormatter setGrammaticalGender:TTTOrdinalNumberFormatterMaleGender];
        
        floor = round(floor*2.0)/2.0;
        
        if (floor < 0) {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(fabs(floor))];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), ordinalNumber];
        } else {
            NSString *ordinalNumber = [ordinalNumberFormatter stringFromNumber:@(floor+1)];
            
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), ordinalNumber];
        }
    } else {
        floor = round(floor*2.0)/2.0;
        
        if (floor < 0) {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorBasementD", @"BlindView", @"basement floor"), @(fabs(floor))];
        } else {
            return [NSString localizedStringWithFormat:NSLocalizedStringFromTable(@"FloorD", @"BlindView", @"floor"), @(floor+1)];
        }
    }
}

- (NSString*)distanceString:(double)distance
{
    NSString *distance_unit = [[NSUserDefaults standardUserDefaults] stringForKey:@"distance_unit"];
    
    BOOL isFeet = [distance_unit isEqualToString:@"unit_feet"];
    const double FEET_UNIT = 0.3024;
    
    if (isFeet) {
        distance /= FEET_UNIT;
    }
    NSString *unit = isFeet?@"unit_feet":@"unit_meter";    
    return [NSString stringWithFormat:NSLocalizedStringFromTable(unit, @"BlindView", @""), (int)round(distance)];
}

- (NSString*)actionString:(NSDictionary*)properties
{
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    HLPLinkType nextLinkType = [properties[@"nextLinkType"] intValue];
    double turnAngle = [properties[@"turnAngle"] doubleValue];
    NSString *string = nil;
    
    if (nextLinkType == LINK_TYPE_ELEVATOR || nextLinkType == LINK_TYPE_ESCALATOR || nextLinkType == LINK_TYPE_STAIRWAY) {
        //int sourceHeight = [properties[@"nextSourceHeight"] intValue];
        int targetHeight = [properties[@"nextTargetHeight"] intValue];
        NSString *mean = [HLPLink nameOfLinkType:nextLinkType];
        
        NSString *angle;
        if (turnAngle < -150) {
            angle = NSLocalizedStringFromTable(@"on your left side(almost back)",@"BlindView", @"something at your degree -150 ~ -180"); //@"左後ろ";
        } else if (turnAngle > 150) {
            angle = NSLocalizedStringFromTable(@"on your right side(almost back)",@"BlindView", @"something at your degree +150 ~ +180"); //@"右後ろ";
        } else if (turnAngle < -120) {
            angle = NSLocalizedStringFromTable(@"on your left side(back)",@"BlindView", @"something at your degree -120 ~ -150"); //@"左斜め後ろ";
        } else if (turnAngle > 120) {
            angle = NSLocalizedStringFromTable(@"on your right side(back)",@"BlindView", @"something at your degree +120 ~ +150"); //@"右斜め後ろ";
        } else if (turnAngle < -60) {
            angle = NSLocalizedStringFromTable(@"on your left side",@"BlindView", @"something at your degree -60 ~ -120"); //@"左";
        } else if (turnAngle > 60) {
            angle = NSLocalizedStringFromTable(@"on your right side",@"BlindView", @"something at your degree +60 ~ +120"); //@"右";
        } else if (turnAngle < -22.5) {
            angle = NSLocalizedStringFromTable(@"on your left side(front)",@"BlindView", @"something at your degree -22.5 ~ -60"); //@"左斜め前";
        } else if (turnAngle > 22.5) {
            angle = NSLocalizedStringFromTable(@"on your right side(front)",@"BlindView", @"something at your degree +22.5 ~ +60"); //@"右斜め前";
        } else {
            angle = NSLocalizedStringFromTable(@"in front of you",@"BlindView", @"something at your degree -22.5 ~ +22.5"); //@"正面";
        }
        
        NSString *floor = [self floorString:targetHeight];
        string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Go to %3$@ by %2$@ %1$@",@"BlindView",@"") , angle, mean, floor];//@""
    }
    else if (linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        int sourceHeight = [properties[@"sourceHeight"] intValue];
        int targetHeight = [properties[@"targetHeight"] intValue];
        NSString *mean = [HLPLink nameOfLinkType:linkType];
        NSString *sfloor = [self floorString:sourceHeight];
        NSString *tfloor = [self floorString:targetHeight];
        string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Go to %2$@ by %1$@, now you are in %3$@",@"BlindView",@"") , mean, tfloor, sfloor]; //@"%1$@を使って%2$@にいきます。現在は%3$@にいます。"
    }
    else {
        if (turnAngle < -150 ) {
            string = NSLocalizedStringFromTable(@"make a u-turn to the left",@"BlindView", @"make turn to -180 ~ -180");
        } else if (turnAngle > 150) {
            string = NSLocalizedStringFromTable(@"make a u-turn to the right",@"BlindView", @"make turn to +150 ~ +180");
        } else if (turnAngle < -120) {
            string = NSLocalizedStringFromTable(@"make a big left turn",@"BlindView", @"make turn to -120 ~ -150");
        } else if (turnAngle > 120) {
            string = NSLocalizedStringFromTable(@"make a big right turn",@"BlindView", @"make turn to +120 ~ +150");
        } else if (turnAngle < -60) {
            string = NSLocalizedStringFromTable(@"turn left",@"BlindView", @"make turn to -60 ~ -120");
        } else if (turnAngle > 60) {
            string = NSLocalizedStringFromTable(@"turn right",@"BlindView", @"make turn to +60 ~ +120");
        } else if (turnAngle < -22.5) {
            string = NSLocalizedStringFromTable(@"make a slight left turn",@"BlindView", @"make turn to -22.5 ~ -60");
        } else if (turnAngle > 22.5) {
            string = NSLocalizedStringFromTable(@"make a slight right turn",@"BlindView", @"make turn to +22.5 ~ +60");
        } else {
            string = NSLocalizedStringFromTable(@"go straight", @"BlindView", @"");
        }
        
        if (linkType == LINK_TYPE_ELEVATOR) {
            string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"After getting off the elevator, %@", @"BlindView", @""), string];
        }
    }
    return string;
}

- (NSString*) startPOIString:(NSArray*) pois
{
    if (pois == nil || [pois count] == 0) {
        return @"";
    }
    NSMutableString *string = [@"" mutableCopy];
    
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forBeforeStart == YES"]];
    
    if (pois && [pois count] > 0) {
        NSArray *infos = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"flagCaution == NO"]];
        for(NavPOI *poi in infos) {
            if (poi.forSign) {
                [string appendFormat:NSLocalizedStringFromTable(@"There is a sign says %@", @"BlindView", @""), poi.text];
            } else {
                [string appendString:poi.text];
            }
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
        }
        NSArray *cautions = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"flagCaution == YES"]];
        for(NavPOI *poi in cautions) {
            if (poi.forFloor) {
                [string appendFormat:NSLocalizedStringFromTable(@"Watch your step, %@", @"BlindView", @""), poi.text];
            } else if (poi.forSign) {
                [string appendFormat:NSLocalizedStringFromTable(@"There is a sign says %@", @"BlindView", @""), poi.text];
            } else {
                [string appendFormat:NSLocalizedStringFromTable(@"Caution, %@", @"BlindView", @""), poi.text];
            }
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
        }
    }

    return string;
}

- (NSString*) floorPOIString:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forFloor == YES && forBeforeStart == NO"]];

    NSString *text = nil;
    if ([pois count] > 1) {
        // TODO: multiple floor info
    }
    if ([pois count] > 0) {
        NavPOI *poi = pois[0];
        if (poi.text && [poi.text length] > 0) {
            text = poi.text;
        }
    }
    return text;
}


- (NSString*) cornerPOIString:(NSArray*)pois
{
    pois = [pois filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"forCorner == YES && forBeforeStart == NO"]];
    NSString *text = nil;
    if ([pois count] > 1) {
        // TODO: multiple floor info
    }
    if ([pois count] > 0) {
        NavPOI *poi = pois[0];
        if (poi.text && [poi.text length] > 0) {
            text = poi.text;
        }
    }
    return text;
}

- (NSString*) headingActionString:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    targetAngle = diffHeading;
    double threshold = [properties[@"threshold"] doubleValue];

    NSString *string;
    if (diffHeading < -150 || 150 < diffHeading) {
        string = NSLocalizedStringFromTable(@"turn around",@"BlindView", @"head to the back");
    } else if (diffHeading < -120) {
        string = NSLocalizedStringFromTable(@"turn to the backward left",@"BlindView", @"head to the diagonally backward left direction");
    } else if (diffHeading > 120) {
        string = NSLocalizedStringFromTable(@"turn to the backward right",@"BlindView", @"head to the diagonally backward right direction");
    } else if (diffHeading < -60) {
        string = NSLocalizedStringFromTable(@"turn to the left",@"BlindView", @"head to the left direction");
    } else if (diffHeading > 60) {
        string = NSLocalizedStringFromTable(@"turn to the right",@"BlindView", @"head to the right direction");
    } else if (diffHeading < -threshold) {
        string = NSLocalizedStringFromTable(@"bear left",@"BlindView", @"head to the diagonally forward left direction");
    } else if (diffHeading > threshold) {
        string = NSLocalizedStringFromTable(@"bear right",@"BlindView", @"head to the diagonally forward right direction");
    } else {
        //@throw [[NSException alloc] initWithName:@"wrong parameters" reason:@"abs(diffHeading) is smaller than threshold" userInfo:nil];
        return nil;
    }

    return string;
}

#pragma mark - NavNavigatorDelegate

- (void)didActiveStatusChanged:(NSDictionary *)properties
{
    if ([navigator isActive]) {
        targetFloor = NAN;
        targetDistance = NAN;
        targetAngle = NAN;

        dispatch_async(dispatch_get_main_queue(), ^{
            [helper evalScript:@"$hulop.map.setSync(true);"];
        
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"reset_as_start_point"]) {
                [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object:properties];
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
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [helper evalScript:[NSString stringWithFormat:@"$hulop.map.getMap().setZoom(%f);", [[NSUserDefaults standardUserDefaults] doubleForKey:@"zoom_for_navigation"]]];
    });

    dispatch_async(dispatch_get_main_queue(), ^{
        [NavUtil hideWaitingForView:self.view];
        [helper showRoute:[[NavDataStore sharedDataStore] route]];
    });

    
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSMutableString *string = [[NSMutableString alloc] init];
    NSString *destination = [NavDataStore sharedDataStore].to.namePron;
    
    double totalLength = [properties[@"totalLength"] doubleValue];
    NSString *totalDist = [self distanceString:totalLength];

    NSArray *pois = properties[@"pois"];
    [string appendString:[self startPOIString:pois]];
    
    if (destination && ![destination isEqual:[NSNull null]] && [destination length] > 0){
        [string appendFormat:NSLocalizedStringFromTable(@"distance to %1$@", @"BlindView", @"distance to a destination name"), destination, totalDist];
    } else {
        [string appendFormat:NSLocalizedStringFromTable(@"distance to the destination", @"BlindView", @"distance to the destination"), totalDist];
    }
    
    [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
    }];
    
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    NSString *destination = nil;
    if (properties[@"isEndOfLink"] && [properties[@"isEndOfLink"] boolValue] == YES) {
        destination = [NavDataStore sharedDataStore].to.name;
    }
    
    NSMutableString *string = [[NSMutableString alloc] init];
    if (destination && ![destination isEqual:[NSNull null]] && [destination length] > 0){
        [string appendFormat:NSLocalizedStringFromTable(@"You arrived at %1$@",@"BlindView", @"arrived message with destination name"), destination];
    } else {
        [string appendFormat:NSLocalizedStringFromTable(@"You arrived",@"BlindView", @"arrived message")];
    }
    
    [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
        [[NavDataStore sharedDataStore] clearRoute];
    }];
    
    [self setAutoProceed:NO];
    
    [NavDataStore sharedDataStore].previewMode = NO;
}

- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    targetAngle = diffHeading;
    
    NSString *string = [self headingActionString:properties];
    
    if (string) {
        [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
            
        }];
    }
}

- (void)userAdjustedHeading:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"speak,<play success sound>");
        if (autoProceed && ![[NSUserDefaults standardUserDefaults] boolForKey:@"preview_with_action"]) {
            return;
        }
        [[NavSound sharedInstance] playSuccess];
    });
}

- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    double distance = [properties[@"distance"] doubleValue];
    BOOL target = [properties[@"target"] boolValue];
    
    targetDistance = distance;
    
    if (target) {
        NSLog(@"%@", NSStringFromSelector(_cmd));
        NSString *dist = [self distanceString:distance];
        NSString *string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"remaining distance",@"BlindView", @""),  dist];
        [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
            
        }];
    }
}

- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSString *action = [self actionString:properties];
    NSString *string = nil;
    
    if (false && action) {
        string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"approaching to %@",@"BlindView",@"approaching to do something") , action];
    } else {
        string = NSLocalizedStringFromTable(@"approaching",@"BlindView",@"approaching");
    }
    
    [[NavDeviceTTS sharedTTS] speak:string force:YES completionHandler:^{
        
    }];
}

- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NSString *string = [self actionString:properties];
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    targetAngle = diffHeading;
    if (properties[@"nextTargetHeight"]) {
        int targetHeight = [properties[@"nextTargetHeight"] intValue];
        targetFloor = targetHeight;
    }
    
    [[NavDeviceTTS sharedTTS] speak:string force:YES completionHandler:^{
        
    }];
}

- (void)userNeedsToWalk:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
 
    double distance = [properties[@"distance"] doubleValue];
    HLPLinkType linkType = [properties[@"linkType"] intValue];
    BOOL isNextDestination = [properties[@"isNextDestination"] boolValue];
    double noAndTurnMinDistance = [properties[@"noAndTurnMinDistance"] doubleValue];

    NSString *action = [self actionString:properties];
    NSMutableString *string = [@"" mutableCopy];
    
    NSArray *pois = properties[@"pois"];
    BOOL isFirst = [properties[@"isFirst"] boolValue];
    if (!isFirst) {
        [string appendString:[self startPOIString:pois]];
    }
    
    NSString *floorInfo = [self floorPOIString:pois];
    NSString *cornerInfo = [self cornerPOIString:pois];
    
    targetDistance = distance;
    NSString *dist = [self distanceString:distance];
    
    
    if (linkType == LINK_TYPE_ELEVATOR || linkType == LINK_TYPE_ESCALATOR || linkType == LINK_TYPE_STAIRWAY) {
        [string appendString:action];
    }
    else if (isNextDestination) {
        NSString *destTitle = [NavDataStore sharedDataStore].to.name;
        
        [string appendString: [NSString stringWithFormat:NSLocalizedStringFromTable(@"destination is in distance",@"BlindView",@"remaining distance to the destination"), destTitle, dist]];
    }
    else if (action) {
        NSString *proceedString = @"proceed distance";
        NSString *nextActionString = @"and action";
        
        if (floorInfo) {
            proceedString = [proceedString stringByAppendingString:@" on floor"];
        }
        if (noAndTurnMinDistance < distance && distance < 50) {
            proceedString = [proceedString stringByAppendingString:@" ..."];
        }
        if (cornerInfo) {
            nextActionString = [nextActionString stringByAppendingString:@" at near object"];
        }
        
        proceedString = NSLocalizedStringFromTable(proceedString, @"BlindView", @"");
        proceedString = [NSString stringWithFormat:proceedString, dist, floorInfo];
        nextActionString = NSLocalizedStringFromTable(nextActionString, @"BlindView", @"");
        nextActionString = [NSString stringWithFormat:nextActionString, action, cornerInfo];
        
        [string appendString:proceedString];
        if (noAndTurnMinDistance < distance && distance < 50) {
            [string appendString:nextActionString];
        }
    }
    
    [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
        
    }];
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary *)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    targetAngle = diffHeading;
    
    NSString *hAction = [self headingActionString:properties];
    
    if (hAction) {
        NSString *string = NSLocalizedStringFromTable(@"%@, you might be going backward.", @"BlindView", @"");
        string = [NSString stringWithFormat:string, hAction];
        [[NavDeviceTTS sharedTTS] speak:string completionHandler:^{
            
        }];
    }

}

- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
    NavPOI *poi = properties[@"poi"];
    double heading = [properties[@"heading"] doubleValue];
    
    if (poi.needsToPlaySound) {
        // play something
    }    
    if (poi.requiresUserAction) {
    } else {
        NSString *angle;
        if (!isnan(heading)) {
            if (heading < -30) {
                angle = NSLocalizedStringFromTable(@"on your left side",@"BlindView", @""); //@"左";
            } else if (heading > 30) {
                angle = NSLocalizedStringFromTable(@"on your right side",@"BlindView", @""); //@"右";
            } else {
                angle = NSLocalizedStringFromTable(@"in front of you",@"BlindView", @""); //@"正面";
            }
        }

        NSString *text = poi.text;
        NSString *ld = poi.longDescription;

        if (poi.isDestination) {
            text = [NavDataStore sharedDataStore].to.namePron;
        }
        
        NSMutableString *string = [@"" mutableCopy];
        if (angle) {
            if (poi.isDestination) {
                [string appendFormat:NSLocalizedStringFromTable(@"destination is %@", @"BlindView", @""), text, angle];
                if (poi.text) {
                    [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
                    [string appendString:poi.text];
                }
            } else {
                if (poi.flagPlural) {
                    [string appendFormat:NSLocalizedStringFromTable(@"poi are %@", @"BlindView", @""), text, angle];
                } else {
                    [string appendFormat:NSLocalizedStringFromTable(@"poi is %@", @"BlindView", @""), text, angle];
                }
            }
        } else {
            if (text) {
                [string appendString:text];
            }
        }
        if (ld) {
            [string appendString:NSLocalizedStringFromTable(@"PERIOD", @"BlindView", @"")];
            [string appendString:ld];
        }
        
        NSArray *result = [self checkCommand:string];

        [[NavDeviceTTS sharedTTS] speak:result[0] completionHandler:^{
            if ([result count] < 2) {
                return;
            }
            
            JSContext *ctx = [[JSContext alloc] init];
            ctx[@"speak"] = ^(NSString *message) {
                [[NavDeviceTTS sharedTTS] speak:message completionHandler:^{
                }];
            };
            ctx[@"openURL"] = ^(NSString *url, NSString *title, NSString *message) {
                if (!title || !message || !url) {
                    if (url) {
                        dispatch_async(dispatch_get_main_queue(), ^(void){
                            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
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
                                                                  [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
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
            [ctx evaluateScript:result[1]];
        }];
    }
}


- (NSArray*)checkCommand:(NSString *)text
{
    NSRegularExpression *commandPattern = [NSRegularExpression regularExpressionWithPattern:@"\\[\\[([^\\]]+)\\]\\]" options:0 error:nil];
    
    NSTextCheckingResult *result;
    NSMutableArray *commands = [@[] mutableCopy];
    while((result = [commandPattern firstMatchInString:text options:0 range:NSMakeRange(0, [text length])]) != nil) {
        NSString *command = [text substringWithRange:[result rangeAtIndex:1]];
        text = [text stringByReplacingCharactersInRange:result.range withString:@""];
        [commands addObject:command];
    }
    [commands insertObject:text atIndex:0];
    return commands;
}

- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
    NSLog(@"%@", NSStringFromSelector(_cmd));
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
