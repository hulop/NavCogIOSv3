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

@implementation NavPreviewer{
    NSTimer *autoTimer;
    
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
        if (needAction) {
            [self.delegate startAction];
        }
        BOOL pm = [NavDataStore sharedDataStore].previewMode;
        double ps = 1.0 / [ud doubleForKey:@"preview_speed"];

        dispatch_async(dispatch_get_main_queue(), ^{
            autoTimer = [NSTimer scheduledTimerWithTimeInterval:pm?ps:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
                double turnAction = self.delegate.turnAction;
                BOOL forwardAction = self.delegate.forwardAction;
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
        });

    } else {
        [autoTimer invalidate];
        [self.delegate stopAction];
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
    if (properties[@"nextTargetHeight"]) {
        int targetHeight = [properties[@"nextTargetHeight"] intValue];
        _targetFloor = targetHeight;
    }

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
    double diffHeading = [properties[@"diffHeading"] doubleValue];
    _targetAngle = diffHeading;
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
