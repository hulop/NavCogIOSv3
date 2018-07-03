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

#import "HLPBeaconSample.h"
#import <UIKit/UIKit.h>

@implementation HLPBeaconSample

- (instancetype)copyWithZone:(NSZone *)zone
{
    HLPBeaconSample* result = [[HLPBeaconSample allocWithZone:zone] initWithBeacons:self.beacons atPoint:self.point];    
    if (result) {
        result->_timestamp = self.timestamp;
    }
    return result;
}

- (BOOL)isEqual:(HLPBeaconSample*)object
{
    if (![object isKindOfClass: HLPBeaconSample.class]) {
        return NO;
    }
    return self.timestamp == object.timestamp;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%ld beacons sample (%lld)", _beacons.count, _timestamp];
}

- (id)initWithBeacons:(NSArray<CLBeacon*> *)array {
    self = [super init];
    _timestamp = (long long)([[NSDate date] timeIntervalSince1970]*1000);
    if (array && [array count] > 0) {
        _uuidString = [[[array objectAtIndex:0] proximityUUID] UUIDString];
    }
    return self;
}

- (instancetype)initWithBeacons:(NSArray *)array atPoint:(HLPPoint3D *)point {
    self = [super init];
    _timestamp = (long long)([[NSDate date] timeIntervalSince1970]*1000);
    if (array && [array count] > 0) {
        _uuidString = [[[array objectAtIndex:0] proximityUUID] UUIDString];
    }
    _beacons = array;
    _point = point;
    return self;
}

- (void) transform2D:(CGAffineTransform)param
{
    [_point transform2D:param];
}

- (NSDictionary *)toJSONByType:(HLPBeaconSamplesType)type withInfo:(NSDictionary *)optionalInfo
{
    NSMutableDictionary *json = [@{} mutableCopy];

    if (type == HLPBeaconSamplesBeacon) {
        NSMutableArray *data = [@[] mutableCopy];
        for(CLBeacon *b in _beacons) {
            [data addObject:@{
                              @"major": b.major,
                              @"minor": b.minor,
                              @"rssi": @(b.rssi)
                              }];
        }
        json[@"timestamp"] = @(_timestamp);
        json[@"data"] = data;
        json[@"uuid"] = _uuidString;
    }
    if (type == HLPBeaconSamplesRaw) {
        NSMutableDictionary *data = [@{} mutableCopy];
        NSMutableArray *beacons = [@[] mutableCopy];
        for(CLBeacon *b in _beacons) {
            [beacons addObject:@{
                              @"type": @"iBeacon",
                              @"rssi": @(b.rssi),
                              @"id": [NSString stringWithFormat:@"%@-%@-%@", b.proximityUUID.UUIDString, b.major, b.minor],
                              @"timestamp": @(_timestamp)
                              }];
        }
        data[@"beacons"] = beacons;
        data[@"timestamp"] = @(_timestamp);
        
        json[@"information"] = [optionalInfo?optionalInfo:@{} mutableCopy];
        json[@"information"][@"x"] = @(_point.x);
        json[@"information"][@"y"] = @(_point.y);

        json[@"data"] = data;
    }
    return json;
}

@end
    
    
@implementation HLPBeaconSamples


- (instancetype)initWithType:(HLPBeaconSamplesType)type {
    self = [super init];
    _type = type;
    return self;
}

- (void)transform2D:(CGAffineTransform)param
{
    for(HLPBeaconSample* sample in _samples) {
        [sample transform2D:param];
    }
}


- (void)addBeacons:(NSArray<CLBeacon *> *)beacons atPoint:(HLPPoint3D *)point
{
    HLPBeaconSample *sample = [[HLPBeaconSample alloc] initWithBeacons:beacons atPoint:point];
    if (_samples == nil) {
        _samples = @[sample];
    } else {
        _samples = [_samples arrayByAddingObject:sample];
    }
}

- (NSArray *)toJSON:(NSDictionary *)optionalInfo {
    NSMutableArray *json = [@[] mutableCopy];
    
    if (_type == HLPBeaconSamplesBeacon) {
        NSMutableDictionary *obj = [@{} mutableCopy];
        NSMutableDictionary *info = [optionalInfo?optionalInfo:@{} mutableCopy];
        NSMutableArray<NSDictionary*> *beacons = [@[] mutableCopy];
        
        for(HLPBeaconSample* sample in _samples) {
            [beacons addObject:[sample toJSONByType:_type withInfo:nil]];
            info[@"x"] = @(sample.point.x);
            info[@"y"] = @(sample.point.y);
        }
        
        obj[@"information"] = info;
        obj[@"beacons"] = beacons;
        [json addObject:obj];
    }
    if (_type == HLPBeaconSamplesRaw) {
        for(HLPBeaconSample* sample in _samples) {
            [json addObject:[sample toJSONByType:_type withInfo:optionalInfo]];
        }        
    }
    return json;
}

- (NSInteger)count
{
    return [_samples count];
}

@end
