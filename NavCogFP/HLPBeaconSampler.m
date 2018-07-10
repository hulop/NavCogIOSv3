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

@implementation HLPBeaconSampler {
    BOOL _ARKitEnabled;
    ARWorldTrackingConfiguration *_arkitConfig;
    CIDetector *_detector;
    NSTimeInterval _lastScan;
}


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
        locationManager = [[CLLocationManager alloc]init];
        locationManager.delegate = self;
        _qrCodeInterval = 0.5;
        recording = FALSE;
    }
    return self;
}

- (void)setARKitEnabled:(BOOL)ARKitEnabled
{
    if (!_ARKitEnabled && ARKitEnabled) {
        [self prepareARKit];
    }
    if (_ARKitEnabled && !ARKitEnabled) {
        [self destroyARKit];
    }
    _ARKitEnabled = ARKitEnabled;
}

- (BOOL)ARKitEnabled {
    return _ARKitEnabled;
}

- (void)prepareARKit
{
    _view = [[ARSCNView alloc] init];
    
    _view.delegate = self;
    //_view.showsStatistics = YES;
    _view.debugOptions = ARSCNDebugOptionShowWorldOrigin | ARSCNDebugOptionShowFeaturePoints;
    
    _detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:nil];
    
    _arkitConfig = [[ARWorldTrackingConfiguration alloc] init];
    [_view.session runWithConfiguration:_arkitConfig];
}

- (void) renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    SCNVector3 pos = SCNVector3Make(0,0,0);
    pos = [_view.pointOfView convertPosition:pos toNode:nil];
    [self.delegate arPositionUpdated:pos];
    
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    if (now - _lastScan < _qrCodeInterval) {
        return;
    }
    _lastScan = now;
    
    CIImage *image = [[CIImage alloc] initWithCVPixelBuffer: _view.session.currentFrame.capturedImage];
    NSArray<CIFeature*>* features = [_detector featuresInImage:image];
    
    for (CIFeature *feature in features) {
        if ([feature isKindOfClass:CIQRCodeFeature.class]) {
                CIQRCodeFeature *qr = (CIQRCodeFeature*) feature;
            
            [self.delegate qrCodeDetected:qr];
        }
    }
}

- (void)destroyARKit
{
    [_view.session pause];
    _view.delegate = nil;
    _view = nil;
    _detector = nil;
    _arkitConfig = nil;
}


- (void)setSamplingBeaconUUID:(NSString *)uuid_str {
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuid_str];
    
    allBeacons = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:@"dynamicBeaconSamplingTool"];
}

- (void) setSamplingLocation:(HLPPoint3D *)_location {
    lastLocation = _location;
    //_samples = [[HLPBeaconSamples alloc] initWithType:_ARKitEnabled?HLPBeaconSamplesRaw:HLPBeaconSamplesBeacon];
}

- (void)reset {
    @synchronized(self) {
        _samples = [[HLPBeaconSamples alloc] initWithType:_ARKitEnabled?HLPBeaconSamplesRaw:HLPBeaconSamplesBeacon];
    }
    _visibleBeacons = nil;
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

- (NSArray *)toJSON:(NSDictionary*)optionalInfo {
    return [_samples toJSON:optionalInfo];
}

- (long) beaconSampleCount {
    return [_samples count];
}

- (long) visibleBeaconCount {
    return [_visibleBeacons count];
}

- (BOOL)isRecording {
    return recording;
}

- (void)transform2D:(CGAffineTransform)param
{
    [_samples transform2D:param];
}


# pragma mark - private
- (void) startSensor
{
    for(CLBeaconRegion *r in locationManager.rangedRegions) {
        [locationManager stopRangingBeaconsInRegion:r];
    }
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

# pragma mark -- location manager delegate

- (void)locationManager:(CLLocationManager *)_manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if (IRTCF_DEBUG) NSLog(@"didRangeBeacons %ld", (unsigned long)[beacons count]);
    
    _visibleBeacons = beacons;
    
    @synchronized(self) {
        [_samples addBeacons:beacons atPoint:lastLocation];
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
