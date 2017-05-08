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

- (id)initWithBeacons:(NSArray *)array {
    self = [super init];
    _time = (long long)([[NSDate date] timeIntervalSince1970]*1000);
    beacons = array;
    if (array && [array count] > 0) {
        CLBeacon *b = (CLBeacon*)[array objectAtIndex:0];
        uuid = b.proximityUUID.UUIDString;
    }
    return self;
}

- (id)initWithBeaconsStr:(NSString *)str {
    return self;
}

- (void)setPoint:(HLPPoint3D *)_point {
    point = _point;
}

- (BOOL) needPoint {
    return point != nil;
}

- (NSMutableDictionary *)toJSON:(BOOL)simple {
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    

    [json setValue:[NSNumber numberWithLongLong:self.time ] forKey:@"timestamp"];
    
    if (point) {
        if(!simple) {[json setValue:@"Beacon" forKey:@"type"];}
        if(!simple) {[json setValue:[NSNumber numberWithFloat:point.x] forKey:@"x"];}
        if(!simple) {[json setValue:[NSNumber numberWithFloat:point.y] forKey:@"y"];}
        if(!simple) {[json setValue:[NSNumber numberWithFloat:point.z] forKey:@"z"];}
        if(!simple) {[json setValue:point.floor forKey:@"floor"];}
    }
    NSMutableArray *ba = [[NSMutableArray alloc] init];
    for(int i = 0; i < [beacons count]; i++) {
        CLBeacon *b = (CLBeacon*)[beacons objectAtIndex:i];
        NSMutableDictionary *bd = [[NSMutableDictionary alloc] init];
        [bd setObject:b.major forKey:@"major"];
        [bd setObject:b.minor forKey:@"minor"];
        [bd setObject:[NSNumber numberWithInteger:b.rssi] forKey:@"rssi"];
        [ba addObject:bd];
    }
    [json setValue:uuid forKey:@"uuid"];
    [json setValue:ba forKey:@"data"];
    
    return json;
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"Beacon(%ld)",(unsigned long)[beacons count]];
}

- (NSString *)getUUID {
    return uuid;
}

@end
