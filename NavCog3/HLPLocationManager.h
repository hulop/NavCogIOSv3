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


#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "HLPLocation.h"


typedef NS_ENUM(NSUInteger, HLPLocationStatus) {
    HLPLocationStatusStable,
    HLPLocationStatusLocating,
    HLPLocationStatusLost,
    HLPLocationStatusBackground,
    HLPLocationStatusUnknown
};

@class HLPLocationManager;

@protocol HLPLocationManagerDelegate
@required
- (void)locationManager:(HLPLocationManager*)manager didLocationUpdate:(HLPLocation*)location;
- (void)locationManager:(HLPLocationManager*)manager didLocationStatusUpdate:(HLPLocationStatus)status;
- (void)locationManager:(HLPLocationManager*)manager didLocationAllowAlert:(BOOL)allowed;
- (void)locationManager:(HLPLocationManager*)manager hasAltimeter:(BOOL)exists;
- (void)locationManager:(HLPLocationManager*)manager didUpdateOrientation:(double)orientation withAccuracy:(double)accuracy;
@optional
- (void)locationManager:(HLPLocationManager*)manager didDebugInfoUpdate:(NSDictionary*)debugInfo;
- (void)locationManager:(HLPLocationManager*)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region;
- (void)locationManager:(HLPLocationManager*)manager didLogText:(NSString *)text;

@end

@interface HLPLocationManager: NSObject < CLLocationManagerDelegate >

@property (weak) id<HLPLocationManagerDelegate> delegate;

@property (readonly) BOOL isActive;
@property BOOL isBackground;
@property BOOL isAccelerationEnabled;
@property (readonly) HLPLocationStatus currentStatus;
@property NSDictionary* parameters;


- (instancetype) init NS_UNAVAILABLE;
+ (instancetype) sharedManager;

- (void) setModelPath:(NSString*)modelPath;
- (void) start;
- (void) restart;
- (void) makeStatusUnknown;
- (void) resetLocation:(HLPLocation*)loc;
- (void) stop;

//- (void) getRssiBias:(NSDictionary*)param withCompletion:(void (^)(float rssiBias)) completion;
//- (loc::LatLngConverter::Ptr) getProjection;
@end
