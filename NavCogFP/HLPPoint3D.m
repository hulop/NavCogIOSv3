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
#import "HLPPoint3D.h"

@implementation HLPPoint3D

- (id)initWithX:(float)x Y:(float)y Z:(float)z Floor:(NSString*)floor {
    self = [super init];
    self.x = x;
    self.y = y;
    self.z = z;
    self.floor = floor;
    self.time = (long long)([[NSDate date] timeIntervalSince1970]*1000);
    return self;
}

- (NSDictionary*) toJSON
{
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    [json setObject:[NSNumber numberWithDouble:self.x] forKey:@"x"];
    [json setObject:[NSNumber numberWithDouble:self.y] forKey:@"y"];
    [json setObject:[NSNumber numberWithDouble:self.z] forKey:@"z"];
    if (self.floor)
        [json setObject:self.floor forKey:@"floor"];
    
    return json;
}

- (BOOL)isEqual:(id)object
{
    return [self x] == [object x] && [self y] == [object y] && [self z] == [object z];
}

+ (HLPPoint3D *)interpolateFrom:(HLPPoint3D*)from To:(HLPPoint3D *)to inTime:(long long)time {
    float ratio = ((float)(time - from.time))/((float)(to.time - from.time));
    return [HLPPoint3D interpolateFrom:from To:to inRatio:ratio];
}

+ (HLPPoint3D *)interpolateFrom:(HLPPoint3D *)from To:(HLPPoint3D *)to inRatio:(float)ratio {
    if (ratio < 0 || 1 < ratio) {
        return nil;
    }
    
    HLPPoint3D *newPoint = [[HLPPoint3D alloc] init];
    newPoint.x = from.x + (to.x-from.x)*ratio;
    newPoint.y = from.y + (to.y-from.y)*ratio;
    newPoint.z = from.z + (to.z-from.z)*ratio;
    newPoint.time = from.time + (to.time-from.time)*ratio;
    if (ratio <= 0.5) {
        newPoint.floor = from.floor;
    } else {
        newPoint.floor = to.floor;
    }
    return newPoint;
}

- (float) distanceTo:(HLPPoint3D *)point {
    float d = pow(self.x - point.x,2) + pow(self.y-point.y,2) + pow(self.z-point.z,2);
    return sqrt(d);
}

- (NSString*) description
{
    if (self.floor) {
        return [NSString stringWithFormat:@"x=%.1f, y=%.1f, z=%.1f, floor=%@", self.x, self.y, self.z, self.floor];
    } else {
        return [NSString stringWithFormat:@"x=%.1f, y=%.1f, z=%.1f", self.x, self.y, self.z];
    }
}

@end
