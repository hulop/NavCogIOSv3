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


#import "HLPLocationManager.h"
#import "HLPLocationManagerParameters.h"
#import "HLPLocation.h"
#import "objc/runtime.h"

#import <CoreMotion/CoreMotion.h>

#import <bleloc/bleloc.h>
#import <bleloc/BasicLocalizer.hpp>
#import <bleloc/LocException.hpp>

#import <iomanip>

using namespace std;
using namespace loc;

typedef struct {
    HLPLocationManager *locationManager;
} LocalUserData;

@implementation HLPLocationManager
{
    @protected
    //public
    BOOL _isSensorEnabled;
    BOOL _isActive;
    BOOL _isBackground;
    BOOL _isAccelerationEnabled;
    HLPLocationStatus _currentStatus;
    HLPLocationManagerParameters *_parameters;
    
    //private
    HLPLocationManagerRepLocation _repLocation;
    double _meanRssiBias;
    double _maxRssiBias;
    double _minRssiBias;
    double _headingConfidenceForOrientationInit;
    
    //
    LocalUserData userData;
    
    shared_ptr<BasicLocalizer> localizer;
    shared_ptr<BasicLocalizerParameters> params;
    
    CLLocationManager *beaconManager;
    CMMotionManager *motionManager;
    CMAltimeter *altimeter;
    
    NSOperationQueue *processQueue;
    NSOperationQueue *loggingQueue;
    NSOperationQueue *locationQueue;
    
    // need to manage multiple maps
    NSString *modelPath;
    NSString *workingDir;
    
    BOOL isMapLoading;
    BOOL isMapLoaded;
    NSDictionary *anchor;
    
    int putBeaconsCount;
    
    BOOL authorized;
    BOOL valid;
    BOOL validHeading;

    HLPLocation *currentLocation;
    
    HLPLocation *replayResetRequestLocation;
    
    BOOL flagPutBeacon;
    double currentFloor;
    double currentOrientation;
    double currentOrientationAccuracy;
    CLHeading *currentMagneticHeading;
    
    double offsetYaw;
    
    double smoothedLocationAcc;
    double smootingLocationRate;
    
    BOOL didAlertAboutAltimeter;
}

static HLPLocationManager *instance;

+ (instancetype) sharedManager
{
    if (!instance) {
        instance = [[HLPLocationManager alloc] initPrivate];
    }
    return instance;
}

- (instancetype) initPrivate
{
    self = [super init];
    
    localizer = shared_ptr<BasicLocalizer>(new BasicLocalizer());
    
    userData.locationManager = self;
    localizer->updateHandler(functionCalledAfterUpdate, (void*) &userData);
    localizer->logHandler(functionCalledToLog, (void*) &userData);
    
    params = localizer;
    params->orientationMeterType = TRANSFORMED_AVERAGE; // default RAW_AVERAGE
    
    params->stdRssiBias = 2.0;          // default 2.0
    params->diffusionRssiBias = 0.2;    // default 0.2
    
    params->angularVelocityLimit = 45.0;// default 30
    
    params->maxIncidenceAngle = 45;     // default 45
    
    params->velocityRateFloor = 1.0;    // default 1.0
    params->velocityRateElevator = 1.0; // default 0.5
    params->velocityRateStair = 0.5;    // default 0.5
    
    params->burnInRadius2D = 5;         // default 10
    params->burnInInterval = 1;         // default 1
    params->burnInInitType = INIT_WITH_SAMPLE_LOCATIONS; // default INIT_WITH_SAMPLE_LOCATIONS
    
    // deactivate elevator transition in system model
    params->prwBuildingProperty->probabilityUpElevator(0.0);
    params->prwBuildingProperty->probabilityDownElevator(0.0);
    params->prwBuildingProperty->probabilityStayElevator(1.0);
    
    _parameters = [[HLPLocationManagerParameters alloc] initWithTarget:self];
    
    _isActive = NO;
    isMapLoaded = NO;
    _isAccelerationEnabled = YES;
    _isSensorEnabled = YES;
    valid = NO;
    validHeading = NO;
    
    _currentStatus = HLPLocationStatusUnknown;
    currentFloor = NAN;
    offsetYaw = M_PI_2;
    currentOrientationAccuracy = 999;
    
    locationQueue = [[NSOperationQueue alloc] init];
    locationQueue.maxConcurrentOperationCount = 1;
    locationQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    processQueue = [[NSOperationQueue alloc] init];
    processQueue.maxConcurrentOperationCount = 1;
    processQueue.qualityOfService = NSQualityOfServiceUserInteractive;
    
    loggingQueue = [[NSOperationQueue alloc] init];
    loggingQueue.maxConcurrentOperationCount = 1;
    loggingQueue.qualityOfService = NSQualityOfServiceBackground;
    
    smoothedLocationAcc = -1;
    smootingLocationRate = 0.1;
    
    return self;
}

- (void) dealloc
{
    [self stop];
}

#pragma mark - public properties

- (void)setIsBackground:(BOOL)value
{
    _isBackground = value;
    
    beaconManager.allowsBackgroundLocationUpdates = _isBackground;
    if (beaconManager.allowsBackgroundLocationUpdates) {
        [beaconManager startUpdatingLocation];
    } else {
        [beaconManager stopUpdatingLocation];
    }
}

- (BOOL)isBackground
{
    return _isBackground;
}

- (void)setIsAccelerationEnabled:(BOOL) value
{
    _isAccelerationEnabled = value;
}

- (BOOL)isAccelerationEnabled
{
    return _isAccelerationEnabled;
}

- (void)setParameters:(NSDictionary *)parameters
{
    [_parameters updateWithDictionary:parameters];
}

- (NSDictionary*)parameters
{
    return [_parameters toDictionary];
}

- (void) setCurrentStatus:(HLPLocationStatus) status // readonly
{
    if (_currentStatus != status) {
        [_delegate locationManager:self didLocationStatusUpdate:status];
    }
    _currentStatus = status;
}

- (HLPLocationStatus) currentStatus {
    return _currentStatus;
}

#pragma mark - private properties

- (shared_ptr<BasicLocalizerParameters>) params
{
    return params;
}

- (shared_ptr<BasicLocalizer>) localizer
{
    return localizer;
}

- (NSDictionary*) anchor
{
    return anchor;
}

- (void)setCurrentFloor:(double) currentFloor_
{
    currentFloor = currentFloor_;
}
- (double)currentFloor
{
    return currentFloor;
}

- (double)currentOrientationAccuracy
{
    return currentOrientationAccuracy;
}

- (void) setRepLocation:(HLPLocationManagerRepLocation) repLocation
{
    _repLocation = repLocation;
}
- (HLPLocationManagerRepLocation) repLocation
{
    return _repLocation;
}

- (void) setMeanRssiBias:(double)meanRssiBias
{
    _meanRssiBias = meanRssiBias;
    localizer->meanRssiBias(meanRssiBias);
}
- (double) meanRssiBias
{
    return _meanRssiBias;
}

- (void) setMinRssiBias:(double)minRssiBias
{
    _minRssiBias = minRssiBias;
    localizer->minRssiBias(minRssiBias);
}
- (double) minRssiBias
{
    return _minRssiBias;
}

- (void) setMaxRssiBias:(double)maxRssiBias
{
    _maxRssiBias = maxRssiBias;
    localizer->maxRssiBias(maxRssiBias);
}
- (double) maxRssiBias
{
    return _maxRssiBias;
}

- (void) setHeadingConfidenceForOrientationInit:(double)headingConfidenceForOrientationInit
{
    _headingConfidenceForOrientationInit = headingConfidenceForOrientationInit;
    localizer->headingConfidenceForOrientationInit(headingConfidenceForOrientationInit);
}
- (double) headingConfidenceForOrientationInit
{
    return _headingConfidenceForOrientationInit;
}


#pragma mark - public methods

- (void)setModelPath:(NSString *)path
{
    modelPath = path;
    workingDir = NSTemporaryDirectory();
}

- (void) start
{
    if (!beaconManager) {
        beaconManager = [[CLLocationManager alloc] init];
        beaconManager.headingFilter = kCLHeadingFilterNone; // always update heading
        beaconManager.delegate = self;
    }
    if (!motionManager) {
        motionManager = [[CMMotionManager alloc] init];
    }
    if( [CMAltimeter isRelativeAltitudeAvailable]){
        if (!altimeter) {
            altimeter = [[CMAltimeter alloc] init];
        }
    }
    
    if (!authorized) {
        [beaconManager requestWhenInUseAuthorization];
    } else {
        [self _didChangeAuthorizationStatus:authorized];
    }
}

- (void) restart
{
    [processQueue addOperationWithBlock:^{
        [self stop];
        [NSThread sleepForTimeInterval:1.0];
        NSLog(@"Restart,%ld", (long)([[NSDate date] timeIntervalSince1970]*1000));
        [self start];
    }];
}

- (void) makeStatusUnknown
{
    [processQueue addOperationWithBlock:^{
        if (localizer) {
            localizer->overwriteLocationStatus(Status::UNKNOWN);
        }
    }];
}

- (void)stop
{
    if (!_isActive) {
        return;
    }
    _isActive = NO;
    isMapLoaded = NO;
    isMapLoading = NO;
    putBeaconsCount = 0;
    
    [self stopAllBeaconRangingAndMonitoring];
    [beaconManager stopUpdatingLocation];
    
    if(altimeter){ [altimeter stopRelativeAltitudeUpdates]; }
    [motionManager stopDeviceMotionUpdates];
    [motionManager stopAccelerometerUpdates];
    [beaconManager stopUpdatingHeading];
    
    //localizer = nil;
}

- (void) resetLocation:(HLPLocation*)loc
{
    double heading = loc.orientation;
    if (isnan(heading)) { // only location
        heading = currentOrientation;
    } else { // set orientation
        currentOrientationAccuracy = 0;
    }
    if (isnan(heading)) {
        heading = 0;
    }
    
    [loc updateOrientation:heading withAccuracy:currentOrientationAccuracy];
    [_delegate locationManager:self didLocationUpdate:loc];
    //
    //    NSDictionary *data = @{
    //                           @"lat": @(loc.lat),
    //                           @"lng": @(loc.lng),
    //                           @"floor": @(loc.floor),
    //                           @"orientation": @(isnan(heading)?0:heading),
    //                           @"orientationAccuracy": @(currentOrientationAccuracy)
    //                           };
    //    [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:self userInfo:data];
    if (!_isActive || !isMapLoaded) {
        return;
    }
    
    [processQueue addOperationWithBlock:^{
        double h = (heading - [anchor[@"rotate"] doubleValue])/180*M_PI;
        double x = sin(h);
        double y = cos(h);
        h = atan2(y,x);
        
        loc::Location location;
        loc::GlobalState<Location> global(location);
        global.lat(loc.lat);
        global.lng(loc.lng);
        location = localizer->latLngConverter()->globalToLocal(global);
        
        loc::Pose newPose(location);
        if(isnan(loc.floor)){
            newPose.floor(currentFloor);
        }else{
            newPose.floor(round(loc.floor));
        }
        newPose.orientation(h);
        
        long timestamp = [[NSDate date] timeIntervalSince1970]*1000;
        
        NSLog(@"Reset,%f,%f,%f,%f,%ld",loc.lat,loc.lng,newPose.floor(),h,timestamp);
        //localizer->resetStatus(newPose);
        
        loc::Pose stdevPose;
        
        double std_dev = loc.accuracy;
        stdevPose.x(std_dev).y(std_dev).orientation(currentOrientationAccuracy/180*M_PI);
        try {
            localizer->resetStatus(newPose, stdevPose);
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
            //error?
            //[[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:self userInfo:data];
        }
    }];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusDenied:
            if ([CLLocationManager locationServicesEnabled]) {
                [self.delegate locationManager:self didLocationAllowAlert:NO];
            } else {
                // OS automatically shows alert
            }
            [self _didChangeAuthorizationStatus:NO];
            break;
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusNotDetermined:
            [self _didChangeAuthorizationStatus:NO];
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            [self _didChangeAuthorizationStatus:YES];
            break;
    }
}

- (void)_didChangeAuthorizationStatus:(BOOL)authorized_
{
    authorized = authorized_;
    
    if (_isActive == YES) {
        if (valid == NO) {
            [self stop];
        } else {
            return;
        }
    }
    
    if (authorized) {
        _isActive = YES;
        [self startSensors];
        [self _loadModels];
        valid = YES;
    } else {
        [self stop];
    }
}


- (void)_loadModels {
    if (isMapLoading) {
        return;
    }
    if (!modelPath) {
        return;
    }
    isMapLoading = YES;
    
    [[[NSOperationQueue alloc] init] addOperationWithBlock:^{
        NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:modelPath];
        [stream open];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:nil];
        anchor = json[@"anchor"];
    }];

    [processQueue addOperationWithBlock:^{
        double s = [[NSDate date] timeIntervalSince1970];
        
        try {
            localizer->setModel([modelPath cStringUsingEncoding:NSUTF8StringEncoding], [workingDir cStringUsingEncoding:NSUTF8StringEncoding]);
            double e = [[NSDate date] timeIntervalSince1970];
            std::cout << (e-s)*1000 << " ms for setModel" << std::endl;
        } catch(LocException& ex) {
            std::cout << ex.what() << std::endl;
            std::cout << boost::diagnostic_information(ex) << std::endl;
            NSLog(@"Error in setModelAtPath");
            return;
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
            NSLog(@"Error in setModelAtPath");
            return;
        }
        
        [self makeStatusUnknown];
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"csv"];
        NSError *error = nil;
        [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            return;
        }
        
        auto& beacons = localizer->dataStore->getBLEBeacons();
        
        NSMutableDictionary *dict = [@{} mutableCopy];
        for(auto it = beacons.begin(); it != beacons.end(); it++) {
            NSString *uuidStr = [NSString stringWithUTF8String: it->uuid().c_str()];
            if (!dict[uuidStr]) {
                NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
                dict[uuidStr] = uuid;
                
                CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:uuidStr];
                
                [beaconManager startRangingBeaconsInRegion:region];
            }
        }
        
        isMapLoaded = YES;
    }];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    currentMagneticHeading = newHeading;
    if (newHeading.headingAccuracy >= 0) {
        if (!localizer->tracksOrientation()) {
            [processQueue addOperationWithBlock:^{
                if (!_isActive) {
                    return;
                }
                [self directionUpdated:newHeading.magneticHeading withAccuracy:newHeading.headingAccuracy];
            }];
        }
    }
    
    loc::Heading (^convertCLHeading)(CLHeading*) = ^(CLHeading* clheading) {
        long timestamp = static_cast<long>([clheading.timestamp timeIntervalSince1970]*1000);
        loc::Heading locheading(timestamp, clheading.magneticHeading, clheading.trueHeading, clheading.headingAccuracy);
        return locheading;
    };
    
    [processQueue addOperationWithBlock:^{
        if (!_isActive) {
            return;
        }
        loc::Heading heading = convertCLHeading(newHeading);
        // putHeading
        try {
            localizer->putHeading(heading);
        }catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
        }
    }];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    //NSLog(@"%@", locations);
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region
{
    [_delegate locationManager:self didRangeBeacons:beacons inRegion:region];
    if (!_isActive || [beacons count] == 0 || !_isSensorEnabled) {
        return;
    }
    Beacons cbeacons;
    for(int i = 0; i < [beacons count]; i++) {
        CLBeacon *b = [beacons objectAtIndex: i];
        
        long rssi = -100;
        if (b.rssi < 0) {
            rssi = b.rssi;
        }
        Beacon cb(b.major.intValue, b.minor.intValue, rssi);
        cbeacons.push_back(cb);
    }
    cbeacons.timestamp([[NSDate date] timeIntervalSince1970]*1000);
    
    [processQueue addOperationWithBlock:^{
        @try {
            [self _processBeacons:cbeacons];
            //[self sendBeacons:beacons];
        }
        @catch (NSException *e) {
            NSLog(@"%@", [e debugDescription]);
        }
    }];
}

- (void) _processBeacons:(Beacons) cbeacons
{
    if (!_isActive) {
        return;
    }
    if (cbeacons.size() > 0) {
        if (altimeter == nil && !didAlertAboutAltimeter) {
            didAlertAboutAltimeter = YES;
            [self.delegate locationManager:self hasAltimeter:NO];
        }
        double s = [[NSDate date] timeIntervalSince1970];
        try {
            flagPutBeacon = YES;
            localizer->putBeacons(cbeacons);
            putBeaconsCount++;
            flagPutBeacon = NO;
        } catch(const std::exception& ex) {
            self.currentStatus = HLPLocationStatusLost;
            std::cout << ex.what() << std::endl;
        }
        double e = [[NSDate date] timeIntervalSince1970];
        std::cout << (e-s)*1000 << " ms for putBeacons " << cbeacons.size() << std::endl;
    }
}



#pragma mark - private methods sensor

- (void) stopAllBeaconRangingAndMonitoring
{
    for(CLRegion *r in [beaconManager rangedRegions]) {
        if ([r isKindOfClass:CLBeaconRegion.class]) {
            [beaconManager stopRangingBeaconsInRegion:(CLBeaconRegion*)r];
        }
        [beaconManager stopMonitoringForRegion:r];
    }
}

- (void) startSensors
{
    [beaconManager startUpdatingHeading];
    
    // remove all beacon region ranging and monitoring
    [self stopAllBeaconRangingAndMonitoring];
    
    NSTimeInterval uptime = [[NSDate date] timeIntervalSince1970] - [[NSProcessInfo processInfo] systemUptime];
    
    [motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical
                                                       toQueue:processQueue withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
        if (!_isActive || !_isSensorEnabled) {
            return;
        }
        try {
            Attitude attitude((uptime+motion.timestamp)*1000,
                              motion.attitude.pitch, motion.attitude.roll, motion.attitude.yaw + offsetYaw);
            
            localizer->putAttitude(attitude);
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
        }
    }];
    [motionManager startAccelerometerUpdatesToQueue: processQueue withHandler:^(CMAccelerometerData * _Nullable acc, NSError * _Nullable error) {
        if (!_isActive || !_isAccelerationEnabled || !_isSensorEnabled) {
            return;
        }
        Acceleration acceleration((uptime+acc.timestamp)*1000,
                                  acc.acceleration.x, acc.acceleration.y, acc.acceleration.z);
        try {
            localizer->putAcceleration(acceleration);
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
        }
        
    }];
    
    if(altimeter){
        [altimeter startRelativeAltitudeUpdatesToQueue: processQueue withHandler:^(CMAltitudeData *altitudeData, NSError *error) {
            if (!_isActive || !_isSensorEnabled) {
                return;
            }
            NSNumber* relAlt=  altitudeData.relativeAltitude;
            NSNumber* pressure = altitudeData.pressure;
            long ts = ((uptime+altitudeData.timestamp))*1000;
            
            Altimeter alt(ts, [relAlt doubleValue], [pressure doubleValue]);
            // putAltimeter
            try {
                localizer->putAltimeter(alt);
            }catch(const std::exception& ex) {
                std::cout << ex.what() << std::endl;
            }
        }];
    }
    
    putBeaconsCount = 0;
}


#pragma mark - private methods location

void functionCalledAfterUpdate(void *inUserData, Status *status)
{
    LocalUserData *userData = (LocalUserData*) inUserData;
    if (!(userData->locationManager.isActive)) {
        return;
    }
    std::shared_ptr<Status> statusCopy(new Status(*status));
    [userData->locationManager updateStatus: statusCopy.get()];
}

void functionCalledToLog(void *inUserData, string text)
{
    LocalUserData *userData = (LocalUserData*) inUserData;
    if (!(userData->locationManager.isActive)) {
        return;
    }
    [userData->locationManager _logText:text];
}

- (void) _logText:(string) text {
    [loggingQueue addOperationWithBlock:^{
        [_delegate locationManager:self didLogText:[NSString stringWithCString:text.c_str() encoding:NSUTF8StringEncoding]];
    }];
}

- (void)directionUpdated:(double)direction withAccuracy:(double)acc
{
    @try {
        [self.delegate locationManager:self didUpdateOrientation:direction withAccuracy:acc];
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}

- (void) updateStatus:(Status*) status
{
    switch (status->locationStatus()){
        case Status::UNKNOWN:
            self.currentStatus = HLPLocationStatusUnknown;
            break;
        case Status::LOCATING:
            self.currentStatus = HLPLocationStatusLocating;
            break;
        case Status::STABLE:
            self.currentStatus = HLPLocationStatusStable;
            break;
        case Status::UNSTABLE:
            // self.currentStatus is not updated
            break;
        case Status::NIL:
            // do nothing for nil status
            break;
        default:
            break;
    }

    // TODO flagPutBeacon is not useful
    [self locationUpdated:status withResampledFlag:flagPutBeacon];
}

- (Pose) computeRepresentativePose:(const Pose&)meanPose withStates:(const std::vector<State>&) states
{
    Pose refPose(meanPose);
    
    int idx;
    Location loc;
    switch(_repLocation) {
        case HLPLocationManagerRepLocationMean:
            // pass
            break;
        case HLPLocationManagerRepLocationDensest:
            idx = Location::findKDEDensestLocationIndex<State>(states);
            loc = states.at(idx);
            refPose.copyLocation(loc);
            break;
        case HLPLocationManagerRepLocationClosestMean:
            idx = Location::findClosestLocationIndex(refPose, states);
            loc = states.at(idx);
            refPose.copyLocation(loc);
            break;
    }
    return refPose;
}

int dcount = 0;
- (void)locationUpdated:(loc::Status*)status withResampledFlag:(BOOL)flag
{
     @try {
        if (!anchor) {
            NSLog(@"Anchor is not specified");
            return;
        }
        
        bool wasFloorUpdated = status->wasFloorUpdated();
        Pose refPose = *status->meanPose();
        std::vector<State> states = *status->states();
         refPose = [self computeRepresentativePose:refPose withStates:states];
        
        auto global = localizer->latLngConverter()->localToGlobal(refPose);
        
        dcount++;
        
        double globalOrientation = refPose.orientation() - [anchor[@"rotate"] doubleValue] / 180 * M_PI;
        double x = cos(globalOrientation);
        double y = sin(globalOrientation);
        double globalHeading = atan2(x, y) / M_PI * 180;
        
        int orientationAccuracy = 999; // large value
        if (localizer->tracksOrientation()) {
            auto normParams = loc::Pose::computeWrappedNormalParameter(states);
            double stdOri = normParams.stdev(); // radian
            orientationAccuracy = static_cast<int>(stdOri/M_PI*180.0);
            //if (orientationAccuracy < ORIENTATION_ACCURACY_THRESHOLD) { // Removed thresholding
            currentOrientation = globalHeading;
            //}
        }
        currentOrientationAccuracy = orientationAccuracy;
        
        double acc = [[NSUserDefaults standardUserDefaults] boolForKey:@"accuracy_for_demo"]?0.5:5.0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"use_blelocpp_acc"]) {
            auto std = loc::Location::standardDeviation(states);
            double sigma = [[NSUserDefaults standardUserDefaults] doubleForKey:@"blelocpp_accuracy_sigma"];
            acc = MAX(acc, (std.x()+std.y())/2.0*sigma);
        }
        
        // smooth acc for display
        if(smoothedLocationAcc<=0){
            smoothedLocationAcc = acc;
        }
        smoothedLocationAcc = (1.0-smootingLocationRate)*smoothedLocationAcc + smootingLocationRate*acc;
        acc = smoothedLocationAcc;
        
        //if (flag) {
        if(wasFloorUpdated || isnan(currentFloor)){
            currentFloor = std::round(refPose.floor());
            std::cout << "refPose=" << refPose << std::endl;
        }
        
        double lat = global.lat();
        double lng = global.lng();
        
        bool showsDebugPose = false;
        if(!showsDebugPose){
            if(status->locationStatus()==Status::UNKNOWN){
                lat = NAN;
                lng = NAN;
                currentOrientation = NAN;
            }
            double oriAccThreshold = [[NSUserDefaults standardUserDefaults] doubleForKey:@"oriAccThreshold"];
            if( oriAccThreshold < orientationAccuracy ){
                currentOrientation = NAN;
            }
        }
        
        HLPLocation *loc = [[HLPLocation alloc] initWithLat:lat
                                                        Lng:lng
                                                   Accuracy:acc
                                                      Floor:currentFloor
                                                      Speed:refPose.velocity()
                                                Orientation:currentOrientation
                                        OrientationAccuracy:orientationAccuracy];
        /*
         NSMutableDictionary *data =
         [@{
         @"x": @(refPose.x()),
         @"y": @(refPose.y()),
         @"z": @(refPose.z()),
         @"floor":@(currentFloor),
         @"lat": @(lat),
         @"lng": @(lng),
         @"speed":@(refPose.velocity()),
         @"orientation":@(currentOrientation),
         @"accuracy":@(acc),
         @"orientationAccuracy":@(orientationAccuracy), // TODO
         @"anchor":@{
         @"lat":anchor[@"latitude"],
         @"lng":anchor[@"longitude"]
         },
         @"rotate":anchor[@"rotate"]
         } mutableCopy];
         */
        
        bool showsState = [[NSUserDefaults standardUserDefaults] boolForKey:@"show_states"] ;
        
        if (showsState && ( wasFloorUpdated ||  dcount % 10 == 0)) {
            NSMutableDictionary *data = [@{} mutableCopy];
            NSMutableArray *debug = [@[] mutableCopy];
            for(loc::State &s: states) {
                [debug addObject:@(s.Location::x())];
                [debug addObject:@(s.Location::y())];
            }
            data[@"debug_info"] = debug;
            NSMutableArray *debug_latlng = [@[] mutableCopy];
            
            for(loc::State &s: states) {
                auto g = localizer->latLngConverter()->localToGlobal(s);
                [debug_latlng addObject:@(g.lat())];
                [debug_latlng addObject:@(g.lng())];
            }
            data[@"debug_latlng"] = debug_latlng;
            [_delegate locationManager:self didDebugInfoUpdate:data];
        }
        
        //currentLocation = data;
        currentLocation = loc;
        
        if (!validHeading && !localizer->tracksOrientation() &&
            [[NSUserDefaults standardUserDefaults] boolForKey:@"use_compass"]) {
            double delayInSeconds = 0.1;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                
                double lat = currentLocation.lat; //[currentLocation[@"lat"] doubleValue];
                double lng = currentLocation.lng; //[currentLocation[@"lng"] doubleValue];
                double floor = currentFloor; //[currentLocation[@"floor"] doubleValue];
                double ori = currentMagneticHeading.trueHeading;
                double oriacc = currentMagneticHeading.headingAccuracy;
                [processQueue addOperationWithBlock:^{
                    double heading = (ori - [anchor[@"rotate"] doubleValue])/180*M_PI;
                    double x = sin(heading);
                    double y = cos(heading);
                    heading = atan2(y,x);
                    
                    loc::Location location;
                    loc::GlobalState<Location> global(location);
                    global.lat(lat);
                    global.lng(lng);
                    
                    location = localizer->latLngConverter()->globalToLocal(global);
                    
                    loc::Pose newPose(location);
                    newPose.floor(round(floor));
                    newPose.orientation(heading);
                    
                    long timestamp = [[NSDate date] timeIntervalSince1970] * 1000.0;
                    NSLog(@"ResetHeading,%f,%f,%f,%f,%f,%ld",lat,lng,floor,ori,oriacc,timestamp);
                    
                    loc::Pose stdevPose;
                    stdevPose.x(1).y(1).orientation(oriacc/180*M_PI);
                    //localizer->resetStatus(newPose, stdevPose, 0.3);
                    
                    double x1 = sin((ori-currentOrientation)/180*M_PI);
                    double y1 = cos((ori-currentOrientation)/180*M_PI);
                    offsetYaw = atan2(y1,x1);
                }];
            });
            validHeading = YES;
        } else {
            validHeading = YES;
            [_delegate locationManager:self didLocationUpdate:loc];
            //[[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:self userInfo:data];
        }
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}

@end

#pragma mark - properties

@implementation HLPLocationManagerLocation {
    loc::Location* _property;
}
- (instancetype) initWithTarget:(loc::Location*)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setX:(double)x { _property->x(x); }
- (double) x { return _property->x(); }

- (void) setY:(double)y { _property->y(y); }
- (double) y { return _property->y(); }

- (void) setZ:(double)z { _property->z(z); }
- (double) z { return _property->z(); }

- (void) setFloor:(double)floor { _property->floor(floor); }
- (double) floor { return _property->floor(); }
@end

@implementation HLPLocationManagerPoseProperty {
    loc::PoseProperty::Ptr _property;
}
- (instancetype) initWithTarget:(loc::PoseProperty::Ptr)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setMeanVelocity:(double)meanVelocity { _property->meanVelocity(meanVelocity); }
- (double) meanVelocity { return _property->meanVelocity(); }

- (void) setStdVelocity:(double)stdVelocity { _property->stdVelocity(stdVelocity); }
- (double) stdVelocity { return _property->stdVelocity(); }

- (void) setDiffusionVelocity:(double)diffusionVelocity { _property->diffusionVelocity(diffusionVelocity); }
- (double) diffusionVelocity { return _property->diffusionVelocity(); }

- (void) setMinVelocity:(double)minVelocity { _property->minVelocity(minVelocity); }
- (double) minVelocity { return _property->minVelocity(); }

- (void) setMaxVelocity:(double)maxVelocity { _property->maxVelocity(maxVelocity); }
- (double) maxVelocity { return _property->maxVelocity(); }

- (void) setStdOrientation:(double)stdOrientation { _property->stdOrientation(stdOrientation); }
- (double) stdOrientation { return _property->stdOrientation(); }
@end

@implementation HLPLocationManagerStateProperty {
    loc::StateProperty::Ptr _property;
}
- (instancetype) initWithTarget:(loc::StateProperty::Ptr)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setMeanRssiBias:(double)meanRssiBias { _property->meanRssiBias(meanRssiBias); }
- (double) meanRssiBias { return _property->meanRssiBias(); }

- (void) setStdRssiBias:(double)stdRssiBias { _property->stdRssiBias(stdRssiBias); }
- (double) stdRssiBias { return _property->stdRssiBias(); }

- (void) setDiffusionRssiBias:(double)diffusionRssiBias { _property->diffusionRssiBias(diffusionRssiBias); }
- (double) diffusionRssiBias { return _property->diffusionRssiBias(); }

- (void) setDiffusionOrientationBias:(double)diffusionOrientationBias { _property->diffusionOrientationBias(diffusionOrientationBias); }
- (double) diffusionOrientationBias { return _property->diffusionOrientationBias(); }

- (void) setMinRssiBias:(double)minRssiBias { _property->minRssiBias(minRssiBias); }
- (double) minRssiBias { return _property->minRssiBias(); }

- (void) setMaxRssiBias:(double)maxRssiBias { _property->maxRssiBias(maxRssiBias); }
- (double) maxRssiBias { return _property->maxRssiBias(); }
@end

@implementation HLPLocationManagerFloorTransitionParameters {
    loc::StreamParticleFilter::FloorTransitionParameters::Ptr _property;
}
- (instancetype) initWithTarget:(loc::StreamParticleFilter::FloorTransitionParameters::Ptr)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setHeightChangedCriterion:(double)heightChangedCriterion { _property->heightChangedCriterion(heightChangedCriterion); }
- (double) heightChangedCriterion { return _property->heightChangedCriterion(); }

- (void) setWeightTransitionArea:(double)weightTransitionArea { _property->weightTransitionArea(weightTransitionArea); }
- (double) weightTransitionArea { return _property->weightTransitionArea(); }

- (void) setMixtureProbaTransArea:(double)mixtureProbaTransArea { _property->mixtureProbaTransArea(mixtureProbaTransArea); }
- (double) mixtureProbaTransArea { return _property->mixtureProbaTransArea(); }

- (void) setRejectDistance:(double)rejectDistance { _property->rejectDistance(rejectDistance); }
- (double) rejectDistance { return _property->rejectDistance(); }
@end

@implementation HLPLocationManagerLocationStatusMonitorParameters {
    loc::LocationStatusMonitorParameters::Ptr _property;
}
- (instancetype) initWithTarget:(loc::LocationStatusMonitorParameters::Ptr)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setMinimumWeightStable:(double)minimumWeightStable { _property->minimumWeightStable(minimumWeightStable); }
- (double) minimumWeightStable { return _property->minimumWeightStable(); }

- (void) setStdev2DEnterStable:(double)stdev2DEnterStable { _property->stdev2DEnterStable(stdev2DEnterStable); }
- (double) stdev2DEnterStable { return _property->stdev2DEnterStable(); }

- (void) setStdev2DExitStable:(double)stdev2DExitStable { _property->stdev2DExitStable(stdev2DExitStable); }
- (double) stdev2DExitStable { return _property->stdev2DExitStable(); }

//- (void) setStdevFloorEnterStable:(double)stdevFloorEnterStable { _property->stdevFloorEnterStable(stdevFloorEnterStable); }
//- (double) stdevFloorEnterStable { return _property->stdevFloorEnterStable(); }

- (void) setStdev2DEnterLocating:(double)stdev2DEnterLocating { _property->stdev2DEnterLocating(stdev2DEnterLocating); }
- (double) stdev2DEnterLocating { return _property->stdev2DEnterLocating(); }

- (void) setStdev2DExitLocating:(double)stdev2DExitLocating { _property->stdev2DExitLocating(stdev2DExitLocating); }
- (double) stdev2DExitLocating { return _property->stdev2DExitLocating(); }

- (void) setMonitorIntervalMS:(long)monitorIntervalMS { _property->monitorIntervalMS(monitorIntervalMS); }
- (long) monitorIntervalMS { return _property->monitorIntervalMS(); }
@end


@implementation HLPLocationManagerSystemModelInBuildingProperty {
    loc::SystemModelInBuildingProperty::Ptr _property;
}
- (instancetype) initWithTarget:(loc::SystemModelInBuildingProperty::Ptr)property
{
    self = [super init];
    _property = property;
    return self;
}
- (void) setProbabilityUpStair:(double)probabilityUpStair { _property->probabilityUpStair(probabilityUpStair); }
- (double) probabilityUpStair { return _property->probabilityUpStair(); }

- (void) setProbabilityDownStair:(double)probabilityDownStair { _property->probabilityDownStair(probabilityDownStair); }
- (double) probabilityDownStair { return _property->probabilityDownStair(); }

- (void) setProbabilityStayStair:(double)probabilityStayStair { _property->probabilityStayStair(probabilityStayStair); }
- (double) probabilityStayStair { return _property->probabilityStayStair(); }

- (void) setProbabilityUpElevator:(double)probabilityUpElevator { _property->probabilityUpElevator(probabilityUpElevator); }
- (double) probabilityUpElevator { return _property->probabilityUpElevator(); }

- (void) setProbabilityDownElevator:(double)probabilityDownElevator { _property->probabilityDownElevator(probabilityDownElevator); }
- (double) probabilityDownElevator { return _property->probabilityDownElevator(); }

- (void) setProbabilityStayElevator:(double)probabilityStayElevator { _property->probabilityStayElevator(probabilityStayElevator); }
- (double) probabilityStayElevator { return _property->probabilityStayElevator(); }

- (void) setProbabilityUpEscalator:(double)probabilityUpEscalator { _property->probabilityUpEscalator(probabilityUpEscalator); }
- (double) probabilityUpEscalator { return _property->probabilityUpEscalator(); }

- (void) setProbabilityDownEscalator:(double)probabilityDownEscalator { _property->probabilityDownEscalator(probabilityDownEscalator); }
- (double) probabilityDownEscalator { return _property->probabilityDownEscalator(); }

- (void) setProbabilityStayEscalator:(double)probabilityStayEscalator { _property->probabilityStayEscalator(probabilityStayEscalator); }
- (double) probabilityStayEscalator { return _property->probabilityStayEscalator(); }

- (void) setProbabilityFloorJump:(double)probabilityFloorJump { _property->probabilityFloorJump(probabilityFloorJump); }
- (double) probabilityFloorJump { return _property->probabilityFloorJump(); }

- (void) setWallCrossingAliveRate:(double)wallCrossingAliveRate { _property->wallCrossingAliveRate(wallCrossingAliveRate); }
- (double) wallCrossingAliveRate { return _property->wallCrossingAliveRate(); }

- (void) setMaxIncidenceAngle:(double)maxIncidenceAngle { _property->maxIncidenceAngle(maxIncidenceAngle); }
- (double) maxIncidenceAngle { return _property->maxIncidenceAngle(); }

- (void) setVelocityRateFloor:(double)velocityRateFloor { _property->velocityRateFloor(velocityRateFloor); }
- (double) velocityRateFloor { return _property->velocityRateFloor(); }

- (void) setVelocityRateStair:(double)velocityRateStair { _property->velocityRateStair(velocityRateStair); }
- (double) velocityRateStair { return _property->velocityRateStair(); }

- (void) setVelocityRateElevator:(double)velocityRateElevator { _property->velocityRateElevator(velocityRateElevator); }
- (double) velocityRateElevator { return _property->velocityRateElevator(); }

- (void) setVelocityRateEscalator:(double)velocityRateEscalator { _property->velocityRateEscalator(velocityRateEscalator); }
- (double) velocityRateEscalator { return _property->velocityRateEscalator(); }

- (void) setRelativeVelocityEscalator:(double)relativeVelocityEscalator { _property->relativeVelocityEscalator(relativeVelocityEscalator); }
- (double) relativeVelocityEscalator { return _property->relativeVelocityEscalator(); }

- (void) setWeightDecayRate:(double)weightDecayRate { _property->weightDecayRate(weightDecayRate); }
- (double) weightDecayRate { return _property->weightDecayRate(); }

//- (void) setMaxTrial:(int)maxTrial { _property->maxTrial(maxTrial); }
- (int) maxTrial { return _property->maxTrial(); }
@end

@implementation HLPLocationManagerParameters

- (instancetype) initWithTarget:(HLPLocationManager*)target
{
    self = [super init];
    _target = target;
    _locLB = [[HLPLocationManagerLocation alloc] initWithTarget:&target.params->locLB];
    _poseProperty = [[HLPLocationManagerPoseProperty alloc] initWithTarget:target.params->poseProperty];
    _stateProperty = [[HLPLocationManagerStateProperty alloc] initWithTarget:target.params->stateProperty];
    _pfFloorTransParams = [[HLPLocationManagerFloorTransitionParameters alloc] initWithTarget:target.params->pfFloorTransParams];
    _locationStatusMonitorParameters = [[HLPLocationManagerLocationStatusMonitorParameters alloc] initWithTarget:target.params->locationStatusMonitorParameters];
    _prwBuildingProperty = [[HLPLocationManagerSystemModelInBuildingProperty alloc] initWithTarget:target.params->prwBuildingProperty];
    return self;
}

- (void) updateWithDictionary:(NSDictionary*) dict
{
    [dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSObject *obj, BOOL * _Nonnull stop) {
        NSArray<NSString*> *items = [key componentsSeparatedByString:@"."];
        
        NSObject *temp = self;
        for(int i = 0; i < items.count-1; i++) {
            temp = [temp valueForKey:items[i]];
        }
        if (temp == nil) {
            NSLog(@"[%@] is not valid parameter", key);
            return;
        }
        @try {
            key = items[items.count-1];
            [temp setValue:obj forKey:key];
            NSLog(@"%@[%@] = %@", temp, key, obj);
        }
        @catch (NSException *e){
            NSLog(@"%@[%@] is not valid parameter", temp, key);

        }
    }];
}


- (NSDictionary*) toDictionary
{
    return nil;
}

- (void) setNStates:(int)nStates { _target.params->nStates = nStates;}
- (int) nStates { return _target.params->nStates; }

- (void) setAlphaWeaken:(double)alphaWeaken { _target.params->alphaWeaken = alphaWeaken;}
- (double) alphaWeaken { return _target.params->alphaWeaken; }

- (void) setNSmooth:(int)nSmooth { _target.params->nSmooth = nSmooth; }
- (int) nSmooth { return _target.params->nSmooth; }

- (void)setNSmoothTracking:(int)nSmoothTracking { _target.params->nSmoothTracking = nSmoothTracking;}
- (int) nSmoothTracking { return _target.params->nSmoothTracking; }

- (void)setSmoothType:(SmoothType)smoothType { _target.params->smoothType = smoothType;}
- (SmoothType) smoothType { return _target.params->smoothType; }

- (void)setLocalizeMode:(LocalizeMode)localizeMode { _target.params->localizeMode = localizeMode;}
- (LocalizeMode) localizeMode { return _target.params->localizeMode; }

- (void)setEffectiveSampleSizeThreshold:(double)effectiveSampleSizeThreshold { _target.params->effectiveSampleSizeThreshold = effectiveSampleSizeThreshold;}
- (double) effectiveSampleSizeThreshold { return _target.params->effectiveSampleSizeThreshold; }
- (void)setNStrongest:(int)nStrongest { _target.params->nStrongest = nStrongest;}
- (int)nStrongest { return _target.params->nStrongest;}

- (void)setEnablesFloorUpdate:(bool) enablesFloorUpdate {_target.params->enablesFloorUpdate = enablesFloorUpdate;}
- (bool)enablesFloorUpdate {return _target.params->enablesFloorUpdate;}


- (void)setWalkDetectSigmaThreshold:(double) walkDetectSigmaThreshold {_target.params->walkDetectSigmaThreshold = walkDetectSigmaThreshold;}
- (double)walkDetectSigmaThreshold {return _target.params->walkDetectSigmaThreshold;}

- (void)setMeanVelocity:(double) meanVelocity {_target.params->meanVelocity = meanVelocity;}
- (double)meanVelocity {return _target.params->meanVelocity;}

- (void)setStdVelocity:(double) stdVelocity {_target.params->stdVelocity = stdVelocity;}
- (double)stdVelocity {return _target.params->stdVelocity;}

- (void)setDiffusionVelocity:(double) diffusionVelocity {_target.params->diffusionVelocity = diffusionVelocity;}
- (double)diffusionVelocity {return _target.params->diffusionVelocity;}

- (void)setMinVelocity:(double) minVelocity {_target.params->minVelocity = minVelocity;}
- (double)minVelocity {return _target.params->minVelocity;}

- (void)setMaxVelocity:(double) maxVelocity {_target.params->maxVelocity = maxVelocity;}
- (double)maxVelocity {return _target.params->maxVelocity;}


- (void)setStdRssiBias:(double) stdRssiBias {_target.params->stdRssiBias = stdRssiBias;}
- (double)stdRssiBias {return _target.params->stdRssiBias;}

- (void)setDiffusionRssiBias:(double) diffusionRssiBias {_target.params->diffusionRssiBias = diffusionRssiBias;}
- (double)diffusionRssiBias {return _target.params->diffusionRssiBias;}

- (void)setStdOrientation:(double) stdOrientation {_target.params->stdOrientation = stdOrientation;}
- (double)stdOrientation {return _target.params->stdOrientation;}

- (void)setDiffusionOrientationBias:(double) diffusionOrientationBias {_target.params->diffusionOrientationBias = diffusionOrientationBias;}
- (double)diffusionOrientationBias {return _target.params->diffusionOrientationBias;}


- (void)setAngularVelocityLimit:(double) angularVelocityLimit {_target.params->angularVelocityLimit = angularVelocityLimit;}
- (double)angularVelocityLimit {return _target.params->angularVelocityLimit;}

// Parametes for PoseRandomWalker
- (void)setDoesUpdateWhenStopping:(bool) doesUpdateWhenStopping {_target.params->doesUpdateWhenStopping = doesUpdateWhenStopping;}
- (bool)doesUpdateWhenStopping {return _target.params->doesUpdateWhenStopping;}


- (void)setMaxIncidenceAngle:(double) maxIncidenceAngle {_target.params->maxIncidenceAngle = maxIncidenceAngle;}
- (double)maxIncidenceAngle {return _target.params->maxIncidenceAngle;}

- (void)setWeightDecayHalfLife:(double) weightDecayHalfLife {_target.params->weightDecayHalfLife = weightDecayHalfLife;}
- (double)weightDecayHalfLife {return _target.params->weightDecayHalfLife;}


// Parameters for RandomWalkerMotion and WeakPoseRandomWalker
- (void)setSigmaStop:(double) sigmaStop {_target.params->sigmaStop = sigmaStop;}
- (double)sigmaStop {return _target.params->sigmaStop;}

- (void)setSigmaMove:(double) sigmaMove {_target.params->sigmaMove = sigmaMove;}
- (double)sigmaMove {return _target.params->sigmaMove;}


// Parameters for SystemModelInBuilding
- (void)setVelocityRateFloor:(double) velocityRateFloor {_target.params->velocityRateFloor = velocityRateFloor;}
- (double)velocityRateFloor {return _target.params->velocityRateFloor;}

- (void)setVelocityRateElevator:(double) velocityRateElevator {_target.params->velocityRateElevator = velocityRateElevator;}
- (double)velocityRateElevator {return _target.params->velocityRateElevator;}

- (void)setVelocityRateStair:(double) velocityRateStair {_target.params->velocityRateStair = velocityRateStair;}
- (double)velocityRateStair {return _target.params->velocityRateStair;}

- (void)setVelocityRateEscalator:(double) velocityRateEscalator {_target.params->velocityRateEscalator = velocityRateEscalator;}
- (double)velocityRateEscalator {return _target.params->velocityRateEscalator;}

- (void)setRelativeVelocityEscalator:(double) relativeVelocityEscalator {_target.params->relativeVelocityEscalator = relativeVelocityEscalator;}
- (double)relativeVelocityEscalator {return _target.params->relativeVelocityEscalator;}


// Parameters for WeakPoseRandomWalker
- (void)setProbabilityOrientationBiasJump:(double) probabilityOrientationBiasJump {_target.params->probabilityOrientationBiasJump = probabilityOrientationBiasJump;}
- (double)probabilityOrientationBiasJump {return _target.params->probabilityOrientationBiasJump;}

- (void)setPoseRandomWalkRate:(double) poseRandomWalkRate {_target.params->poseRandomWalkRate = poseRandomWalkRate;}
- (double)poseRandomWalkRate {return _target.params->poseRandomWalkRate;}

- (void)setRandomWalkRate:(double) randomWalkRate {_target.params->randomWalkRate = randomWalkRate;}
- (double)randomWalkRate {return _target.params->randomWalkRate;}

- (void)setProbabilityBackwardMove:(double) probabilityBackwardMove {_target.params->probabilityBackwardMove = probabilityBackwardMove;}
- (double)probabilityBackwardMove {return _target.params->probabilityBackwardMove;}


- (void)setNBurnIn:(int) nBurnIn {_target.params->nBurnIn = nBurnIn;}
- (int)nBurnIn {return _target.params->nBurnIn;}

- (void)setBurnInRadius2D:(int) burnInRadius2D {_target.params->burnInRadius2D = burnInRadius2D;}
- (int)burnInRadius2D {return _target.params->burnInRadius2D;}

- (void)setBurnInInterval:(int) burnInInterval {_target.params->burnInInterval = burnInInterval;}
- (int)burnInInterval {return _target.params->burnInInterval;}

- (void)setBurnInInitType:(InitType) burnInInitType {_target.params->burnInInitType = burnInInitType;}
- (InitType)burnInInitType {return _target.params->burnInInitType;}


- (void)setMixProba:(double) mixProba {_target.params->mixProba = mixProba;}
- (double)mixProba {return _target.params->mixProba;}

- (void)setRejectDistance:(double) rejectDistance {_target.params->rejectDistance = rejectDistance;}
- (double)rejectDistance {return _target.params->rejectDistance;}

- (void)setRejectFloorDifference:(double) rejectFloorDifference {_target.params->rejectFloorDifference = rejectFloorDifference;}
- (double)rejectFloorDifference {return _target.params->rejectFloorDifference;}

- (void)setNBeaconsMinimum:(int) nBeaconsMinimum {_target.params->nBeaconsMinimum = nBeaconsMinimum;}
- (int)nBeaconsMinimum {return _target.params->nBeaconsMinimum;}


- (void)setUsesAltimeterForFloorTransCheck:(bool) usesAltimeterForFloorTransCheck {_target.params->usesAltimeterForFloorTransCheck = usesAltimeterForFloorTransCheck;}
- (bool)usesAltimeterForFloorTransCheck {return _target.params->usesAltimeterForFloorTransCheck;}

- (void)setCoeffDiffFloorStdev:(double) coeffDiffFloorStdev {_target.params->coeffDiffFloorStdev = coeffDiffFloorStdev;}
- (double)coeffDiffFloorStdev {return _target.params->coeffDiffFloorStdev;}


- (void)setOrientationMeterType:(OrientationMeterType) orientationMeterType {_target.params->orientationMeterType = orientationMeterType;}
- (OrientationMeterType)orientationMeterType {return _target.params->orientationMeterType;}

- (void)setRepLocation:(HLPLocationManagerRepLocation) repLocation {_target.repLocation = repLocation;}
- (HLPLocationManagerRepLocation) repLocation {return _target.repLocation;}
- (void)setMeanRssiBias:(double) meanRssiBias {_target.meanRssiBias = meanRssiBias;}
- (double)meanRssiBias {return _target.meanRssiBias;}
- (void)setMaxRssiBias:(double) maxRssiBias {_target.maxRssiBias = maxRssiBias;}
- (double)maxRssiBias {return _target.maxRssiBias;}
- (void)setMinRssiBias:(double) minRssiBias {_target.minRssiBias = minRssiBias;}
- (double)minRssiBias {return _target.minRssiBias;}
- (void)setHeadingConfidenceForOrientationInit:(double) headingConfidenceForOrientationInit {_target.headingConfidenceForOrientationInit = headingConfidenceForOrientationInit;}
- (double)headingConfidenceForOrientationInit {return _target.headingConfidenceForOrientationInit;}

@end
