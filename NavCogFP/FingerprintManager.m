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

#import "FingerprintManager.h"
#import "ServerConfig+FingerPrint.h"
#import "HLPDataUtil.h"
#import "HLPFingerprint.h"
#import "HLPBeaconSampler.h"
#import <sys/types.h>
#import <sys/sysctl.h>

#define SAMPLINGS_API_URL @"%@://%@/data/samplings%@"
#define FLOORPLANS_API_URL @"%@://%@/data/floorplans%@"
#define REFPOINTS_API_URL @"%@://%@/data/refpoints%@"

@implementation FingerprintManager {
    double lat,lng,x,y;
    HLPBeaconSampler *sampler;
}

static FingerprintManager *instance;

+(instancetype)sharedManager {
    if (!instance) {
        instance = [[FingerprintManager alloc] init];
    }
    return instance;
}

- (instancetype) init
{
    self = [super init];
    _isReady = false;
    sampler = [HLPBeaconSampler sharedInstance];
    return self;
}

- (void)load
{
    [self loadFloorplans:^{
        [self loadRefpoints: ^{
            [self createRefpoints];
        }];
    }];
}

- (HLPFloorplan*)getSelectedFloorplan
{
    if (!_selectedRefpoint) {
        return nil;
    }
    HLPFloorplan *fp;
    for(fp in _floorplans) {
        if ([_selectedRefpoint.refid[@"$oid"] isEqualToString:fp._id[@"$oid"]]) {
            break;
        }
    }
    return fp;
}

- (void)select:(HLPRefpoint *)rp
{
    _selectedRefpoint = rp;
    if (!rp) {
        return;
    }
    _selectedFloorplan = [self getSelectedFloorplan];
    [_delegate manager:self didRefpointSelected:_selectedRefpoint];
    [self loadSamplings:^{
        [_delegate manager:self didSamplingsLoaded:_samplings];
    }];
}

- (void) createRefpoints
{
    for(HLPFloorplan *fp in _floorplans) {
        if ([self createRefpointForFloorplan:fp withComplete:^{
            [self createRefpoints];
        }]) {
            return;
        }
    }
    _isReady = true;
    [_delegate manager:self didStatusChanged:_isReady];
    if (_selectedRefpoint) {
        [self select:_selectedRefpoint];
    }
}

- (void) loadFloorplans:(void(^)(void))complete
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:FLOORPLANS_API_URL, https, server, [self getTime]]];
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if ([result isKindOfClass:NSArray.class]) {
            NSArray *fs = (NSArray*)result;
            NSMutableArray *temp = [@[] mutableCopy];
            _floorplanMap = [@{} mutableCopy];
            for (NSDictionary *dic in fs) {
                NSError *error;
                HLPFloorplan *fp = [MTLJSONAdapter modelOfClass:HLPFloorplan.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [temp addObject:fp];
                    NSString *idstr = fp._id[@"$oid"];
                    if (idstr) {
                        _floorplanMap[idstr] = fp;
                    }
                }
            }
            _floorplans = temp;
            if (_selectedRefpoint) {
                _selectedFloorplan = [self getSelectedFloorplan];
            }
            complete();
            //NSLog(@"%@", floorplans);
        }
    }];
}

- (void) loadRefpoints:(void(^)(void))complete
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:REFPOINTS_API_URL, https, server, [self getTime]]];
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if ([result isKindOfClass:NSArray.class]) {
            NSArray *rs = (NSArray*)result;
            NSMutableArray *temp = [@[] mutableCopy];
            _floorplanRefpointMap = [@{} mutableCopy];
            for (NSDictionary *dic in rs) {
                NSError *error;
                HLPRefpoint *rp = [MTLJSONAdapter modelOfClass:HLPRefpoint.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [temp addObject:rp];
                    NSString *refid = rp.refid[@"$oid"];
                    if (refid) {
                        if (rp.x == 0 && rp.y == 0 && rp.rotate == 0) {
                            _floorplanRefpointMap[refid] = rp;
                        }
                    }
                    if (_floorplanMap[refid]) {
                        [rp updateWithFloorplan:_floorplanMap[refid]];
                    }
                }
            }
            _refpoints = temp;
            //NSLog(@"%@", refpoints);
            complete();
        }
    }];
}

- (void) loadSamplings:(void(^)(void))complete
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSString *query = [self stringify:
                       @{
                         @"information.refid" :
                             @{
                                 @"$in" : @[_selectedRefpoint._id]
                                 }
                         }];
    
    NSURLComponents *components = [NSURLComponents componentsWithString:[NSString stringWithFormat:SAMPLINGS_API_URL, https, server, [self getTime]]];
    NSURLQueryItem *search = [NSURLQueryItem queryItemWithName:@"query" value:query];
    components.queryItems = @[ search ];
    NSURL *url = components.URL;
    NSLog(@"%@", url);
    
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if ([result isKindOfClass:NSArray.class]) {
            NSArray *rs = (NSArray*)result;
            NSMutableArray *temp = [@[] mutableCopy];
            for (NSDictionary *dic in rs) {
                NSError *error;
                HLPSampling *sp = [MTLJSONAdapter modelOfClass:HLPSampling.class fromJSONDictionary:dic error:&error];
                
                MKMapPoint local = MKMapPointMake(sp.information.absx, sp.information.absy);
                CLLocationCoordinate2D global = [FingerprintManager convertFromLocal:local ToGlobalWithRefpoint:_selectedRefpoint];
                sp.lat = global.latitude;
                sp.lng = global.longitude;
                
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [temp addObject:sp];
                }
            }
            _samplings = temp;
            complete();
        }
    }];
}

- (BOOL) createRefpointForFloorplan:(HLPFloorplan*)fp withComplete:(void(^)(void)) complete
{
    if (_floorplanRefpointMap[fp._id[@"$oid"]]) {
        return false;
    }
    
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:REFPOINTS_API_URL, https, server, [self getTime]]];
    
    NSString *name = [NSString stringWithFormat:@"%@-%@", fp.group, [self floorString:fp.floor]];;
    
    NSMutableDictionary *data = [@{} mutableCopy];
    data[@"x"] = @(0);
    data[@"y"] = @(0);
    data[@"rotate"] = @(0);
    data[@"anchor_lat"] = @(fp.lat);
    data[@"anchor_lng"] = @(fp.lng);
    data[@"anchor_rotate"] = @(fp.rotate);
    data[@"filename"] = fp.filename;
    data[@"floor"] = name;
    data[@"floor_num"] = @(fp.floor);
    data[@"refid"] = fp._id;
    
    NSMutableDictionary *_metadata = [@{} mutableCopy];
    _metadata[@"name"] = name;
    
    NSMutableDictionary *dic = [@{} mutableCopy];
    dic[@"data"] = [self stringify:data];
    dic[@"_metadata"] = [self stringify:_metadata];

    [HLPDataUtil postRequest:url withData:dic callback:^(NSData *response) {
        if (response) {
            [self loadRefpoints:^{
                complete();
            }];
        }
    }];
    return true;
}

- (NSString*) floorString:(double)floor
{
    if (floor < 0) {
        return [NSString stringWithFormat:@"B%dF", -(int)round(floor)];
    } else {
        return [NSString stringWithFormat:@"%dF", (int)round(floor+1)];
    }
}

- (NSString*) stringify:(NSDictionary*)dic
{
    NSData *data = [NSJSONSerialization dataWithJSONObject:dic options:0 error:nil];
    return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)startSamplingAtLat:(double)lat_ Lng:(double)lng_
{
    if (_selectedRefpoint == nil) {
        return;
    }
    
    lat = lat_;
    lng = lng_;
    
    CLLocationCoordinate2D g = CLLocationCoordinate2DMake(lat, lng);
    
    MKMapPoint local = [FingerprintManager convertFromGlobal:g ToLocalWithRefpoint:_selectedRefpoint];
    x = local.x;
    y = local.y;
    
    [self startSampling];
}

- (void)startSampling {
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"selected_finger_printing_beacon_uuid"];
    if (!uuid) {
        return;
    }
    
    _isSampling = YES;
    sampler.delegate = self;
    [sampler setSamplingBeaconUUID:uuid];
    [sampler startRecording];
}

- (void)cancel
{
    [sampler stopRecording];
    [sampler reset];
    _isSampling = NO;
    _visibleBeaconCount = 0;
    _beaconsSampleCount = 0;
    [_delegate manager:self didStatusChanged:_isReady];
}

- (void)updated
{
    _visibleBeaconCount = sampler.visibleBeaconCount;
    _beaconsSampleCount = sampler.beaconSampleCount;
    
    if ([_delegate manager:self didObservedBeacons:(int)_visibleBeaconCount atSample:(int)_beaconsSampleCount]) {
        
    } else {
        if (sampler.isRecording) {
            [sampler stopRecording];
            //[self sendData];
        }
    }
}

- (void)sendData
{
    NSMutableDictionary *json = [[HLPBeaconSampler sharedInstance] toJSON];
    
    NSMutableDictionary *meta = [@{} mutableCopy];
    meta[@"name"] = _selectedRefpoint._metadata[@"name"];
    
    NSMutableDictionary *info = [@{} mutableCopy];
    info[@"site_id"] = _selectedRefpoint.floor;
    info[@"x"] = @(x);
    info[@"y"] = @(y);
    info[@"z"] = @(0);
    info[@"lat"] = @(lat);
    info[@"lng"] = @(lng);
    info[@"refid"] = _selectedRefpoint._id;
    info[@"floor"] = _selectedRefpoint.floor;
    info[@"floor_num"] = @(_selectedRefpoint.floor_num);

    NSMutableArray *tags = [@[] mutableCopy];
    
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    NSString *device_uuid = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    
    [tags addObject:platform];
    [tags addObject:device_uuid];
    info[@"tags"] = tags;
    
    json[@"information"] = info;
    
    NSDictionary *data = @{
                           @"_metadata":[self stringify:meta],
                           @"data":[self stringify:json]
                           };
    
    NSLog(@"%@", data);
    
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:SAMPLINGS_API_URL, https, server, @""]];
    [HLPDataUtil postRequest:url withData:data callback:^(NSData *response) {
        _isSampling = NO;
        if (response) {
            NSError *error;
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
            if (error) {
                NSLog(@"%@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
                [_delegate manager:self didSendData:nil withError:[NSError errorWithDomain:@"beacon.send" code:0 userInfo:nil]];
            } else {
                NSString *oid = dic[@"_id"][@"$oid"];
                NSLog(@"sent %ld", [response length]);
                [_delegate manager:self didSendData:oid withError:nil];
                
                [self loadSamplings:^{
                    [_delegate manager:self didSamplingsLoaded:_samplings];
                }];
            }
        } else {
            [_delegate manager:self didSendData:nil withError:[NSError errorWithDomain:@"beacon.send" code:0 userInfo:nil]];
        }
    }];
    
    [sampler reset];
}

- (void)deleteFingerprint:(NSString *)idString
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:SAMPLINGS_API_URL, https, server, [@"/" stringByAppendingString:idString]]];
    
    [HLPDataUtil deleteRequest:url withData:nil callback:^(NSData *response) {
        [self loadSamplings:^{
            [_delegate manager:self didSamplingsLoaded:_samplings];
        }];
    }];

}

- (long)beaconsCount
{
    if (!_selectedFloorplan) {
        return 0;
    }
    return [_selectedFloorplan.beacons.features count];
}

- (void)addBeacon:(CLBeacon *)beacon atLat:(double)lat_ Lng:(double)lng_
{
    if (!beacon) {
        return;
    }
    if (!_selectedFloorplan) {
        return;
    }
    
    lat = lat_;
    lng = lng_;
    
    CLLocationCoordinate2D g = CLLocationCoordinate2DMake(lat, lng);
    
    MKMapPoint local = [FingerprintManager convertFromGlobal:g ToLocalWithRefpoint:_selectedRefpoint];
    x = local.x;
    y = local.y;
    
    NSError *error;
    NSDictionary *dic =
    @{
      @"type": @"Feature",
      @"properties": @{
              @"type": @"beacon",
              @"uuid": beacon.proximityUUID.UUIDString,
              @"major": beacon.major,
              @"minor": beacon.minor,
              },
      @"geometry": @{
              @"type": @"Point",
              @"coordinates": @[@(x), @(y)]
              }
      };
    HLPGeoJSONFeature *feature = [MTLJSONAdapter modelOfClass:HLPGeoJSONFeature.class fromJSONDictionary:dic error:&error];

    
    HLPFloorplan *fp = _selectedFloorplan;
    NSMutableArray *features = [[NSMutableArray alloc] initWithArray:fp.beacons.features];
    [features addObject:feature];
    
    NSDictionary *json = @{
        @"type": @"FeatureCollection",
        @"features": [MTLJSONAdapter JSONArrayFromModels:features error:&error]
        };
    HLPGeoJSON *temp =  [MTLJSONAdapter modelOfClass:HLPGeoJSON.class fromJSONDictionary:json error:&error];
    if (!temp) {
        return;
    }
    
    NSDictionary *query = @{@"_id":fp._id};
    NSDictionary *beacons = [MTLJSONAdapter JSONDictionaryFromModel:temp error:&error];
    NSDictionary *update = @{@"$set" : @{@"beacons" : beacons}};
    
    [self requestUpdate:update withQuery:query];
}

- (CLBeacon*)strongestBeacon
{
    CLBeacon *strongest = nil;
    for(CLBeacon *beacon in sampler.visibleBeacons) {
        if (beacon.rssi == 0) {
            continue;
        }
        if (strongest == nil || strongest.rssi < beacon.rssi) {
            strongest = beacon;
        }
    }
    return strongest;
}

- (void)reset
{
    [sampler reset];
}

- (void)removeBeacon:(HLPGeoJSONFeature *)beacon
{
    if (!beacon) {
        return;
    }
    if (!_selectedFloorplan) {
        return;
    }
    
    NSError *error;
    NSArray *features = [_selectedFloorplan.beacons.features mtl_arrayByRemovingObject:beacon];
    NSDictionary *json = @{
                           @"type": @"FeatureCollection",
                           @"features": [MTLJSONAdapter JSONArrayFromModels:features error:&error]
                           };
    HLPGeoJSON *temp =  [MTLJSONAdapter modelOfClass:HLPGeoJSON.class fromJSONDictionary:json error:&error];
    if (!temp) {
        return;
    }
    
    NSDictionary *query = @{@"_id":_selectedFloorplan._id};
    NSDictionary *beacons = [MTLJSONAdapter JSONDictionaryFromModel:temp error:&error];
    NSDictionary *update = @{@"$set" : @{@"beacons" : beacons}};
    
    [self requestUpdate:update withQuery:query];
}

-(void)removeSample:(HLPSampling *)sample
{
    
}

-(void) requestUpdate:(NSDictionary*)update withQuery:(NSDictionary*)query
{
    NSDictionary *data =
    @{
      @"action": @"update",
      @"query": [self stringify:query],
      @"update": [self stringify:update]
    };
    NSLog(@"%@", data);
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:FLOORPLANS_API_URL, https, server, @""]];
    [HLPDataUtil postRequest:url withData:data callback:^(NSData *response) {
        _isSampling = NO;
        if (response) {
            [self loadFloorplans:^{
                [self.delegate manager:self didStatusChanged:_isReady];
            }];
        } else {
            [_delegate manager:self didSendData:nil withError:[NSError errorWithDomain:@"beacon.update" code:0 userInfo:nil]];
        }
    }];
}

- (NSArray<CLBeacon *> *)visibleBeacons
{
    return sampler.visibleBeacons;
}

- (NSString*) getTime
{
    return [NSString stringWithFormat:@"?dummy=%ld", (long)([[NSDate date] timeIntervalSince1970] * 1000)];
}

+ (MKMapPoint) convertFromGlobal:(CLLocationCoordinate2D)global ToLocalWithRefpoint:(HLPRefpoint*)rp
{
    double distance = [HLPLocation distanceFromLat:global.latitude Lng:global.longitude toLat:rp.anchor_lat Lng:rp.anchor_lng];
    double d2r = M_PI / 180;
    double r = [HLPLocation bearingFromLat:rp.anchor_lat Lng:rp.anchor_lng toLat:global.latitude Lng:global.longitude];
    r = (r - rp.anchor_rotate) * d2r;
    
    return MKMapPointMake(distance*sin(r), distance*cos(r));
}

+ (CLLocationCoordinate2D) convertFromLocal:(MKMapPoint)local ToGlobalWithRefpoint:(HLPRefpoint*)rp
{
    HLPLocation *loc = [[HLPLocation alloc] initWithLat:rp.anchor_lat Lng:rp.anchor_lng];
    double r = atan2(local.x, local.y)*180/M_PI + rp.anchor_rotate;
    double d = sqrt(local.x*local.x+local.y*local.y);
    
    loc = [loc offsetLocationByDistance:d Bearing:r];
    return CLLocationCoordinate2DMake(loc.lat, loc.lng);
}

@end
