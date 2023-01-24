//
//  LocationManager.m
//  NavCog3
//
//  Created by yoshizawr204 on 2023/01/24.
//  Copyright © 2023 HULOP. All rights reserved.
//

#import "LocationManager.h"
#import <Foundation/Foundation.h>
#import <HLPLocationManager/HLPLocationManager+Player.h>
#import "LocationEvent.h"
#import "NavDataStore.h"

@import HLPDialog;

@implementation LocationManager

static LocationManager *instance;

static NSTimeInterval lastActiveTime;
static long locationChangedTime;
static int temporaryFloor;
static int currentFloor;
static int continueFloorCount;


+ (instancetype)sharedManager
{
    if (!instance) {
        instance = [[LocationManager alloc] init];
    }
    return instance;
}

- (id)init
{
   self = [super init];
   if (self) {
       //Initialization
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableAcceleration:) name:DISABLE_ACCELEARATION object:nil];

       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enableAcceleration:) name:ENABLE_ACCELEARATION object:nil];

       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(disableStabilizeLocalize:) name:DISABLE_STABILIZE_LOCALIZE object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enableStabilizeLocalize:) name:ENABLE_STABILIZE_LOCALIZE object:nil];
       
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationRestart:) name:REQUEST_LOCATION_RESTART object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationStop:) name:REQUEST_LOCATION_STOP object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationHeadingReset:) name:REQUEST_LOCATION_HEADING_RESET object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationReset:) name:REQUEST_LOCATION_RESET object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationUnknown:) name:REQUEST_LOCATION_UNKNOWN object:nil];
       
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestBackgroundLocation:) name:REQUEST_BACKGROUND_LOCATION object:nil];

       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplay:) name:REQUEST_LOG_REPLAY object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLogReplayStop:) name:REQUEST_LOG_REPLAY_STOP object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(requestLocationInit:) name:REQUEST_LOCATION_INIT object:nil];

       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverConfigChanged:) name:SERVER_CONFIG_CHANGED_NOTIFICATION object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(locationChanged:) name:NAV_LOCATION_CHANGED_NOTIFICATION object:nil];
       [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildingChanged:) name:BUILDING_CHANGED_NOTIFICATION object:nil];

       lastActiveTime = [[NSDate date] timeIntervalSince1970];
   }
   return self;
}



- (void)setup {
    HLPLocationManager *manager = [HLPLocationManager sharedManager];
    manager.delegate = self;
}

- (void)serverConfigChanged:(NSNotification*)note
{
    NSMutableDictionary *config = [note.userInfo mutableCopy];
    config[@"conv_client_id"] = [NavDataStore sharedDataStore].userID;
    [DialogManager sharedManager].config = config;
}

- (void)locationChanged:(NSNotification*)note
{
    HLPLocation *loc = [NavDataStore sharedDataStore].currentLocation;
    [[DialogManager sharedManager] changeLocationWithLat:loc.lat lng:loc.lng floor:loc.floor];
}

- (void)buildingChanged:(NSNotification*)note
{
    [[DialogManager sharedManager] changeBuilding:note.userInfo[@"building"]];
}

#pragma mark - NotificationCenter Observers

- (void)disableAcceleration:(NSNotification*)note
{
    [HLPLocationManager sharedManager].isAccelerationEnabled = NO;
}

- (void)enableAcceleration:(NSNotification*)note
{
    [HLPLocationManager sharedManager].isAccelerationEnabled = YES;
}

- (void)disableStabilizeLocalize:(NSNotification*)note
{
    [HLPLocationManager sharedManager].isStabilizeLocalizeEnabled = NO;
}

- (void)enableStabilizeLocalize:(NSNotification*)note
{
    [HLPLocationManager sharedManager].isStabilizeLocalizeEnabled = YES;
}

- (void) requestLocationRestart:(NSNotification*) note
{
    [[HLPLocationManager sharedManager] restart];
}

- (void) requestLocationStop:(NSNotification*) note
{
    [[HLPLocationManager sharedManager] stop];
}

- (void) requestLocationUnknown:(NSNotification*) note
{
    [[HLPLocationManager sharedManager] makeStatusUnknown];
}

- (void) requestLocationReset:(NSNotification*) note
{
    NSDictionary *properties = [note userInfo];
    HLPLocation *loc = properties[@"location"];
    double std_dev = [[NSUserDefaults standardUserDefaults] doubleForKey:@"reset_std_dev"];
    [loc updateOrientation:NAN withAccuracy:std_dev];
    [[HLPLocationManager sharedManager] resetLocation:loc];
}

- (void) requestLocationHeadingReset:(NSNotification*) note
{
    NSDictionary *properties = [note userInfo];
    HLPLocation *loc = properties[@"location"];
    double heading = [properties[@"heading"] doubleValue];
    double std_dev = [[NSUserDefaults standardUserDefaults] doubleForKey:@"reset_std_dev"];
    [loc updateOrientation:heading withAccuracy:std_dev];
    [[HLPLocationManager sharedManager] resetLocation:loc];
}

- (void) requestLocationInit:(NSNotification*) note
{
    HLPLocationManager *manager = [HLPLocationManager sharedManager];
    manager.delegate = self;
}

- (void) requestBackgroundLocation:(NSNotification*) note
{
    BOOL backgroundMode = (note && [[note userInfo][@"value"] boolValue]) ||
    [[NSUserDefaults standardUserDefaults] boolForKey:@"background_mode"];
    [HLPLocationManager sharedManager].isBackground = backgroundMode;
}

- (void) requestLogReplay:(NSNotification*) note
{
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSDictionary *option =
    @{
      @"replay_in_realtime": [ud valueForKey:@"replay_in_realtime"],
      @"replay_sensor": [ud valueForKey:@"replay_sensor"],
      @"replay_show_sensor_log": [ud valueForKey:@"replay_show_sensor_log"],
      @"replay_with_reset": [ud valueForKey:@"replay_with_reset"],
      };
    BOOL bNavigation = [[NSUserDefaults standardUserDefaults] boolForKey:@"replay_navigation"];
    [[HLPLocationManager sharedManager] startLogReplay:note.userInfo[@"path"] withOption:option withLogHandler:^(NSString *line) {
        if (bNavigation) {
            NSArray *v = [line componentsSeparatedByString:@" "];
            if (v.count > 3 && [v[3] hasPrefix:@"initTarget"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_INIT_TARGET_LOG object:self userInfo:@{@"text":line}];
                });
            }
            if (v.count > 3 && [v[3] hasPrefix:@"showRoute"]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:REQUEST_PROCESS_SHOW_ROUTE_LOG object:self userInfo:@{@"text":line}];
                });
            }
        }
    }];
}

- (void)requestLogReplayStop:(NSNotification*) note {
    [[HLPLocationManager sharedManager] stopLogReplay];
}




#pragma mark - HLPLocationManagerDelegate

- (void)locationManager:(HLPLocationManager *)manager didLocationUpdate:(HLPLocation *)location
{
    if (isnan(location.lat) || isnan(location.lng)) {
        // handle location information nan here
        return;
    }

    long now = (long)([[NSDate date] timeIntervalSince1970]*1000);

    NSMutableDictionary *data =
    [@{
       @"floor":@(location.floor),
       @"lat": @(location.lat),
       @"lng": @(location.lng),
       @"speed":@(location.speed),
       @"orientation":@(location.orientation),
       @"accuracy":@(location.accuracy),
       @"orientationAccuracy":@(location.orientationAccuracy),
       } mutableCopy];
    
    // Floor change continuity check
    if (temporaryFloor == location.floor) {
        continueFloorCount++;
    } else {
        continueFloorCount = 0;
    }
    temporaryFloor = location.floor;

    if ((continueFloorCount > 8) &&
        (locationChangedTime + 200 > now)) {
        currentFloor = temporaryFloor;
        [[NSNotificationCenter defaultCenter] postNotificationName:LOCATION_CHANGED_NOTIFICATION object:self userInfo:data];
    }
    locationChangedTime = now;
}

- (void)locationManager:(HLPLocationManager *)manager didLocationStatusUpdate:(HLPLocationStatus)status
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NAV_LOCATION_STATUS_CHANGE
                                                        object:self
                                                      userInfo:@{@"status":@(status)}];
}

- (void)locationManager:(HLPLocationManager *)manager didUpdateOrientation:(double)orientation withAccuracy:(double)accuracy
{
    NSDictionary *dic = @{
                          @"orientation": @(orientation),
                          @"orientationAccuracy": @(accuracy)
                          };

    [[NSNotificationCenter defaultCenter] postNotificationName:ORIENTATION_CHANGED_NOTIFICATION object:self userInfo:dic];
}

- (void)locationManager:(HLPLocationManager*)manager didLogText:(NSString *)text
{
    
}

@end
