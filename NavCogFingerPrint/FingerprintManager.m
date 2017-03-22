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
#import <MapKit/MapKit.h>
#import <sys/types.h>
#import <sys/sysctl.h>

#define SAMPLINGS_API_URL @"%@://%@/LocationService/data/samplings"
#define FLOORPLANS_API_URL @"%@://%@/LocationService/data/floorplans"
#define REFPOINTS_API_URL @"%@://%@/LocationService/data/refpoints"

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

- (void)select:(HLPRefpoint *)rp
{
    _selectedRefpoint = rp;
    [_delegate manager:self didStatusChanged:_isReady];
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
}

- (void) loadFloorplans:(void(^)(void))complete
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:FLOORPLANS_API_URL, https, server]];
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if ([result isKindOfClass:NSArray.class]) {
            NSArray *fs = (NSArray*)result;
            NSMutableArray *temp = [@[] mutableCopy];
            for (NSDictionary *dic in fs) {
                NSError *error;
                HLPFloorplan *fp = [MTLJSONAdapter modelOfClass:HLPFloorplan.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    [temp addObject:fp];
                }
            }
            _floorplans = temp;
            complete();
            //NSLog(@"%@", floorplans);
        }
    }];
}

- (void) loadRefpoints:(void(^)(void))complete
{
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:REFPOINTS_API_URL, https, server]];
    [HLPDataUtil getJSON:url withCallback:^(NSObject *result) {
        if ([result isKindOfClass:NSArray.class]) {
            NSArray *rs = (NSArray*)result;
            _refpoints = [@{} mutableCopy];
            for (NSDictionary *dic in rs) {
                NSError *error;
                HLPRefpoint *rp = [MTLJSONAdapter modelOfClass:HLPRefpoint.class fromJSONDictionary:dic error:&error];
                if (error) {
                    NSLog(@"%@", error);
                    NSLog(@"%@", dic);
                } else {
                    NSString *refid = rp.refid[@"$oid"];
                    if (refid) {
                        if (rp.x == 0 && rp.y == 0) {
                            _refpoints[refid] = rp;
                        }
                    }
                }
            }
            //NSLog(@"%@", refpoints);
            complete();
        }
    }];
}

- (BOOL) createRefpointForFloorplan:(HLPFloorplan*)fp withComplete:(void(^)(void)) complete
{
    if (_refpoints[fp._id[@"$oid"]]) {
        return false;
    }
    
    NSString *https = [[NSUserDefaults standardUserDefaults] boolForKey:@"https_connection"]?@"https":@"http";
    NSString *server = [[ServerConfig sharedConfig] fingerPrintingServerHost];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:REFPOINTS_API_URL, https, server]];
    
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
            NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:response options:0 error:nil];
            NSError *error;
            HLPRefpoint *rp = [MTLJSONAdapter modelOfClass:HLPRefpoint.class fromJSONDictionary:dic error:&error];
            if (error) {
                NSLog(@"%@", error);
                NSLog(@"%@", dic);
            } else {
                NSString *refid = rp.refid[@"$oid"];
                if (refid) {
                    if (rp.x == 0 && rp.y == 0) {
                        _refpoints[refid] = rp;
                    }
                }
            }
            complete();
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
    MKMapPoint gm = MKMapPointForCoordinate(g);
    
    CLLocationCoordinate2D a = CLLocationCoordinate2DMake(_selectedRefpoint.anchor_lat, _selectedRefpoint.anchor_lng);
    MKMapPoint am = MKMapPointForCoordinate(a);
    
    CLLocationDistance distance = MKMetersBetweenMapPoints(gm, am);
    double r = atan2(gm.y-am.y, gm.x-am.x) - _selectedRefpoint.anchor_rotate / 180 * M_PI;
    
    x = distance*cos(r);
    y = -distance*sin(r);
    
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
            [self sendData];
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
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:SAMPLINGS_API_URL, https, server]];
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
            }
        } else {
            [_delegate manager:self didSendData:nil withError:[NSError errorWithDomain:@"beacon.send" code:0 userInfo:nil]];
        }
    }];
    
    [sampler reset];
}

- (void)deleteFingerprint:(NSString *)idString
{
    
}

@end
