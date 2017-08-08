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

#import <Foundation/Foundation.h>

@interface HLPLocation : NSObject <NSCoding>
@property (readonly) double lat;
@property (readonly) double lng;
@property (readonly) double accuracy;
@property (readonly) double floor;
@property (readonly) double speed;
@property (readonly) double orientation;
@property (readonly) double orientationAccuracy;
@property (readonly) NSDictionary *params;

- (instancetype)initWithLat:(double)lat Lng:(double)lng;
- (instancetype)initWithLat:(double)lat Lng:(double)lng Floor:(double)floor;
- (instancetype)initWithLat:(double)lat Lng:(double)lng Accuracy:(double)accuracy Floor:(double)floor Speed:(double)speed Orientation:(double)orientation OrientationAccuracy:(double)orientationAccuracy;

- (void) update:(HLPLocation*)loc;
- (void) updateLat:(double)lat Lng:(double)lng;
- (void) updateLat:(double)lat Lng:(double)lng Accuracy:(double)accuracy Floor:(double)floor;
- (void) updateFloor:(double)floor;
- (void) updateSpeed:(double)speed;
- (void) updateOrientation:(double)orientation withAccuracy:(double)accuracy;
- (void) updateParams:(NSDictionary*)params;

- (double)distanceTo:(HLPLocation*)to;
- (double)fastDistanceTo:(HLPLocation*)to;
- (double)distanceToLat:(double)lat Lng:(double)lng;
- (double)bearingTo:(HLPLocation*)to;
- (double)bearingToLat:(double)lat Lng:(double)lng;
+ (double)distanceFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2;
+ (double)fastDistanceFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2;
+ (double)bearingFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2;
+ (double)normalizeDegree:(double)degree;
- (double)distanceToLineFromLocation:(HLPLocation*)location1 ToLocation:(HLPLocation*)location2;
- (HLPLocation*)nearestLocationToLineFromLocation:(HLPLocation*)location1 ToLocation:(HLPLocation*)location2;
- (HLPLocation*)offsetLocationByDistance:(double)distance Bearing:(double)bearing;
@end
