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

- (id)initWithX:(float)x Y:(float)y Z:(float)z Floor:(int)floor {
    self = [super init];
    _x = x;
    _y = y;
    _z = z;
    _floor = floor;
    return self;
}

- (NSDictionary*) toJSON
{
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    [json setObject:@(_x) forKey:@"x"];
    [json setObject:@(_y) forKey:@"y"];
    [json setObject:@(_z) forKey:@"z"];
    [json setObject:@(_floor) forKey:@"floor"];
    
    return json;
}

- (BOOL)isEqual:(id)object
{
    return _x == [object x] && _y == [object y] && _z == [object z];
}

- (void)transform2D:(CGAffineTransform)param
{
    CGPoint point = CGPointApplyAffineTransform(CGPointMake(_x, _y), param);
    _x = point.x;
    _y = point.y;
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"x=%.1f, y=%.1f, z=%.1f, floor=%d", self.x, self.y, self.z, self.floor];
}

@end
