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

#import <MapKit/MapKit.h>
#import "HLPLocation.h"

//#define EARTH_R 6378137
#define EARTH_R 6371e3

const double d2r = M_PI / 180.0;
const double r2d = 180.0 / M_PI;

@implementation HLPLocation

double(^normalize)(double) = ^(double deg) {
    double x = cos(deg/180*M_PI);
    double y = sin(deg/180*M_PI);
    return atan2(y,x)/M_PI*180;
};


- (instancetype) init
{
    self = [super init];
    _lat = NAN;
    _lng = NAN;
    return self;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    _lat = [[aDecoder decodeObjectForKey:@"lat"] doubleValue];
    _lng = [[aDecoder decodeObjectForKey:@"lng"] doubleValue];
    _accuracy = [[aDecoder decodeObjectForKey:@"accuracy"] doubleValue];
    _floor = [[aDecoder decodeObjectForKey:@"floor"] doubleValue];
    _speed = [[aDecoder decodeObjectForKey:@"speed"] doubleValue];
    _orientation = [[aDecoder decodeObjectForKey:@"orientation"] doubleValue];
    _orientationAccuracy = [[aDecoder decodeObjectForKey:@"orientationAccuracy"] doubleValue];
    _params = [aDecoder decodeObjectForKey:@"params"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[NSNumber numberWithDouble:_lat] forKey:@"lat"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_lng] forKey:@"lng"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_accuracy] forKey:@"accuracy"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_floor] forKey:@"floor"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_speed] forKey:@"speed"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_orientation] forKey:@"orientation"];
    [aCoder encodeObject:[NSNumber numberWithDouble:_orientationAccuracy] forKey:@"orientationAccuracy"];
    [aCoder encodeObject:_params forKey:@"params"];
}

- (instancetype) initWithLat:(double)lat Lng:(double)lng
{
    self = [super init];
    _lat = normalize(lat);
    _lng = normalize(lng);
    return self;
}

- (instancetype) initWithLat:(double)lat Lng:(double)lng Floor:(double)floor
{
    self = [super init];
    _lat = normalize(lat);
    _lng = normalize(lng);
    _floor = floor;
    return self;
}

- (instancetype) initWithLat:(double)lat Lng:(double)lng Accuracy:(double)accuracy Floor:(double)floor Speed:(double)speed Orientation:(double)orientation OrientationAccuracy:(double)orientationAccuracy
{
    self = [super init];
    _lat = normalize(lat);
    _lng = normalize(lng);
    _accuracy = accuracy;
    _floor = floor;
    _speed = speed;
    _orientation = orientation;
    _orientationAccuracy = orientationAccuracy;
    return self;
}

- (BOOL) isEqual:(id)obj
{
    if ([obj isKindOfClass:HLPLocation.class]) {
        HLPLocation *loc = (HLPLocation*)obj;
        return _lat == loc.lat && _lng == loc.lng && _floor == loc.floor;
    }
    return [super isEqual:obj];
}

- (NSString*) description
{
    return [NSString stringWithFormat:@"%f,%f,%f,%f,%f,%f,%f", _lat, _lng, _accuracy, _floor, _speed, _orientation, _orientationAccuracy];
}

- (void) update:(HLPLocation *)loc
{
    if (!loc) {
        return;
    }
    @synchronized (self) {
        _lat = normalize(loc.lat);
        _lng = normalize(loc.lng);
        _accuracy = loc.accuracy;
        _floor = loc.floor;
        _speed = loc.speed;
        _orientation = loc.orientation;
        _orientationAccuracy = loc.orientationAccuracy;
        _params = loc.params;
        _params = loc.params;
    }
}

- (void) updateLat:(double)lat Lng:(double)lng
{
    @synchronized (self) {
        _lat = normalize(lat);
        _lng = normalize(lng);
    }
}

- (void) updateLat:(double)lat Lng:(double)lng Accuracy:(double)accuracy Floor:(double)floor
{
    @synchronized (self) {
        _lat = normalize(lat);
        _lng = normalize(lng);
        _accuracy = accuracy;
        _floor = floor;
    }
}

- (void) updateFloor:(double)floor
{
    @synchronized (self) {
        _floor = floor;
    }
}

- (void) updateSpeed:(double)speed
{
    @synchronized (self) {
        _speed = speed;
    }
}

- (void) updateOrientation:(double)orientation withAccuracy:(double)accuracy
{
    @synchronized (self) {
        double x = cos(orientation/180*M_PI);
        double y = sin(orientation/180*M_PI);
        
        _orientation = atan2(y,x)/M_PI*180;
        _orientationAccuracy = accuracy;
    }
}

- (void)updateParams:(NSDictionary *)params
{
    _params = params;
}

- (double)distanceTo:(HLPLocation *)to
{
    return [HLPLocation distanceFromLat:self.lat Lng:self.lng toLat:to.lat Lng:to.lng];
}

- (double)fastDistanceTo:(HLPLocation *)to
{
    return [HLPLocation fastDistanceFromLat:self.lat Lng:self.lng toLat:to.lat Lng:to.lng];
}

- (double)distanceToLat:(double)lat Lng:(double)lng
{
    return [HLPLocation distanceFromLat:self.lat Lng:self.lng toLat:lat Lng:lng];
}

- (double)bearingTo:(HLPLocation *)to
{
    return [HLPLocation bearingFromLat:self.lat Lng:self.lng toLat:to.lat Lng:to.lng];
}

- (double)bearingToLat:(double)lat Lng:(double)lng
{
    return [HLPLocation bearingFromLat:self.lat Lng:self.lng toLat:lat Lng:lng];
}

+(double)distanceFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2
{
    if (lat1 == lat2 && lng1 == lng2) {
        return 0;
    }

    CLLocation *l1 = [[CLLocation alloc] initWithLatitude:lat1 longitude:lng1];
    CLLocation *l2 = [[CLLocation alloc] initWithLatitude:lat2 longitude:lng2];
    return [l1 distanceFromLocation:l2];
}
    
+(double)fastDistanceFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2
{
    // Haversine Formula
    const double d2r = M_PI / 180;
    const double P = (lat1 + lat2) / 2 * d2r;
    const double dP = (lat1 - lat2) * d2r;
    const double dR = (lng1 - lng2) * d2r;
    const double sinP = sin(P);
    const double PP = 1 - 0.006674 * sinP * sinP;
    const double sqrtPP = sqrt(PP);
    const double M = 6334834.0 / (sqrtPP * PP);
    const double N = 6377397.0 / sqrtPP;
    const double a = M * dP;
    const double b = N * cos(P) * dR;
    return sqrt(a*a + b*b);
}

+ (double)bearingFromLat:(double)lat1 Lng:(double)lng1 toLat:(double)lat2 Lng:(double)lng2
{
    double deltaLng = (lng2 - lng1)*d2r;
    lat1 = lat1*d2r;
    lat2 = lat2*d2r;
    
    double x = cos(lat2) * sin(deltaLng);
    double y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLng);
    return atan2(x,y)*r2d;
}

+(double)normalizeDegree:(double)degree
{
    double x = cos(degree*d2r);
    double y = sin(degree*d2r);
    double a = atan2(y,x);
    
    return a*r2d;
}

- (double)distanceToLineFromLocation:(HLPLocation *)location1 ToLocation:(HLPLocation *)location2
{
    return [[self nearestLocationToLineFromLocation:location1 ToLocation:location2] distanceToLat:_lat Lng:_lng];
}

- (HLPLocation *)nearestLocationToLineFromLocation:(HLPLocation *)location1 ToLocation:(HLPLocation *)location2
{
    MKMapPoint A = MKMapPointForCoordinate(CLLocationCoordinate2DMake(location1.lat, location1.lng));
    MKMapPoint B = MKMapPointForCoordinate(CLLocationCoordinate2DMake(location2.lat, location2.lng));
    MKMapPoint C = MKMapPointForCoordinate(CLLocationCoordinate2DMake(_lat, _lng));
    
    //NSLog(@"%f, %f, %f, %f, %f, %f", A.x, A.y, B.x, B.y, C.x, C.y);
    
    // Distance between A and B
    double distAB = sqrt(pow(A.x - B.x, 2) + pow(A.y - B.y, 2));
    
    // Direction vector from A to B
    double vecABx = (B.x - A.x) / distAB;
    double vecABy = (B.y - A.y) / distAB;
    
    // Time from A to C
    double timeAC = fmax(0, fmin(distAB, vecABx * (C.x - A.x) + vecABy * (C.y - A.y)));
    
    // LatLng of the point
    double x = timeAC * vecABx + A.x;
    double y = timeAC * vecABy + A.y;
    
    // NSLog(@"%f, %f, %f, %f, %f, %f", distAB, vecABx, vecABy, timeAC, x, y);
    CLLocationCoordinate2D target = MKCoordinateForMapPoint(MKMapPointMake(x, y));
    
    return [[HLPLocation alloc] initWithLat:target.latitude Lng:target.longitude];
}

- (HLPLocation *)offsetLocationByDistance:(double)distance Bearing:(double)bearing
{
    double rad = bearing / 180 * M_PI;
    double x = distance * cos(rad);
    double y = distance * sin(rad);
    
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(_lat, _lng);
    MKCoordinateRegion tempRegion = MKCoordinateRegionMakeWithDistance(coord, x, y);
    MKCoordinateSpan tempSpan = tempRegion.span;
    
    double lat2 = _lat + tempSpan.latitudeDelta;
    double lng2 = _lng + tempSpan.longitudeDelta;

    HLPLocation *loc = [[HLPLocation alloc] init];
    [loc update:self];
    [loc updateLat:lat2 Lng:lng2 Accuracy:0 Floor:loc.floor];
    return loc;
}

@end
