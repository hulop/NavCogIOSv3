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


#import "HLPLocationManager+Player.h"
#import "LocationEvent.h"

#import <bleloc/BasicLocalizer.hpp>
#import <bleloc/LogUtil.hpp>

#include <iomanip>
#include <fstream>

using namespace std;
using namespace loc;

@interface HLPLocationManager () {
    BOOL _isSensorEnabled;
    NSOperationQueue *processQueue;
}

- (shared_ptr<BasicLocalizer>) localizer;
- (NSDictionary*) anchor;
- (void) setCurrentFloor:(double) currentFloor_;
- (double) currentFloor;
- (double) currentOrientationAccuracy;
- (void) _processBeacons:(Beacons)beacons;
@end

@implementation HLPLocationManager (Player)

static BOOL isPlaying;
static HLPLocation* replayResetRequestLocation;

- (void)prepareForPlayer
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplay:) name:REQUEST_LOG_REPLAY object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplayStop:) name:REQUEST_LOG_REPLAY_STOP object:nil];
}

- (void) requestLogReplayStop:(NSNotification*) note
{
    isPlaying = NO;
}

- (void) requestLogReplay:(NSNotification*) note
{
    _isSensorEnabled = NO;
    isPlaying = YES;
    
    self.localizer->resetStatus();
    
    [processQueue addOperationWithBlock:^{
        [[HLPLocationManager sharedManager] stop];
        [self stop];
    }];
    
    dispatch_queue_t queue = dispatch_queue_create("org.hulop.logreplay", NULL);
    dispatch_async(queue, ^{
        [NSThread sleepForTimeInterval:1.0];
        HLPLocationManager *manager = [HLPLocationManager sharedManager];
        [manager start];
        [self start];
        
        while(!manager.isActive && isPlaying) {
            [NSThread sleepForTimeInterval:0.1];
        }
        
        NSString *path = [note userInfo][@"path"];
        
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
        while (getline(ifs, str) && isPlaying)
        {
            [NSThread sleepForTimeInterval:0.001];
            
            if (replayResetRequestLocation) {
                HLPLocation *loc = replayResetRequestLocation;
                double heading = loc.orientation;
                double acc = self.currentOrientationAccuracy;
                if (isnan(heading)) { // only location
                    heading = 0;
                } else { // set orientation
                    acc = 0;
                }
                
                heading = (heading - [self.anchor[@"rotate"] doubleValue])/180*M_PI;
                double x = sin(heading);
                double y = cos(heading);
                heading = atan2(y,x);
                
                loc::Location location;
                loc::GlobalState<Location> global(location);
                global.lat(loc.lat);
                global.lng(loc.lng);
                
                location = self.localizer->latLngConverter()->globalToLocal(global);
                
                loc::Pose newPose(location);
                if(isnan(loc.floor)){
                    newPose.floor(self.currentFloor);
                }else{
                    newPose.floor(round(loc.floor));
                }
                newPose.orientation(heading);
                
                loc::Pose stdevPose;
                stdevPose.x(1).y(1).orientation(acc/180*M_PI);
                self.localizer->resetStatus(newPose, stdevPose);
                
                replayResetRequestLocation = nil;
            }
            
            
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            
            long diffr = (now - start)*1000;
            long difft = timestamp - first;
            
            progress += str.length()+1;
            if (count*500 < difft) {
                
                auto currentLocationStatus = self.localizer->getStatus()->locationStatus();
                std::string locStatusStr = Status::locationStatusToString(currentLocationStatus);
                
                [[NSNotificationCenter defaultCenter] postNotificationName:LOG_REPLAY_PROGRESS object:self userInfo:
                 @{
                   @"progress":@(progress),
                   @"total":@(total),
                   @"marker":marker,
                   @"floor":@(self.currentFloor),
                   @"difft":@(difft),
                   @"message":@(locStatusStr.c_str())
                   }];
                count++;
            }
            
            if (difft - diffr > 1000 && bRealtime) { // skip
                first +=  difft - diffr - 1000;
                difft = diffr + 1000;
            }
            
            while (difft-diffr > 0 && bRealtime && isPlaying) {
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
                        [self _processBeacons:beacons];
                    }
                    // Parsing acceleration values
                    else if (logString.compare(0, 3, "Acc") == 0) {
                        Acceleration acc = LogUtil::toAcceleration(logString);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << acc.timestamp() << ",Acc," << acc << std::endl;
                        }
                        timestamp = acc.timestamp();
                        self.localizer->putAcceleration(acc);
                    }
                    // Parsing motion values
                    else if (logString.compare(0, 6, "Motion") == 0) {
                        Attitude att = LogUtil::toAttitude(logString);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << att.timestamp() << ",Motion," << att << std::endl;
                        }
                        timestamp = att.timestamp();
                        self.localizer->putAttitude(att);
                    }
                    else if (logString.compare(0, 7, "Heading") == 0){
                        Heading head = LogUtil::toHeading(logString);
                        self.localizer->putHeading(head);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << head.timestamp() << ",Heading," << head.trueHeading() << "," << head.magneticHeading() << "," << head.headingAccuracy() << std::endl;
                        }
                    }
                    else if (logString.compare(0, 9, "Altimeter") == 0){
                        Altimeter alt = LogUtil::toAltimeter(logString);
                        self.localizer->putAltimeter(alt);
                        if (bShowSensorLog) {
                            std::cout << "LogReplay:" << alt.timestamp() << ",Altimeter," << alt.relativeAltitude() << "," << alt.pressure() << std::endl;
                        }
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
                            [loc updateOrientation:orientation withAccuracy:0];
                            
                            replayResetRequestLocation = loc;
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
                        self.currentFloor = floor;
                        double accuracy = stod(att_values.at(4));
                        double orientation = stod(att_values.at(5));
                        double orientationAccuracy = stod(att_values.at(6));
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:self userInfo:
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
                        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_INIT_TARGET_LOG object:self userInfo:@{@"text":objcStr}];
                    }
                    
                    if (v.size() > 3 && v.at(3).compare(0, 9, "showRoute") == 0) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_SHOW_ROUTE_LOG object:self userInfo:@{@"text":objcStr}];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:LOG_REPLAY_PROGRESS object:self userInfo:@{@"progress":@(total),@"total":@(total)}];
        isPlaying = NO;
        _isSensorEnabled = YES;

        [self stop];
        [self start];
    });
}



@end
