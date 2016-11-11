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


#import "LocationManager.h"
#import <bleloc/bleloc.h>
#import <bleloc/BasicLocalizer.hpp>
#import <bleloc/LocException.hpp>
#import <bleloc/LogUtil.hpp>
#import "Logging.h"
#import <sys/sysctl.h>
#import <UIKit/UIKit.h>
#import "LocationEvent.h"
#import "NavSound.h"
#import "HLPLocation.h"
#import "ConfigManager.h"
#import "NavUtil.h"
#include <iomanip>

#define CALIBRATION_BEACON_UUID @"00000000-30A4-1001-B000-001C4D1E8637"
#define CALIBRATION_BEACON_MAJOR 9999

using namespace std;
using namespace loc;

typedef struct {
    LocationManager *locationManager;
} LocalUserData;

@implementation LocationManager
{
    shared_ptr<BasicLocalizer> localizer;
    CLLocationManager *beaconManager;
    LocalUserData userData;
    CMMotionManager *motionManager;
    CMAltimeter *altimeter;
    NSOperationQueue *processQueue;
    NSOperationQueue *loggingQueue;
    NSOperationQueue *locationQueue;
    
    NSDictionary *rssiBiasParam;
    void (^rssiBiasCompletionHandler)(float rssiBias);
    int rssiBiasCount;
    
    BOOL isMapLoading;
    BOOL isMapLoaded;
    NSDictionary *anchor;
    
    int putBeaconsCount;
    
    NSTimeInterval lastCalibrationTime;
    
    BOOL authorized;
    BOOL valid;
    
    BOOL isLogReplaying;
    
    BOOL flagPutBeacon;
    double currentFloor;
}

static LocationManager *instance;

+ (instancetype) sharedManager
{
    if (!instance) {
        instance = [[LocationManager alloc] initPrivate];
    }
    return instance;
}


void functionCalledAfterUpdate(void *inUserData, Status *status)
{
    LocalUserData *userData = (LocalUserData*) inUserData;
    if (!(userData->locationManager.isActive)) {
        return;
    }
    [userData->locationManager updateStatus:status];
}

void functionCalledToLog(void *inUserData, string text)
{
    LocalUserData *userData = (LocalUserData*) inUserData;
    if (!(userData->locationManager.isActive)) {
        return;
    }
    [userData->locationManager logText:text];
}

- (instancetype) initPrivate
{
    self = [super init];
    
    _isActive = NO;
    isMapLoaded = NO;
    valid = NO;
    
    userData.locationManager = self;

    locationQueue = [[NSOperationQueue alloc] init];
    locationQueue.maxConcurrentOperationCount = 1;
    locationQueue.qualityOfService = NSQualityOfServiceUserInteractive;

    processQueue = [[NSOperationQueue alloc] init];
    processQueue.maxConcurrentOperationCount = 1;
    processQueue.qualityOfService = NSQualityOfServiceUserInteractive;

    loggingQueue = [[NSOperationQueue alloc] init];
    loggingQueue.maxConcurrentOperationCount = 1;
    loggingQueue.qualityOfService = NSQualityOfServiceBackground;
    
    beaconManager = [[CLLocationManager alloc] init];
    beaconManager.delegate = self;
    
    motionManager = [[CMMotionManager alloc] init];
    
    if( [CMAltimeter isRelativeAltitudeAvailable]){
        altimeter = [[CMAltimeter alloc] init];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestRssiBias:) name:REQUEST_RSSI_BIAS object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationRestart:) name:REQUEST_LOCATION_RESTART object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationReset:) name:REQUEST_LOCATION_RESET object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplay:) name:REQUEST_LOG_REPLAY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplayStop:) name:REQUEST_LOG_REPLAY_STOP object:nil];
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud addObserver:self forKeyPath:@"nSmooth" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"nStates" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"rssi_bias" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"wheelchair_pdr" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"mixProba" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"rejectDistance" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"diffusionOrientationBias" options:NSKeyValueObservingOptionNew context:nil];
    [ud addObserver:self forKeyPath:@"location_tracking" options:NSKeyValueObservingOptionNew context:nil];
    
    return self;
}

- (void) requestLogReplayStop:(NSNotification*) notification
{
    isLogReplaying = NO;
}
- (void) requestLogReplay:(NSNotification*) notification
{
    isLogReplaying = YES;
    
    //localizer->resetStatus();
    
    [processQueue addOperationWithBlock:^{
        [self stop];
    }];
    
    dispatch_queue_t queue = dispatch_queue_create("org.hulop.logreplay", NULL);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:1.0];
        [self start];
        
        while(!isMapLoaded && isLogReplaying) {
            [NSThread sleepForTimeInterval:0.1];
        }

        NSString *path = [notification object];
        
        std::ifstream ifs([path cStringUsingEncoding:NSUTF8StringEncoding]);
        std::string str;
        if (ifs.fail())
        {
            NSLog(@"Fail to load file");
            return;
        }
        long total = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
        long progress = 0;
        
        NSTimeInterval start = [[NSDate date] timeIntervalSince1970];
        long first = 0;
        long timestamp = 0;
        
        BOOL bRealtime = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_in_realtime"];
        BOOL bSensor = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_sensor"];
        BOOL bShowSensorLog = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_show_sensor_log"];
        BOOL bResetInLog = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_with_reset"];
        BOOL bNavigation = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_navigation"];
        
        NSMutableDictionary *marker = [@{} mutableCopy];
        long count = 0;
        while (getline(ifs, str) && isLogReplaying)
        {
            [NSThread sleepForTimeInterval:0.001];

            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            
            long diffr = (now - start)*1000;
            long difft = timestamp - first;

            progress += str.length()+1;
            if (count*500 < difft) {
                [[NSNotificationCenter defaultCenter] postNotificationName:LOG_REPLAY_PROGRESS object:
                 @{
                   @"progress":@(progress),
                   @"total":@(total),
                   @"marker":marker,
                   @"floor":@(currentFloor),
                   @"difft":@(difft)
                   }];
                count++;
            }
            
            if (difft - diffr > 1000 && bRealtime) { // skip
                first +=  difft - diffr - 1000;
                difft = diffr + 1000;
            }
            
            while (difft-diffr > 0 && bRealtime && isLogReplaying) {
                //std::cout << difft-diffr << std::endl;
                [NSThread sleepForTimeInterval:0.1];
                diffr = ([[NSDate date] timeIntervalSince1970] - start)*1000;
            }
            //std::cout << str << std::endl;
            try {
                std::vector<std::string> v;
                boost::split(v, str, boost::is_any_of(" "));
                
                if (bSensor && v.size() > 3) {
                    std::string logString = v.at(3);
                    // Parsing beacons value
                    if (logString.compare(0, 6, "Beacon") == 0) {
                        Beacons beacons = DataUtils::parseLogBeaconsCSV(logString);
                        std::cout << "LogReplay:" << beacons.timestamp() << ",Beacon," << beacons.size();
                        for(auto& b : beacons){
                            std::cout << "," << b.major() << "," << b.minor() << "," << b.rssi();
                        }
                        std::cout << std::endl;
                        timestamp = beacons.timestamp();
                        [self processBeacons:beacons];
                        putBeaconsCount++;
                    }
                    // Parsing acceleration values
                    else if (logString.compare(0, 3, "Acc") == 0) {
                        Acceleration acc = LogUtil::toAcceleration(logString);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << acc.timestamp() << ",Acc," << acc << std::endl;
                        }
                        timestamp = acc.timestamp();
                        localizer->putAcceleration(acc);
                    }
                    // Parsing motion values
                    else if (logString.compare(0, 6, "Motion") == 0) {
                        Attitude att = LogUtil::toAttitude(logString);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << att.timestamp() << ",Motion," << att << std::endl;
                        }
                        timestamp = att.timestamp();
                        localizer->putAttitude(att);
                    }
                    // Parsing reset
                    else if (logString.compare(0, 5, "Reset") == 0) {
                        if (bResetInLog){
                            // "Reset",lat,lng,floor,heading,timestamp
                            std::vector<std::string> values;
                            boost::split(values, logString, boost::is_any_of(","));
                            timestamp = stol(values.at(5));
                            double lat = stod(values.at(1));
                            double lng = stod(values.at(2));
                            double floor = stod(values.at(3));
                            double orientation = stod(values.at(4));
                            std::cout << "LogReplay:" << timestamp << ",Reset,";
                            std::cout << std::setprecision(10) << lat <<"," <<lng;
                            std::cout <<"," <<floor <<"," <<orientation << std::endl;
                            marker[@"lat"] = @(lat);
                            marker[@"lng"] = @(lng);
                            marker[@"floor"] = @(floor);

                            HLPLocation *loc = [[HLPLocation alloc] initWithLat:lat Lng:lng Floor:floor];
                            NSDictionary* properties = @{@"location" : loc,
                                                         @"heading": @(orientation)
                                                         };
                            [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_LOCATION_RESET object: properties];
                        }
                    }
                    // Marker
                    else if (logString.compare(0, 6, "Marker") == 0){
                        // "Marker",lat,lng,floor,timestamp
                        std::vector<std::string> values;
                        boost::split(values, logString, boost::is_any_of(","));
                        double lat = stod(values.at(1));
                        double lng = stod(values.at(2));
                        double floor = stod(values.at(3));
                        timestamp = stol(values.at(4));
                        std::cout << "LogReplay:" << timestamp << ",Marker,";
                        std::cout << std::setprecision(10) << lat << "," << lng;
                        std::cout << "," << floor << std::endl;
                        marker[@"lat"] = @(lat);
                        marker[@"lng"] = @(lng);
                        marker[@"floor"] = @(floor);
                    }
                }

                if (!bSensor) {
                    if (v.size() > 3 && v.at(3).compare(0, 4, "Pose") == 0) {
                        std::string log_string = v.at(3);
                        std::vector<std::string> att_values;
                        boost::split(att_values, log_string, boost::is_any_of(","));
                        timestamp = stol(att_values.at(7));
                        
                        double lat = stod(att_values.at(1));
                        double lng = stod(att_values.at(2));
                        double floor = stod(att_values.at(3));
                        currentFloor = floor;
                        double accuracy = stod(att_values.at(4));
                        double orientation = stod(att_values.at(5));
                        double orientationAccuracy = stod(att_values.at(6));
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:
                         @{
                           @"lat": @(lat),
                           @"lng": @(lng),
                           @"floor": @(floor),
                           @"accuracy": @(accuracy),
                           @"orientation": @(orientation),
                           @"orientationAccuracy": @(orientationAccuracy)
                           }
                         ];
                    }
                }
                
                if (bNavigation) {
                    NSString *objcStr = [[NSString alloc] initWithCString:str.c_str() encoding:NSUTF8StringEncoding];
                    if (v.size() > 3 && v.at(3).compare(0, 10, "initTarget") == 0) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_INIT_TARGET_LOG object:objcStr];
                    }
                    
                    if (v.size() > 3 && v.at(3).compare(0, 9, "showRoute") == 0) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_SHOW_ROUTE_LOG object:objcStr];
                    }
                }

                if (first == 0) {
                    first = timestamp;
                }
                
            } catch (std::invalid_argument e){
                std::cerr << e.what() << std::endl;
                std::cerr << "error in parse log file" << std::endl;
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:LOG_REPLAY_PROGRESS object:@{@"progress":@(total),@"total":@(total)}];
        isLogReplaying = NO;
        [self stop];
        [self start];
    });
}


- (void) requestLocationRestart:(NSNotification*) notification
{
    [processQueue addOperationWithBlock:^{
        [self stop];
        [NSThread sleepForTimeInterval:1.0];
        NSLog(@"Restart");
        [self start];
    }];
}

- (void) requestLocationReset:(NSNotification*) notification
{
    if (!_isActive || !isMapLoaded) {
        NSDictionary *properties = [notification object];
        HLPLocation *loc = properties[@"location"];
        double heading = [properties[@"heading"] doubleValue];
        NSDictionary *data = @{
                               @"lat": @(loc.lat),
                               @"lng": @(loc.lng),
                               @"floor": @(loc.floor),
                               @"orientation": @(isnan(heading)?0:heading),
                               @"orientationAccuracy": @(1)
                               };
        [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:data];

        return;
    }

    [processQueue addOperationWithBlock:^{
        NSDictionary *properties = [notification object];
        HLPLocation *loc = properties[@"location"];
        double heading = ([properties[@"heading"] doubleValue] - [anchor[@"rotate"] doubleValue])/180*M_PI;
        double x = sin(heading);
        double y = cos(heading);
        heading = atan2(y,x);
        
        loc::LatLngConverter::Ptr projection = [self getProjection];
        
        loc::Location location;
        loc::GlobalState<Location> global(location);
        global.lat(loc.lat);
        global.lng(loc.lng);
        
        location = projection->globalToLocal(global);
        
        loc::Pose newPose(location);
        newPose.floor(round(loc.floor));
        newPose.orientation(heading);
        
        long timestamp = [[NSDate date] timeIntervalSince1970]*1000;
        
        
        NSLog(@"Reset,%f,%f,%f,%f,%ld",loc.lat,loc.lng,loc.floor,[properties[@"heading"] doubleValue],timestamp);
        localizer->resetStatus(newPose);
    }];
}

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
        if (!_isActive || isLogReplaying) {
            return;
        }
        Attitude attitude((uptime+motion.timestamp)*1000,
                          motion.attitude.pitch, motion.attitude.roll, motion.attitude.yaw);
        
        try {
            localizer->putAttitude(attitude);
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
        }
    }];
    [motionManager startAccelerometerUpdatesToQueue: processQueue withHandler:^(CMAccelerometerData * _Nullable acc, NSError * _Nullable error) {
        if (!_isActive || isLogReplaying) {
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
            if (!_isActive || isLogReplaying) {
                return;
            }
            NSNumber* relAlt=  altitudeData.relativeAltitude;
            NSNumber* pressure = altitudeData.pressure;
            long ts = ((uptime+altitudeData.timestamp))*1000;
            std::stringstream ss;
            // "Altimeter",relativeAltitude,pressure,timestamp
            ss << "Altimeter," << [relAlt doubleValue] << "," << [pressure doubleValue]<< "," << ts;
            std::string logStr = ss.str();
            [self logText: logStr];
        }];
    }
    
    rssiBiasCount = -1;
    putBeaconsCount = 0;
}

- (void) buildLocalizer
{
    localizer = shared_ptr<BasicLocalizer>(new BasicLocalizer());
    localizer->updateHandler(functionCalledAfterUpdate, (void*) &userData);
    localizer->logHandler(functionCalledToLog, (void*) &userData);
    
    NSString *location_tracking = [[NSUserDefaults standardUserDefaults] stringForKey:@"location_tracking"];
    
    if ([location_tracking isEqualToString:@"tracking"]) {
        localizer->localizeMode = RANDOM_WALK_ACC_ATT;
    } else if([location_tracking isEqualToString:@"oneshot"]) {
        localizer->localizeMode = ONESHOT;
    } else if([location_tracking isEqualToString:@"randomwalker"]) {
        localizer->localizeMode = RANDOM_WALK_ACC;
    } else if([location_tracking isEqualToString:@"weak_pose_random_walker"]) {
        localizer->localizeMode = WEAK_POSE_RANDOM_WALKER;
    }
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    localizer->nStates = [ud doubleForKey:@"nStates"];
    localizer->effectiveSampleSizeThreshold = [ud doubleForKey:@"nEffective"];
    localizer->alphaWeaken = [ud doubleForKey:@"alphaWeaken"];
    localizer->nSmooth = [ud doubleForKey:@"nSmooth"];
    localizer->nSmoothTracking = [ud doubleForKey:@"nSmoothTracking"];
    // localizer->smoothType
    
    localizer->walkDetectSigmaThreshold = [ud boolForKey:@"wheelchair_pdr"]?0.1:0.6;
    localizer->meanVelocity = [ud doubleForKey:@"meanVelocity"];;
    localizer->stdVelocity = 0.3;
    localizer->diffusionVelocity = 0.1;
    localizer->minVelocity = 0.1;
    localizer->maxVelocity = 1.5;
    
    localizer->stdRssiBias = 2.0;
    localizer->diffusionRssiBias = 0.2;
    
    localizer->diffusionOrientationBias = [ud doubleForKey:@"diffusionOrientationBias"];
    localizer->angularVelocityLimit = 45.0; // default 30;
    
    localizer->maxIncidenceAngle = 45;
    localizer->weightDecayHalfLife = [ud doubleForKey:@"weightDecayHalfLife"];
    
    localizer->sigmaStop = 0.1;
    localizer->sigmaMove = 1.0;
    
    localizer->velocityRateFloor = 1.0;
    localizer->velocityRateElevator = 1.0;
    localizer->velocityRateStair = 0.5;
    
    localizer->nBurnIn = [ud doubleForKey:@"nStates"];
    localizer->burnInRadius2D = 5; // default 10
    localizer->burnInInterval = 1;
    localizer->burnInInitType = INIT_WITH_SAMPLE_LOCATIONS;
    
    localizer->mixProba = [ud doubleForKey:@"mixProba"];
    localizer->rejectDistance = [ud doubleForKey:@"rejectDistance"];
    localizer->rejectFloorDifference = [ud doubleForKey:@"rejectFloorDifference"];
    
    // for WeakPoseRandomWalker
    localizer->probabilityOrientationBiasJump =0.0;
    localizer->poseRandomWalkRate = 1.0;
    localizer->randomWalkRate = 0.2;
    
    double lb = [ud doubleForKey:@"locLB"];
    double lbFloor = [ud doubleForKey:@"floorLB"];
    localizer->locLB = Location(lb, lb, 1e-6, lbFloor);

    //localizer->normalFunction(TDIST, 3);
}

- (void) dealloc
{
    [self stop];
}

- (void) start
{

    if (!authorized) {
        [beaconManager requestAlwaysAuthorization];
    } else {
        [self didChangeAuthorizationStatus:authorized];
    }
}

- (void)didChangeAuthorizationStatus:(BOOL)authorized_
{
    if (_isActive == YES) {
        if (valid == NO) {
            [self stop];
        } else {
            return;
        }
    }
    
    authorized = authorized_;
    if (authorized) {
        [self buildLocalizer];
        [self startSensors];
        [self loadMaps];
        valid = YES;
        _isActive = YES;
    } else {
        [self stop];
    }
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
    
    if(altimeter){ [altimeter stopRelativeAltitudeUpdates]; }
    [motionManager stopDeviceMotionUpdates];
    [motionManager stopAccelerometerUpdates];
    [beaconManager stopUpdatingHeading];
    
    localizer = nil;
}

- (void)requestRssiBias:(NSNotification*) notification
{
    NSDictionary *param = [notification object];
    if (param) {
        [self getRssiBias:param withCompletion:^(float rssiBias) {
            [[NSUserDefaults standardUserDefaults] setFloat:rssiBias forKey:@"rssi_bias"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    valid = NO;
}

- (void) updateStatus:(Status*) status
{
    if (putBeaconsCount < localizer->nSmooth) {
        return;
    }
    [self locationUpdated:status withResampledFlag:flagPutBeacon];
}

-(void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    if (newHeading.headingAccuracy < 0) {
        return;
    }
    [processQueue addOperationWithBlock:^{
        [self directionUpdated:newHeading.magneticHeading withAccuracy:newHeading.headingAccuracy];
    }];
    [processQueue addOperationWithBlock:^{
        // logging
        if (!_isActive || isLogReplaying) {
            return;
        }
        std::string logString = [self logStringFrom:newHeading];
        [self logText: logString];
    }];
}

- (std::string) logStringFrom:(CLHeading*)heading
{
    //"Heading",magneticHeading,trueHeading,headingAccuracy,timestamp
    std::stringstream ss;
    ss << "Heading," << heading.magneticHeading << "," << heading.trueHeading << ","
    << heading.headingAccuracy << "," << (long) ([heading.timestamp timeIntervalSince1970]*1000);
    return ss.str();
}

- (BOOL)checkCalibrationBeacon:(CLBeacon *)beacon
{
    if (!anchor) {
        return NO;
    }
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"tracking"]) {
        return NO;
    }
    if ([[NSDate date] timeIntervalSince1970] - lastCalibrationTime < 5) {
        return NO;
    }
    if ([beacon.major intValue] != CALIBRATION_BEACON_MAJOR) {
        return NO;
    }
    if (![beacon.proximityUUID.UUIDString isEqualToString:CALIBRATION_BEACON_UUID]) {
        return NO;
    }
    NSLog(@"accuracy=%f", beacon.accuracy);
    if (beacon.accuracy < 0 || 0.3 < beacon.accuracy) {
        return NO;
    }
    
    signed short ss = (signed short)[beacon.minor intValue];
    double degree = ss*180.0/32767.0;
    double rotate = [anchor[@"rotate"] doubleValue];
    
    double r = (degree - rotate)/180*M_PI;
    double x = sin(r);
    double y = cos(r);
    double orientation = atan2(y, x);
    
    [[NSNotificationCenter defaultCenter] postNotificationName:CALIBRATION_BEACON_FOUND object:@{@"degree":@(degree)}];
    
    [processQueue addOperationWithBlock:^{
        std::shared_ptr<loc::Pose> pose = localizer->getStatus()->meanPose();
        
        loc::Pose newPose(*pose);
        newPose.floor(round(newPose.floor()));
        newPose.orientation(orientation);

        std::cerr << newPose << std::endl;
        localizer->resetStatus(newPose);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NavSound sharedInstance] playSuccess];
        });
    }];
    
    lastCalibrationTime = [[NSDate date] timeIntervalSince1970];
    
    return YES;
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region
{
    if (!_isActive || [beacons count] == 0 || isLogReplaying) {
        return;
    }
    Beacons cbeacons;
    for(int i = 0; i < [beacons count]; i++) {
        CLBeacon *b = [beacons objectAtIndex: i];
        if ([self checkCalibrationBeacon:b]) {
            continue;
        }
        
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
            [self processBeacons:cbeacons];
            [self sendBeacons:beacons];
            putBeaconsCount++;
        }
        @catch (NSException *e) {
            NSLog(@"%@", [e debugDescription]);
        }
    }];
}

- (void) processBeacons:(Beacons) cbeacons
{
    if (!_isActive) {
        return;
    }
    if (cbeacons.size() > 0) {
        if (rssiBiasCount > 0) {
            rssiBiasCount -= 1;
            
            try {
                loc::LatLngConverter::Ptr projection = [self getProjection];
                Location loc;
                GlobalState<Location> global(loc);
                global.lat([rssiBiasParam[@"lat"] doubleValue]);
                global.lng([rssiBiasParam[@"lng"] doubleValue]);
                
                auto loc2 = projection->globalToLocal(global);

                localizer->minRssiBias(localizer->estimatedRssiBias()-10);
                localizer->maxRssiBias(localizer->estimatedRssiBias()+10);
                localizer->meanRssiBias(localizer->estimatedRssiBias());
                localizer->resetStatus(loc2, cbeacons);
                if (rssiBiasCount == 0) {
                    rssiBiasCompletionHandler(localizer->estimatedRssiBias());
                }
            } catch(const std::exception& ex) {
                std::cout << ex.what() << std::endl;
            }
        } else {
            double s = [[NSDate date] timeIntervalSince1970];
            try {
                flagPutBeacon = YES;
                localizer->putBeacons(cbeacons);
                flagPutBeacon = NO;
            } catch(const std::exception& ex) {
                std::cout << ex.what() << std::endl;
            }
            double e = [[NSDate date] timeIntervalSince1970];
            std::cout << (e-s)*1000 << " ms for putBeacons " << cbeacons.size() << std::endl;
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusDenied:
        case kCLAuthorizationStatusRestricted:
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            [self didChangeAuthorizationStatus:NO];
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            [self didChangeAuthorizationStatus:YES];
            break;
    }
}

- (void)setModelAtPath:(NSString *)path withWorkingDir:(NSString *)dir
{
    [processQueue addOperationWithBlock:^{
        double s = [[NSDate date] timeIntervalSince1970];
        
        try {
            localizer->setModel([path cStringUsingEncoding:NSUTF8StringEncoding], [dir cStringUsingEncoding:NSUTF8StringEncoding]);
            double e = [[NSDate date] timeIntervalSince1970];
            std::cout << (e-s)*1000 << " ms for setModel" << std::endl;            
        } catch(const std::exception& ex) {
            std::cout << ex.what() << std::endl;
            NSLog(@"Error in setModelAtPath");
            return;
        }
        
        float rssiBias = [[NSUserDefaults standardUserDefaults] floatForKey:@"rssi_bias"];
        localizer->minRssiBias(rssiBias-0.1);
        localizer->maxRssiBias(rssiBias+0.1);
        localizer->meanRssiBias(rssiBias);
        
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"test" withExtension:@"csv"];
        NSError *error = nil;
        [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (!error) {
            return;
        }
        
        
        auto& beacons = localizer->dataStore->getBLEBeacons();
        
        NSMutableDictionary *dict = [@{} mutableCopy];
        BOOL needToAddCalibrationBeaconUUID = YES;
        for(auto it = beacons.begin(); it != beacons.end(); it++) {
            NSString *uuidStr = [NSString stringWithUTF8String: it->uuid().c_str()];
            if ([uuidStr isEqualToString:CALIBRATION_BEACON_UUID]) {
                needToAddCalibrationBeaconUUID = NO;
            }
            if (!dict[uuidStr]) {
                NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidStr];
                dict[uuidStr] = uuid;
                
                CLBeaconRegion *region = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:uuidStr];
                
                [beaconManager startRangingBeaconsInRegion:region];
            }
        }
        
        if (needToAddCalibrationBeaconUUID) {
            NSUUID *calibUUID = [[NSUUID alloc] initWithUUIDString:CALIBRATION_BEACON_UUID];
            CLBeaconRegion *calibRegion = [[CLBeaconRegion alloc] initWithProximityUUID:calibUUID identifier:CALIBRATION_BEACON_UUID];
            [beaconManager startRangingBeaconsInRegion:calibRegion];
        }
        
        isMapLoaded = YES;
    }];
}

- (void) getRssiBias:(NSDictionary*)param withCompletion:(void (^)(float rssiBias)) completion
{
    rssiBiasParam = param;
    rssiBiasCompletionHandler = completion;
    rssiBiasCount = 5;
}

int sendcount = 0;

- (void) logText:(string) text {
    [loggingQueue addOperationWithBlock:^{
        if ([Logging isLogging]) {
            NSLog(@"%s", text.c_str());
        }
    }];
}

- (NSString*) platformString
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = (char*)malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *deviceName = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    return deviceName;
}

- (NSDictionary*) buildBeaconJSON:(NSArray<CLBeacon *> *) beacons
{
    NSMutableDictionary *json = [@{} mutableCopy];
    json[@"type"] = @"rssi";
    

    NSString *phoneID = [NSString stringWithFormat:@"%@-%@", [self platformString], UIDevice.currentDevice.identifierForVendor.UUIDString];
    json[@"phoneID"] = phoneID;
    
    long timestamp = [[NSDate date] timeIntervalSince1970] * 1000.0;
    
    json[@"timestamp"] = @(timestamp);

    NSMutableArray* array = [@[] mutableCopy];

    for(CLBeacon *beacon: beacons) {
        NSString* id = [NSString stringWithFormat:@"%@-%@-%@",
                        beacon.proximityUUID.UUIDString,
                        beacon.major,
                        beacon.minor];
        NSDictionary* obj = @{
                              @"type": @"iBeacon",
                              @"id": id,
                              @"rssi": @(beacon.rssi)
                              };
        [array addObject:obj];
    }
    json[@"data"] = array;

    return json;
}

- (void) sendBeacons:(NSArray<CLBeacon *> *) beacons
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if (![ud boolForKey:@"send_beacon_data"]) {
        return;
    }
    
    NSDictionary *json = [self buildBeaconJSON:beacons];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/beacon", [ud stringForKey:@"beacon_data_server"]]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    
    request.HTTPMethod = @"POST";
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    request.HTTPBody = data;
    
    NSLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 2;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data != nil) {
            std::cout << "Send success" << std::endl;
        }
        if (error) {
            std::cout << [[error localizedDescription] cStringUsingEncoding:NSUTF8StringEncoding] << std::endl;
        }
    }];
    
    [task resume];
}

- (loc::LatLngConverter::Ptr) getProjection
{
    return localizer->latLngConverter();
}


- (void)directionUpdated:(double)direction withAccuracy:(double)acc
{
    @try {
    NSDictionary *dic = @{
                          @"orientation": @(direction),
                          @"orientationAccuracy": @(acc)
                          };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ORIENTATION_CHANGED_NOTIFICATION object:dic];
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}


Pose computeRepresentativePose(const Pose& meanPose, const std::vector<State>& states){
    Pose refPose(meanPose);
    NSString *rep_location = [[NSUserDefaults standardUserDefaults] stringForKey:@"rep_location"];
    if([rep_location isEqualToString:@"mean"]){
        // pass
    }else if([rep_location isEqualToString:@"densest"]){
        int idx = Location::findKDEDensestLocationIndex<State>(states);
        Location locDensest = states.at(idx);
        refPose.copyLocation(locDensest);
    }else if([rep_location isEqualToString:@"closest_mean"]){
        int idx = Location::findClosestLocationIndex(refPose, states);
        Location locClosest = states.at(idx);
        refPose.copyLocation(locClosest);
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
        
        Pose refPose = *status->meanPose();
        std::vector<State> states = *status->states();
        refPose = computeRepresentativePose(refPose, states);
        
        loc::LatLngConverter::Ptr projection = [self getProjection];
        auto global = projection->localToGlobal(refPose);
        
        dcount++;
        
        double orientation = refPose.orientation() - [anchor[@"rotate"] doubleValue] / 180 * M_PI;
        double x = cos(orientation);
        double y = sin(orientation);
        orientation = atan2(x, y) / M_PI * 180;
        
        int orientationAccuracy = 999;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"tracking"] ||
            localizer->tracksOrientation()) {
            
            auto dirStats = loc::Pose::computeDirectionalStatistics(states);
            double m = dirStats.circularMean();
            double v = dirStats.circularVariance();

            orientationAccuracy = v/M_PI*180;
        }
        
        double acc = [[NSUserDefaults standardUserDefaults] boolForKey:@"accuracy_for_wow"]?0.5:5.0;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"use_blelocpp_acc"]) {
            auto std = loc::Location::standardDeviation(states);
            double sigma = [[NSUserDefaults standardUserDefaults] doubleForKey:@"blelocpp_accuracy_sigma"];
            acc = MAX(acc, (std.x()+std.y())/2.0*sigma);
        }
        
        if (flag) {
            currentFloor = refPose.floor();
        }
        
        NSMutableDictionary *data =
        [@{
           @"x": @(refPose.x()),
           @"y": @(refPose.y()),
           @"z": @(refPose.z()),
           @"floor":@(currentFloor),
           @"lat": @(global.lat()),
           @"lng": @(global.lng()),
           @"speed":@(refPose.velocity()),
           @"orientation":@(orientation),
           @"accuracy":@(acc),
           @"orientationAccuracy":@(orientationAccuracy), // TODO
           @"anchor":@{
                   @"lat":anchor[@"latitude"],
                   @"lng":anchor[@"longitude"]
                   },
           @"rotate":anchor[@"rotate"]
           } mutableCopy];
        
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"show_states"] && dcount % 10 == 0) {
            NSMutableArray *debug = [@[] mutableCopy];
            for(loc::State &s: states) {
                [debug addObject:@(s.Location::x())];
                [debug addObject:@(s.Location::y())];
            }
            data[@"debug_info"] = debug;
            NSMutableArray *debug_latlng = [@[] mutableCopy];
            
            for(loc::State &s: states) {
                auto g = projection->localToGlobal(s);
                [debug_latlng addObject:@(g.lat())];
                [debug_latlng addObject:@(g.lng())];
            }
            data[@"debug_latlng"] = debug_latlng;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:data];
    }
    @catch(NSException *e) {
        NSLog(@"%@", [e debugDescription]);
    }
}

- (void)loadMaps {
    if (isMapLoading) {
        return;
    }
    isMapLoading = YES;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString __block *mapName = [ud stringForKey:@"bleloc_map_data"];
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    while(YES) {
        NSString* path = [documentsPath stringByAppendingPathComponent:mapName];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) {
            for(NSString *file in [ConfigManager filenamesWithSuffix:@"json"]) {
                mapName = file;
                [ud setValue:mapName forKey:@"bleloc_map_data"];
                break;
            }
            continue;
        }
        
        [[[NSOperationQueue alloc] init] addOperationWithBlock:^{
            NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
            [stream open];
            NSDictionary *json = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:nil];
            anchor = json[@"anchor"];
        
            NSString *tempDir = NSTemporaryDirectory();
            
            [self setModelAtPath:path withWorkingDir:tempDir];
        }];
        break;
    }

}



@end
