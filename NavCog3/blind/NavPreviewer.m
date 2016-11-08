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

#import "NavPreviewer.h"
#import "NavDataStore.h"
#import "LocationEvent.h"
@import CoreMotion;

@implementation NavPreviewer{
    NSTimer *autoTimer;
    CMMotionManager *motionManager;
    NSOperationQueue *motionQueue;
    double yaws[10];
    int yawsIndex;
    double accs[10];
    int accsIndex;
    
    BOOL _autoProceed;
}

- (void)dealloc
{
    [autoTimer invalidate];
}

- (void)setAutoProceed:(BOOL)autoProceed
{
    _autoProceed = autoProceed;
    if (_autoProceed) {
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

        BOOL pm = [NavDataStore sharedDataStore].previewMode;
        double ps = 1.0 / [ud doubleForKey:@"preview_speed"];
        
        autoTimer = [NSTimer timerWithTimeInterval:pm?ps:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
            //NSLog(@"angle=%f, dist=%f, floor=%f, f=%d, t=%f", _targetAngle, _targetDistance, _targetFloor, forwardAction, turnAction);
            if (needAction) {
                if (fabs(_targetAngle) > 5 && turnAction != 0) {
                    if (_targetAngle < 0 && turnAction < 0) {
                        [[NavDataStore sharedDataStore] manualTurn:_targetAngle];
                        _targetAngle = 0;
                    } else if (_targetAngle > 0 && turnAction > 0) {
                        [[NavDataStore sharedDataStore] manualTurn:_targetAngle];
                        _targetAngle = 0;
                    }
                }
                
                if (!isnan(_targetDistance) && _targetDistance > 0 && forwardAction) {
                    [self manualGoForward:0.2];
                    _targetDistance -= 0.2;
                    return;
                }
                
                if (!isnan(_targetFloor) && turnAction) {
                    [self manualGoFloor:_targetFloor];
                    _targetFloor = NAN;
                    return;
                }
            } else {
                if (fabs(_targetAngle) > 5) {
                    if (isnan(_targetDistance) || _targetDistance < 0) {
                        if (fabs(_targetAngle) > 1) {
                            const double PREVIEW_TURN_RATE = 0.75;
                            [[NavDataStore sharedDataStore] manualTurn:_targetAngle*PREVIEW_TURN_RATE];
                            _targetAngle *= (1.0-PREVIEW_TURN_RATE);
                            return;
                        }
                    } else {
                        [[NavDataStore sharedDataStore] manualTurn:_targetAngle<0?-5:5];
                        _targetAngle -= _targetAngle<0?-5:5;
                    }
                }
                
                if (!isnan(_targetDistance) && _targetDistance > 0) {
                    [self manualGoForward:0.2];
                    _targetDistance -= 0.2;
                    return;
                }
                
                if (!isnan(_targetFloor)) {
                    [self manualGoFloor:_targetFloor];
                    _targetFloor = NAN;
                    return;
                }
            }
            [[NavDataStore sharedDataStore] manualLocation:nil];
            
        }];
        [[NSRunLoop currentRunLoop] addTimer:autoTimer forMode:NSDefaultRunLoopMode];

    } else {
        [autoTimer invalidate];
        [motionManager stopDeviceMotionUpdates];
    }
}

- (BOOL) autoProceed
{
    return _autoProceed;
}

#pragma mark - NavNavigatorDelegate
- (void)didActiveStatusChanged:(NSDictionary *)properties
{
    _targetFloor = NAN;
    _targetDistance = NAN;
    _targetAngle = NAN;
}

- (void)couldNotStartNavigation:(NSDictionary *)properties
{
}

- (void)didNavigationStarted:(NSDictionary *)properties
{
}

- (void)didNavigationFinished:(NSDictionary *)properties
{
    [self setAutoProceed:NO];
    [NavDataStore sharedDataStore].previewMode = NO;
}

// basic functions
- (void)userNeedsToChangeHeading:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    _targetAngle = diffHeading;
}
- (void)userAdjustedHeading:(NSDictionary*)properties
{
}
- (void)remainingDistanceToTarget:(NSDictionary*)properties
{
    double distance = [properties[@"distance"] doubleValue];
    _targetDistance = distance;
}
- (void)userIsApproachingToTarget:(NSDictionary*)properties
{
}
- (void)userNeedsToTakeAction:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    _targetAngle = diffHeading;
    if (properties[@"nextTargetHeight"]) {
        int targetHeight = [properties[@"nextTargetHeight"] intValue];
        _targetFloor = targetHeight;
    }
}
- (void)userNeedsToWalk:(NSDictionary*)properties
{
    double distance = [properties[@"distance"] doubleValue];
    _targetDistance = distance;
}

// advanced functions
- (void)userMaybeGoingBackward:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    _targetAngle = diffHeading;
}
- (void)userMaybeOffRoute:(NSDictionary*)properties
{
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    _targetAngle = diffHeading;
}
- (void)userMayGetBackOnRoute:(NSDictionary*)properties
{
}
- (void)userShouldAdjustBearing:(NSDictionary*)properties
{
}

// POI
- (void)userIsApproachingToPOI:(NSDictionary*)properties
{
}
- (void)userIsLeavingFromPOI:(NSDictionary*)properties
{
}

#pragma mark - manual movement functions

- (void)manualTurn:(double)angle
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
        [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION object:loc];
    }
}

- (void)manualGoFloor:(double)floor {
    //NSLog(@"go floor %f", floor);
    
    if ([NavDataStore sharedDataStore].previewMode) {
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        [loc updateLat:loc.lat Lng:loc.lng Accuracy:loc.accuracy Floor:floor];
        [[NavDataStore sharedDataStore] manualLocation:loc];
    } else {
        HLPLocation *loc = [[NavDataStore sharedDataStore] currentLocation];
        [loc updateLat:loc.lat Lng:loc.lng Accuracy:loc.accuracy Floor:round(floor)];
        [[NSNotificationCenter defaultCenter] postNotificationName:MANUAL_LOCATION object:loc];
    }
}


@end
