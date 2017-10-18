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
#import <MapKit/MapKit.h>
#import "HLPFingerprint.h"
#import "HLPBeaconSampler.h"
#import <CoreLocation/CoreLocation.h>

@class FingerprintManager;

@protocol FingerprintManagerDelegate

@required
// return if observe one more fingerprint sample
-(void)manager:(FingerprintManager*)manager didStatusChanged:(BOOL)isReady;
-(void)manager:(FingerprintManager*)manager didRefpointSelected:(HLPRefpoint*)refpoint;
-(BOOL)manager:(FingerprintManager*)manager didObservedBeacons:(int)beaconCount atSample:(int)sampleCount;
-(void)manager:(FingerprintManager*)manager didSendData:(NSString*)idString withError:(NSError*)error;
-(void)manager:(FingerprintManager*)manager didSamplingsLoaded:(NSArray*)samplings;
@end

@interface FingerprintManager : NSObject <HLPBeaconSamplerDelegate>

@property id<FingerprintManagerDelegate> delegate;
@property (readonly) BOOL isReady;
@property (readonly) BOOL isSampling;
@property (readonly) long visibleBeaconCount;
@property (readonly) long beaconsSampleCount;
@property NSArray *floorplans;
@property NSArray *refpoints;
@property NSMutableDictionary *floorplanRefpointMap;
@property NSArray *samplings;
@property (readonly) HLPRefpoint *selectedRefpoint;
@property (readonly) HLPFloorplan *selectedFloorplan;

+(instancetype)sharedManager;

-(void)load;
-(void)loadSamplings:(void(^)(void))complete;
-(void)select:(HLPRefpoint*)rp;
-(void)startSamplingAtLat:(double)lat Lng:(double)lng;
-(void)startSampling;
-(void)cancel;
-(void)sendData;
-(void)deleteFingerprint:(NSString*)idString;
-(long)beaconsCount;
-(void)addBeacon:(CLBeacon*)beacon atLat:(double)lat Lng:(double)lng;
-(void)removeBeacon:(HLPGeoJSONFeature*)beacon;
-(CLBeacon*)strongestBeacon;
-(void)reset;
-(NSArray<CLBeacon*>*)visibleBeacons;

+ (MKMapPoint) convertFromGlobal:(CLLocationCoordinate2D)global ToLocalWithRefpoint:(HLPRefpoint*)rp;
+ (CLLocationCoordinate2D) convertFromLocal:(MKMapPoint)local ToGlobalWithRefpoint:(HLPRefpoint*)rp;

@end
