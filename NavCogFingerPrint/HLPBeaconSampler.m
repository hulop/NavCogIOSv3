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

#import "HLPBeaconSampler.h"

@implementation HLPBeaconSampler


static HLPBeaconSampler *sharedData_ = nil;


+ (HLPBeaconSampler *)sharedInstance{
    @synchronized(self){
        if (!sharedData_) {
            sharedData_ = [HLPBeaconSampler new];
        }
    }
    return sharedData_;
}

- (id)init
{
    self = [super init];
    if (self) {
        sampledData = [[NSMutableArray alloc] init];
        lastProcessedIndex = 0;
        sampledPoint = [[NSMutableArray alloc] init];
        
        locationManager = [[CLLocationManager alloc]init];
        locationManager.delegate = self;
        
        recording = FALSE;
    }
    return self;
}


- (void)setSamplingBeaconUUID:(NSString *)uuid_str {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuid_str];
    
    allBeacons = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"dynamicBeaconSamplingTool"];
}

- (void) setSamplingLocation:(HLPPoint3D *)point {
    for (HLPBeaconSample *bs in sampledData) {
        [bs setPoint:point];
    }
}

- (void)reset {
    @synchronized(self) {
        [sampledData removeAllObjects];
    }
    lastProcessedIndex = 0;
    [sampledPoint removeAllObjects];
}

- (BOOL) startRecording {
    if (!allBeacons) {
        NSLog(@"Beacon region should be set first");
        return false;
    }
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    if (IRTCF_DEBUG) NSLog(@"authorized status = %d, %d", status, kCLAuthorizationStatusNotDetermined);
    if (status == kCLAuthorizationStatusNotDetermined && [locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        if (IRTCF_DEBUG) NSLog(@"not authorized. try to get authorization.");
        [locationManager requestWhenInUseAuthorization];
    }
    
    status = [CLLocationManager authorizationStatus];
    
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self startSensor];
        recording = true;
    } else {
        isStartRecording = true;
    }
    pauseing = false;
    [self fireUpdated];
    return recording;
}

- (void) stopRecording {
    if (recording) {
        [self stopSensor];
    }
    recording = false;
    [self fireUpdated];
}

- (NSMutableDictionary *)toJSON {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    NSMutableArray *beacons = [[NSMutableArray alloc] init];
    [json setObject:beacons forKey:@"beacons"];
    
    for(HLPBeaconSample *bs in sampledData) {
        [beacons addObject:[bs toJSON:TRUE]];
    }
    return json;
}

- (long) beaconSampleCount {
    return [sampledData count];
}

- (long) visibleBeaconCount {
    return [visibleBeacons count];
}

- (BOOL)isRecording {
    return recording;
}


# pragma mark - private
- (void) startSensor
{
    [locationManager startRangingBeaconsInRegion:allBeacons];
}

- (void) stopSensor {
    [locationManager stopRangingBeaconsInRegion:allBeacons];
}

- (void) fireUpdated {
    if (self.delegate) {
        [self.delegate updated];
    }
}

- (void) addSample:(HLPBeaconSample*)bs {
    if (recording) {
        if (!pauseing) {
            [sampledData addObject:bs];
        }
    }
}

# pragma mark -- location manager delegate

- (void)locationManager:(CLLocationManager *)_manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if (IRTCF_DEBUG) NSLog(@"didRangeBeacons %ld", (unsigned long)[beacons count]);
    
    visibleBeacons = beacons;
    
    @synchronized(self) {
        HLPBeaconSample *bs = [[HLPBeaconSample alloc ]initWithBeacons:beacons];
        [self addSample:bs];
    }
    
    [self fireUpdated];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (IRTCF_DEBUG) NSLog(@"authorization status is changed %d", status);
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (isStartRecording) {
            [self startRecording];
            isStartRecording = false;
        }
    }
}


@end
